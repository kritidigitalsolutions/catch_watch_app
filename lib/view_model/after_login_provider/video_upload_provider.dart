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
  double get fileSizeMB => _fileSizeMB;
  bool get isPicking => _isPicking;
  PickError get pickError => _pickError;
  bool get hasFile => _pickedFile != null;

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

  // ── Pick video from gallery ───────────────────────────────────────────────
  Future<void> pickVideo() async {
    _isPicking = true;
    _pickError = PickError.none;
    _uploadError = null;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickVideo(
        source: ImageSource.gallery,
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

  void setVisibility(VisibilityOption option) {
    _visibility = option;
    notifyListeners();
  }

  Future<bool> publish() async {
    if (_pickedFile == null) return false;
    
    _isUploading = true;
    _uploadError = null;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      dio.FormData formData = dio.FormData.fromMap({
        'caption': captionController.text, // Use captionController
        'hashtags': hashtagsController.text.split(' ').where((h) => h.startsWith('#')).toList(),
        'video': await dio.MultipartFile.fromFile(
          _pickedFile!.path,
          filename: _pickedFile!.name,
        ),
      });

      final response = await _reelsRepository.uploadReel(
        formData,
        onSendProgress: (sent, total) {
          _uploadProgress = sent / total;
          notifyListeners();
        },
      );

      if (response['success'] == true) {
        _uploadProgress = 1.0;
        _uploadComplete = true;
        _isUploading = false;
        notifyListeners();
        return true;
      } else {
        _uploadError = response['message'] ?? 'Failed to upload reel';
        _isUploading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _uploadError = e.toString();
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
