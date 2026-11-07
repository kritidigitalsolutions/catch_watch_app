import 'dart:async';
import 'dart:io';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../res/appUrl.dart';

enum VisibilityOption { public, private }

enum PickError { none, tooLarge, cancelled, unsupported, tooLong, tooShort }

class VideoUploadProvider extends ChangeNotifier {
  final ReelsRepository _reelsRepository = ReelsRepository();
  static final ImagePicker _picker = ImagePicker();

  // ── Validation limits ─────────────────────────────────────────────────────
  static const double maxFileMB = 100;
  static const Duration maxReelDuration = Duration(seconds: 90);
  static const Duration minReelDuration = Duration(seconds: 1);
  static const List<String> allowedVideoExtensions = ['mp4', 'mov', 'm4v'];

  // ── Picked file ──────────────────────────────────────────────────────────
  XFile? _pickedFile;
  XFile? _thumbnailFile; // cover explicitly chosen by the user
  XFile? _generatedThumbnail; // cover auto-generated from the video
  Duration? _videoDuration;
  double _fileSizeMB = 0;
  bool _isPicking = false;
  PickError _pickError = PickError.none;

  // ── Trim ─────────────────────────────────────────────────────────────────
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  XFile? _trimmedFile;
  bool _isTrimming = false;

  // ── Upload ───────────────────────────────────────────────────────────────
  double _uploadProgress = 0;
  bool _isUploading = false;
  bool _uploadComplete = false;
  bool _uploadCancelled = false;
  String? _uploadError;
  dio.CancelToken? _cancelToken;
  int _lastNotifiedPercent = -1;

  // ── Recovery ───────────────────────────────────────────────────────────
  bool _wasDataRecovered = false;
  bool get wasDataRecovered => _wasDataRecovered;

  void consumeRecoveredData() {
    _wasDataRecovered = false;
    notifyListeners();
  }

  // ── Form ─────────────────────────────────────────────────────────────────
  final TextEditingController titleController = TextEditingController();
  final TextEditingController captionController = TextEditingController();
  final TextEditingController hashtagsController = TextEditingController(
    text: '#Movies #Action #Entertainment',
  );

  VisibilityOption _visibility = VisibilityOption.public;

  // ── Getters ───────────────────────────────────────────────────────────────
  XFile? get pickedFile => _pickedFile;
  XFile? get manualThumbnail => _thumbnailFile;
  XFile? get generatedThumbnail => _generatedThumbnail;

  /// Best available cover: an explicit pick wins over the auto-generated frame.
  XFile? get thumbnailFile => _thumbnailFile ?? _generatedThumbnail;
  bool get hasThumbnail => thumbnailFile != null;
  Duration? get videoDuration => _videoDuration;
  double get fileSizeMB => _fileSizeMB;
  bool get isPicking => _isPicking;
  PickError get pickError => _pickError;
  bool get hasFile => _pickedFile != null;

  Duration get trimStart => _trimStart;
  Duration get trimEnd => _trimEnd;
  bool get hasTrim => _trimmedFile != null;
  bool get isTrimming => _isTrimming;

  /// The file that will actually be uploaded: the trimmed clip if one exists,
  /// otherwise the original pick.
  XFile? get effectiveVideoFile => _trimmedFile ?? _pickedFile;

  double get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;
  bool get uploadComplete => _uploadComplete;
  String? get uploadError => _uploadError;

  String get fileName => effectiveVideoFile?.name ?? '';
  int get uploadPercent => (_uploadProgress * 100).toInt();

  VisibilityOption get visibility => _visibility;
  bool get isFormValid => hasFile && !_isTrimming;

  VideoUploadProvider() {
    captionController.addListener(() {
      notifyListeners();
    });
    // Check for lost data on initialization (essential for Android)
    handleLostData();
  }

  Future<void> handleLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return;
      }
      if (response.file != null) {
        if (response.type == RetrieveType.video) {
          debugPrint("✅ Recovered lost video: ${response.file!.path}");
          await _processPickedVideo(response.file!);
          _wasDataRecovered = true;
          notifyListeners();
        } else if (response.type == RetrieveType.image) {
          debugPrint("✅ Recovered lost thumbnail: ${response.file!.path}");
          _thumbnailFile = response.file;
          _wasDataRecovered = true;
          notifyListeners();
        }
      } else if (response.exception != null) {
        debugPrint("❌ Lost data error: ${response.exception!.code}");
        _uploadError = "Failed to recover selection: ${response.exception!.message}";
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Lost data check failed: $e");
    }
  }

  void reset() {
    _pickedFile = null;
    _thumbnailFile = null;
    _generatedThumbnail = null;
    _videoDuration = null;
    _trimmedFile = null;
    _trimStart = Duration.zero;
    _trimEnd = Duration.zero;
    _isTrimming = false;
    _fileSizeMB = 0;
    _isPicking = false;
    _pickError = PickError.none;
    _uploadProgress = 0;
    _isUploading = false;
    _uploadComplete = false;
    _uploadCancelled = false;
    _uploadError = null;
    _cancelToken = null;
    _lastNotifiedPercent = -1;

    titleController.clear();
    captionController.clear();
    hashtagsController.text = '#Movies #Action #Entertainment';
    _visibility = VisibilityOption.public;

    notifyListeners();
  }

  Future<bool> _checkPermissions(ImageSource source, {bool isVideo = true}) async {
    if (!Platform.isAndroid) return true;

    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        debugPrint("Camera permission: $cameraStatus");
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) return false;

        if (isVideo) {
          final micStatus = await Permission.microphone.request();
          debugPrint("Microphone permission: $micStatus");
          if (micStatus.isDenied || micStatus.isPermanentlyDenied) return false;
        }
        return true;
      } else {
        // Gallery / Storage
        // For Android 13+ (API 33), we use READ_MEDIA_VIDEO / READ_MEDIA_IMAGES
        // The permission_handler uses Permission.videos and Permission.photos for these.

        List<Permission> permissionsToRequest = [];

        if (isVideo) {
          permissionsToRequest.add(Permission.videos);
        } else {
          permissionsToRequest.add(Permission.photos);
        }

        // Add storage as a fallback for older Android versions
        permissionsToRequest.add(Permission.storage);

        final statuses = await permissionsToRequest.request();

        bool granted = false;
        if (isVideo) {
          granted = statuses[Permission.videos]?.isGranted == true ||
                    statuses[Permission.storage]?.isGranted == true;
          debugPrint("Video Permission: ${statuses[Permission.videos]}, Storage: ${statuses[Permission.storage]}");
        } else {
          granted = statuses[Permission.photos]?.isGranted == true ||
                    statuses[Permission.storage]?.isGranted == true;
          debugPrint("Photo Permission: ${statuses[Permission.photos]}, Storage: ${statuses[Permission.storage]}");
        }

        // On some devices, the Map might not reflect accurately if already granted
        if (!granted) {
          if (isVideo) {
             granted = await Permission.videos.isGranted || await Permission.storage.isGranted;
          } else {
             granted = await Permission.photos.isGranted || await Permission.storage.isGranted;
          }
        }

        return granted;
      }
    } catch (e) {
      debugPrint("Permission check error: $e");
      return true; // Fallback to let the picker try anyway
    }
  }

  // ── Pick video from camera or gallery ───────────────────────────────────────
  Future<void> pickVideo({ImageSource source = ImageSource.gallery}) async {
    _isPicking = true;
    _pickError = PickError.none;
    _uploadError = null;
    notifyListeners();

    try {
      final hasPermission = await _checkPermissions(source, isVideo: true);
      debugPrint("Permission check result: $hasPermission");

      if (!hasPermission) {
        _isPicking = false;
        _uploadError = source == ImageSource.camera
            ? "Camera and microphone access is required to record a video."
            : "Photo library access is required to pick a video.";
        notifyListeners();
        return;
      }

      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: source == ImageSource.camera ? maxReelDuration : null,
      );

      if (file == null) {
        debugPrint("Video picking returned null. Checking for lost data...");

        // Fallback for Android activity destruction
        final LostDataResponse response = await _picker.retrieveLostData();
        if (response.file != null) {
           debugPrint("✅ Recovered video from lost data: ${response.file!.path}");
           await _processPickedVideo(response.file!);
           return;
        }

        debugPrint("Video picking definitely returned null (likely cancelled)");
        _isPicking = false;
        notifyListeners();
        return;
      }

      debugPrint("Video picked successfully: ${file.path}");
      await _processPickedVideo(file);
    } catch (e) {
      debugPrint("❌ PICK ERROR: $e");
      _pickError = PickError.unsupported;
      _uploadError = "Failed to pick video: $e";
      _isPicking = false;
      notifyListeners();
    }
  }

  /// Validates the picked file (type, size, duration) before accepting it.
  /// A rejected pick sets [pickError] and leaves the previous selection intact.
  Future<void> _processPickedVideo(XFile file) async {
    final pickedFile = File(file.path);

    // 1. File type validation
    final nameParts = file.name.split('.');
    final extension = nameParts.length > 1 ? nameParts.last.toLowerCase() : '';
    if (extension.isEmpty || !allowedVideoExtensions.contains(extension)) {
      debugPrint("❌ Unsupported extension: $extension");
      _pickError = PickError.unsupported;
      _isPicking = false;
      notifyListeners();
      return;
    }

    // 2. File size validation
    int bytes = 0;
    try {
      bytes = await pickedFile.length();
    } catch (e) {
      debugPrint("Error getting file length: $e");
    }

    final sizeMB = bytes / (1024 * 1024);
    if (bytes > 0 && sizeMB > maxFileMB) {
      _pickError = PickError.tooLarge;
      _isPicking = false;
      notifyListeners();
      return;
    }

    // 3. Duration validation
    final duration = await _probeDuration(file.path);
    if (duration != null) {
      if (duration > maxReelDuration) {
        debugPrint("❌ Video too long: $duration");
        _pickError = PickError.tooLong;
        _isPicking = false;
        notifyListeners();
        return;
      }
      if (duration < minReelDuration) {
        debugPrint("❌ Video too short: $duration");
        _pickError = PickError.tooShort;
        _isPicking = false;
        notifyListeners();
        return;
      }
    }

    _pickedFile = file;
    _fileSizeMB = double.parse(sizeMB.toStringAsFixed(1));
    _videoDuration = duration;

    // A fresh pick invalidates any previous cover / trim.
    _thumbnailFile = null;
    _generatedThumbnail = null;
    _trimmedFile = null;
    _trimStart = Duration.zero;
    _trimEnd = duration ?? Duration.zero;

    _uploadProgress = 0;
    _uploadComplete = false;
    _pickError = PickError.none;
    _isPicking = false;
    notifyListeners();

    // Generate a cover frame from the video automatically.
    unawaited(_generateThumbnail(file.path));
  }

  /// Reads the duration of a local video without keeping a player alive.
  Future<Duration?> _probeDuration(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      return controller.value.duration;
    } catch (e) {
      debugPrint("Duration probe failed: $e");
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Extracts a poster frame from the video and exposes it as the default cover.
  Future<void> _generateThumbnail(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
        timeMs: 0,
      );
      if (path == null) return;
      _generatedThumbnail = XFile(path);
      notifyListeners();
    } catch (e) {
      debugPrint("Auto thumbnail generation failed: $e");
    }
  }

  Future<void> pickThumbnail() async {
    _uploadError = null;
    try {
      final hasPermission = await _checkPermissions(ImageSource.gallery, isVideo: false);
      debugPrint("Thumbnail permission check result: $hasPermission");

      if (!hasPermission) {
        _uploadError = "Photo library access is required to pick a cover image.";
        notifyListeners();
        return;
      }

      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (file != null) {
        debugPrint("Thumbnail picked: ${file.path}");
        _thumbnailFile = file;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking thumbnail: $e");
      _uploadError = "Failed to pick thumbnail: $e";
      notifyListeners();
    }
  }

  // ── Trim ──────────────────────────────────────────────────────────────────
  void setTrim({required Duration start, required Duration end}) {
    _trimStart = start;
    _trimEnd = end;
    notifyListeners();
  }

  void setTrimming(bool value) {
    _isTrimming = value;
    notifyListeners();
  }

  /// Records the trimmed clip produced by the trim editor.
  Future<void> setTrimmedFile(XFile? file) async {
    _trimmedFile = file;
    if (file != null) {
      try {
        final bytes = await File(file.path).length();
        _fileSizeMB = double.parse((bytes / (1024 * 1024)).toStringAsFixed(1));
      } catch (e) {
        debugPrint("Error getting trimmed file length: $e");
      }
    }
    notifyListeners();
  }

  void clearTrim() {
    _trimmedFile = null;
    _trimStart = Duration.zero;
    _trimEnd = _videoDuration ?? Duration.zero;
    notifyListeners();
  }

  void setVisibility(VisibilityOption option) {
    _visibility = option;
    notifyListeners();
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  /// Aborts an in-flight upload. Dio throws a cancel error which [publish]
  /// handles as a user-initiated cancellation rather than a failure.
  void cancelUpload() {
    if (!_isUploading) return;
    _uploadCancelled = true;
    _cancelToken?.cancel('User cancelled the upload');
    notifyListeners();
  }

  Future<bool> publish() async {
    if (_pickedFile == null) {
      _uploadError = "Please select a video";
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadCancelled = false;
    _uploadError = null;
    _uploadProgress = 0.0;
    _lastNotifiedPercent = -1;
    _cancelToken = dio.CancelToken();
    notifyListeners();

    try {
      final hashtagsText = hashtagsController.text.trim();
      List<String> hashtagsList = [];
      if (hashtagsText.isNotEmpty) {
        // Normalise to a de-duplicated list of `#tag` values.
        final seen = <String>{};
        for (final raw in hashtagsText.split(RegExp(r'\s+'))) {
          final trimmed = raw.trim();
          if (trimmed.isEmpty) continue;
          final tag = trimmed.startsWith('#') ? trimmed : '#$trimmed';
          if (seen.add(tag.toLowerCase())) hashtagsList.add(tag);
        }
      }

      // Prefer the trimmed clip when the user applied a trim.
      final uploadFile = effectiveVideoFile!;
      final String videoPath = uploadFile.path;
      final String videoFileName = uploadFile.name;

      // Map common extensions to MIME types
      final String videoMimeType = lookupMimeType(videoPath) ?? 'video/mp4';

      final Map<String, dynamic> dataMap = {
        'title': titleController.text.trim().isEmpty ? 'New Reel' : titleController.text.trim(),
        'caption': captionController.text.trim(),
        // Dio's FormData.fromMap with the default ListFormat.multi serialises a
        // List into repeated `hashtags` multipart fields, which Multer-style
        // backends parse back into an array.
        'hashtags': hashtagsList,
        'visibility': _visibility == VisibilityOption.private ? 'private' : 'public',
        'video': await dio.MultipartFile.fromFile(
          videoPath,
          filename: videoFileName,
          contentType: dio.DioMediaType.parse(videoMimeType),
        ),
      };

      final thumb = thumbnailFile;
      if (thumb != null) {
        final String thumbPath = thumb.path;
        final String thumbFileName = thumb.name;
        final String thumbMimeType = lookupMimeType(thumbPath) ?? 'image/jpeg';

        dataMap['thumbnail'] = await dio.MultipartFile.fromFile(
          thumbPath,
          filename: thumbFileName,
          contentType: dio.DioMediaType.parse(thumbMimeType),
        );
      }

      final formData = dio.FormData.fromMap(dataMap);

      debugPrint("📤 Uploading Reel: $videoFileName (${_fileSizeMB}MB)");
      debugPrint("📤 Endpoint: ${AppUrl.uploadReel}");

      final response = await _reelsRepository.uploadReel(
        formData,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          _uploadProgress = sent / total;
          // Throttle UI notifications to whole-percent changes to avoid
          // rebuilding on every network chunk.
          final percent = (_uploadProgress * 100).floor();
          if (percent != _lastNotifiedPercent) {
            _lastNotifiedPercent = percent;
            notifyListeners();
          }
        },
      );

      if (kDebugMode) {
        debugPrint("✅ Upload Response: $response");
      }

      bool isSuccess = false;
      String? message;

      if (response is Map) {
        isSuccess = response['success'] == true ||
                    response['status'] == 'success' ||
                    response['status'] == 200 ||
                    response['statusCode'] == 200;
        message = response['message']?.toString();
      }

      if (isSuccess) {
        _uploadProgress = 1.0;
        _uploadComplete = true;
        _isUploading = false;
        notifyListeners();
        return true;
      } else {
        _uploadError = message ?? 'Server failed to process the upload';
        _isUploading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // A cancellation is not a failure — clear state without an error message.
      if (_uploadCancelled) {
        debugPrint("ℹ️ Upload cancelled by user");
        _isUploading = false;
        _uploadError = null;
        _uploadProgress = 0;
        _lastNotifiedPercent = -1;
        notifyListeners();
        return false;
      }

      debugPrint("❌ UPLOAD ERROR: $e");

      if (e is dio.DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (responseData is Map && responseData.containsKey('message')) {
          _uploadError = responseData['message'].toString();
        } else if (statusCode == 413) {
          _uploadError = "File too large for the server.";
        } else {
          _uploadError = "Network error (${e.type}). Please try again.";
        }
      } else {
        _uploadError = e.toString().replaceAll("Exception:", "").trim();
      }

      if (_uploadError == null || _uploadError!.isEmpty) {
        _uploadError = "Upload failed. Please check your connection or video size.";
      }

      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  String? get pickErrorMessage {
    if (_uploadError != null && (_pickError == PickError.unsupported || _pickError == PickError.none)) {
      return _uploadError;
    }
    switch (_pickError) {
      case PickError.tooLarge:
        return 'Video exceeds ${maxFileMB.toInt()} MB. Please choose a smaller file.';
      case PickError.tooLong:
        return 'Video is too long. Reels can be up to ${maxReelDuration.inSeconds} seconds.';
      case PickError.tooShort:
        return 'Video is too short. Please choose a clip of at least ${minReelDuration.inSeconds} second.';
      case PickError.unsupported:
        return 'Unsupported file. Please choose an MP4 or MOV video.';
      case PickError.cancelled:
      case PickError.none:
        return null;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    captionController.dispose();
    hashtagsController.dispose();
    super.dispose();
  }
}
