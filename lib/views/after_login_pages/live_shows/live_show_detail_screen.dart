import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import '../../../view_model/after_login_provider/live_show_provider.dart';

class LiveShowDetailScreen extends StatefulWidget {
  final String showId;

  const LiveShowDetailScreen({super.key, required this.showId});

  @override
  State<LiveShowDetailScreen> createState() => _LiveShowDetailScreenState();
}

class _LiveShowDetailScreenState extends State<LiveShowDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveShowProvider(),
      child: _ShowDetailView(showId: widget.showId),
    );
  }
}

class _ShowDetailView extends StatefulWidget {
  final String showId;

  const _ShowDetailView({required this.showId});

  @override
  State<_ShowDetailView> createState() => _ShowDetailViewState();
}

class _ShowDetailViewState extends State<_ShowDetailView> {
  YoutubePlayerController? _youtubeController;
  bool _isYouTubeInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveShowProvider>().loadShowDetails(widget.showId);
    });
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    context.read<LiveShowProvider>().stopPolling();
    super.dispose();
  }

  void _initYouTube(String videoId) {
    if (_youtubeController != null) return;
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: true,
        enableCaption: true,
      ),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _isYouTubeInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveShowProvider>();
    final show = provider.currentShowDetail;

    if (show != null && show.youtubeVideoId != null && show.youtubeVideoId!.isNotEmpty && !_isYouTubeInitialized) {
      _initYouTube(show.youtubeVideoId!);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          show?.title ?? 'Live Show',
          style: text16(color: AppColors.black, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => provider.loadShowDetails(widget.showId),
          ),
        ],
      ),
      body: provider.isDetailLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : show == null
              ? Center(child: Text('Failed to load show details.', style: text14(color: AppColors.error)))
              : RefreshIndicator(
                  onRefresh: () => provider.loadShowDetails(widget.showId),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Video Player Area
                      Container(
                        color: Colors.black,
                        width: double.infinity,
                        child: _youtubeController != null
                            ? YoutubePlayerBuilder(
                                player: YoutubePlayer(
                                  controller: _youtubeController!,
                                ),
                                builder: (context, player) {
                                  return player;
                                },
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  show.thumbnail != null && show.thumbnail!.isNotEmpty
                                      ? UniversalImage(url: show.thumbnail!, height: 240, width: double.infinity, fit: BoxFit.cover)
                                      : Container(height: 240, color: AppColors.grey800),
                                  Container(height: 240, color: Colors.black.withAlpha(120)),
                                  const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 64),
                                  // LIVE STREAM badge
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                          const SizedBox(width: 4),
                                          Text('LIVE STREAM', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Viewers count badge
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.black.withAlpha(180), borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.remove_red_eye, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text('${show.viewerCount ?? 5} watching', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Details Section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges Row: LIVE SHOW, YOUTUBE, Date
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                                  child: Text('LIVE SHOW', style: text10(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                                  child: Text(show.resolvedStreamType?.toUpperCase() ?? 'YOUTUBE', style: text10(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.calendar_today, size: 12, color: AppColors.grey500),
                                const SizedBox(width: 4),
                                Text(
                                  show.scheduledStartTime != null ? _formatFullDate(show.scheduledStartTime!) : 'Nov 27, 07:57 AM',
                                  style: text11(color: AppColors.grey600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Title & Share Button Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    show.title ?? '',
                                    style: text20(color: AppColors.black, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Share.share('Check out this live show: ${show.title} on CatchWatch!');
                                  },
                                  icon: const Icon(Icons.share, size: 14, color: Colors.white),
                                  label: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Description
                            if (show.description != null && show.description!.isNotEmpty)
                              Text(
                                show.description!,
                                style: text13(color: AppColors.grey700),
                              ),
                            const SizedBox(height: 20),

                            // Live Chat / Q&A Section
                            Text('Live Chat & Fan Reactions', style: text14(color: AppColors.black, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.grey300),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: show.chatMessages == null || show.chatMessages!.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                        child: Text(
                                          'Chat is active. Send a message to interact with the host!',
                                          style: TextStyle(color: AppColors.grey500, fontSize: 12),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: show.chatMessages!.length,
                                      itemBuilder: (context, index) {
                                        final msg = show.chatMessages![index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: AppColors.primary.withAlpha(30),
                                                child: const Icon(Icons.person, size: 14, color: AppColors.primary),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(msg.username ?? 'Viewer', style: text11(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 2),
                                                    Text(msg.message ?? '', style: text12(color: AppColors.black)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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

  String _formatFullDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $hour:$minute $amPm';
    } catch (_) {
      return 'Nov 27, 07:57 AM';
    }
  }
}
