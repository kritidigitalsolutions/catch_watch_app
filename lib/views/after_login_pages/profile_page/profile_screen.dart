import 'dart:io';

import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/edit_profile_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/menu_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../utils/hive_service/hive_service.dart';
import '../../../models/content_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';
import '../../../view_model/after_login_provider/reels_provider.dart';
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
                // Full expanded orange header (no appbar title here)
                SliverToBoxAdapter(child: _ExpandedHeader(provider: provider)),

                // // Stats
                // SliverToBoxAdapter(child: _buildStats(provider)),

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
      (ProfileTab.videos, Icons.play_circle_outline_rounded, 'VIDEOS'),
      // (ProfileTab.cuts, Icons.cut_rounded, 'CUTS'),
      (ProfileTab.saved, Icons.bookmark_border_rounded, 'SAVED'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: tabs.map((t) {
          final isActive = provider.activeTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setTab(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.grey100,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      t.$2,
                      size: 18,
                      color: isActive ? AppColors.primary : AppColors.grey600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.$3,
                      style: text8(
                        color: isActive ? AppColors.primary : AppColors.grey600,
                        fontWeight: FontWeight.w700,
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

// ─── Full expanded orange header ────────────────────────────────────────────
class _ExpandedHeader extends StatelessWidget {
  final ProfileProvider provider;
  const _ExpandedHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
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
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Menu button top-right (always visible) ──
          Positioned(
            top: 0,
            right: 16,
            child: Container(
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
          ),

          // ── Profile Content ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 3,
                        ),
                      ),
                      child: provider.user?.profileImage != null &&
                              provider.user!.profileImage!.isNotEmpty
                          ? CircleAvatar(
                              radius: 42,
                              backgroundImage:
                                  NetworkImage(provider.user!.profileImage!),
                              backgroundColor: Colors.white,
                            )
                          : CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person_rounded, 
                                  size: 48, color: AppColors.primary),
                            ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.name,
                            style: text20(
                                color: Colors.white,
                                fontWeight: FontWeight.w900),
                          ),
                          Text(provider.handle,
                              style: text14(color: Colors.white70)),
                          const SizedBox(height: 12),
                          _pill(context, Icons.edit_rounded, 'Edit Profile'),
                        ],
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 24),
                // // Stats Row
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                //   children: [
                //     _statItem(provider.videosCount, 'Videos'),
                //     _statDivider(),
                //     _statItem(provider.followers, 'Followers'),
                //     _statDivider(),
                //     _statItem(provider.following, 'Following'),
                //   ],
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: text18(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: text12(color: Colors.white70, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: text12(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
                    onBackgroundImageError: (_, __) {},
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
                Text(
                  provider.name,
                  style: text14(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // Text(
                //   '${provider.followers} Followers • ${provider.following} Following',
                //   style: text11(color: Colors.white70),
                // ),
                Text(provider.handle, style: text11(color: Colors.white70)),
              ],
            ),
          ),

          // Edit pill
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: text11(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
