import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final List<Map<String, dynamic>> _downloads = [
    {
      'title': 'Inception',
      'subtitle': 'Season 1 • Episode 3',
      'size': '1.2 GB',
      'duration': '2h 28m',
      'status': 'completed',
      'progress': 1.0,
    },
    {
      'title': 'Breaking Bad',
      'subtitle': 'Season 3 • Episode 7',
      'size': '680 MB',
      'duration': '47m',
      'status': 'downloading',
      'progress': 0.65,
    },
    {
      'title': 'The Dark Knight',
      'subtitle': 'Movie',
      'size': '2.1 GB',
      'duration': '2h 32m',
      'status': 'completed',
      'progress': 1.0,
    },
    {
      'title': 'Stranger Things',
      'subtitle': 'Season 4 • Episode 1',
      'size': '920 MB',
      'duration': '1h 16m',
      'status': 'paused',
      'progress': 0.38,
    },
    {
      'title': 'Interstellar',
      'subtitle': 'Movie',
      'size': '1.8 GB',
      'duration': '2h 49m',
      'status': 'completed',
      'progress': 1.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _downloads.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _downloads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildDownloadCard(_downloads[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
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
                  '4.72 GB used  •  ${_downloads.length} files',
                  style: text13(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(Map<String, dynamic> item, int index) {
    final bool isCompleted = item['status'] == 'completed';
    final bool isDownloading = item['status'] == 'downloading';
    final bool isPaused = item['status'] == 'paused';

    Color statusColor = isCompleted
        ? AppColors.success
        : isPaused
        ? AppColors.warning
        : AppColors.primary;

    String statusLabel = isCompleted
        ? 'Completed'
        : isPaused
        ? 'Paused'
        : 'Downloading...';

    return Container(
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
              ),
              child: const Icon(
                Icons.movie_outlined,
                color: AppColors.grey400,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: text15(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'],
                    style: text12(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (!isCompleted) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item['progress'],
                        backgroundColor: AppColors.grey200,
                        color: statusColor,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: text11(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item['size']}  •  ${item['duration']}',
                        style: text11(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (isDownloading || isPaused)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _downloads[index]['status'] = isPaused
                            ? 'downloading'
                            : 'paused';
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    setState(() => _downloads.removeAt(index));
                  },
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
          ],
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
