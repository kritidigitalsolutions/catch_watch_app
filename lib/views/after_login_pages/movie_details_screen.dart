import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/movie_details_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class MovieDetailScreen extends StatelessWidget {
  final Content content;
  const MovieDetailScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MovieDetailProvider(content),
      child: const _MovieDetailView(),
    );
  }
}

class _MovieDetailView extends StatelessWidget {
  const _MovieDetailView();

  @override
  Widget build(BuildContext context) {
    final isFullscreen = context.select<MovieDetailProvider, bool>(
      (p) => p.isFullscreen,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      body: isFullscreen
          ? const _VideoPlayerSection()
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _VideoPlayerSection()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _MovieInfoHeader(),
                          SizedBox(height: 20),
                          _ActionButtons(),
                          SizedBox(height: 20),
                          _DescriptionSection(),
                          SizedBox(height: 24),
                          _CastSection(),
                          SizedBox(height: 24),
                          _MoreLikeThisSection(),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _VideoPlayerSection extends StatelessWidget {
  const _VideoPlayerSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();
    final isFullscreen = provider.isFullscreen;
    final height = isFullscreen ? MediaQuery.of(context).size.height : 240.0;

    return GestureDetector(
      onTap: provider.toggleControls,
      child: Container(
        width: double.infinity,
        height: height,
        color: AppColors.black,
        child: Stack(
          children: [
            Positioned.fill(child: _VideoContent()),

            if (provider.isBuffering && provider.isInitialized)
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ),

            AnimatedOpacity(
              opacity: provider.showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !provider.showControls,
                child: Container(
                  color: AppColors.black.withOpacity(0.45),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PlayerTopBar(),
                      _PlayerControls(),
                      _PlayerBottomBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();

    if (provider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.white54, size: 40),
            const SizedBox(height: 10),
            Text(
              provider.errorMessage,
              style: text13(color: AppColors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    if (!provider.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          provider.content.poster != null
              ? Image.network(
                  provider.content.poster!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: Colors.grey[900]),
                )
              : Container(color: Colors.grey[900]),
          Container(color: Colors.black.withOpacity(0.5)),
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: provider.videoController!.value.aspectRatio,
        child: VideoPlayer(provider.videoController!),
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();
    return SafeArea(
      bottom: false,
      top: provider
          .isFullscreen, // ← FIX: non-fullscreen mein SafeArea top disable
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _iconBtn(
              Icons.arrow_back_ios_new_rounded,
              () => provider.isFullscreen
                  ? provider.exitFullscreen()
                  : Navigator.maybePop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                provider.content.title ?? '',
                style: text14(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _iconBtn(
              provider.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              provider.toggleMute,
            ),
            GestureDetector(
              onTap: () => _showSpeedSheet(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${provider.playbackSpeed}x',
                  style: text12(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showQualitySheet(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider.selectedQuality,
                  style: text12(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: AppColors.white, size: 20),
    ),
  );

  void _showSpeedSheet(BuildContext context, MovieDetailProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SpeedSheet(provider: provider),
    );
  }

  void _showQualitySheet(BuildContext context, MovieDetailProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QualitySheet(provider: provider),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SeekButton(
          icon: Icons.replay_10_rounded,
          onTap: provider.seekBackward,
        ),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: provider.togglePlay,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              provider.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: AppColors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 28),
        _SeekButton(
          icon: Icons.forward_10_rounded,
          onTap: provider.seekForward,
        ),
      ],
    );
  }
}

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SeekButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.white, size: 24),
      ),
    );
  }
}

class _PlayerBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();
    return SafeArea(
      top: false,
      bottom: provider
          .isFullscreen, // ← FIX: non-fullscreen mein SafeArea bottom disable
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.formattedPosition,
                  style: text11(color: AppColors.white70),
                ),
                Text(
                  provider.formattedDuration,
                  style: text11(color: AppColors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                LayoutBuilder(
                  builder: (_, constraints) => Container(
                    height: 3,
                    width: constraints.maxWidth * provider.bufferedValue,
                    decoration: BoxDecoration(
                      color: AppColors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.25),
                  ),
                  child: Slider(
                    value: provider.progressValue,
                    onChanged: provider.seekTo,
                    onChangeStart: (_) => provider.showControlsTemporarily(),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => provider.isFullscreen
                      ? provider.exitFullscreen()
                      : provider.enterFullscreen(context),
                  child: Icon(
                    provider.isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: AppColors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieInfoHeader extends StatelessWidget {
  const _MovieInfoHeader();

  @override
  Widget build(BuildContext context) {
    final content = context.read<MovieDetailProvider>().content;
    final infoStr = [
      content.releaseYear?.toString(),
      content.duration,
      content.language,
    ].where((e) => e != null).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                content.title ?? '',
                style: text20(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    content.rating?.toString() ?? '0.0',
                    style: text13(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(infoStr, style: text12(color: AppColors.textSecondary)),
        if (content.genre != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: content.genre!
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      g,
                      style: text11(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieDetailProvider>();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.togglePlay,
            icon: Icon(
              provider.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              provider.isPlaying ? 'Pause' : 'Watch Now',
              style: text14(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _SmallActionBtn(
          icon: Icons.download_outlined,
          label: 'Download',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _SmallActionBtn(
          icon: provider.isWishlisted
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: 'Wishlist',
          onTap: provider.toggleWishlist,
          iconColor: provider.isWishlisted
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        const SizedBox(width: 8),
        _SmallActionBtn(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  const _SmallActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: text10(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection();

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final desc = context.read<MovieDetailProvider>().content.description;
    if (desc == null || desc.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: text16(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc,
                style: text13(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _expanded ? 'Show less' : 'Read more',
                style: text12(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection();

  @override
  Widget build(BuildContext context) {
    final cast = context.read<MovieDetailProvider>().content.cast;
    if (cast == null || cast.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cast', style: text16(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _CastCard(name: cast[i]),
          ),
        ),
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  final String name;
  const _CastCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.35),
              width: 2,
            ),
          ),
          child: const ClipOval(
            child: Icon(Icons.person, color: AppColors.grey400, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          child: Text(
            name,
            style: text10(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MoreLikeThisSection extends StatelessWidget {
  const _MoreLikeThisSection();

  @override
  Widget build(BuildContext context) {
    // For now, we can use trending content as "more like this" or similar
    // Since we don't have a direct field for it in Content model
    return const SizedBox();
  }
}

class _SpeedSheet extends StatelessWidget {
  final MovieDetailProvider provider;
  const _SpeedSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Playback Speed',
            style: text16(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...MovieDetailProvider.speedOptions.map((speed) {
            final selected = provider.playbackSpeed == speed;
            return GestureDetector(
              onTap: () {
                provider.setSpeed(speed);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        speed == 1.0 ? 'Normal (1.0x)' : '${speed}x',
                        style: text15(
                          color: selected ? AppColors.primary : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QualitySheet extends StatelessWidget {
  final MovieDetailProvider provider;
  const _QualitySheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Video Quality',
            style: text16(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...provider.qualityOptions.map((q) {
            final selected = provider.selectedQuality == q;
            return GestureDetector(
              onTap: () {
                provider.setQuality(q);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q,
                        style: text15(
                          color: selected ? AppColors.primary : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
