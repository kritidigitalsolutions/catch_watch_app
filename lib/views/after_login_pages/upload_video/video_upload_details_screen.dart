import 'dart:io';

import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_trimmer/video_trimmer.dart';

/// When navigated from UploadScreen, the provider is injected via
/// ChangeNotifierProvider.value — no local provider needed.
/// If used standalone (e.g. deep-link), wrap with ChangeNotifierProvider.
class VideoDetailScreen extends StatelessWidget {
  const VideoDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _VideoDetailView();
  }
}

class _VideoDetailView extends StatelessWidget {
  const _VideoDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text('Video Detail', style: text16(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrimEditorCard(),
            const SizedBox(height: 20),
            _UploadStatusCard(),
            const SizedBox(height: 24),
            _ThumbnailPicker(),
            const SizedBox(height: 24),
            _TitleField(),
            const SizedBox(height: 20),
            _CaptionField(),
            const SizedBox(height: 20),
            _HashtagsField(),
            const SizedBox(height: 20),
            _VisibilitySection(),
            const SizedBox(height: 32),
            _PublishButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

// ─── Preview + Trim editor ────────────────────────────────────────────────────

class _TrimEditorCard extends StatefulWidget {
  @override
  State<_TrimEditorCard> createState() => _TrimEditorCardState();
}

class _TrimEditorCardState extends State<_TrimEditorCard> {
  final Trimmer _trimmer = Trimmer();
  bool _initialized = false;
  bool _showTrimmer = false;
  bool _isApplying = false;
  bool _isPlaying = false;
  double _startMs = 0;
  double _endMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final provider = context.read<VideoUploadProvider>();
    final file = provider.pickedFile;
    if (file == null) return;
    try {
      await _trimmer.loadVideo(videoPath: file.path);
      if (!mounted) return;
      final duration =
          _trimmer.videoPlayerController?.value.duration ?? provider.videoDuration ?? Duration.zero;
      setState(() {
        _initialized = true;
        _startMs = provider.trimStart.inMilliseconds.toDouble();
        _endMs = provider.trimEnd.inMilliseconds > 0
            ? provider.trimEnd.inMilliseconds.toDouble()
            : duration.inMilliseconds.toDouble();
      });
    } catch (e) {
      debugPrint('Trim editor load failed: $e');
      if (mounted) setState(() => _initialized = true);
    }
  }

  Future<void> _togglePlay() async {
    if (!_initialized || _trimmer.videoPlayerController == null) return;
    try {
      final playing = await _trimmer.videoPlaybackControl(
        startValue: _startMs,
        endValue: _endMs,
      );
      if (mounted) setState(() => _isPlaying = playing);
    } catch (e) {
      debugPrint('Playback toggle failed: $e');
    }
  }

  Future<void> _applyTrim() async {
    final provider = context.read<VideoUploadProvider>();
    setState(() => _isApplying = true);
    provider.setTrimming(true);
    try {
      await _trimmer.saveTrimmedVideo(
        startValue: _startMs,
        endValue: _endMs,
        storageDir: StorageDir.temporaryDirectory,
        onSave: (path) {
          if (path != null) provider.setTrimmedFile(XFile(path));
        },
      );
    } catch (e) {
      debugPrint('Trim failed: $e');
    } finally {
      provider.setTrimming(false);
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _resetTrim() {
    final duration = _trimmer.videoPlayerController?.value.duration ?? Duration.zero;
    setState(() {
      _startMs = 0;
      _endMs = duration.inMilliseconds.toDouble();
    });
    context.read<VideoUploadProvider>().clearTrim();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();
    final duration = _trimmer.videoPlayerController?.value.duration ?? provider.videoDuration;
    final selectedMs = (_endMs - _startMs).clamp(0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Video preview ────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 220,
            width: double.infinity,
            color: Colors.black,
            child: !_initialized
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoViewer(trimmer: _trimmer),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      if (duration != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _fmtDuration(duration),
                              style: text11(color: AppColors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Trim toggle + state ──────────────────────────────────────────
        Row(
          children: [
            Text('Preview', style: text13(color: AppColors.textSecondary)),
            const Spacer(),
            if (provider.hasTrim)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Trimmed clip ready',
                  style: text11(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: _initialized
                  ? () => setState(() => _showTrimmer = !_showTrimmer)
                  : null,
              icon: const Icon(Icons.content_cut, size: 18),
              label: Text(_showTrimmer ? 'Hide trim' : 'Trim'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),

        // ── Trim strip ───────────────────────────────────────────────────
        if (_showTrimmer && _initialized) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return TrimViewer(
                trimmer: _trimmer,
                maxVideoLength: VideoUploadProvider.maxReelDuration,
                viewerWidth: constraints.maxWidth,
                viewerHeight: 56,
                onChangeStart: (v) => setState(() => _startMs = v),
                onChangeEnd: (v) => setState(() => _endMs = v),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Selected: ${_fmtDuration(Duration(milliseconds: selectedMs.toInt()))}',
                style: text12(color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isApplying ? null : _resetTrim,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isApplying ? null : _applyTrim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isApplying
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Apply Trim'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Upload Status Card ───────────────────────────────────────────────────────

class _UploadStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();
    final cover = provider.thumbnailFile;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          // Real cover frame (auto-generated or chosen)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 56,
              color: AppColors.grey800,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.file(
                      File(cover.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white54,
                        size: 28,
                      ),
                    )
                  else
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white54,
                      size: 28,
                    ),
                  if (provider.videoDuration != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fmtDuration(provider.videoDuration!),
                          style: text8(color: AppColors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // File info & progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.fileName,
                  style: text12(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (provider.uploadError != null)
                  Text(
                    provider.uploadError!,
                    style: text11(color: AppColors.error),
                  )
                else if (provider.isUploading) ...[
                  Text(
                    'Uploading your video...',
                    style: text11(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: provider.uploadProgress,
                            backgroundColor: AppColors.grey300,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${provider.uploadPercent}%',
                        style: text11(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ] else if (provider.uploadComplete) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Upload complete',
                        style: text12(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ] else
                   Text(
                    'Ready to upload',
                    style: text11(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${provider.fileSizeMB} MB',
                  style: text11(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Input Decorator ────────────────────────────────────────────────────

InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: appTextStyle(fontSize: 13, color: AppColors.hintText),
    filled: true,
    fillColor: AppColors.grey50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.grey300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.grey300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    suffixIcon: suffixIcon,
  );
}

// ─── Thumbnail Picker ──────────────────────────────────────────────────────────

class _ThumbnailPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();
    final cover = provider.thumbnailFile;
    final isManual = provider.manualThumbnail != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reel Thumbnail', style: text14(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: provider.isUploading ? null : () => provider.pickThumbnail(),
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey300),
            ),
            child: cover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(cover.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _addCoverPlaceholder(isManual: false),
                    ),
                  )
                : _addCoverPlaceholder(isManual: false),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isManual
              ? 'Custom cover selected · Tap to change'
              : 'Auto-generated from your video · Tap to change',
          style: text11(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _addCoverPlaceholder({required bool isManual}) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, color: AppColors.grey600),
        SizedBox(height: 8),
        Text(
          'Add Cover',
          style: TextStyle(fontSize: 12, color: AppColors.grey600),
        ),
      ],
    );
  }
}

// ─── Title Field ───────────────────────────────────────────────────────────────

class _TitleField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<VideoUploadProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add video title', style: text14(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: provider.titleController,
          style: text14(),
          decoration: _inputDecoration(hint: 'Add video title'),
        ),
      ],
    );
  }
}

// ─── Caption Field ─────────────────────────────────────────────────────────────

class _CaptionField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<VideoUploadProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Caption', style: text14(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: provider.captionController,
          style: text13(),
          maxLines: 4,
          decoration: _inputDecoration(hint: 'Write a caption..'),
        ),
      ],
    );
  }
}

// ─── Hashtags Field ────────────────────────────────────────────────────────────

class _HashtagsField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<VideoUploadProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add hashtags', style: text14(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: provider.hashtagsController,
          style: text13(color: AppColors.primary),
          decoration: _inputDecoration(hint: '#Movies #Action #Entertainment'),
        ),
      ],
    );
  }
}

// ─── Visibility Section ────────────────────────────────────────────────────────

class _VisibilitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visibility & Publish',
          style: text14(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _VisibilityTab(
              label: 'Public',
              isSelected: provider.visibility == VisibilityOption.public,
              onTap: () => provider.setVisibility(VisibilityOption.public),
            ),
            const SizedBox(width: 24),
            _VisibilityTab(
              label: 'Private',
              isSelected: provider.visibility == VisibilityOption.private,
              onTap: () => provider.setVisibility(VisibilityOption.private),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisibilityTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: text14(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: 48,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Publish Button ───────────────────────────────────────────────────────────

class _PublishButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();
    final hasError = provider.uploadError != null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (provider.isFormValid && !provider.isUploading)
                ? () async {
                    final success = await provider.publish();
                    if (!context.mounted) return;
                    if (success) {
                      // Refresh the reels feed so the new reel is visible immediately.
                      context
                          .read<ReelsProvider>()
                          .fetchReelsFeed(forceRefresh: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reel uploaded successfully!')),
                      );
                      provider.reset();
                      Navigator.of(context).pop();
                    } else if (provider.uploadError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(provider.uploadError!)),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.grey300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: provider.isUploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    hasError ? 'Retry' : 'Publish',
                    style: text16(
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
        if (provider.isUploading) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: provider.cancelUpload,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel upload'),
          ),
        ],
      ],
    );
  }
}
