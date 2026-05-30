import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum VisibilityOption { public, private }

enum PickError { none, tooLarge, cancelled, unsupported }

class VideoUploadProvider extends ChangeNotifier {
  // ── Picked file ──────────────────────────────────────────────────────────
  XFile? _pickedFile;
  double _fileSizeMB = 0;
  bool _isPicking = false;
  PickError _pickError = PickError.none;

  // ── Upload simulation ────────────────────────────────────────────────────
  double _uploadProgress = 0;
  bool _isUploading = false;
  bool _uploadComplete = false;

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

  // Backwards-compat helpers used in card widget
  String get fileName => _pickedFile?.name ?? '';
  int get uploadPercent => (_uploadProgress * 100).toInt();

  VisibilityOption get visibility => _visibility;
  bool get isFormValid => _title.trim().isNotEmpty && hasFile;

  static const double maxFileMB = 100;

  VideoUploadProvider() {
    titleController.addListener(() {
      _title = titleController.text;
      notifyListeners();
    });
  }

  // ── Pick video from gallery ───────────────────────────────────────────────
  Future<void> pickVideo() async {
    _isPicking = true;
    _pickError = PickError.none;
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

      // Auto-start upload simulation once file is picked
      _simulateUpload();
    } catch (e) {
      _pickError = PickError.unsupported;
      _isPicking = false;
      notifyListeners();
    }
  }

  // ── Upload simulation (replace with real HTTP multipart in production) ────
  Future<void> _simulateUpload() async {
    _isUploading = true;
    _uploadProgress = 0;
    notifyListeners();

    // Simulate speed proportional to file size
    final delayMs = ((_fileSizeMB / maxFileMB) * 200 + 80).toInt();

    for (int i = 1; i <= 100; i++) {
      await Future.delayed(Duration(milliseconds: delayMs));
      _uploadProgress = i / 100;
      notifyListeners();
    }

    _isUploading = false;
    _uploadComplete = true;
    notifyListeners();
  }

  void setVisibility(VisibilityOption option) {
    _visibility = option;
    notifyListeners();
  }

  void publish() {
    if (!isFormValid) return;
    // TODO: wire to real API
    notifyListeners();
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
