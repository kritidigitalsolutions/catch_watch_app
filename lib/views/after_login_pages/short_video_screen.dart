import 'package:catch_watch/res/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../utils/text_style.dart';

class ShortVideoPlayerScreen extends StatefulWidget {
  final bool isVisible;

  const ShortVideoPlayerScreen({super.key, required this.isVisible});

  @override
  State<ShortVideoPlayerScreen> createState() => _ShortVideoPlayerScreenState();
}

class _ShortVideoPlayerScreenState extends State<ShortVideoPlayerScreen> {
  final PageController _pageController = PageController();
  final List<_ShortVideo> _shorts = _dummyShorts;
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _toggleLike(int index) {
    setState(() {
      final short = _shorts[index];
      short.isLiked = !short.isLiked;
      short.likes += short.isLiked ? 1 : -1;
    });
  }

  void _toggleSave(int index) {
    setState(() {
      _shorts[index].isSaved = !_shorts[index].isSaved;
    });
  }

  void _showComments(_ShortVideo short) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${short.comments} comments',
                  style: text18(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ...short.sampleComments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: comment.color,
                          child: Text(
                            comment.name[0],
                            style: text14(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.name,
                                style: text14(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                comment.message,
                                style: text14(color: AppColors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(), // ✅ ADD
        itemBuilder: (context, index) {
          return _ShortVideoPage(
            key: ValueKey(_shorts[index].videoUrl),
            short: _shorts[index],
            isActive: widget.isVisible && index == _currentIndex,
            onLike: () => _toggleLike(index),
            onSave: () => _toggleSave(index),
            onComment: () => _showComments(_shorts[index]),
          );
        },
      ),
    );
  }
}

class _ShortVideoPage extends StatefulWidget {
  final _ShortVideo short;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _ShortVideoPage({
    super.key,
    required this.short,
    required this.isActive,
    required this.onLike,
    required this.onSave,
    required this.onComment,
  });

  @override
  State<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<_ShortVideoPage> {
  late final VideoPlayerController _controller;
  bool _hasStarted = false;
  bool _showPlayIcon = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.short.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (!mounted) return;
      setState(() {});
      _syncPlayback(); // ✅ YAHAN ADD KARO — pehle yeh missing tha
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
    if (!_controller.value.isInitialized) return;

    if (mounted) {
      setState(() {
        if (widget.isActive) {
          _controller.play();
          _hasStarted = true;
        } else {
          _controller.pause();
          _controller.seekTo(Duration.zero);
          _hasStarted = false;
          _showPlayIcon = false;
        }
      });
    }
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showPlayIcon = true;
      } else {
        _controller.play();
        _hasStarted = true;
        _showPlayIcon = false;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
            short: widget.short,
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
                  'Shorts',
                  style: text24(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () {},
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 112,
            child: _ShortActions(
              short: widget.short,
              onLike: widget.onLike,
              onSave: widget.onSave,
              onComment: widget.onComment,
            ),
          ),
          Positioned(
            left: 16,
            right: 82,
            bottom: 34,
            child: _ShortInfo(short: widget.short),
          ),
          Positioned(
            right: 18,
            bottom: 40,
            child: _MusicDisc(image: widget.short.posterAsset),
          ),
          if (!_controller.value.isInitialized)
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
                  color: Colors.black.withOpacity(0.45),
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
  final VideoPlayerController controller;
  final _ShortVideo short;
  final bool hasStarted;

  const _VideoBackground({
    required this.controller,
    required this.short,
    required this.hasStarted,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Image.asset(short.posterAsset, fit: BoxFit.cover);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
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
            Colors.black.withOpacity(0.42),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.9),
          ],
          stops: const [0, 0.26, 0.55, 1],
        ),
      ),
    );
  }
}

class _ShortActions extends StatelessWidget {
  final _ShortVideo short;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _ShortActions({
    required this.short,
    required this.onLike,
    required this.onSave,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: short.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: _compactCount(short.likes),
          color: short.isLiked ? const Color(0xFFFF3D57) : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _compactCount(short.comments),
          onTap: onComment,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: short.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: short.isSaved ? 'Saved' : 'Save',
          color: short.isSaved ? const Color(0xFFFFC145) : Colors.white,
          onTap: onSave,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Share ${short.title}'),
                duration: const Duration(milliseconds: 900),
              ),
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
              color: Colors.black.withOpacity(0.38),
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
  final _ShortVideo short;

  const _ShortInfo({required this.short});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: short.avatarColor,
              child: Text(
                short.creator[0],
                style: text18(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '@${short.creator}',
                overflow: TextOverflow.ellipsis,
                style: text16(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Follow',
                style: text12(color: Colors.black, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          short.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text16(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          short.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text14(color: Colors.white.withOpacity(0.86)),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                short.sound,
                overflow: TextOverflow.ellipsis,
                style: text12(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MusicDisc extends StatelessWidget {
  final String image;

  const _MusicDisc({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
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

class _ShortVideo {
  final String creator;
  final String title;
  final String caption;
  final String sound;
  final String videoUrl;
  final String posterAsset;
  final Color avatarColor;
  final List<_Comment> sampleComments;
  int likes;
  int comments;
  bool isLiked;
  bool isSaved;

  _ShortVideo({
    required this.creator,
    required this.title,
    required this.caption,
    required this.sound,
    required this.videoUrl,
    required this.posterAsset,
    required this.avatarColor,
    required this.sampleComments,
    required this.likes,
    required this.comments,
    this.isLiked = false,
    this.isSaved = false,
  });
}

class _Comment {
  final String name;
  final String message;
  final Color color;

  const _Comment({
    required this.name,
    required this.message,
    required this.color,
  });
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

final List<_ShortVideo> _dummyShorts = [
  _ShortVideo(
    creator: 'kimvastavik',
    title: 'Morning chase',
    caption: 'A tiny city moment with full movie energy.',
    sound: 'Original audio - Catch Watch',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    posterAsset: 'assets/images/1.png',
    avatarColor: const Color(0xFFFF5F00),
    likes: 12400,
    comments: 248,
    sampleComments: const [
      _Comment(
        name: 'Aarav',
        message: 'This shot is so clean.',
        color: Color(0xFF7C4DFF),
      ),
      _Comment(
        name: 'Neha',
        message: 'Need the full short film now.',
        color: Color(0xFF009688),
      ),
    ],
  ),
  _ShortVideo(
    creator: 'storycuts',
    title: 'Late night reveal',
    caption: 'When the final clue changes everything.',
    sound: 'Suspense beat - Studio Mix',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    posterAsset: 'assets/images/2.png',
    avatarColor: const Color(0xFF1565C0),
    likes: 8700,
    comments: 119,
    sampleComments: const [
      _Comment(
        name: 'Riya',
        message: 'The ending hook got me.',
        color: Color(0xFFD81B60),
      ),
      _Comment(
        name: 'Kabir',
        message: 'This needs part two.',
        color: Color(0xFF5D4037),
      ),
    ],
  ),
  _ShortVideo(
    creator: 'framepilot',
    title: 'Behind the stunt',
    caption: 'No budget, just timing, teamwork and a fearless camera move.',
    sound: 'Action loop - Creators Pack',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    posterAsset: 'assets/images/3.png',
    avatarColor: const Color(0xFF2E7D32),
    likes: 20300,
    comments: 412,
    sampleComments: const [
      _Comment(
        name: 'Ishaan',
        message: 'Camera movement is fire.',
        color: Color(0xFFEF6C00),
      ),
      _Comment(
        name: 'Tara',
        message: 'Loved the practical setup.',
        color: Color(0xFF00838F),
      ),
    ],
  ),
  _ShortVideo(
    creator: 'reelcraft',
    title: 'Golden hour magic',
    caption: 'One shot, no edit, pure light.',
    sound: 'Chill vibes - Reel Pack',
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/hummingbird.mp4',
    posterAsset: 'assets/images/1.png',
    avatarColor: const Color(0xFF6A1B9A),
    likes: 31500,
    comments: 674,
    sampleComments: const [
      _Comment(
        name: 'Priya',
        message: 'This light is unreal!',
        color: Color(0xFFFDD835),
      ),
      _Comment(
        name: 'Aryan',
        message: 'Shot on what?',
        color: Color(0xFF1E88E5),
      ),
    ],
  ),
];
