import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:catch_watch/views/after_login_pages/upload_video/video_upload_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wrap this screen in its own provider so the same provider instance
/// is shared between UploadScreen → VideoDetailScreen.
class UploadScreenWrapper extends StatelessWidget {
  const UploadScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoUploadProvider(),
      child: const UploadScreen(),
    );
  }
}

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoUploadProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const SizedBox(height: 50),

          // ── Upload Area ────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: provider.isPicking ? null : () => provider.pickVideo(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: provider.hasFile
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: provider.hasFile ? 2 : 1.5,
                  ),
                ),
                child: provider.isPicking
                    ? _PickingIndicator()
                    : provider.hasFile
                    ? _FilePreview(provider: provider)
                    : _EmptyState(),
              ),
            ),
          ),

          // ── Error banner ───────────────────────────────────────────────
          if (provider.pickErrorMessage != null)
            _ErrorBanner(message: provider.pickErrorMessage!),

          const SizedBox(height: 20),

          // ── CTA ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.hasFile
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Pass the existing provider down
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: const VideoDetailScreen(),
                          ),
                        ),
                      )
                    : provider.isPicking
                    ? null
                    : () => provider.pickVideo(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  provider.hasFile ? 'Continue' : 'Select Reel',
                  style: text16(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Max file size: 100 MB · MP4 & MOV supported',
              textAlign: TextAlign.center,
              style: text13(color: AppColors.textSecondary),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Empty state (no file chosen) ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_upload_outlined,
            size: 80,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text('Select your video', style: text24(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'MP4 · MOV · Max 100 MB',
          style: text15(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            'Tap to browse gallery',
            style: text14(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── While picker dialog is open ──────────────────────────────────────────────

class _PickingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 20),
        Text('Opening gallery…', style: text15(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── File chosen preview ──────────────────────────────────────────────────────

class _FilePreview extends StatelessWidget {
  final VideoUploadProvider provider;
  const _FilePreview({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // File icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.video_file_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),

        // File name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            provider.fileName,
            style: text14(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),

        // File size badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${provider.fileSizeMB} MB',
            style: text13(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 24),

        // Upload progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.uploadComplete ? 'Upload complete' : 'Uploading…',
                    style: text12(
                      color: provider.uploadComplete
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${provider.uploadPercent}%',
                    style: text12(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.uploadProgress,
                  backgroundColor: AppColors.grey300,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Change file
        GestureDetector(
          onTap: () => provider.pickVideo(),
          child: Text(
            'Change video',
            style: text13(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: text13(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
