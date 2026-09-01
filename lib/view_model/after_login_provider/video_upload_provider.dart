import 'dart:io';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';

import '../../res/appUrl.dart';

enum VisibilityOption { public, private }

enum PickError { none, tooLarge, cancelled, unsupported }

class VideoUploadProvider extends ChangeNotifier {
  final ReelsRepository _reelsRepository = ReelsRepository();
  static final ImagePicker _picker = ImagePicker();

  // ── Picked file ──────────────────────────────────────────────────────────
  XFile? _pickedFile;
  XFile? _thumbnailFile;
  double _fileSizeMB = 0;
  bool _isPicking = false;
  PickError _pickError = PickError.none;

  // ── Upload ───────────────────────────────────────────────────────
  double _uploadProgress = 0;
  bool _isUploading = false;
  bool _uploadComplete = false;
  String? _uploadError;

  // ── Recovery ───────────────────────────────────────────────────────
  bool _wasDataRecovered = false;
  bool get wasDataRecovered => _wasDataRecovered;

  void consumeRecoveredData() {
    _wasDataRecovered = false;
    notifyListeners();
  }

  // ── Form ─────────────────────────────────────────────────────────────────
  final TextEditingController titleController = TextEditingController();
  final TextEditingController captionController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController hashtagsController = TextEditingController(
    text: '#Movies #Action #Entertainment',
  );

  VisibilityOption _visibility = VisibilityOption.public;

  // ── Getters ───────────────────────────────────────────────────────────────
  XFile? get pickedFile => _pickedFile;
  XFile? get thumbnailFile => _thumbnailFile;
  double get fileSizeMB => _fileSizeMB;
  bool get isPicking => _isPicking;
  PickError get pickError => _pickError;
  bool get hasFile => _pickedFile != null;
  bool get hasThumbnail => _thumbnailFile != null;

  double get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;
  bool get uploadComplete => _uploadComplete;
  String? get uploadError => _uploadError;

  // Backwards-compat helpers used in card widget
  String get fileName => _pickedFile?.name ?? '';
  int get uploadPercent => (_uploadProgress * 100).toInt();

  VisibilityOption get visibility => _visibility;
  bool get isFormValid => hasFile;

  static const double maxFileMB = 100;

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
    _fileSizeMB = 0;
    _isPicking = false;
    _pickError = PickError.none;
    _uploadProgress = 0;
    _isUploading = false;
    _uploadComplete = false;
    _uploadError = null;

    titleController.clear();
    captionController.clear();
    commentController.clear();
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
        _uploadError = "Storage permission is required to pick videos.";
        notifyListeners();
        return;
      }

      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: source == ImageSource.camera ? const Duration(minutes: 30) : null,
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

  Future<void> _processPickedVideo(XFile file) async {
    final pickedFile = File(file.path);

    // Check file size
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

    _pickedFile = file;
    _fileSizeMB = double.parse(sizeMB.toStringAsFixed(1));

    // Reset thumbnail when a new video is picked
    _thumbnailFile = null;

    _uploadProgress = 0;
    _uploadComplete = false;
    _isPicking = false;
    notifyListeners();
  }

  Future<void> pickThumbnail() async {
    _uploadError = null;
    try {
      final hasPermission = await _checkPermissions(ImageSource.gallery, isVideo: false);
      debugPrint("Thumbnail permission check result: $hasPermission");

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

  void setVisibility(VisibilityOption option) {
    _visibility = option;
    notifyListeners();
  }

  Future<bool> publish() async {
    if (_pickedFile == null) {
      _uploadError = "Please select a video";
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadError = null;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final hashtagsText = hashtagsController.text.trim();
      List<String> hashtagsList = [];
      if (hashtagsText.isNotEmpty) {
        hashtagsList = hashtagsText
            .split(RegExp(r'\s+'))
            .where((h) => h.trim().isNotEmpty)
            .map((h) => h.startsWith('#') ? h : '#$h')
            .toList();
      }

      // Create FormData
      final String videoPath = _pickedFile!.path;
      final String videoFileName = _pickedFile!.name;
      final String videoExtension = videoFileName.split('.').last.toLowerCase();
      
      // Map common extensions to MIME types
      final String videoMimeType = lookupMimeType(videoPath) ?? 'video/mp4';

      final Map<String, dynamic> dataMap = {
        'title': titleController.text.trim().isEmpty ? 'New Reel' : titleController.text.trim(),
        'caption': captionController.text.trim(),
        'hashtags': hashtagsList, // Send as List, Dio will handle it
        'video': await dio.MultipartFile.fromFile(
          videoPath,
          filename: videoFileName,
          contentType: dio.DioMediaType.parse(videoMimeType),
        ),
      };

      if (_thumbnailFile != null) {
        final String thumbPath = _thumbnailFile!.path;
        final String thumbFileName = _thumbnailFile!.name;
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
        onSendProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      debugPrint("✅ Upload Response: $response");

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
        return 'Video exceeds 100 MB. Please choose a smaller file.';
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
    commentController.dispose();
    hashtagsController.dispose();
    super.dispose();
  }
}
