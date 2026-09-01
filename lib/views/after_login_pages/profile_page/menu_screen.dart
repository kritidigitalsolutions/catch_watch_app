import 'package:catch_watch/views/after_login_pages/profile_page/notification_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/edit_profile_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/wish_list_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/help_support_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/policy_screen.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/verification/verification_main_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/verification/verified_status_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/vip_support/vip_support_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/legal_policies_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context, provider),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _menuItem(
                    Icons.person_outline_rounded,
                    'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  if (context.watch<VerificationProvider>().currentApplication?.status != 'approved' && provider.user?.isVerified != true && provider.user?.blueTick != true) ...[
                    _menuItem(
                      Icons.verified_user_outlined,
                      'Get Blue Tick',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerificationMainScreen(),
                          ),
                        );
                      },
                    ),
                    _divider(),
                  ],
                  _menuItem(
                    Icons.workspace_premium_rounded,
                    'Subscription',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  if (context.watch<VerificationProvider>().currentApplication?.status == 'approved' || provider.user?.isVerified == true || provider.user?.blueTick == true) ...[
                    // _menuItem(
                    //   Icons.verified_user_rounded,
                    //   'Verified User',
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (_) => const VerifiedStatusScreen(),
                    //       ),
                    //     );
                    //   },
                    // ),
                    // _divider(),
                  ],
                  _menuItem(
                    Icons.notifications_outlined,
                    'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _menuItem(
                    Icons.favorite_outline_rounded,
                    'WishList',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WishListScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _menuItem(
                    Icons.privacy_tip_outlined,
                    'Legal Policies',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPoliciesListScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _menuItem(
                    Icons.help_outline_rounded,
                    'Help & Support',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _divider(),
                  _logoutItem(context, provider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileProvider provider) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 28,
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
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _glassButton(
                  Icons.close_rounded,
                  () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 2.5,
                      ),
                    ),
                    child: provider.user?.profileImage != null &&
                            provider.user!.profileImage!.isNotEmpty
                        ? CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                NetworkImage(provider.user!.profileImage!),
                            backgroundColor: Colors.white,
                          )
                        : const CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                AssetImage('assets/images/logo.jpg'),
                            backgroundColor: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.name,
                            style: text18(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (context.watch<VerificationProvider>().currentApplication?.status == 'approved' || provider.user?.isVerified == true || provider.user?.blueTick == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, 
                                color: Colors.blue, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.handle,
                        style: text13(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: text15(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.grey400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutItem(BuildContext context, ProfileProvider provider) {
    return InkWell(
      onTap: () => _showLogoutDialog(context, provider),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Log Out',
                style: text15(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: text18(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?', style: text14(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: text14(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.logout(context);
            },
            child: Text(
              'Logout',
              style: text14(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: Divider(color: AppColors.grey200, height: 8, thickness: 0.5),
  );
}
