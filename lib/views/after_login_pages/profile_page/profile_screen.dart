import 'dart:io';

import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/menu_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/followers_following_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/dashboard_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/wallet_screen.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/verification/verification_main_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/vip_support/vip_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../utils/hive_service/hive_service.dart';
import '../../../models/content_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';
import '../../../view_model/after_login_provider/reels_provider.dart';
import '../../../view_model/after_login_provider/wallet_provider.dart';
import '../movie_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  // Jab scroll is value se zyada ho, collapsed bar dikhao
  static const double _collapseThreshold = 160.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchProfile();
      context.read<VerificationProvider>().fetchVerificationStatus();
      context.read<WalletProvider>().fetchPointsSummary();
      context.read<WalletProvider>().fetchWalletSummary();

      // Listen to page changes in HomeScreenProvider to refresh profile when navigating to it
      final homeProvider = context.read<HomeScreenProvider>();
      homeProvider.addListener(_homeProviderListener);
    });
    _scrollController.addListener(_scrollListener);
  }

  void _homeProviderListener() {
    final homeProvider = context.read<HomeScreenProvider>();
    if (homeProvider.pageIndex == 4) { // 4 is the Profile tab index
       context.read<ProfileProvider>().fetchProfile();
    }
  }

  void _scrollListener() {
    final collapsed = _scrollController.offset > _collapseThreshold;
    if (collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    context.read<HomeScreenProvider>().removeListener(_homeProviderListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          RefreshIndicator(
            onRefresh: () => provider.fetchProfile(),
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Full expanded orange header
                SliverToBoxAdapter(child: _ExpandedHeader(provider: provider)),

                // Stats Section (New position and design)
                SliverToBoxAdapter(child: _buildStatsSection(context, provider)),

                // Tab row
                SliverToBoxAdapter(child: _buildTabRow(provider)),

                // Divider
                const SliverToBoxAdapter(
                  child: Divider(
                    color: Color(0xFFF0F0F0),
                    thickness: 1,
                    height: 1,
                  ),
                ),

                // Grid
                _buildGrid(provider),

                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
                ),
              ],
            ),
          ),

          // ── Collapsed sticky bar (only visible after scroll threshold) ───
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isCollapsed ? 0 : -80, // slide in from top
            left: 0,
            right: 0,
            child: _CollapsedBar(provider: provider),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow(ProfileProvider provider) {
    final tabs = [
      (ProfileTab.videos, Icons.grid_view_rounded, 'Posts'),
      (ProfileTab.saved, Icons.bookmark_outline_rounded, 'Saved'),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Row(
        children: tabs.map((t) {
          final isActive = provider.activeTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setTab(t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      t.$2,
                      size: 20,
                      color: isActive ? AppColors.primary : AppColors.grey500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.$3,
                      style: text14(
                        color: isActive ? AppColors.primary : AppColors.grey500,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ProfileProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(provider.videosCount, 'Videos', null),
          _verticalDivider(),
          _statItem(provider.followers, 'Followers', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FollowersFollowingScreen(
                  title: 'Followers',
                  isFollowers: true,
                ),
              ),
            );
          }),
          _verticalDivider(),
          _statItem(provider.following, 'Following', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FollowersFollowingScreen(
                  title: 'Following',
                  isFollowers: false,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statItem(String count, String label, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              count,
              style: text20(color: AppColors.textPrimary, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: text12(color: AppColors.grey600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: const Color(0xFFE0E0E0),
    );
  }

  Widget _buildGrid(ProfileProvider provider) {
    final uploadProvider = context.watch<VideoUploadProvider>();
    List<dynamic> items = List.from(provider.currentTabItems);

    // Add current uploading video to CUTS tab (drafts)
    if (provider.activeTab == ProfileTab.cuts && uploadProvider.isUploading) {
      items.insert(0, uploadProvider);
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _GridCard(item: items[i]),
          childCount: items.length,
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

class _ExpandedHeader extends StatelessWidget {
  final ProfileProvider provider;
  const _ExpandedHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPadding + 16, bottom: 20, left: 14, right: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: provider.user?.profileImage != null && provider.user!.profileImage!.isNotEmpty
                      ? CircleAvatar(
                          radius: 35,
                          backgroundImage: NetworkImage(provider.user!.profileImage!),
                        )
                      : CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.grey200,
                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                ),
                const SizedBox(width: 14),
                // Info & Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.name,
                            style: text18(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                          if (context.watch<VerificationProvider>().currentApplication?.status == 'approved' || provider.user?.isVerified == true || provider.user?.blueTick == true) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, 
                                color: Colors.blue, size: 18),
                          ],
                        ],
                      ),
                      Text(
                        provider.handle,
                        style: text13(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _actionPill(
                            context,
                            const Icon(Icons.stars_rounded, color: AppColors.yellow, size: 14),
                            "${context.watch<WalletProvider>().availablePoints} Pts",
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                          ),
                          if (context.watch<VerificationProvider>().currentApplication?.status != 'approved' && provider.user?.isVerified != true && provider.user?.blueTick != true) ...[
                            _actionPill(
                              context,
                              const Icon(Icons.verified_rounded, color: Colors.blue, size: 12),
                              "Get Blue Tick",
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationMainScreen())),
                              isPrimary: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPadding + 8,
            right: 14,
            child: Row(
              children: [
                _glassIconButton(
                  Icons.grid_view_rounded,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen())),
                ),
                const SizedBox(width: 8),
                _glassIconButton(
                  Icons.menu_rounded,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _actionPill(BuildContext context, Widget icon, String label, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(
              label,
              style: text10(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Collapsed sticky bar (slides in from top when scrolled) ───────────────
class _CollapsedBar extends StatelessWidget {
  final ProfileProvider provider;
  const _CollapsedBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 8,
        bottom: 10,
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
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF5F00),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Small avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: provider.user?.profileImage != null && provider.user!.profileImage!.isNotEmpty
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(provider.user!.profileImage!),
                    backgroundColor: Colors.white,
                    onBackgroundImageError: (_, _) {},
                  )
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                  ),
          ),
          const SizedBox(width: 10),

          // Name + handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      provider.name,
                      style: text14(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (context.watch<VerificationProvider>().currentApplication?.status == 'approved' || provider.user?.isVerified == true || provider.user?.blueTick == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, 
                          color: Colors.blue, size: 14),
                    ],
                  ],
                ),
                Text(
                  '${provider.followers} Followers • ${provider.following} Following',
                  style: text11(color: Colors.white70),
                ),
                Text(provider.handle, style: text11(color: Colors.white70)),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Menu button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomIconButton(
              icon: Icons.menu_rounded,
              color: AppColors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MenuScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid card ──────────────────────────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final dynamic item;
  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeScreenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final reelsProvider = context.read<ReelsProvider>();
    String? imageUrl;
    String? overlayText;

    if (item is ReelModel) {
      imageUrl = (item as ReelModel).thumbnail;
      overlayText = (item as ReelModel).viewsCount?.toString() ?? '0';
    } else if (item is WatchlistItem) {
      imageUrl = (item as WatchlistItem).item?.poster;
      overlayText = (item as WatchlistItem).item?.rating?.toString() ?? '0.0';
    } else if (item is Content) {
      imageUrl = (item as Content).poster;
      overlayText = (item as Content).rating?.toString() ?? '0.0';
    }

    return GestureDetector(
      onTap: () {
        if (item is VideoUploadProvider) return;

        if (item is ReelModel) {
          if (profileProvider.activeTab == ProfileTab.cuts) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortVideoPlayerScreen(
                  isVisible: true,
                  initialReels: [item],
                ),
              ),
            );
          } else {
            reelsProvider.setTargetReelId(item.id);
            homeProvider.changePage(1);
          }
        } else if (item is WatchlistItem || item is Content) {
          final content = item is WatchlistItem ? item.item : item as Content;
          if (content == null) return;

          if (content.type == 'shortFilm' || content.type == 'short' || content.type == 'shortfilm') {
            final subProvider = context.read<SubscriptionProvider>();
            bool canWatch = content.isPremium != true || subProvider.currentSubscription != null;

            if (!canWatch) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortVideoPlayerScreen(
                  isVisible: true,
                  initialReels: [ReelModel.fromContent(content)],
                ),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MovieDetailScreen(content: content)),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildThumbnail(imageUrl, item),
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
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item is ReelModel
                          ? Icons.play_circle_fill_rounded
                          : Icons.star_rounded,
                      color: item is WatchlistItem
                          ? AppColors.warning
                          : Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      overlayText ?? '',
                      style: text8(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (item is ReelModel &&
                (profileProvider.activeTab == ProfileTab.videos || profileProvider.activeTab == ProfileTab.cuts))
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Video'),
                        content: const Text(
                            'Are you sure you want to delete this video?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              profileProvider.deleteReel(item.id!);
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl, dynamic item) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl.startsWith('http')
          ? Image.network(
              imageUrl,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => _errorPlaceholder(),
            )
          : (imageUrl.startsWith('assets/')
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => _errorPlaceholder(),
                )
              : _errorPlaceholder());
    }

    if (item is ReelModel &&
        item.videoUrl != null &&
        item.videoUrl!.isNotEmpty) {
      return _VideoPreviewThumbnail(videoUrl: item.videoUrl!);
    }

    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppColors.grey200,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.grey400),
      ),
    );
  }
}

class _VideoPreviewThumbnail extends StatefulWidget {
  final String videoUrl;
  const _VideoPreviewThumbnail({required this.videoUrl});

  @override
  State<_VideoPreviewThumbnail> createState() => _VideoPreviewThumbnailState();
}

class _VideoPreviewThumbnailState extends State<_VideoPreviewThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.startsWith('http')) {
      final token = HiveService.getToken();
      Map<String, String> headers = {
        'Referer': 'https://catchandwatch.com',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: headers,
      );
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }
    
    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller!.seekTo(const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black12,
        child: const Center(
            child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return VideoPlayer(_controller!);
  }
}
