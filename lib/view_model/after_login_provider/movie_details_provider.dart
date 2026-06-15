import 'dart:async';
import 'dart:io';
import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/view_model/after_login_provider/download_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/repository/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

class MovieDetailProvider extends ChangeNotifier {
  // ── Data ──────────────────────────────────────────────────────────────────
  final Content content;
  final BuildContext? context;
  final ContentRepository _contentRepository = ContentRepository();

  List<Content> _episodes = [];
  List<Content> get episodes => _episodes;

  bool _isLoadingEpisodes = false;
  bool get isLoadingEpisodes => _isLoadingEpisodes;

  // ── Video Player ──────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isBuffering = false;
  bool get isBuffering => _isBuffering;

  bool _hasError = false;
  bool get hasError => _hasError;
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // ── Controls UI ───────────────────────────────────────────────────────────
  bool _showControls = true;
  bool get showControls => _showControls;

  bool _isFullscreen = false;
  bool get isFullscreen => _isFullscreen;

  Timer? _hideControlsTimer;

  // ── Volume & Brightness ───────────────────────────────────────────────────
  double _volume = 1.0;
  double get volume => _volume;

  // ── Wishlist ──────────────────────────────────────────────────────────────
  bool _isWishlisted = false;
  bool get isWishlisted => _isWishlisted;

  // ── Speed ─────────────────────────────────────────────────────────────────
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // ── Quality ───────────────────────────────────────────────────────────────
  String _selectedQuality = 'Auto';
  String get selectedQuality => _selectedQuality;
  final List<String> qualityOptions = ['Auto', '1080p', '720p', '480p', '360p'];

  // ─────────────────────────────────────────────────────────────────────────

  MovieDetailProvider(this.content, {this.context}) {
    _initPlayer();
    if (content.type == 'tvshow') {
      _fetchEpisodes();
    }
  }

  Future<void> _fetchEpisodes() async {
    _isLoadingEpisodes = true;
    notifyListeners();
    try {
      _episodes = await _contentRepository.getTvShowEpisodes(content.id!);
      // Sort episodes by number
      _episodes.sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
    } catch (e) {
      debugPrint('Error fetching episodes: $e');
    } finally {
      _isLoadingEpisodes = false;
      notifyListeners();
    }
  }

  void playEpisode(Content episode) async {
    // If already playing this episode, do nothing
    if (_videoController != null && _videoController!.dataSource.contains(episode.videoUrl ?? '')) {
      return;
    }

    _isInitialized = false;
    _hasError = false;
    notifyListeners();

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _initPlayer(url: episode.videoUrl);
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initPlayer({String? url}) async {
    String? finalUrl = url ?? content.videoUrl;
    
    // Check if downloaded
    if (context != null) {
      final downloadProvider = context!.read<DownloadProvider>();
      final localPath = downloadProvider.getLocalVideoPath(content.id!);
      if (localPath != null && File(localPath).existsSync()) {
        finalUrl = localPath;
      }
    }

    if (finalUrl == null || finalUrl.isEmpty) {
      _hasError = true;
      _errorMessage = 'Video URL is not available.';
      notifyListeners();
      return;
    }

    try {
      if (finalUrl.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(finalUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      } else {
        _videoController = VideoPlayerController.file(
          File(finalUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }

      await _videoController!.initialize();
      _videoController!.addListener(_onVideoUpdate);
      _videoController!.play(); // Auto-play when screen opens
      _isInitialized = true;
      WakelockPlus.enable();
      _resetHideTimer();
      notifyListeners();
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Could not load video. Please try again.';
      notifyListeners();
    }
  }

  void _onVideoUpdate() {
    final ctrl = _videoController;
    if (ctrl == null) return;

    final isBuffering = ctrl.value.isBuffering;
    if (isBuffering != _isBuffering) {
      _isBuffering = isBuffering;
      notifyListeners();
    }

    // Update continue watching in HomeProvider
    if (ctrl.value.isPlaying && context != null) {
      context!.read<HomeScreenProvider>().addToContinueWatching(
        content,
        ctrl.value.position,
        ctrl.value.duration,
      );
    }

    // Auto-hide controls while playing
    if (ctrl.value.isPlaying) notifyListeners();

    // Loop ended
    if (ctrl.value.position >= ctrl.value.duration &&
        ctrl.value.duration > Duration.zero) {
      notifyListeners();
    }
  }

  // ── Play / Pause ──────────────────────────────────────────────────────────

  bool get isPlaying => _videoController?.value.isPlaying ?? false;

  void togglePlay() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      WakelockPlus.disable();
    } else {
      ctrl.play();
      WakelockPlus.enable();
    }
    _resetHideTimer();
    notifyListeners();
  }

  // ── Seek ──────────────────────────────────────────────────────────────────

  void seekTo(double ratio) {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    final duration = ctrl.value.duration;
    final newPos = Duration(
      milliseconds: (duration.inMilliseconds * ratio).round(),
    );
    ctrl.seekTo(newPos);
    _resetHideTimer();
    notifyListeners();
  }

  void seekForward() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    final newPos = ctrl.value.position + const Duration(seconds: 10);
    ctrl.seekTo(newPos > ctrl.value.duration ? ctrl.value.duration : newPos);
    _resetHideTimer();
    notifyListeners();
  }

  void seekBackward() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    final newPos = ctrl.value.position - const Duration(seconds: 10);
    ctrl.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
    _resetHideTimer();
    notifyListeners();
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  double get progressValue {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return 0.0;
    final dur = ctrl.value.duration.inMilliseconds;
    if (dur == 0) return 0.0;
    return (ctrl.value.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  String get formattedPosition {
    final pos = _videoController?.value.position ?? Duration.zero;
    return _fmt(pos);
  }

  String get formattedDuration {
    final dur = _videoController?.value.duration ?? Duration.zero;
    return _fmt(dur);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Buffered ──────────────────────────────────────────────────────────────

  double get bufferedValue {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return 0.0;
    final dur = ctrl.value.duration.inMilliseconds;
    if (dur == 0 || ctrl.value.buffered.isEmpty) return 0.0;
    return (ctrl.value.buffered.last.end.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  // ── Controls Visibility ───────────────────────────────────────────────────

  void toggleControls() {
    _showControls = !_showControls;
    if (_showControls) _resetHideTimer();
    notifyListeners();
  }

  void showControlsTemporarily() {
    _showControls = true;
    _resetHideTimer();
    notifyListeners();
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (isPlaying) {
        _showControls = false;
        notifyListeners();
      }
    });
  }

  // ── Volume ────────────────────────────────────────────────────────────────

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _videoController?.setVolume(_volume);
    notifyListeners();
  }

  bool get isMuted => _volume == 0.0;

  void toggleMute() {
    setVolume(isMuted ? 1.0 : 0.0);
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  void setSpeed(double speed) {
    _playbackSpeed = speed;
    _videoController?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  // ── Quality ───────────────────────────────────────────────────────────────

  void setQuality(String quality) {
    _selectedQuality = quality;
    notifyListeners();
  }

  // ── Fullscreen ────────────────────────────────────────────────────────────

  void enterFullscreen(BuildContext context) {
    _isFullscreen = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    notifyListeners();
  }

  void exitFullscreen() {
    _isFullscreen = false;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    notifyListeners();
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────

  void toggleWishlist() {
    _isWishlisted = !_isWishlisted;
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
