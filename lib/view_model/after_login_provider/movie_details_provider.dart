import 'dart:async';
import 'dart:io';
import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/view_model/after_login_provider/download_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/repository/content_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
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

  String? _currentBaseUrl; // Tracks the original URL (episode or movie) across quality/audio changes

  List<Content> _episodes = [];
  List<Content> get episodes => _episodes;

  bool _isLoadingEpisodes = false;
  bool get isLoadingEpisodes => _isLoadingEpisodes;

  // ── Video Player ──────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  VideoPlayerController? _audioController; // Separate audio track controller

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

  String? _detectedQuality; // Quality detected from source URL
  String get displayQuality => _selectedQuality == 'Auto' && _detectedQuality != null
      ? 'Auto ($_detectedQuality)'
      : _selectedQuality;

  final List<String> qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];

  // ── Audio Tracks ──────────────────────────────────────────────────────────
  AudioTrack? _selectedAudioTrack;
  AudioTrack? get selectedAudioTrack => _selectedAudioTrack;

  List<AudioTrack> get availableAudioTracks {
    final tracks = <AudioTrack>[];
    // Add default language if it exists
    if (content.language != null && content.videoUrl != null) {
      tracks.add(AudioTrack(language: content.language, fileUrl: content.videoUrl, isDefault: true));
    }
    // Add other tracks
    if (content.audioTracks != null) {
      for (var track in content.audioTracks!) {
        // Only add if not already present (by URL)
        if (!tracks.any((t) => t.fileUrl == track.fileUrl)) {
          tracks.add(track);
        }
      }
    }
    return tracks;
  }

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

    if (_videoController != null) {
      _videoController!.removeListener(_onVideoUpdate);
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_audioController != null) {
      await _audioController!.dispose();
      _audioController = null;
    }

    _initPlayer(url: episode.videoUrl);
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initPlayer({String? url, Duration? initialPosition, bool autoPlay = true}) async {
    _isInitialized = false;
    _hasError = false;
    notifyListeners();

    // 1. Determine Video URL
    if (url != null) {
      _currentBaseUrl = url;
    }
    
    String? baseVideoUrl = _currentBaseUrl;

    // Check for local file if we don't have a URL yet
    if (baseVideoUrl == null && context != null) {
      final downloadProvider = context!.read<DownloadProvider>();
      final localPath = downloadProvider.getLocalVideoPath(content.id!);
      if (localPath != null && File(localPath).existsSync()) {
        baseVideoUrl = localPath;
      }
    }
    
    baseVideoUrl ??= content.videoUrl;
    
    if (baseVideoUrl == null || baseVideoUrl.isEmpty) {
      _hasError = true;
      _errorMessage = 'Video URL is not available.';
      notifyListeners();
      return;
    }

    // Keep track of the base URL for quality switches
    _currentBaseUrl = baseVideoUrl;

    // Detect quality if current selection is Auto
    if (_selectedQuality == 'Auto') {
      _detectQualityFromUrl(baseVideoUrl);
    }

    // 2. Quality Application
    String finalVideoUrl = baseVideoUrl;
    if (finalVideoUrl.startsWith('http') && _selectedQuality != 'Auto') {
      finalVideoUrl = _applyQualityToUrl(finalVideoUrl, _selectedQuality);
    }
    debugPrint('Final Video URL (Quality: $_selectedQuality): $finalVideoUrl');

    // 3. Handle Audio Track Selection
    final tracks = availableAudioTracks;
    if (url != null && tracks.isNotEmpty) {
      _selectedAudioTrack = tracks.firstWhere(
        (t) => t.fileUrl == url,
        orElse: () => tracks.first,
      );
    } else if (_selectedAudioTrack == null && tracks.isNotEmpty) {
      _selectedAudioTrack = tracks.firstWhere(
        (t) => t.isDefault == true,
        orElse: () => tracks.first,
      );
    }

    // 4. Separate Audio Logic
    bool isSeparateAudio = false;
    String? audioUrl;
    if (_selectedAudioTrack != null) {
      final bool isDefault = _selectedAudioTrack!.isDefault ?? false;
      final bool isSameAsBaseVideo = _selectedAudioTrack!.fileUrl == baseVideoUrl;
      if (!isDefault && !isSameAsBaseVideo) {
        isSeparateAudio = true;
        audioUrl = _selectedAudioTrack!.fileUrl;
      }
    }

    try {
      final token = HiveService.getToken();
      Map<String, String> headers = {'Referer': 'https://catchandwatch.com'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Initialize Video
      if (finalVideoUrl.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(finalVideoUrl),
          httpHeaders: headers,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        _videoController = VideoPlayerController.file(
          File(finalVideoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoUpdate);

      // Initialize Audio if needed
      if (isSeparateAudio && audioUrl != null) {
        if (audioUrl.startsWith('http')) {
          _audioController = VideoPlayerController.networkUrl(
            Uri.parse(audioUrl),
            httpHeaders: headers,
          );
        } else {
          _audioController = VideoPlayerController.file(File(audioUrl));
        }
        await _audioController!.initialize();
        _videoController!.setVolume(0);
        _audioController!.setVolume(_volume);
        _audioController!.setPlaybackSpeed(_playbackSpeed);
        if (autoPlay) _audioController!.play();
      } else {
        _videoController!.setVolume(_volume);
        _videoController!.setPlaybackSpeed(_playbackSpeed);
      }

      if (initialPosition != null) {
        await _videoController!.seekTo(initialPosition);
        await _audioController?.seekTo(initialPosition);
      }

      if (autoPlay) {
        _videoController!.play();
        WakelockPlus.enable();
      }

      _isInitialized = true;
      _resetHideTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing player: $e');
      _hasError = true;
      _errorMessage = 'Could not load video. Please try again.';
      notifyListeners();
    }
  }

  void _onVideoUpdate() {
    final ctrl = _videoController;
    if (ctrl == null) return;

    // Sync audio position if it drifts too much (> 300ms)
    if (_audioController != null && _isInitialized) {
      final vPos = ctrl.value.position;
      final aPos = _audioController!.value.position;
      final diff = (vPos.inMilliseconds - aPos.inMilliseconds).abs();
      
      // If video is playing but audio is buffering, pause video to wait
      if (_audioController!.value.isBuffering && ctrl.value.isPlaying) {
        ctrl.pause();
      } else if (!_audioController!.value.isBuffering && !ctrl.value.isPlaying && _isInitialized && _showControls == false) {
        // Resume video if audio finished buffering (only if we didn't manually pause)
        ctrl.play();
      }

      if (diff > 300) {
        _audioController!.seekTo(vPos);
      }
      
      // Sync play/pause state
      if (ctrl.value.isPlaying && !_audioController!.value.isPlaying && !_audioController!.value.isBuffering) {
        _audioController!.play();
      } else if (!ctrl.value.isPlaying && _audioController!.value.isPlaying) {
        _audioController!.pause();
      }
    }

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
      _audioController?.pause();
      WakelockPlus.disable();
    } else {
      ctrl.play();
      _audioController?.play();
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
    _audioController?.seekTo(newPos);
    _resetHideTimer();
    notifyListeners();
  }

  void seekForward() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    final newPos = ctrl.value.position + const Duration(seconds: 10);
    final targetPos = newPos > ctrl.value.duration ? ctrl.value.duration : newPos;
    ctrl.seekTo(targetPos);
    _audioController?.seekTo(targetPos);
    _resetHideTimer();
    notifyListeners();
  }

  void seekBackward() {
    final ctrl = _videoController;
    if (ctrl == null || !_isInitialized) return;
    final newPos = ctrl.value.position - const Duration(seconds: 10);
    final targetPos = newPos < Duration.zero ? Duration.zero : newPos;
    ctrl.seekTo(targetPos);
    _audioController?.seekTo(targetPos);
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
    if (_audioController != null) {
      _audioController!.setVolume(_volume);
      _videoController?.setVolume(0);
    } else {
      _videoController?.setVolume(_volume);
    }
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
    _audioController?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  // ── Quality ───────────────────────────────────────────────────────────────

  void _detectQualityFromUrl(String url) {
    final qualityFolderRegex = RegExp(r'/(1080p|720p|480p|360p|240p)/');
    final match = qualityFolderRegex.firstMatch(url);
    if (match != null) {
      final q = match.group(1);
      if (q != null) {
        final found = qualityOptions.firstWhere(
          (opt) => opt.toLowerCase() == q.toLowerCase(),
          orElse: () => 'Auto',
        );
        if (found != 'Auto') {
          _detectedQuality = found;
        }
      }
      return;
    }

    final qualityTagRegex = RegExp(r'[_-](1080p|720p|480p|360p|240p)(\.mp4)');
    final mp4Match = qualityTagRegex.firstMatch(url);
    if (mp4Match != null) {
      final q = mp4Match.group(1);
      if (q != null) {
        final found = qualityOptions.firstWhere(
          (opt) => opt.toLowerCase() == q.toLowerCase(),
          orElse: () => 'Auto',
        );
        if (found != 'Auto') {
          _detectedQuality = found;
        }
      }
    }
  }

  void setQuality(String quality) async {
    if (_selectedQuality == quality) return;

    final currentPosition = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;

    final previousQuality = _selectedQuality;
    _selectedQuality = quality;
    notifyListeners();

    if (_videoController != null) {
      _videoController!.removeListener(_onVideoUpdate);
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_audioController != null) {
      await _audioController!.dispose();
      _audioController = null;
    }

    try {
      await _initPlayer(initialPosition: currentPosition, autoPlay: wasPlaying);
      if (_hasError) throw 'Failed to load video with quality $quality';
    } catch (e) {
      debugPrint('Error switching quality to $quality: $e');
      if (quality != 'Auto') {
        _selectedQuality = previousQuality;
        await _initPlayer(initialPosition: currentPosition, autoPlay: wasPlaying);
      }
    }
    _resetHideTimer();
  }

  String _applyQualityToUrl(String url, String quality) {
    if (!url.startsWith('http')) return url;

    final qualityFolderRegex = RegExp(r'/(1080p|720p|480p|360p|240p)/');
    final qualityTagRegex = RegExp(r'[_-](1080p|720p|480p|360p|240p)(\.mp4)');

    if (quality == 'Auto') {
      // Try to revert to master playlist if it was a specific quality URL
      if (url.contains(qualityFolderRegex)) {
        return url.replaceFirst(qualityFolderRegex, '/');
      }
      if (url.contains(qualityTagRegex)) {
        return url.replaceFirst(qualityTagRegex, '.mp4');
      }
      return url;
    }

    final String q = quality.toLowerCase();

    // 1. HLS (.m3u8)
    if (url.contains('.m3u8')) {
      if (url.contains(qualityFolderRegex)) {
        return url.replaceFirst(qualityFolderRegex, '/$q/');
      }
      if (url.contains('playlist.m3u8')) {
        return url.replaceFirst('playlist.m3u8', '$q/playlist.m3u8');
      }
    }

    // 2. MP4
    if (url.contains('.mp4')) {
      if (url.contains(qualityTagRegex)) {
        return url.replaceFirst(qualityTagRegex, '_$q.mp4');
      }
      if (url.contains(qualityFolderRegex)) {
        return url.replaceFirst(qualityFolderRegex, '/$q/');
      }
    }

    return url;
  }

  // ── Audio Tracks ──────────────────────────────────────────────────────────

  void setAudioTrack(AudioTrack track) async {
    if (_selectedAudioTrack?.fileUrl == track.fileUrl) return;

    final currentPosition = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;

    _selectedAudioTrack = track;

    if (_videoController != null) {
      _videoController!.removeListener(_onVideoUpdate);
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_audioController != null) {
      await _audioController!.dispose();
      _audioController = null;
    }

    await _initPlayer(initialPosition: currentPosition, autoPlay: wasPlaying);
    _resetHideTimer();
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
    _audioController?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
