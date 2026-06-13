import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            _UploadProgressCard(),
            const SizedBox(height: 24),
            // _TitleField(),
            // const SizedBox(height: 20),
            _CaptionField(),
            const SizedBox(height: 20),
            // _CommentsField(),
            // const SizedBox(height: 20),
            _HashtagsField(),
            const SizedBox(height: 20),
            // _VisibilitySection(),
            const SizedBox(height: 32),
            _PublishButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Upload Progress Card ─────────────────────────────────────────────────────

class _UploadProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          // Video thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 56,
              color: AppColors.grey800,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white54,
                    size: 28,
                  ),
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
                        '00:35',
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

// ─── Comments Field ────────────────────────────────────────────────────────────

class _CommentsField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<VideoUploadProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: text14(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: provider.commentController,
          style: text13(),
          maxLines: 4,
          decoration: _inputDecoration(hint: 'Write a Comments..'),
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (provider.isFormValid && !provider.isUploading)
            ? () async {
                final success = await provider.publish();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reel uploaded successfully!')),
                  );
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (provider.uploadError != null && context.mounted) {
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
                'Publish',
                style: text16(fontWeight: FontWeight.w600, color: AppColors.white),
              ),
      ),
    );
  }
}
