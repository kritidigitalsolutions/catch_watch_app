import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // bool _pushEnabled = true;
  // bool _emailEnabled = false;
  // bool _newReleases = true;
  // bool _watchlistUpdates = true;
  // bool _recommendations = false;
  // bool _promoOffers = true;

  final List<Map<String, dynamic>> _recentNotifications = [
    {
      'icon': Icons.movie_creation_outlined,
      'title': 'New Episode Available',
      'body': 'Breaking Bad S3E8 is now available to watch.',
      'time': '2 min ago',
      'isRead': false,
      'color': AppColors.primary,
    },
    {
      'icon': Icons.workspace_premium_rounded,
      'title': 'Subscription Renewed',
      'body': 'Your Premium plan has been renewed successfully.',
      'time': '1 hr ago',
      'isRead': false,
      'color': AppColors.success,
    },
    {
      'icon': Icons.recommend_outlined,
      'title': 'Recommended for You',
      'body': 'Based on your watch history: Interstellar, Inception...',
      'time': '3 hrs ago',
      'isRead': true,
      'color': AppColors.info,
    },
    {
      'icon': Icons.download_done_rounded,
      'title': 'Download Complete',
      'body': 'The Dark Knight is ready to watch offline.',
      'time': 'Yesterday',
      'isRead': true,
      'color': AppColors.warning,
    },
    {
      'icon': Icons.local_offer_outlined,
      'title': 'Special Offer',
      'body': 'Upgrade to Annual Plan & save 40%! Limited time.',
      'time': '2 days ago',
      'isRead': true,
      'color': AppColors.yellow,
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Recent'),
                  ..._recentNotifications.asMap().entries.map(
                    (e) => _buildNotifTile(e.value, e.key),
                  ),
                  // const Divider(
                  //   color: AppColors.grey200,
                  //   height: 24,
                  //   thickness: 6,
                  // ),
                  // _sectionTitle('Notification Settings'),
                  // _settingTile(
                  //   Icons.notifications_active_outlined,
                  //   'Push Notifications',
                  //   'Get notified on your device',
                  //   _pushEnabled,
                  //   (v) => setState(() => _pushEnabled = v),
                  // ),
                  // _settingTile(
                  //   Icons.mail_outline_rounded,
                  //   'Email Notifications',
                  //   'Receive updates via email',
                  //   _emailEnabled,
                  //   (v) => setState(() => _emailEnabled = v),
                  // ),
                  // const Divider(color: AppColors.grey200, height: 1),
                  // Padding(
                  //   padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  //   child: Text(
                  //     'Alert Types',
                  //     style: text12(
                  //       color: AppColors.textSecondary,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  // ),
                  // _settingTile(
                  //   Icons.fiber_new_rounded,
                  //   'New Releases',
                  //   'Movies, shows & episodes',
                  //   _newReleases,
                  //   (v) => setState(() => _newReleases = v),
                  // ),
                  // _settingTile(
                  //   Icons.bookmark_outline_rounded,
                  //   'Watchlist Updates',
                  //   'When your watchlist content changes',
                  //   _watchlistUpdates,
                  //   (v) => setState(() => _watchlistUpdates = v),
                  // ),
                  // _settingTile(
                  //   Icons.auto_awesome_outlined,
                  //   'Recommendations',
                  //   'Personalized picks for you',
                  //   _recommendations,
                  //   (v) => setState(() => _recommendations = v),
                  // ),
                  // _settingTile(
                  //   Icons.local_offer_outlined,
                  //   'Promo & Offers',
                  //   'Deals, discounts & special offers',
                  //   _promoOffers,
                  //   (v) => setState(() => _promoOffers = v),
                  // ),
                  // const SizedBox(height: 32),
                ],
              ),
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
      child: Row(
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
          Expanded(
            child: Text(
              'Notifications',
              style: text18(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                for (var n in _recentNotifications) {
                  n['isRead'] = true;
                }
              });
            },
            child: Text(
              'Mark all read',
              style: text12(color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: text13(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNotifTile(Map<String, dynamic> item, int index) {
    final bool isRead = item['isRead'];
    return GestureDetector(
      onTap: () => setState(() => _recentNotifications[index]['isRead'] = true),
      child: Container(
        color: isRead ? AppColors.white : const Color(0xFFFFF5F0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title'],
                          style: text14(
                            color: AppColors.textPrimary,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['body'],
                    style: text12(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['time'],
                    style: text11(
                      color: AppColors.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //   Widget _settingTile(
  //     IconData icon,
  //     String title,
  //     String subtitle,
  //     bool value,
  //     ValueChanged<bool> onChanged,
  //   ) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
  //       child: Row(
  //         children: [
  //           Container(
  //             width: 42,
  //             height: 42,
  //             decoration: BoxDecoration(
  //               color: const Color(0xFFFFF0E8),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(icon, color: AppColors.primary, size: 20),
  //           ),
  //           const SizedBox(width: 14),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: text14(
  //                     color: AppColors.textPrimary,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //                 Text(subtitle, style: text12(color: AppColors.textSecondary)),
  //               ],
  //             ),
  //           ),
  //           Switch(
  //             value: value,
  //             onChanged: onChanged,
  //             activeColor: AppColors.primary,
  //           ),
  //         ],
  //       ),
  //     );
  //   }
}
