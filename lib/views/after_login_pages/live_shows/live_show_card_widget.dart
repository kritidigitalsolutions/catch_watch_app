import 'package:flutter/material.dart';
import '../../../models/live_show_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import 'live_show_detail_screen.dart';

class LiveShowCardWidget extends StatelessWidget {
  final LiveShow show;
  final bool isFullWidth;

  const LiveShowCardWidget({super.key, required this.show, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = isFullWidth ? screenWidth - 32 : (screenWidth * 0.82).clamp(280.0, 400.0);
    final imageUrl = show.thumbnail ?? show.banner ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveShowDetailScreen(showId: show.id ?? ''),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: isFullWidth ? 0 : 14),
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
            // Responsive Poster Image & Badges
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty
                      ? UniversalImage(
                          url: imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 180,
                          color: AppColors.grey800,
                          child: const Center(
                            child: Icon(Icons.live_tv, color: Colors.white, size: 40),
                          ),
                        ),
                  // LIVE Indicator Badge (Top Left)
                  if (show.status == 'LIVE' || show.isLive == true)
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
                  // Viewers Count Badge (Top Right)
                  if (show.viewerCount != null && show.viewerCount! > 0)
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
                            const Icon(Icons.remove_red_eye, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${show.viewerCount}', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          show.title ?? 'demo live show',
                          style: text15(color: AppColors.black, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        show.scheduledStartTime != null && show.scheduledStartTime!.isNotEmpty
                            ? _formatDate(show.scheduledStartTime!)
                            : 'Nov 27',
                        style: text12(color: AppColors.grey500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    show.description ?? 'fjryfujy',
                    style: text12(color: AppColors.grey600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return 'Nov 27';
    }
  }
}
