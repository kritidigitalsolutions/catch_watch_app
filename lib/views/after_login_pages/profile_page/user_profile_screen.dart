import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/followers_following_screen.dart';
import 'package:catch_watch/views/after_login_pages/message/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/share_helper.dart';
import 'package:catch_watch/views/after_login_pages/report/report_bottom_sheet.dart';
import 'package:catch_watch/view_model/after_login_provider/block_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/block_confirmation_dialog.dart';
import 'package:catch_watch/view_model/after_login_provider/user_search_provider.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  const UserProfileScreen({super.key, required this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;
  static const double _collapseThreshold = 160.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProfileProvider = context.read<UserProfileProvider>();
      await userProfileProvider.fetchUserProfile(widget.username);
      
      // Sync follow status from ReelsProvider if user was loaded
      if (mounted && userProfileProvider.user?.id != null) {
        final reelsProvider = context.read<ReelsProvider>();
        final bool isFollowedInReels = reelsProvider.isUserFollowed(userProfileProvider.user!.id!);
        if (isFollowedInReels && userProfileProvider.user?.isFollowing != true) {
          // If ReelsProvider knows we follow them, but UserProfileProvider doesn't, sync it.
          // This usually happens if the profile API doesn't return isFollowing accurately.
          userProfileProvider.syncFollowStatus(true);
        }
      }
    });
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final collapsed = _scrollController.offset > _collapseThreshold;
    if (collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProfileProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (provider.error != null)
            _ErrorState(
              message: provider.error!,
              onRetry: () => provider.fetchUserProfile(widget.username),
            )
          else if (provider.user == null)
            const Center(child: Text('User not found'))
          else
            RefreshIndicator(
              onRefresh: () => provider.fetchUserProfile(widget.username),
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _ExpandedHeader(provider: provider)),
                  SliverToBoxAdapter(child: _buildTabRow()),
                  const SliverToBoxAdapter(
                    child: Divider(
                      color: Color(0xFFF0F0F0),
                      thickness: 1,
                      height: 1,
                    ),
                  ),
                  _buildGrid(provider),
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
                  ),
                ],
              ),
            ),

          // Collapsed sticky bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: _isCollapsed ? 0 : -200,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isCollapsed ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isCollapsed,
                child: _CollapsedBar(provider: provider),
              ),
            ),
          ),

          // Fallback back button if loading, error, or user not found
          if (provider.isLoading || provider.error != null || provider.user == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey300),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ));
  }

  Widget _buildTabRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: Column(
                children: [
                  Icon(Icons.play_circle_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(height: 4),
                  Text(
                    'POSTS',
                    style: text8(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(UserProfileProvider provider) {
    if (provider.isBlocked) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.grey100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, size: 48, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'You blocked this user',
                style: text16(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'You will no longer see posts or reels from @${provider.user?.username ?? ''}.',
                textAlign: TextAlign.center,
                style: text14(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showUnblockConfirmationDialog(
                    context: context,
                    userId: provider.user!.id!,
                    username: provider.user?.username,
                    name: provider.user?.name,
                    onConfirmUnblock: () async {
                      try {
                        final res = await context.read<BlockProvider>().unblockUser(provider.user!.id!);
                        if (res != null && res.success) {
                          context.read<ReelsProvider>().onUserUnblocked(provider.user!.id!);
                          context.read<UserProfileProvider>().setBlockedByMe(false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                          return true;
                        }
                        return false;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return false;
                      }
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isBlockedBy) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: EmptyStateWidget(
            title: 'User Unavailable',
            message: 'This account content is not available.',
            icon: Icons.person_off_outlined,
            isScrollable: false,
          ),
        ),
      );
    }

    if (provider.userReels.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyStateWidget(
          title: 'No Posts Found',
          message: 'No posts are available yet.',
          icon: Icons.grid_view_rounded,
          isScrollable: false,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _GridCard(item: provider.userReels[i], allReels: provider.userReels, index: i),
          childCount: provider.userReels.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text18(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your internet connection or server status and try again.',
              textAlign: TextAlign.center,
              style: text14(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  final UserProfileProvider provider;
  const _ExpandedHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final user = provider.user!;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 12, bottom: 28),
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
        alignment: Alignment.topLeft,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    if (user.id != null && user.id != HiveService.userId)
                      GestureDetector(
                        onTap: () => _showOtherUserProfileMenu(context, user),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: user.profileImage != null && user.profileImage!.isNotEmpty
                          ? CircleAvatar(
                              radius: 42,
                              backgroundImage: NetworkImage(user.profileImage!),
                              backgroundColor: Colors.white,
                            )
                          : const CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person_rounded, size: 48, color: Color(0xFFFF5F00)),
                            ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.name ?? '',
                                style: text20(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                              if (user.hasVerifiedTick) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, 
                                    color: AppColors.primary, size: 20),
                              ],
                            ],
                          ),
                          Text(
                            user.username?.startsWith('@') == true
                                ? user.username!
                                : '@${user.username ?? ''}',
                            style: text14(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (provider.isBlocked)
                  _actionButton(
                    context,
                    'Unblock',
                    Colors.white,
                    const Color(0xFFFF5F00),
                    () {
                      showUnblockConfirmationDialog(
                        context: context,
                        userId: user.id!,
                        username: user.username,
                        name: user.name,
                        onConfirmUnblock: () async {
                          try {
                            final res = await context.read<BlockProvider>().unblockUser(user.id!);
                            if (res != null && res.success) {
                              context.read<ReelsProvider>().onUserUnblocked(user.id!);
                              context.read<UserProfileProvider>().setBlockedByMe(false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.message),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                              return true;
                            }
                            return false;
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                            return false;
                          }
                        },
                      );
                    },
                  )
                else if (provider.isBlockedBy)
                  const SizedBox.shrink()
                else
                  Row(
                    children: [
                      Expanded(
                        child: Selector<ProfileProvider, bool>(
                          selector: (_, p) => p.isUserFollowed(user.id!),
                          builder: (context, isFollowing, _) {
                            return _actionButton(
                              context,
                              isFollowing ? 'Following' : 'Follow',
                              isFollowing ? Colors.white.withOpacity(0.2) : Colors.white,
                              isFollowing ? Colors.white : const Color(0xFFFF5F00),
                              () {
                                provider.toggleFollow(
                                  user.id!,
                                  onSuccess: () {
                                    final actualFollowing = provider.user?.isFollowing ?? false;
                                    context.read<ReelsProvider>().updateFollowStatus(
                                      user.id!,
                                      actualFollowing,
                                    );
                                    context.read<ProfileProvider>().syncFollowStatus(
                                      user.id!,
                                      actualFollowing,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          context,
                          'Message',
                          Colors.white.withOpacity(0.15),
                          Colors.white,
                          () async {
                            final chatProvider = context.read<ChatProvider>();
                            final convId = await chatProvider.createConversation(user.id!);
                            if (convId != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    conversationId: convId,
                                    partnerId: user.id!,
                                    name: user.name ?? '',
                                    username: user.username ?? '',
                                    image: user.profileImage ?? '',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(context, provider.userReels.length.toString(), 'Posts', null),
                    _statDivider(),
                    _statItem(context, user.followersCount?.toString() ?? '0', 'Followers', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersFollowingScreen(
                            title: 'Followers',
                            isFollowers: true,
                            userId: user.id,
                          ),
                        ),
                      );
                    }),
                    _statDivider(),
                    _statItem(context, user.followingCount?.toString() ?? '0', 'Following', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersFollowingScreen(
                            title: 'Following',
                            isFollowers: false,
                            userId: user.id,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String count, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: text18(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: text12(color: Colors.white70, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(height: 24, width: 1, color: Colors.white24);
  }

  Widget _actionButton(BuildContext context, String label, Color bgColor, Color textColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: text13(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  final UserProfileProvider provider;
  const _CollapsedBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    // Safety check to avoid Null check operator crash
    if (provider.user == null) return const SizedBox.shrink();
    
    final user = provider.user!;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 8, bottom: 10, left: 16, right: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x33FF5F00), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: user.profileImage != null && user.profileImage!.isNotEmpty
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(user.profileImage!),
                    backgroundColor: Colors.white,
                  )
                : const CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.person_rounded, size: 20, color: Color(0xFFFF5F00))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(user.name ?? '', style: text14(color: Colors.white, fontWeight: FontWeight.w800)),
                    if (user.hasVerifiedTick) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, 
                          color: AppColors.primary, size: 14),
                    ],
                  ],
                ),
                Text(
                  '${user.followersCount ?? 0} Followers • ${user.followingCount ?? 0} Following',
                  style: text11(color: Colors.white70),
                ),
                Text(
                  user.username?.startsWith('@') == true
                      ? user.username!
                      : '@${user.username ?? ''}',
                  style: text11(color: Colors.white70),
                ),
              ],
            ),
          ),
          Selector<ProfileProvider, bool>(
            selector: (_, p) => p.isUserFollowed(user.id!),
            builder: (context, isFollowing, _) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      provider.toggleFollow(
                        user.id!,
                        onSuccess: () {
                          final actualFollowing = provider.user?.isFollowing ?? false;
                          context.read<ReelsProvider>().updateFollowStatus(
                            user.id!,
                            actualFollowing,
                          );
                          context.read<ProfileProvider>().syncFollowStatus(
                            user.id!,
                            actualFollowing,
                          );
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: text11(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (user.id != null && user.id != HiveService.userId) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showOtherUserProfileMenu(context, user),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showOtherUserProfileMenu(BuildContext context, UserModel user) {
  if (user.id == null || user.id!.isEmpty) return;
  if (user.id == HiveService.userId) return;

  final blockProvider = context.read<BlockProvider>();
  final userProfileProvider = context.read<UserProfileProvider>();
  final bool isBlocked = userProfileProvider.isBlocked || blockProvider.isUserBlocked(user.id!);

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text('Share Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(modalCtx);
                ShareHelper.shareContent(
                  title: 'Catch Watch Profile',
                  text: 'Check out ${user.name ?? 'this creator'} on Catch&Watch: @${user.username ?? ''}',
                  contentId: user.id,
                  contentType: 'user',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: const Text('Report Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Report @${user.username ?? ''} for spam, abuse, or impersonation',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(modalCtx);
                showReportBottomSheet(
                  context,
                  targetType: 'user',
                  targetId: user.id!,
                  targetTitle: 'Report Profile',
                );
              },
            ),
            if (isBlocked)
              ListTile(
                leading: const Icon(Icons.lock_open_rounded, color: Colors.greenAccent),
                title: const Text('Unblock User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Allow @${user.username ?? ''} to see your profile and content',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(modalCtx);
                  showUnblockConfirmationDialog(
                    context: context,
                    userId: user.id!,
                    username: user.username,
                    name: user.name,
                    onConfirmUnblock: () async {
                      try {
                        final res = await context.read<BlockProvider>().unblockUser(user.id!);
                        if (res != null && res.success) {
                          context.read<ReelsProvider>().onUserUnblocked(user.id!);
                          context.read<UserProfileProvider>().setBlockedByMe(false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                          return true;
                        }
                        return false;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return false;
                      }
                    },
                  );
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                title: const Text('Block User', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Block @${user.username ?? ''} and hide their content',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(modalCtx);
                  showBlockConfirmationDialog(
                    context: context,
                    userId: user.id!,
                    username: user.username,
                    name: user.name,
                    onConfirmBlock: () async {
                      try {
                        final res = await context.read<BlockProvider>().blockUser(
                          user.id!,
                          username: user.username,
                          name: user.name,
                          profileImage: user.profileImage,
                        );
                        if (res != null && res.success) {
                          context.read<ReelsProvider>().onUserBlocked(user.id!);
                          context.read<UserSearchProvider>().onUserBlocked(user.id!);
                          context.read<ProfileProvider>().syncFollowStatus(user.id!, false);
                          context.read<UserProfileProvider>().setBlockedByMe(true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                          return true;
                        }
                        return false;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return false;
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _GridCard extends StatelessWidget {
  final ReelModel item;
  final List<ReelModel> allReels;
  final int index;
  const _GridCard({required this.item, required this.allReels, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShortVideoPlayerScreen(
              isVisible: true,
              initialReels: allReels,
              initialIndex: index,
              showBackButton: true,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.thumbnail != null && item.thumbnail!.isNotEmpty)
              Image.network(item.thumbnail!, fit: BoxFit.fill, errorBuilder: (_, __, ___) => _errorPlaceholder())
            else
              _errorPlaceholder(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      item.viewsCount?.toString() ?? '0',
                      style: text8(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppColors.grey200,
      child: Center(child: Icon(Icons.image_not_supported_outlined, color: AppColors.grey400)),
    );
  }
}
