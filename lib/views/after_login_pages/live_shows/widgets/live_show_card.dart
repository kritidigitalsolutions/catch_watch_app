import 'package:flutter/material.dart';
import '../../../../models/live_show_model.dart';
import '../../../../res/app_colors.dart';
import '../../../../utils/text_style.dart';
import '../live_show_details_screen.dart';

/// Horizontal Live Show Card matching Catch & Watch design.
class LiveShowCard extends StatelessWidget {
  final LiveShowModel show;
  final double? width;
  final VoidCallback? onTap;

  const LiveShowCard({
    super.key,
    required this.show,
    this.width = 330,
    this.onTap,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = show.isLive;
    final bannerUrl = show.banner ?? show.poster ?? '';
    final dateStr = _formatDate(show.startTime);

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveShowDetailsScreen(showId: show.id, initialShow: show),
            ),
          );
        }
      },
      child: Container(
        width: width ?? 330,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster / Banner Image & Badges (Height 170)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  bannerUrl.isNotEmpty
                      ? Image.network(
                          bannerUrl,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 170,
                            color: AppColors.grey800,
                            child: const Center(
                              child: Icon(Icons.live_tv_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        )
                      : Container(
                          height: 170,
                          color: AppColors.grey800,
                          child: const Center(
                            child: Icon(Icons.live_tv_rounded, color: Colors.white, size: 40),
                          ),
                        ),
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(160)],
                      ),
                    ),
                  ),
                  // LIVE Indicator Badge (Top Left)
                  if (isLive)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('LIVE', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  // Viewer Count Badge (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '${show.viewerCount}',
                            style: text10(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          show.title,
                          style: text14(color: AppColors.black, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: text12(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                  if (show.description != null && show.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      show.description!,
                      style: text12(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
