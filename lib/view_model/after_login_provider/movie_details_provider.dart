import 'dart:async';
import 'dart:io';
import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/repository/content_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;

// ─── Provider ─────────────────────────────────────────────────────────────────

class MovieDetailProvider extends ChangeNotifier with WidgetsBindingObserver {
  // ── Data ──────────────────────────────────────────────────────────────────
  final Content content;
  final BuildContext? context;
  final ContentRepository _contentRepository = ContentRepository();

  // ── Throttling ────────────────────────────────────────────────────────────
  // Playback progress is persisted and the UI is notified on a throttle so we
  // don't hit Hive / rebuild the player on every video frame tick.
  static const Duration _progressSaveInterval = Duration(seconds: 5);
  static const Duration _uiNotifyInterval = Duration(milliseconds: 500);
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUiNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Set when playback was paused because the app moved to the background, so
  // it can be resumed automatically when the app returns to the foreground.
  bool _resumeOnForeground = false;

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

  List<String> _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];
  List<String> get qualityOptions => _qualityOptions;

  Map<String, String> _availableQualityUrls = {};

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

  MovieDetailProvider(this.content, {this.context, Duration? initialPosition}) {
    WidgetsBinding.instance.addObserver(this);
    _initPlayer(initialPosition: initialPosition);
    if (content.type == 'tvshow') {
      _fetchEpisodes();
    }
    
    // Listen for calls
    if (context != null) {
      context!.read<CallProvider>().addListener(_callStatusListener);
    }
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _videoController;
    if (ctrl == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Persist the current position before the app is suspended, then pause
        // so audio does not keep playing in the background.
        _saveProgress();
        if (ctrl.value.isPlaying) {
          _resumeOnForeground = true;
          ctrl.pause();
          _audioController?.pause();
        }
        WakelockPlus.disable();
        break;
      case AppLifecycleState.resumed:
        if (_resumeOnForeground) {
          _resumeOnForeground = false;
          if (_isInitialized) {
            ctrl.play();
            _audioController?.play();
            WakelockPlus.enable();
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _callStatusListener() {
    if (context != null) {
      final callStatus = context!.read<CallProvider>().status;
      if (callStatus != CallStatus.idle && isPlaying) {
        togglePlay(); // This handles pausing and wakelock
      }
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

    // Reset quality states for the new episode
    _availableQualityUrls.clear();
    _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];
    _detectedQuality = null;
    _selectedQuality = 'Auto'; // Always start new content in Auto

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
      // Reset qualities when base URL changes explicitly
      _availableQualityUrls.clear();
      _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p', '240p'];
      _detectedQuality = null;
    }
    
    String? baseVideoUrl = _currentBaseUrl;

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

    // Load available qualities. Only an HLS master playlist exposes real,
    // independently addressable variant URLs; for plain files (e.g. MP4) the
    // API provides a single source, so we never advertise guessed qualities
    // that would resolve to dead URLs.
    if (baseVideoUrl.startsWith('http') && _availableQualityUrls.isEmpty) {
      if (baseVideoUrl.contains('.m3u8')) {
        await _loadHlsQualities(baseVideoUrl);
      }
      if (_availableQualityUrls.isEmpty) {
        _availableQualityUrls = {'Auto': baseVideoUrl};
        _qualityOptions = ['Auto'];
      }
    }

    // 2. Quality Application (only real, discovered URLs are ever used)
    String finalVideoUrl = baseVideoUrl;
    if (_availableQualityUrls.containsKey(_selectedQuality)) {
      finalVideoUrl = _availableQualityUrls[_selectedQuality]!;
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

      // Initialize Video
      if (finalVideoUrl.startsWith('http')) {
        final Map<String, String> videoHeaders = AppUrl.buildVideoRequestHeaders(
          finalVideoUrl,
          token: token,
        );
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(finalVideoUrl),
          httpHeaders: videoHeaders,
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
          final Map<String, String> audioHeaders = AppUrl.buildVideoRequestHeaders(
            audioUrl,
            token: token,
          );
          _audioController = VideoPlayerController.networkUrl(
            Uri.parse(audioUrl),
            httpHeaders: audioHeaders,
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

      // Quality fallback: if a non-Auto variant failed to load, retry once with
      // the base URL so a bad quality URL never leaves the player dead.
      if (_selectedQuality != 'Auto' && finalVideoUrl != baseVideoUrl) {
        debugPrint('Quality "$_selectedQuality" failed to load; falling back to Auto.');
        _selectedQuality = 'Auto';
        if (_videoController != null) {
          _videoController!.removeListener(_onVideoUpdate);
          await _videoController!.dispose();
          _videoController = null;
        }
        if (_audioController != null) {
          await _audioController!.dispose();
          _audioController = null;
        }
        await _initPlayer(initialPosition: initialPosition, autoPlay: autoPlay);
        return;
      }

      _hasError = true;
      _errorMessage = 'Could not load video. Please try again.';
      notifyListeners();
    }
  }

  /// Re-initializes the player after a playback failure (retry button).
  Future<void> retry() async {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
    await _initPlayer(autoPlay: true);
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

    final now = DateTime.now();

    // Persist the playback position to "Continue Watching" on a throttle so we
    // don't hit Hive (disk I/O) on every frame tick.
    if (ctrl.value.isPlaying &&
        now.difference(_lastProgressSave) >= _progressSaveInterval) {
      _saveProgress(timestamp: now);
    }

    // Throttle UI rebuilds for the progress bar / time label while playing.
    final bool ended = ctrl.value.duration > Duration.zero &&
        ctrl.value.position >= ctrl.value.duration;
    if (ended || now.difference(_lastUiNotify) >= _uiNotifyInterval) {
      _lastUiNotify = now;
      notifyListeners();
    }
  }

  /// Persists the current playback [position] so "Continue Watching" can resume
  /// from where the user left off. Writes are throttled by [_progressSaveInterval]
  /// when called from the frame listener; lifecycle events may force a save.
  void _saveProgress({DateTime? timestamp}) {
    final ctrl = _videoController;
    final ctx = context;
    if (ctrl == null || ctx == null || !_isInitialized) return;

    final duration = ctrl.value.duration;
    final position = ctrl.value.position;
    if (duration <= Duration.zero || position <= Duration.zero) return;

    _lastProgressSave = timestamp ?? DateTime.now();
    try {
      ctx.read<HomeScreenProvider>().addToContinueWatching(
        content,
        position,
        duration,
      );
    } catch (e) {
      debugPrint('Error saving playback progress: $e');
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
    final qualityRegex = RegExp(r'(1080p|720p|480p|360p|240p)');
    final match = qualityRegex.firstMatch(url);
    if (match != null) {
      _detectedQuality = match.group(1);
    }
  }

  Future<void> _loadHlsQualities(String masterUrl) async {
    try {
      final token = HiveService.getToken();
      final Map<String, String> headers = AppUrl.buildVideoRequestHeaders(
        masterUrl,
        token: token,
        extraHeaders: const <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      final response = await http.get(Uri.parse(masterUrl), headers: headers);
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final Map<String, String> discovered = {'Auto': masterUrl};
        
        String? currentResolution;
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          if (line.contains('#EXT-X-STREAM-INF:')) {
            final resMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
            if (resMatch != null) {
              currentResolution = '${resMatch.group(1)}p';
            }
          } else if (!line.startsWith('#') && currentResolution != null) {
            String variantUrl = line;
            if (!variantUrl.startsWith('http')) {
              final uri = Uri.parse(masterUrl);
              final path = uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
              variantUrl = uri.replace(path: path + variantUrl).toString();
            }
            discovered[currentResolution] = variantUrl;
            currentResolution = null;
          }
        }
        
        if (discovered.length > 1) {
          _availableQualityUrls = discovered;
          final sortedKeys = discovered.keys.where((k) => k != 'Auto').toList();
          sortedKeys.sort((a, b) {
            final vA = int.tryParse(a.replaceAll('p', '')) ?? 0;
            final vB = int.tryParse(b.replaceAll('p', '')) ?? 0;
            return vB.compareTo(vA);
          });
          _qualityOptions = ['Auto', ...sortedKeys];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error parsing HLS: $e');
    }
  }

  void setQuality(String quality) async {
    if (_selectedQuality == quality) return;

    final currentPosition = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;

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

    await _initPlayer(initialPosition: currentPosition, autoPlay: wasPlaying);
    _resetHideTimer();
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
    // iPads support multitasking / Split View; forcing landscape breaks that,
    // so we only lock landscape on phones and let tablets rotate freely.
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    if (!isTablet) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
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
    if (context != null) {
      try {
        context!.read<CallProvider>().removeListener(_callStatusListener);
      } catch (_) {}
    }
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
