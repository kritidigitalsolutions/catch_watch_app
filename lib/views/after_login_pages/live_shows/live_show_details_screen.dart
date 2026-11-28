import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../models/live_show_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_show_provider.dart';

/// Screen displaying complete details, live stream / video playback, and metadata for a live show matching Catch & Watch UI.
class LiveShowDetailsScreen extends StatefulWidget {
  final String showId;
  final LiveShowModel? initialShow;

  const LiveShowDetailsScreen({
    super.key,
    required this.showId,
    this.initialShow,
  });

  @override
  State<LiveShowDetailsScreen> createState() => _LiveShowDetailsScreenState();
}

class _LiveShowDetailsScreenState extends State<LiveShowDetailsScreen> {
  LiveShowProvider? _showProvider;
  YoutubePlayerController? _youtubeController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _showProvider = context.read<LiveShowProvider>();

    if (widget.initialShow != null) {
      _showProvider?.setSelectedShow(widget.initialShow!);
      _initPlayer(widget.initialShow);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showId.trim().isNotEmpty) {
        _showProvider?.fetchShowDetails(widget.showId).then((_) {
          final fetched = _showProvider?.selectedShow;
          if (fetched != null && !_isPlaying) {
            _initPlayer(fetched);
          }
        });
        _showProvider?.startShowPolling(widget.showId);
        _showProvider?.startViewerHeartbeat(widget.showId);
      }
    });
  }

  void _initPlayer(LiveShowModel? show) {
    if (show == null) return;
    final ytId = show.youtubeVideoId ?? extractYouTubeId(show.streamUrl);
    if (ytId != null && ytId.isNotEmpty && _youtubeController == null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: ytId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          isLive: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _showProvider?.stopShowPolling();
    _showProvider?.stopViewerHeartbeat();
    super.dispose();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nov 27, 2:27 AM';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<LiveShowProvider>(
          builder: (context, provider, _) {
            final show = provider.selectedShow ?? widget.initialShow;
            return Text(
              show?.title ?? 'Live Show Details',
              style: text16(color: AppColors.black, fontWeight: FontWeight.w900),
            );
          },
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () {
              if (widget.showId.trim().isNotEmpty) {
                context.read<LiveShowProvider>().fetchShowDetails(widget.showId);
              }
            },
          ),
        ],
      ),
      body: Consumer<LiveShowProvider>(
        builder: (context, provider, _) {
          final show = provider.selectedShow ?? widget.initialShow;
          final isLoading = provider.isLoadingDetails;
          final error = provider.detailsError;

          if (show == null && isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (show == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(error ?? 'Live show not found', style: text14(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchShowDetails(widget.showId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          _initPlayer(show);
          final bannerUrl = show.banner ?? show.poster ?? '';
          final dateStr = _formatDateTime(show.startTime);

          return RefreshIndicator(
            onRefresh: () => provider.fetchShowDetails(widget.showId),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Video Player / Stream Banner Preview (Height 230)
                  Container(
                    height: 230,
                    width: double.infinity,
                    color: Colors.black,
                    child: _isPlaying && _youtubeController != null
                        ? YoutubePlayer(
                            controller: _youtubeController!,
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              bannerUrl.isNotEmpty
                                  ? Image.network(
                                      bannerUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(),
                                    )
                                  : _buildFallbackBanner(),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withAlpha(80), Colors.black.withAlpha(180)],
                                  ),
                                ),
                              ),
                              Center(
                                child: GestureDetector(
                                  onTap: () async {
                                    provider.recordViewPing(show.id);
                                    if (_youtubeController != null) {
                                      setState(() {
                                        _isPlaying = true;
                                      });
                                    } else if (show.streamUrl != null && show.streamUrl!.isNotEmpty) {
                                      final uri = Uri.parse(show.streamUrl!);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withAlpha(128),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  // 2. Metadata Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags Row (LIVE SHOW, YOUTUBE, Date)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0E8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('LIVE SHOW', style: text10(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('YOUTUBE', style: text10(color: const Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(dateStr, style: text11(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Title & Share Button Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                show.title,
                                style: text20(color: AppColors.black, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sharing live show...')),
                                );
                              },
                              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 16),
                              label: Text('Share', style: text12(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (show.description != null && show.description!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            show.description!,
                            style: text13(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // 3. Live Chat & Fan Reactions Section
                        Text(
                          'Live Chat & Fan Reactions',
                          style: text15(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.grey200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Chat is active. Send a message to interact with the host!',
                            style: text13(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
    );
  }
}
