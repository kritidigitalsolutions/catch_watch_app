import 'dart:async';
import 'dart:io';
import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/share_helper.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../utils/hive_service/hive_service.dart';
import '../../res/appUrl.dart' show AppUrl;
import '../../utils/text_style.dart';
import '../../view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/views/after_login_pages/report/report_bottom_sheet.dart';
import 'package:catch_watch/view_model/after_login_provider/block_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/block_confirmation_dialog.dart';
import 'package:catch_watch/view_model/after_login_provider/user_search_provider.dart';

/// Why a reel video failed to play (drives the message shown to the user).
enum _PlaybackFailureKind {
  none(''),
  missingUrl('This video has no playable link.'),
  blockedContent("This video type isn't available on iOS."),
  invalidUrl('The video link is invalid.'),
  expiredOrDenied(
      'The video link expired or access was denied. Pull down to refresh the feed.'),
  notFound('This video is no longer available.'),
  serverError('The video server is having problems. Please try again shortly.'),
  network('Check your internet connection and retry.'),
  timeout('The video took too long to load. Please retry.'),
  unsupportedFormat("This video format isn't supported on your device."),
  unknown('Something went wrong while loading this video.');

  const _PlaybackFailureKind(this.userMessage);
  final String userMessage;
}

/// Result of a lightweight reachability probe against a video URL.
class ReelVideoProbeResult {
  final int? statusCode;
  final String? contentType;
  final Object? error;
  const ReelVideoProbeResult({this.statusCode, this.contentType, this.error});
}

typedef ReelVideoProbe = Future<ReelVideoProbeResult> Function(
  String url,
  Map<String, String> headers,
);

Future<ReelVideoProbeResult> _defaultReelVideoProbe(
  String url,
  Map<String, String> headers,
) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  try {
    final HttpClientRequest request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
    final HttpClientResponse response =
        await request.close().timeout(const Duration(seconds: 8));
    final String? contentType = response.headers.contentType?.mimeType;
    await response.drain<void>().timeout(const Duration(seconds: 4));
    return ReelVideoProbeResult(
      statusCode: response.statusCode,
      contentType: contentType,
    );
  } catch (e) {
    return ReelVideoProbeResult(error: e);
  } finally {
    client.close(force: true);
  }
}

/// Probe used to diagnose failed playback. Overridable in tests.
ReelVideoProbe debugReelVideoProbe = _defaultReelVideoProbe;

/// Removes query strings/fragments/userinfo so signed URLs and tokens never reach logs.
String redactReelUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url.split('?').first;
  final String hasQuery = uri.hasQuery ? '?<redacted>' : '';
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}$hasQuery';
}

/// Maps a probe result to a failure kind, or `null` if the probe cannot explain the failure.
_PlaybackFailureKind? _classifyReelProbe(ReelVideoProbeResult probe) {
  final Object? error = probe.error;
  if (error != null) {
    if (error is TimeoutException) return _PlaybackFailureKind.timeout;
    if (error is SocketException || error is HandshakeException) {
      return _PlaybackFailureKind.network;
    }
    return null;
  }
  final int? status = probe.statusCode;
  if (status == null) return null;
  if (status == 401 || status == 403) return _PlaybackFailureKind.expiredOrDenied;
  if (status == 404 || status == 410) return _PlaybackFailureKind.notFound;
  if (status >= 500) return _PlaybackFailureKind.serverError;
  if (status >= 400 && status != 416) return _PlaybackFailureKind.unknown;
  final String type = (probe.contentType ?? '').toLowerCase();
  if (type.startsWith('text/') ||
      type == 'application/json' ||
      type.startsWith('image/')) {
    return _PlaybackFailureKind.unsupportedFormat;
  }
  // Reachable, 2xx and video-ish content: the player rejected it, most likely a codec/container issue.
  return _PlaybackFailureKind.unsupportedFormat;
}

class ShortVideoPlayerScreen extends StatefulWidget {
  final bool isVisible;
  final List<ReelModel>? initialReels;
  final int initialIndex;
  final bool? showBackButton;

  const ShortVideoPlayerScreen({
    super.key,
    required this.isVisible,
    this.initialReels,
    this.initialIndex = 0,
    this.showBackButton,
  });

  @override
  State<ShortVideoPlayerScreen> createState() => _ShortVideoPlayerScreenState();
}

class _ShortVideoPlayerScreenState extends State<ShortVideoPlayerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  List<ReelModel> _getDisplayReels(ReelsProvider provider) {
    final List<ReelModel> source = widget.initialReels ?? provider.reels;
    return source.where(provider.shouldIncludeReelInFeed).toList();
  }

  int _resolveInitialIndex() {
    final List<ReelModel>? initialList = widget.initialReels;
    if (initialList == null || initialList.isEmpty) {
      return widget.initialIndex;
    }
    final List<ReelModel> filtered = ReelsProvider.filterPlayableReels(initialList);
    if (filtered.isEmpty) return 0;

    if (widget.initialIndex >= 0 && widget.initialIndex < initialList.length) {
      final ReelModel selected = initialList[widget.initialIndex];
      final int matchedIndex = filtered.indexWhere(
        (r) => identical(r, selected) || (r.id != null && r.id == selected.id),
      );
      if (matchedIndex != -1) return matchedIndex;
    }
    return widget.initialIndex.clamp(0, filtered.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _resolveInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reelsProvider = context.read<ReelsProvider>();
      if (widget.initialReels != null) {
        reelsProvider.applyInteractionsTo(
          _getDisplayReels(reelsProvider),
        );
      } else {
        if (!reelsProvider.hasFetchedFeed && !reelsProvider.isLoading) {
          reelsProvider.fetchReelsFeed().then((_) {
            if (mounted && reelsProvider.targetReelId != null) {
              _handleTargetReel();
            }
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortVideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the tab becomes visible in IndexedStack
    if (widget.isVisible && !oldWidget.isVisible) {
      final reelsProvider = context.read<ReelsProvider>();
      if (widget.initialReels == null) {
        if (!reelsProvider.hasFetchedFeed && !reelsProvider.isLoading) {
          reelsProvider.fetchReelsFeed().then((_) {
            if (mounted && reelsProvider.targetReelId != null) {
              _handleTargetReel();
            }
          });
        } else if (reelsProvider.targetReelId != null) {
          _handleTargetReel();
        }
      }
    }
  }

  Future<void> _handleTargetReel() async {
    final reelsProvider = context.read<ReelsProvider>();
    final targetId = reelsProvider.targetReelId;
    if (targetId == null) return;

    // Ensure the reel is in the list (fetch if missing)
    await reelsProvider.ensureReelVisible(targetId);
    
    final index = reelsProvider.reels.indexWhere((r) => r.id == targetId);
    if (mounted) {
      if (index != -1 && _pageController.hasClients) {
        _pageController.jumpToPage(index);
        setState(() => _currentIndex = index);
      }
      reelsProvider.setTargetReelId(null);
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
    if (reel.id == null) return;
    final provider = context.read<ReelsProvider>();
    final String? currentUserId = HiveService.userId;
    final bool isOwner = currentUserId != null && reel.user?.id == currentUserId;
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
                        color: Colors.white.withOpacity(0.24),
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
                            final bool isPinned = comment['isPinned'] ?? false;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                _showCommentOptions(context, comment, reel.id!, p, isOwner: isOwner);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SafeCircularImage(
                                      radius: 16,
                                      imageUrl: ReelModel.normalizeMediaUrl(
                                        user is Map ? user['profileImage']?.toString() : null,
                                      ),
                                      backgroundColor: AppColors.primary,
                                      fallback: Text(
                                        (user is Map &&
                                                user['name'] != null &&
                                                user['name'].toString().trim().isNotEmpty)
                                            ? user['name'].toString().trim()[0]
                                            : '?',
                                        style: text12(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                user?['username'] ?? 'User',
                                                style: text12(color: Colors.white70, fontWeight: FontWeight.bold),
                                              ),
                                              if (isPinned) ...[
                                                const SizedBox(width: 8),
                                                const Icon(Icons.push_pin_rounded, color: AppColors.primary, size: 12),
                                                const SizedBox(width: 4),
                                                Text('Pinned', style: text10(color: AppColors.primary)),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            comment['text'] ?? '',
                                            style: text14(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showCommentOptions(context, comment, reel.id!, p, isOwner: isOwner),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Icon(Icons.more_vert_rounded, color: Colors.white38, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
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
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
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

  void _showCommentOptions(BuildContext context, dynamic comment, String reelId, ReelsProvider p, {bool isOwner = false}) {
    final bool isPinned = comment['isPinned'] ?? false;
    final currentUserId = HiveService.userId;
    final user = comment['user'];
    final String? commentAuthorId = user is Map ? user['_id']?.toString() : user?.toString();
    final bool isAuthor = currentUserId != null && commentAuthorId == currentUserId;
    final String commentId = comment['_id']?.toString() ?? comment['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
              if (isOwner || isAuthor)
                ListTile(
                  leading: Icon(isPinned ? Icons.pin_end_rounded : Icons.push_pin_rounded, color: Colors.white),
                  title: Text(isPinned ? 'Unpin your comment' : 'Pin your comment', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    p.pinComment(comment['_id'], !isPinned, reelId);
                  },
                ),
              if (!isAuthor && commentId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: const Text('Report Comment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Report abuse, spam, or inappropriate content', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    showReportBottomSheet(
                      context,
                      targetType: 'comment',
                      targetId: commentId,
                      targetTitle: 'Report Comment',
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

  void _showReelOptions(BuildContext context, ReelModel reel) {
    if (reel.id == null || reel.id!.isEmpty) return;
    final currentUserId = HiveService.userId;
    final String? reelAuthorId = reel.user?.id;
    final bool isMyReel = currentUserId != null && reelAuthorId != null && currentUserId == reelAuthorId;

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
              if (!isMyReel)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                  title: const Text('Report Reel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Report inappropriate or infringing content', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    showReportBottomSheet(
                      context,
                      targetType: 'reel',
                      targetId: reel.id!,
                      targetTitle: 'Report Reel',
                    );
                  },
                ),
              if (!isMyReel && reelAuthorId != null && reelAuthorId.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                  title: const Text('Block User', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Block @${reel.user?.username ?? reel.user?.name ?? 'user'} and hide their content',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    if (!HiveService.isLogin()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please login to block users')),
                      );
                      return;
                    }

                    if (reelAuthorId == currentUserId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You cannot block your own account')),
                      );
                      return;
                    }

                    String? backendMessage;
                    final bool? confirmed = await showBlockConfirmationDialog(
                      context: context,
                      userId: reelAuthorId,
                      username: reel.user?.username,
                      name: reel.user?.name,
                      onConfirmBlock: () async {
                        try {
                          final res = await context.read<BlockProvider>().blockUser(
                            reelAuthorId,
                            username: reel.user?.username,
                            name: reel.user?.name,
                            profileImage: reel.user?.profileImage,
                          );
                          backendMessage = res?.message ?? 'User blocked successfully.';
                          return res != null && res.success;
                        } catch (e) {
                          final msg = e.toString().replaceAll('Exception: ', '');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: AppColors.error),
                            );
                          }
                          return false;
                        }
                      },
                    );

                    if (confirmed == true && context.mounted) {
                      context.read<ReelsProvider>().onUserBlocked(reelAuthorId);
                      context.read<UserSearchProvider>().onUserBlocked(reelAuthorId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(backendMessage ?? 'User blocked successfully.'),
                          backgroundColor: Colors.black87,
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text('Share Reel', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(modalCtx);
                  context.read<ReelsProvider>().incrementShares(reel.id!, reel: reel);
                  ShareHelper.shareContent(
                    title: 'Catch Watch Reel',
                    text: 'Check out this Reel: ${reel.caption}',
                    imageUrl: reel.thumbnail,
                    contentId: reel.id,
                    contentType: 'reel',
                    context: context,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelsProvider>();
    final reels = _getDisplayReels(provider);
    final bool canPop = Navigator.canPop(context);
    final bool shouldShowBack = widget.showBackButton ?? (canPop && widget.initialReels != null);

    Widget buildBackBtn() {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
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
          ),
        ),
      );
    }

    // Listen for targetReelId even after initState (if already on this screen)
    if (widget.isVisible && provider.targetReelId != null && widget.initialReels == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTargetReel());
    }

    // Auto-fetch if screen is visible, initialReels is null, feed hasn't been fetched yet, and not currently loading or in error
    if (widget.isVisible && widget.initialReels == null && !provider.hasFetchedFeed && !provider.isLoading && provider.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !provider.hasFetchedFeed && !provider.isLoading && provider.error == null) {
          provider.fetchReelsFeed();
        }
      });
    }

    final bool isFeedWaiting = widget.initialReels == null &&
        (!provider.hasFetchedFeed || provider.isLoading) &&
        reels.isEmpty &&
        provider.error == null;

    if (isFeedWaiting || (provider.isLoading && reels.isEmpty)) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            if (shouldShowBack) buildBackBtn(),
          ],
        ),
      );
    }

    if (reels.isEmpty && provider.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
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
            if (shouldShowBack) buildBackBtn(),
          ],
        ),
      );
    }

    if (reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No reels available', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 16),
                  if (widget.initialReels == null)
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchReelsFeed(forceRefresh: true),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                ],
              ),
            ),
            if (shouldShowBack) buildBackBtn(),
          ],
        ),
      );
    }

    Widget buildPager() {
      return PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        onPageChanged: _onPageChanged,
        // Always scrollable so pull-to-refresh works even with a single reel.
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemBuilder: (context, index) {
          final reel = reels[index];
          return _ShortVideoPage(
            key: ValueKey(
              '${reel.isSponsoredAd ? "ad" : "reel"}_${reel.id ?? reel.adId ?? index}_${reel.videoUrl ?? ""}',
            ),
            reel: reel,
            isActive: widget.isVisible && index == _currentIndex,
            onLike: () {
              if (reel.id != null) provider.toggleLike(reel.id!, reel: reel);
            },
            onSave: () {
              if (reel.id != null) provider.toggleBookmark(reel.id!, reel: reel);
            },
            onComment: () => _showComments(reel),
            onMore: () => _showReelOptions(context, reel),
            onRefreshFeed:
                widget.initialReels == null ? _refreshFeed : null,
          );
        },
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (widget.initialReels == null)
              RefreshIndicator(
                onRefresh: _refreshFeed,
                color: AppColors.primary,
                backgroundColor: const Color(0xFF1E1E1E),
                edgeOffset: MediaQuery.paddingOf(context).top,
                notificationPredicate: (notification) => notification.depth == 0,
                child: buildPager(),
              )
            else
              buildPager(),
            if (shouldShowBack) buildBackBtn(),
          ],
        ),
      ),
    );
  }

  /// Pull-to-refresh handler: re-fetches page 1 of the feed (replacing stale
  /// data, keeping server ordering and sponsored interleaving), resets to the
  /// first reel and surfaces failures without wiping the existing feed.
  Future<void> _refreshFeed() async {
    if (widget.initialReels != null || !mounted) return;
    final ReelsProvider provider = context.read<ReelsProvider>();
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final bool ok = await provider.refreshReelsFeed();
    if (!mounted) return;
    if (ok) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      setState(() => _currentIndex = 0);
    } else {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Couldn't refresh reels. Showing your previous feed."),
        ),
      );
    }
  }
}

class _ShortVideoPage extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onMore;
  final Future<void> Function()? onRefreshFeed;

  const _ShortVideoPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onMore,
    this.onRefreshFeed,
  });

  @override
  State<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<_ShortVideoPage>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  YoutubePlayerController? _ytController;
  int _initGeneration = 0;
  Size _lastKnownVideoSize = Size.zero;
  bool _lastKnownIsInitialized = false;
  bool _hasStarted = false;
  bool _hasRenderedFirstFrame = false;
  bool _showPlayIcon = false;
  bool _isYoutube = false;
  bool _isImageAd = false;
  bool _hasVideoError = false;
  _PlaybackFailureKind _failureKind = _PlaybackFailureKind.none;
  String? _failureMessage;
  int _failureGeneration = -1;
  int _retryAttempt = 0;
  bool _isRetrying = false;
  String _activeUrl = '';
  static const Duration _initTimeout = Duration(seconds: 25);
  
  // Tracking logic
  late final Stopwatch _watchStopwatch;
  CallProvider? _callProvider;
  bool _viewRecorded = false;
  bool _impressionRecorded = false;
  static const int _viewThresholdSeconds = 3;
  static const int _qualifiedViewThresholdSeconds = 10;
  bool _qualifiedViewRecorded = false;

  String? get _effectiveAdId {
    final String? rawAdId = widget.reel.adId?.trim();
    if (rawAdId != null && rawAdId.isNotEmpty) {
      return rawAdId;
    }
    if (widget.reel.isSponsoredAd) {
      final String? fallbackId = widget.reel.id?.trim();
      if (fallbackId != null && fallbackId.isNotEmpty) {
        return fallbackId;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _watchStopwatch = Stopwatch();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
    
    // Record impression if active sponsored ad on initial mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isActive && widget.reel.isSponsoredAd && !_hasVideoError) {
        _recordAdImpression();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Stop playback so audio doesn't continue in the background.
        _pauseVideo();
        break;
      case AppLifecycleState.resumed:
        // Resume only the currently visible reel.
        if (widget.isActive && mounted) {
          _syncPlayback();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _callListener() {
    if (mounted) {
      final callStatus = (_callProvider ?? context.read<CallProvider>()).status;
      if (callStatus != CallStatus.idle) {
        _pauseVideo();
      } else if (widget.isActive) {
        _syncPlayback();
      }
    }
  }

  void _pauseVideo() {
    if (_isYoutube) {
      _ytController?.pause();
    } else {
      _controller?.pause();
    }
    if (_watchStopwatch.isRunning) {
      _watchStopwatch.stop();
    }
    if (mounted) setState(() {});
  }

  void _disposeControllerSafely(VideoPlayerController controller) {
    controller.removeListener(_videoListener);
    unawaited(
      controller.dispose().catchError((Object e) {
        _log('dispose_failed', <String, Object?>{'error': e.toString()});
      }),
    );
  }

  /// Returns the freshest known copy of the current reel (e.g. after a feed
  /// refresh delivered a new/unexpired URL), falling back to the widget's reel.
  ReelModel _latestReel() {
    try {
      final ReelsProvider provider = context.read<ReelsProvider>();
      final String? id = widget.reel.id;
      if (id == null) return widget.reel;
      for (final ReelModel candidate in provider.reels) {
        if (candidate.id == id &&
            candidate.isSponsoredAd == widget.reel.isSponsoredAd &&
            (candidate.videoUrl ?? '').trim().isNotEmpty &&
            provider.shouldIncludeReelInFeed(candidate)) {
          return candidate;
        }
      }
    } catch (_) {}
    return widget.reel;
  }

  /// Structured, token-safe debug logging for reel playback diagnostics.
  void _log(String event, [Map<String, Object?> fields = const <String, Object?>{}]) {
    if (!kDebugMode) return;
    final Map<String, Object?> payload = <String, Object?>{
      'reelId': widget.reel.id,
      'type': widget.reel.isSponsoredAd ? 'sponsored' : 'creator',
      'gen': _initGeneration,
      'retryAttempt': _retryAttempt,
      ...fields,
    };
    debugPrint('[REEL_PLAYBACK] $event $payload');
  }

  void _setFailure(_PlaybackFailureKind kind) {
    _hasVideoError = true;
    _failureKind = kind;
    _failureMessage = kind.userMessage;
  }

  /// Records a playback failure once per initialization generation, logs it,
  /// then probes the URL (HTTP status / content type) to give a meaningful reason.
  Future<void> _registerFailure({
    required int generation,
    required String url,
    Object? error,
    String? description,
  }) async {
    if (!mounted || generation != _initGeneration) return;
    if (_failureGeneration == generation) return;
    _failureGeneration = generation;

    final String? desc = description ?? error?.toString();
    _setFailure(error is TimeoutException
        ? _PlaybackFailureKind.timeout
        : _PlaybackFailureKind.unknown);
    _log('init_failed', <String, Object?>{
      'url': redactReelUrl(url),
      'error': desc,
      'kind': _failureKind.name,
    });
    if (mounted) setState(() {});

    if (!url.startsWith('http')) return;
    ReelVideoProbeResult probe;
    try {
      probe = await debugReelVideoProbe(
        url,
        AppUrl.buildVideoRequestHeaders(url, token: HiveService.getToken()),
      );
    } catch (e) {
      probe = ReelVideoProbeResult(error: e);
    }
    if (!mounted || generation != _initGeneration) return;
    _log('probe_result', <String, Object?>{
      'url': redactReelUrl(url),
      'status': probe.statusCode,
      'contentType': probe.contentType,
      'probeError': probe.error?.toString(),
    });
    final _PlaybackFailureKind? refined = _classifyReelProbe(probe);
    if (refined != null && refined != _failureKind) {
      _setFailure(refined);
      _log('failure_classified', <String, Object?>{'kind': refined.name});
      if (mounted) setState(() {});
    }
  }

  /// Retry: disposes the failed controller and re-creates it from the latest
  /// valid URL. Ignored while a previous retry is still in flight.
  Future<void> _retryPlayback() async {
    if (_isRetrying) return;
    _isRetrying = true;
    _retryAttempt++;
    _log('retry_start');
    if (mounted) setState(() {});
    try {
      final String? reelId = widget.reel.id;
      if (reelId != null && !widget.reel.isSponsoredAd) {
        try {
          await context.read<ReelsProvider>().fetchFreshReel(reelId);
        } catch (_) {}
      }
      await _initializeVideo(isRetry: true);
      _log('retry_result', <String, Object?>{
        'success': !_hasVideoError &&
            (_controller?.value.isInitialized ?? false),
        'kind': _failureKind.name,
      });
    } finally {
      _isRetrying = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _initializeVideo({bool isRetry = false}) async {
    final int generation = ++_initGeneration;
    final ReelModel reel = isRetry ? _latestReel() : widget.reel;
    final videoUrl = (reel.videoUrl ?? '').trim();
    _activeUrl = videoUrl;
    final bool isIOS = ReelsProvider.isIOSPlatform;
    final bool isAd = reel.isSponsoredAd;
    _log('init_start', <String, Object?>{
      'url': redactReelUrl(videoUrl),
      'isRetry': isRetry,
    });

    _isYoutube = ReelsProvider.isYoutubeUrl(videoUrl);
    _isImageAd = !isIOS && isAd && ReelsProvider.isImageAdReel(reel);
    _hasVideoError = false;
    _failureKind = _PlaybackFailureKind.none;
    _failureMessage = null;
    _showPlayIcon = false;
    _hasRenderedFirstFrame = false;
    _lastKnownVideoSize = Size.zero;
    _lastKnownIsInitialized = false;

    final oldController = _controller;
    final oldYtController = _ytController;
    _controller = null;
    _ytController = null;
    if (mounted) setState(() {});

    if (oldController != null) {
      // Never block (re)initialization on disposing a failed controller:
      // VideoPlayerController.dispose() awaits its creation completer, which
      // never completes if platform `create` threw, which would hang Retry forever.
      _disposeControllerSafely(oldController);
    }
    if (oldYtController != null) {
      oldYtController.removeListener(_ytVideoListener);
      oldYtController.dispose();
    }

    if (!mounted || generation != _initGeneration) return;

    if (videoUrl.isEmpty) {
      _setFailure(_PlaybackFailureKind.missingUrl);
      _log('init_failed', <String, Object?>{'kind': _failureKind.name});
      if (mounted) setState(() {});
      return;
    }

    // Defense-in-depth on iOS: block YouTube embeds and external/image ad items.
    if (isIOS && (_isYoutube || ReelsProvider.isAdOrExternalRedirectReel(reel))) {
      _setFailure(_PlaybackFailureKind.blockedContent);
      _log('init_failed', <String, Object?>{
        'url': redactReelUrl(videoUrl),
        'kind': _failureKind.name,
      });
      if (mounted) setState(() {});
      return;
    }

    // Static image ads on Android are rendered via Image.network in _VideoBackground.
    if (_isImageAd) {
      if (mounted) setState(() {});
      return;
    }

    if (_isYoutube) {
      final videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null && videoId.isNotEmpty) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            loop: true,
            hideControls: true,
            disableDragSeek: true,
            showLiveFullscreenButton: false,
          ),
        );
      } else {
        _setFailure(_PlaybackFailureKind.invalidUrl);
      }
      if (mounted) setState(() {});
      if (!_hasVideoError) {
        _syncPlayback();
      }
      return;
    }

    final Uri? parsedUri = videoUrl.startsWith('http') ? Uri.tryParse(videoUrl) : null;
    if (videoUrl.startsWith('http') &&
        (parsedUri == null || !parsedUri.hasAuthority || parsedUri.host.isEmpty)) {
      _setFailure(_PlaybackFailureKind.invalidUrl);
      _log('init_failed', <String, Object?>{
        'url': redactReelUrl(videoUrl),
        'kind': _failureKind.name,
      });
      if (mounted) setState(() {});
      return;
    }

    final VideoPlayerController nextController;
    if (videoUrl.startsWith('http')) {
      final token = HiveService.getToken();
      final Map<String, String> headers = AppUrl.buildVideoRequestHeaders(
        videoUrl,
        token: token,
      );
      nextController = VideoPlayerController.networkUrl(
        parsedUri!,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    } else {
      nextController = VideoPlayerController.file(
        File(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
    }

    _controller = nextController;
    nextController.addListener(_videoListener);

    try {
      await nextController.initialize().timeout(_initTimeout);
      if (!mounted || generation != _initGeneration || _controller != nextController) {
        _disposeControllerSafely(nextController);
        return;
      }
      if (nextController.value.hasError) {
        await _registerFailure(
          generation: generation,
          url: videoUrl,
          description: nextController.value.errorDescription,
        );
      } else {
        _lastKnownIsInitialized = nextController.value.isInitialized;
        _lastKnownVideoSize = nextController.value.size;
        await nextController.setLooping(true);
        _log('init_ok', <String, Object?>{
          'url': redactReelUrl(videoUrl),
          'size': '${nextController.value.size.width}x${nextController.value.size.height}',
          'aspectRatio': nextController.value.aspectRatio,
          'durationMs': nextController.value.duration.inMilliseconds,
          'positionMs': nextController.value.position.inMilliseconds,
        });
      }
      if (!mounted || generation != _initGeneration) return;
      setState(() {});
      if (!_hasVideoError) {
        _syncPlayback();
      }
    } catch (e) {
      if (!mounted || generation != _initGeneration || _controller != nextController) {
        _disposeControllerSafely(nextController);
        return;
      }
      await _registerFailure(generation: generation, url: videoUrl, error: e);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newCallProvider = context.read<CallProvider>();
    if (_callProvider != newCallProvider) {
      _callProvider?.removeListener(_callListener);
      _callProvider = newCallProvider;
      _callProvider?.addListener(_callListener);
    }
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id ||
        oldWidget.reel.adId != widget.reel.adId ||
        oldWidget.reel.videoUrl != widget.reel.videoUrl ||
        oldWidget.reel.isSponsoredAd != widget.reel.isSponsoredAd) {
      _impressionRecorded = false;
      _viewRecorded = false;
      _qualifiedViewRecorded = false;
      _initializeVideo();
      if (widget.isActive && widget.reel.isSponsoredAd && !_hasVideoError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive && widget.reel.isSponsoredAd && !_hasVideoError) {
            _recordAdImpression();
          }
        });
      }
    } else if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && widget.reel.isSponsoredAd && !_hasVideoError) {
        _recordAdImpression();
      }
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (!mounted) return;
    final bool isRouteActive = ModalRoute.of(context)?.isCurrent ?? true;
    final callProvider = _callProvider ?? context.read<CallProvider>();
    final bool isCallActive = callProvider.status != CallStatus.idle;

    if (!isRouteActive || isCallActive) {
      _pauseVideo();
      return;
    }

    if (_isYoutube) {
      if (_ytController == null) return;
      if (mounted) {
        setState(() {
          if (widget.isActive) {
            _ytController!.play();
            _hasStarted = true;
            _watchStopwatch.start();
            _ytController!.addListener(_ytVideoListener);
          } else {
            _ytController!.pause();
            _ytController!.seekTo(Duration.zero);
            _hasStarted = false;
            if (_watchStopwatch.isRunning) {
              _watchStopwatch.stop();
              _reportViewIfNecessary();
            }
            _ytController!.removeListener(_ytVideoListener);
          }
        });
      }
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;

    if (mounted) {
      setState(() {
        if (widget.isActive) {
          if (!_controller!.value.isPlaying) {
            _controller!.play();
          }
          _hasStarted = true;
          if (!_watchStopwatch.isRunning) {
            _watchStopwatch.start();
          }
          if (widget.reel.isSponsoredAd && !_hasVideoError) {
            _recordAdImpression();
          }
        } else {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          }
          // Avoid seeking to zero if near beginning to prevent texture freeze on iOS
          if (_controller!.value.position > const Duration(seconds: 1)) {
            _controller!.seekTo(Duration.zero);
          }
          _hasStarted = false;
          _showPlayIcon = false;
          
          if (_watchStopwatch.isRunning) {
            _watchStopwatch.stop();
            _reportViewIfNecessary();
          }
        }
      });
    }
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.hasError && !_hasVideoError) {
      _registerFailure(
        generation: _initGeneration,
        url: _activeUrl,
        description: controller.value.errorDescription,
      );
      return;
    }

    if (controller.value.position > Duration.zero) {
      if (!_hasRenderedFirstFrame) {
        _hasRenderedFirstFrame = true;
        if (mounted) setState(() {});
      }
    }

    // Rebuild when iOS AVPlayer reports or updates video presentation size / initialization state
    final Size currentSize = controller.value.size;
    final bool currentInit = controller.value.isInitialized;
    if (currentInit != _lastKnownIsInitialized || currentSize != _lastKnownVideoSize) {
      _lastKnownIsInitialized = currentInit;
      _lastKnownVideoSize = currentSize;
      if (mounted) setState(() {});
    }

    if (!_impressionRecorded && widget.reel.isSponsoredAd && _watchStopwatch.elapsed.inMilliseconds > 100) {
      _recordAdImpression();
    }

    if (!_viewRecorded && _watchStopwatch.elapsed.inSeconds >= _viewThresholdSeconds) {
      _reportViewIfNecessary();
    }
    
    if (widget.reel.isSponsoredAd && !_qualifiedViewRecorded && _watchStopwatch.elapsed.inSeconds >= _qualifiedViewThresholdSeconds) {
      _recordAdQualifiedView();
    }
  }

  void _ytVideoListener() {
    if (!_impressionRecorded && widget.reel.isSponsoredAd && _watchStopwatch.elapsed.inMilliseconds > 100) {
      _recordAdImpression();
    }

    if (!_viewRecorded && _watchStopwatch.elapsed.inSeconds >= _viewThresholdSeconds) {
      _reportViewIfNecessary();
    }

    if (widget.reel.isSponsoredAd && !_qualifiedViewRecorded && _watchStopwatch.elapsed.inSeconds >= _qualifiedViewThresholdSeconds) {
      _recordAdQualifiedView();
    }
  }

  void _recordAdImpression() {
    final String? adId = _effectiveAdId;
    if (_impressionRecorded || adId == null) return;
    final provider = context.read<ReelsProvider>();
    if (provider.hasRecordedAdImpression(adId, campaignId: widget.reel.campaignId)) {
      _impressionRecorded = true;
      return;
    }
    _impressionRecorded = true;
    provider.recordAdEvent(
      adId: adId,
      campaignId: widget.reel.campaignId ?? '',
      eventType: 'IMPRESSION',
    );
  }

  void _recordAdQualifiedView() {
    final String? adId = _effectiveAdId;
    if (_qualifiedViewRecorded || adId == null) return;
    _qualifiedViewRecorded = true;
    context.read<ReelsProvider>().recordAdEvent(
      adId: adId,
      campaignId: widget.reel.campaignId ?? '',
      eventType: 'QUALIFIED_VIEW',
      watchDuration: _watchStopwatch.elapsed.inSeconds,
    );
  }

  void _reportViewIfNecessary() {
    if (_viewRecorded || _watchStopwatch.elapsed.inSeconds < 1) return;
    
    // We only record "official" views after threshold, but we could report any duration if swiped away
    if (_watchStopwatch.elapsed.inSeconds >= _viewThresholdSeconds) {
      _viewRecorded = true;
      final reelId = widget.reel.id;
      final String? adId = _effectiveAdId;
      if (widget.reel.isSponsoredAd && adId != null) {
        context.read<ReelsProvider>().recordAdEvent(
          adId: adId,
          campaignId: widget.reel.campaignId ?? '',
          eventType: 'VIEW',
          watchDuration: _watchStopwatch.elapsed.inSeconds,
        );
      } else if (reelId != null) {
        context.read<ReelsProvider>().recordReelView(reelId, _watchStopwatch.elapsed.inSeconds);
      }
    }
  }

  void _togglePlay() {
    if (_isYoutube) {
      if (_ytController == null) return;
      setState(() {
        if (_ytController!.value.isPlaying) {
          _ytController!.pause();
          _watchStopwatch.stop();
        } else {
          _ytController!.play();
          _hasStarted = true;
          _watchStopwatch.start();
        }
      });
      return;
    }

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
    _initGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _callProvider?.removeListener(_callListener);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _ytController?.dispose();
    _watchStopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAd = widget.reel.isSponsoredAd;
    final bool hasPlaybackError = _hasVideoError ||
        (!_isYoutube && !_isImageAd && (_controller?.value.hasError ?? false));
    final bool isNativeLoading = !_isYoutube &&
        !_isImageAd &&
        !hasPlaybackError &&
        (_controller == null ||
            !_controller!.value.isInitialized ||
            (!_hasRenderedFirstFrame && (_controller?.value.isBuffering ?? false)));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isAd ? _handleAdClick : _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _VideoBackground(
              controller: _controller,
              ytController: _ytController,
              reel: widget.reel,
              hasStarted: _hasStarted,
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: _ShortGradient(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Text(
                  isAd ? 'Sponsored' : 'Reels',
                  style: text24(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          if (!isAd)
            Positioned(
              right: 12,
              bottom: 96 + MediaQuery.paddingOf(context).bottom,
              child: _ShortActions(
                reel: widget.reel,
                onLike: widget.onLike,
                onSave: widget.onSave,
                onComment: widget.onComment,
                onMore: widget.onMore,
              ),
            ),
          Positioned(
            left: 16,
            right: isAd ? 16 : 82,
            bottom: 34 + MediaQuery.paddingOf(context).bottom,
            child: _ShortInfo(
              reel: widget.reel,
              onAdClick: isAd ? _handleAdClick : null,
            ),
          ),
          if (!isAd)
            Positioned(
              right: 18,
              bottom: 40 + MediaQuery.paddingOf(context).bottom,
              child: _MusicDisc(image: widget.reel.thumbnail),
            ),
          if (isNativeLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          if (hasPlaybackError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white70,
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to play video',
                    style: text14(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_failureMessage != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _failureMessage!,
                        textAlign: TextAlign.center,
                        style: text12(color: Colors.white54),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_failureKind != _PlaybackFailureKind.blockedContent)
                    TextButton.icon(
                      onPressed: _isRetrying ? null : _retryPlayback,
                      icon: _isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: Text(
                        _isRetrying ? 'Retrying…' : 'Retry',
                        style: text12(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (widget.onRefreshFeed != null)
                    TextButton(
                      onPressed: _isRetrying ? null : () => widget.onRefreshFeed!(),
                      child: Text(
                        'Refresh feed',
                        style: text12(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_showPlayIcon && !isAd && !hasPlaybackError)
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

  Future<void> _handleAdClick() async {
    final reel = widget.reel;
    if (!reel.isSponsoredAd) return;
    final provider = context.read<ReelsProvider>();
    final String? adId = _effectiveAdId;

    // Always record CLICK event when a sponsored ad or its CTA is tapped
    if (adId != null) {
      provider.recordAdEvent(
        adId: adId,
        campaignId: reel.campaignId ?? '',
        eventType: 'CLICK',
      );
    }

    final String destination = (reel.destinationUrl ?? '').trim();
    if (destination.isNotEmpty) {
      final Uri? url = Uri.tryParse(destination);
      if (url != null && (url.scheme == 'http' || url.scheme == 'https')) {
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      }
    }
  }
}


class _VideoBackground extends StatelessWidget {
  final VideoPlayerController? controller;
  final YoutubePlayerController? ytController;
  final ReelModel reel;
  final bool hasStarted;

  const _VideoBackground({
    required this.controller,
    this.ytController,
    required this.reel,
    required this.hasStarted,
  });

  Widget _buildSafeThumbnailPlaceholder() {
    final String? thumbUrl = reel.thumbnail;
    if (ReelModel.isValidThumbnailUrl(
      thumbUrl,
      videoUrl: reel.videoUrl,
      destinationUrl: reel.destinationUrl,
    )) {
      return Image.network(
        thumbUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(color: Colors.black);
        },
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    if (!ReelsProvider.isIOSPlatform && ytController != null) {
      return YoutubePlayer(
        controller: ytController!,
        showVideoProgressIndicator: false,
      );
    }

    if (!ReelsProvider.isIOSPlatform &&
        reel.isSponsoredAd &&
        ReelsProvider.isImageAdReel(reel) &&
        ReelModel.isValidThumbnailUrl(
          reel.videoUrl,
          destinationUrl: reel.destinationUrl,
        )) {
      return Image.network(
        reel.videoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(color: Colors.black);
        },
      );
    }

    final VideoPlayerController? activeController = controller;
    if (activeController == null) {
      return _buildSafeThumbnailPlaceholder();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: activeController,
      builder: (context, value, _) {
        if (!value.isInitialized) {
          return _buildSafeThumbnailPlaceholder();
        }

        final Size rawSize = value.size;
        final bool hasValidSize = rawSize.width.isFinite &&
            rawSize.height.isFinite &&
            rawSize.width > 0 &&
            rawSize.height > 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double viewportW =
                (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
                    ? constraints.maxWidth
                    : 1080.0;
            final double viewportH =
                (constraints.maxHeight.isFinite && constraints.maxHeight > 0)
                    ? constraints.maxHeight
                    : 1920.0;

            final double contentW;
            final double contentH;
            if (hasValidSize) {
              contentW = rawSize.width;
              contentH = rawSize.height;
            } else {
              final double rawAspect = value.aspectRatio;
              final double safeAspect =
                  (rawAspect.isFinite && rawAspect > 0 && rawAspect != 1.0)
                      ? rawAspect
                      : (9.0 / 16.0);
              contentW = viewportW;
              contentH = viewportW / safeAspect;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                _buildSafeThumbnailPlaceholder(),
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: contentW > 0 ? contentW : viewportW,
                      height: contentH > 0 ? contentH : viewportH,
                      child: VideoPlayer(activeController),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
  final ReelModel reel;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onMore;

  const _ShortActions({
    required this.reel,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onMore,
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
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: _compactCount(reel.commentsCount ?? 0),
          onTap: onComment,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: reel.isBookmarked == true 
              ? Icons.bookmark_rounded 
              : Icons.bookmark_border_rounded,
          label: reel.isBookmarked == true ? 'Saved' : 'Save',
          color: reel.isBookmarked == true ? Colors.amber : Colors.white,
          onTap: onSave,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () {
            context.read<ReelsProvider>().incrementShares(reel.id!, reel: reel);
            ShareHelper.shareContent(
              title: 'Catch Watch Reel',
              text: 'Check out this Reel: ${reel.caption}',
              imageUrl: reel.thumbnail,
              contentId: reel.id,
              contentType: 'reel',
              context: context,
            );
          },
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          onTap: onMore,
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
  final ReelModel reel;
  final VoidCallback? onAdClick;

  const _ShortInfo({required this.reel, this.onAdClick});

  @override
  Widget build(BuildContext context) {
    final reelsProvider = context.read<ReelsProvider>();
    final bool isAd = reel.isSponsoredAd;

    final String myId = (HiveService.userId ?? HiveService.getUser()?.sId ?? '').toString();
    final String authorId = (reel.user?.id ?? '').toString();
    final bool isSelf = !isAd && myId.isNotEmpty && authorId.isNotEmpty && myId == authorId;

    final String? advertiserDisplayName = (reel.advertiserName != null && reel.advertiserName!.trim().isNotEmpty)
        ? reel.advertiserName!.trim()
        : ((reel.user?.name != null && reel.user!.name!.trim().isNotEmpty)
            ? reel.user!.name!.trim()
            : ((reel.user?.username != null && reel.user!.username!.trim().isNotEmpty)
                ? reel.user!.username!.trim()
                : null));
    final String? advertiserAvatar = (reel.advertiserLogo != null && reel.advertiserLogo!.trim().isNotEmpty)
        ? reel.advertiserLogo!.trim()
        : ((reel.user?.profileImage != null && reel.user!.profileImage!.trim().isNotEmpty)
            ? reel.user!.profileImage!.trim()
            : null);
    final String? effectiveCtaText = (reel.ctaText != null && reel.ctaText!.trim().isNotEmpty)
        ? reel.ctaText!.trim()
        : ((reel.destinationUrl != null && reel.destinationUrl!.trim().isNotEmpty)
            ? 'Learn More'
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAd)
          Row(
            children: [
              _SafeCircularImage(
                radius: 18,
                imageUrl: advertiserAvatar,
                videoUrl: reel.videoUrl,
                destinationUrl: reel.destinationUrl,
                backgroundColor: Colors.white24,
                fallback: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (advertiserDisplayName != null)
                      Text(
                        advertiserDisplayName,
                        overflow: TextOverflow.ellipsis,
                        style: text14(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Sponsored',
                            style: text11(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        else
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
                child: _SafeCircularImage(
                  radius: 20,
                  imageUrl: reel.user?.profileImage,
                  videoUrl: reel.videoUrl,
                  destinationUrl: reel.destinationUrl,
                  backgroundColor: AppColors.primary,
                  fallback: Text(
                    (reel.user?.name != null && reel.user!.name!.trim().isNotEmpty)
                        ? reel.user!.name!.trim()[0]
                        : '?',
                    style: text16(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
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
              if (reel.user?.hasVerifiedTick == true) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
              ],
              // if (!isSelf && reel.user?.id != null) ...[
              if (!isSelf && myId.isNotEmpty && reel.user?.id != null) ...[
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
          style: text14(color: Colors.white.withOpacity(0.86)),
        ),
        if (isAd && effectiveCtaText != null) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAdClick,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveCtaText,
                    style: text14(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                isAd ? 'Sponsored Content' : 'Original Audio - ${reel.user?.username ?? 'User'}',
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

class _SafeCircularImage extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final String? videoUrl;
  final String? destinationUrl;
  final Color backgroundColor;
  final Widget fallback;

  const _SafeCircularImage({
    required this.radius,
    required this.imageUrl,
    required this.backgroundColor,
    required this.fallback,
    this.videoUrl,
    this.destinationUrl,
  });

  @override
  Widget build(BuildContext context) {
    final double diameter = radius * 2;
    final bool isValid = ReelModel.isValidThumbnailUrl(
      imageUrl,
      videoUrl: videoUrl,
      destinationUrl: destinationUrl,
    );

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: isValid
          ? Image.network(
              imageUrl!,
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(child: fallback),
            )
          : fallback,
    );
  }
}

class _MusicDisc extends StatelessWidget {
  final String? image;

  const _MusicDisc({required this.image});

  @override
  Widget build(BuildContext context) {
    final bool hasValidImage = ReelModel.isValidThumbnailUrl(image);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasValidImage)
              Image.network(
                image!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                ),
              )
            else
              Image.asset(
                'assets/images/logo.jpg',
                fit: BoxFit.cover,
              ),
            Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
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
