import 'dart:io';
import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/view_model/after_login_provider/download_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        final downloads = provider.getAllDownloads();

        return Scaffold(
          backgroundColor: AppColors.white,
          body: Column(
            children: [
              _buildHeader(context, downloads.length),
              Expanded(
                child: downloads.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: downloads.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildDownloadCard(downloads[index], provider),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Downloads',
                style: text18(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storage_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  '$count files downloaded',
                  style: text13(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(Map<dynamic, dynamic> item, DownloadProvider provider) {
    final String title = item['title'] ?? 'Unknown';
    final String? posterPath = item['posterPath'];
    final String contentId = item['id'].toString();
    
    Content? content;
    if (item['content'] != null) {
      content = Content.fromJson(Map<String, dynamic>.from(item['content']));
    }

    return GestureDetector(
      onTap: () {
        if (content != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailScreen(content: content!),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(10),
                  image: posterPath != null && File(posterPath).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(posterPath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: posterPath == null || !File(posterPath).existsSync()
                    ? const Icon(
                        Icons.movie_outlined,
                        color: AppColors.grey400,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text15(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Completed',
                        style: text11(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => provider.removeDownload(contentId),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.download_outlined,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Downloads Yet',
            style: text18(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your downloaded content will appear here',
            style: text14(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
