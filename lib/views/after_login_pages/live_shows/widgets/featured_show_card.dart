import 'package:flutter/material.dart';
import '../../../../models/live_show_model.dart';
import '../../../../res/app_colors.dart';
import '../../../../utils/text_style.dart';
import '../live_show_details_screen.dart';

/// Hero Featured Live Show Card matching Catch & Watch design.
class FeaturedShowCard extends StatelessWidget {
  final LiveShowModel show;
  final VoidCallback? onWatchLive;

  const FeaturedShowCard({
    super.key,
    required this.show,
    this.onWatchLive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveShowDetailsScreen(showId: show.id, initialShow: show),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image / Banner
              Positioned.fill(
                child: show.banner != null && show.banner!.isNotEmpty
                    ? Image.network(
                        show.banner!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(),
                      )
                    : show.poster != null && show.poster!.isNotEmpty
                        ? Image.network(
                            show.poster!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackBackground(),
                          )
                        : _buildFallbackBackground(),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category & Live Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.live_tv_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  show.category ?? 'Featured Live Show',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text13(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Title
                    Text(
                      show.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text18(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Host & Viewer count Row
                    Row(
                      children: [
                        if (show.hostName != null && show.hostName!.isNotEmpty) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white24,
                            backgroundImage: show.hostAvatar != null && show.hostAvatar!.isNotEmpty
                                ? NetworkImage(show.hostAvatar!)
                                : null,
                            child: show.hostAvatar == null || show.hostAvatar!.isEmpty
                                ? Text(
                                    show.hostName![0].toUpperCase(),
                                    style: text11(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            show.hostName!,
                            style: text12(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (show.viewerCount > 0) ...[
                          const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${show.viewerCount} watching',
                            style: text11(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Watch Live Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          if (onWatchLive != null) {
                            onWatchLive!();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveShowDetailsScreen(
                                  showId: show.id,
                                  initialShow: show,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              show.isLive ? 'Watch Live Show' : 'View Show Details',
                              style: text14(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (show.isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              'LIVE',
              style: text11(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    if (show.isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'UPCOMING',
          style: text10(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'ENDED',
        style: text10(color: Colors.white70, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1C2C),
            Color(0xFF928DAB),
          ],
        ),
      ),
    );
  }
}
