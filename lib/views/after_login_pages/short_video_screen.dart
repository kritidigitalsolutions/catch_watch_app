import 'dart:io';

import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/share_helper.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../utils/hive_service/hive_service.dart';
import '../../res/appUrl.dart' show AppUrl;
import '../../utils/text_style.dart';
import '../../view_model/after_login_provider/profile_provider.dart';

class ShortVideoPlayerScreen extends StatefulWidget {
  final bool isVisible;
  final List<ReelModel>? initialReels;
  final int initialIndex;

  const ShortVideoPlayerScreen({
    super.key,
    required this.isVisible,
    this.initialReels,
    this.initialIndex = 0,
  });

  @override
  State<ShortVideoPlayerScreen> createState() => _ShortVideoPlayerScreenState();
}

class _ShortVideoPlayerScreenState extends State<ShortVideoPlayerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reelsProvider = context.read<ReelsProvider>();
      if (widget.initialReels != null) {
        reelsProvider.applyInteractionsTo(widget.initialReels!);
      }
      if (widget.initialReels == null) {
        reelsProvider.fetchReelsFeed().then((_) {
          if (reelsProvider.targetReelId != null) {
            _handleTargetReel();
          }
        });
      }
    });
  }

  Future<void> _handleTargetReel() async {
    final reelsProvider = context.read<ReelsProvider>();
    final targetId = reelsProvider.targetReelId;
    if (targetId == null) return;

    // Ensure the reel is in the list (fetch if missing)
    await reelsProvider.ensureReelVisible(targetId);
    
    final index = reelsProvider.reels.indexWhere((r) => r.id == targetId);
    if (index != -1 && mounted) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
        setState(() => _currentIndex = index);
        reelsProvider.setTargetReelId(null);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _showComments(ReelModel reel) {
    final provider = context.read<ReelsProvider>();
    provider.fetchComments(reel.id!);
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Comments',
                        style: text18(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${reel.commentsCount ?? 0}',
                        style: text14(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<ReelsProvider>(
                      builder: (context, p, _) {
                        if (p.isCommentsLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (p.currentComments.isEmpty) {
                          return const Center(
                            child: Text('No comments yet', style: TextStyle(color: Colors.white70)),
                          );
                        }
                        return ListView.builder(
                          itemCount: p.currentComments.length,
                          itemBuilder: (context, index) {
                            final comment = p.currentComments[index];
                            final user = comment['user'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: user?['profileImage'] != null && user['profileImage'].toString().isNotEmpty
                                        ? NetworkImage(user['profileImage'].toString().startsWith('http') 
                                            ? user['profileImage'] 
                                            : '${AppUrl.serverUrl}/${user['profileImage']}')
                                        : null,
                                    child: user?['profileImage'] == null || user!['profileImage'].toString().isEmpty
                                        ? Text(user?['name']?[0] ?? '?')
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?['username'] ?? 'User',
                                          style: text12(color: Colors.white70, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          comment['text'] ?? '',
                                          style: text14(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              final text = commentController.text.trim();
                              commentController.clear();
                              final success = await provider.postComment(reel.id!, text, reel: reel);
                              if (!success) {
                                // Maybe show a toast
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelsProvider>();
    final reels = widget.initialReels ?? provider.reels;

    // Listen for targetReelId even after initState (if already on this screen)
    if (widget.isVisible && provider.targetReelId != null && widget.initialReels == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTargetReel());
    }

    if (provider.isLoading && reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (reels.isEmpty && provider.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white.withOpacity(0.5)),
                const SizedBox(height: 24),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: text18(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => provider.fetchReelsFeed(forceRefresh: true),
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
        ),
      );
    }

    if (reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No reels available', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final reel = reels[index];
          return _ShortVideoPage(
            key: ValueKey(reel.id),
            reel: reel,
            isActive: widget.isVisible && index == _currentIndex,
            onLike: () => provider.toggleLike(reel.id!, reel: reel),
            onSave: () => provider.toggleBookmark(reel.id!, reel: reel),
            onComment: () => _showComments(reel),
          );
        },
      ),
    );
  }
}

class _ShortVideoPage extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _ShortVideoPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.onLike,
    required this.onSave,
    required this.onComment,
  });

  @override
  State<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<_ShortVideoPage> {
  VideoPlayerController? _controller;
  bool _hasStarted = false;
  bool _showPlayIcon = false;
  
  // Tracking logic
  late final Stopwatch _watchStopwatch;
  bool _viewRecorded = false;
  static const int _viewThresholdSeconds = 3;

  @override
  void initState() {
    super.initState();
    _watchStopwatch = Stopwatch();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.reel.videoUrl ?? '';
    if (videoUrl.isEmpty) return;

    if (_controller != null) {
      await _controller!.dispose();
    }

    if (videoUrl.startsWith('http')) {
      final token = HiveService.getToken();
      Map<String, String> headers = {
        'Referer': 'https://catchandwatch.com',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    } else {
      _controller = VideoPlayerController.file(
        File(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    }

    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      if (!mounted) return;
      setState(() {});
      _syncPlayback();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (mounted) {
      setState(() {
        if (widget.isActive) {
          _controller!.play();
          _hasStarted = true;
          _watchStopwatch.start();
          _controller!.addListener(_videoListener);
        } else {
          _controller!.pause();
          _controller!.seekTo(Duration.zero);
          _hasStarted = false;
          _showPlayIcon = false;
          
          if (_watchStopwatch.isRunning) {
            _watchStopwatch.stop();
            _reportViewIfNecessary();
          }
          _controller!.removeListener(_videoListener);
        }
      });
    }
  }

  void _videoListener() {
    if (!_viewRecorded && _watchStopwatch.elapsed.inSeconds >= _viewThresholdSeconds) {
      _reportViewIfNecessary();
    }
  }

  void _reportViewIfNecessary() {
    if (_viewRecorded || _watchStopwatch.elapsed.inSeconds < 1) return;
    
    // We only record "official" views after threshold, but we could report any duration if swiped away
    if (_watchStopwatch.elapsed.inSeconds >= _viewThresholdSeconds) {
      _viewRecorded = true;
      final reelId = widget.reel.id;
      if (reelId != null) {
        context.read<ReelsProvider>().recordReelView(reelId, _watchStopwatch.elapsed.inSeconds);
      }
    }
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPlayIcon = true;
        _watchStopwatch.stop();
      } else {
        _controller!.play();
        _hasStarted = true;
        _showPlayIcon = false;
        _watchStopwatch.start();
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _watchStopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VideoBackground(
            controller: _controller,
            reel: widget.reel,
            hasStarted: _hasStarted,
          ),
          const _ShortGradient(),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Text(
                  'Reels',
                  style: text24(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 112 + MediaQuery.paddingOf(context).bottom,
            child: _ShortActions(
              reel: widget.reel,
              onLike: widget.onLike,
              onSave: widget.onSave,
              onComment: widget.onComment,
            ),
          ),
          Positioned(
            left: 16,
            right: 82,
            bottom: 34 + MediaQuery.paddingOf(context).bottom,
            child: _ShortInfo(reel: widget.reel),
          ),
          Positioned(
            right: 18,
            bottom: 40 + MediaQuery.paddingOf(context).bottom,
            child: _MusicDisc(image: widget.reel.thumbnail),
          ),
          if (_controller == null || !_controller!.value.isInitialized)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          if (_showPlayIcon)
            Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _VideoBackground extends StatelessWidget {
  final VideoPlayerController? controller;
  final ReelModel reel;
  final bool hasStarted;

  const _VideoBackground({
    required this.controller,
    required this.reel,
    required this.hasStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return reel.thumbnail != null && reel.thumbnail!.isNotEmpty
          ? Image.network(reel.thumbnail!, fit: BoxFit.cover)
          : Container(color: Colors.black);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }
}

class _ShortGradient extends StatelessWidget {
  const _ShortGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.42),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.9),
          ],
          stops: const [0, 0.26, 0.55, 1],
        ),
      ),
    );
  }
}

class _ShortActions extends StatelessWidget {
  final ReelModel reel;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _ShortActions({
    required this.reel,
    required this.onLike,
    required this.onSave,
    required this.onComment,
  });

  bool get _isLiked => reel.userInteraction?.toUpperCase() == 'LIKE';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: _isLiked 
              ? Icons.favorite_rounded 
              : Icons.favorite_border_rounded,
          label: _compactCount(reel.likesCount ?? 0),
          color: _isLiked ? AppColors.primary : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _compactCount(reel.commentsCount ?? 0),
          onTap: onComment,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: reel.isBookmarked == true 
              ? Icons.bookmark_rounded 
              : Icons.bookmark_border_rounded,
          label: reel.isBookmarked == true ? 'Saved' : 'Save',
          color: reel.isBookmarked == true ? Colors.amber : Colors.white,
          onTap: onSave,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () {
            ShareHelper.shareContent(
              title: 'Catch Watch Reel',
              text: 'Check out this Reel: ${reel.caption}',
              imageUrl: reel.thumbnail,
              contentId: reel.id,
              contentType: 'reel',
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 58,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: text12(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortInfo extends StatelessWidget {
  final ReelModel reel;

  const _ShortInfo({required this.reel});

  @override
  Widget build(BuildContext context) {
    final reelsProvider = context.read<ReelsProvider>();
    final currentUser = HiveService.getUser();
    final bool isSelf = currentUser?.sId == reel.user?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (reel.user?.username != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(username: reel.user!.username!),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: reel.user?.profileImage != null && reel.user!.profileImage!.isNotEmpty
                    ? NetworkImage(reel.user!.profileImage!)
                    : null,
                backgroundColor: AppColors.primary,
                child: reel.user?.profileImage == null || reel.user!.profileImage!.isEmpty
                    ? Text(
                        reel.user?.name?[0] ?? '?',
                        style: text16(color: Colors.white, fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (reel.user?.username != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(username: reel.user!.username!),
                      ),
                    );
                  }
                },
                child: Text(
                  reel.user?.username ?? '@unknown',
                  overflow: TextOverflow.ellipsis,
                  style: text14(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (reel.user?.isVerified == true || reel.user?.blueTick == true) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
            ],
            if (!isSelf && reel.user?.id != null) ...[
              const SizedBox(width: 12),
              Selector<ProfileProvider, bool>(
                selector: (_, p) => p.isUserFollowed(reel.user!.id!),
                builder: (context, isFollowing, _) {
                  return GestureDetector(
                    onTap: () async {
                      await reelsProvider.toggleFollow(reel.user!.id!, reel: reel);
                      if (context.mounted) {
                        context.read<ProfileProvider>().syncFollowStatus(
                          reel.user!.id!, 
                          reelsProvider.isUserFollowed(reel.user!.id!),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFollowing ? Colors.white.withOpacity(0.5) : Colors.white,
                          width: 1.2,
                        ),
                        color: isFollowing ? Colors.white.withOpacity(0.12) : AppColors.primary.withOpacity(0.9),
                      ),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: text11(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          reel.caption ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text14(color: Colors.white.withValues(alpha: 0.86)),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Original Audio - ${reel.user?.username ?? 'User'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MusicDisc extends StatelessWidget {
  final String? image;

  const _MusicDisc({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: image != null && image!.isNotEmpty
            ? DecorationImage(image: NetworkImage(image!), fit: BoxFit.cover)
            : const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}
