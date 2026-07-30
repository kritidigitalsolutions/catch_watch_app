import 'dart:io';
import 'package:catch_watch/repository/reels_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum VisibilityOption { public, private }

enum PickError { none, tooLarge, cancelled, unsupported }

class VideoUploadProvider extends ChangeNotifier {
  final ReelsRepository _reelsRepository = ReelsRepository();

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

  // ── Form ─────────────────────────────────────────────────────────────────
  final TextEditingController titleController = TextEditingController();
  final TextEditingController captionController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController hashtagsController = TextEditingController(
    text: '#Movies #Action #Entertainment',
  );

  String _title = '';
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
  }

  // ── Pick video from camera or gallery ───────────────────────────────────────
  Future<void> pickVideo({ImageSource source = ImageSource.gallery}) async {
    _isPicking = true;
    _pickError = PickError.none;
    _uploadError = null;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 30),
      );

      if (file == null) {
        _pickError = PickError.cancelled;
        _isPicking = false;
        notifyListeners();
        return;
      }

      // Check file size
      final bytes = await File(file.path).length();
      final sizeMB = bytes / (1024 * 1024);

      if (sizeMB > maxFileMB) {
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
    } catch (e) {
      _pickError = PickError.unsupported;
      _isPicking = false;
      notifyListeners();
    }
  }

  Future<void> pickThumbnail() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (file != null) {
        _thumbnailFile = file;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking thumbnail: $e");
    }
  }

  void setVisibility(VisibilityOption option) {
    _visibility = option;
    notifyListeners();
  }

  Future<bool> publish() async {
    if (_pickedFile == null || _thumbnailFile == null) {
      _uploadError = _thumbnailFile == null ? "Please select a thumbnail image" : "Please select a video";
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadError = null;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final hashtags = hashtagsController.text
          .split(' ')
          .where((h) => h.trim().startsWith('#'))
          .join(',');

      // Create FormData - match Postman's simple structure
      final String videoFileName = _pickedFile!.path.split('/').last;
      final String videoExtension = videoFileName.split('.').last.toLowerCase();
      final String videoMimeType = (videoExtension == 'mov') ? 'video/quicktime' : 'video/mp4';

      final String thumbFileName = _thumbnailFile!.path.split('/').last;
      final String thumbExtension = thumbFileName.split('.').last.toLowerCase();
      final String thumbMimeType = (thumbExtension == 'png') ? 'image/png' : 'image/jpeg';

      final Map<String, dynamic> dataMap = {
        'title': titleController.text.trim().isEmpty ? 'New Reel' : titleController.text.trim(),
        'caption': captionController.text.trim(),
        'hashtags': hashtags,
        'video': await dio.MultipartFile.fromFile(
          _pickedFile!.path,
          filename: videoFileName,
          contentType: dio.DioMediaType.parse(videoMimeType),
        ),
        'thumbnail': await dio.MultipartFile.fromFile(
          _thumbnailFile!.path,
          filename: thumbFileName,
          contentType: dio.DioMediaType.parse(thumbMimeType),
        ),
      };

      final formData = dio.FormData.fromMap(dataMap);

      debugPrint("📤 Uploading to API: ${_pickedFile!.path}");

      final response = await _reelsRepository.uploadReel(
        formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      if (response != null && response is Map && (response['success'] == true || response['status'] == 'success')) {
        _uploadProgress = 1.0;
        _uploadComplete = true;
        _isUploading = false;
        notifyListeners();
        return true;
      } else {
        _uploadError = (response is Map ? response['message'] : null) ?? 'Server returned an error';
        _isUploading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("❌ UPLOAD ERROR: $e");
      _uploadError = e.toString().replaceAll("Exception:", "").trim();
      if (_uploadError!.isEmpty) {
        _uploadError = "Upload failed. Please check your internet or try a smaller video.";
      }
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  String? get pickErrorMessage {
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
