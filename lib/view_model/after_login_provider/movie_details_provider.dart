import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class CastMember {
  final String name;
  final String role;
  final String imageUrl;

  const CastMember({
    required this.name,
    required this.role,
    required this.imageUrl,
  });
}

class MovieModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String year;
  final List<String> genres;
  final List<String> languages;
  final double rating;
  final String duration;
  final List<CastMember> cast;
  final List<MovieModel> moreLikeThis;

  const MovieModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.year,
    required this.genres,
    required this.languages,
    required this.rating,
    required this.duration,
    required this.cast,
    this.moreLikeThis = const [],
  });
}

// ─── Sample Data ──────────────────────────────────────────────────────────────

class SampleMovies {
  static final List<CastMember> spiderManCast = [
    const CastMember(
      name: 'Tom Holland',
      role: 'Spider-Man',
      imageUrl: 'https://i.pravatar.cc/150?img=11',
    ),
    const CastMember(
      name: 'Zendaya',
      role: 'MJ',
      imageUrl: 'https://i.pravatar.cc/150?img=5',
    ),
    const CastMember(
      name: 'Benedict C.',
      role: 'Dr Strange',
      imageUrl: 'https://i.pravatar.cc/150?img=13',
    ),
    const CastMember(
      name: 'Alfred Molina',
      role: 'Doc Ock',
      imageUrl: 'https://i.pravatar.cc/150?img=15',
    ),
    const CastMember(
      name: 'Jamie Foxx',
      role: 'Electro',
      imageUrl: 'https://i.pravatar.cc/150?img=17',
    ),
  ];

  static final MovieModel spiderMan = MovieModel(
    id: 'sm_nwh',
    title: 'Spider-Man: No Way Home',
    description:
        'With Spider-Man\'s identity now revealed, Peter asks Doctor Strange for help. When a spell goes wrong, dangerous foes from other worlds start to appear, forcing Peter to discover what it truly means to be Spider-Man. A thrilling multiversal adventure that brings beloved characters from across Spider-Man\'s cinematic history.',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1635805737707-575885ab0820?w=800',
    // Public domain Big Buck Bunny — works without auth
    videoUrl:
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    year: '2021',
    genres: ['Action', 'Adventure', 'Sci-Fi'],
    languages: ['English', 'Hindi'],
    rating: 8.3,
    duration: '2h 28m',
    cast: spiderManCast,
    moreLikeThis: [
      MovieModel(
        id: 'doc_strange',
        title: 'Doctor Strange MoM',
        description: '',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1518676590629-3dcbd9c5a5c9?w=400',
        videoUrl: '',
        year: '2022',
        genres: ['Action'],
        languages: ['English'],
        rating: 6.9,
        duration: '2h 6m',
        cast: [],
      ),
      MovieModel(
        id: 'thor',
        title: 'Thor: Love and Thunder',
        description: '',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?w=400',
        videoUrl: '',
        year: '2022',
        genres: ['Action'],
        languages: ['English'],
        rating: 6.3,
        duration: '1h 59m',
        cast: [],
      ),
      MovieModel(
        id: 'black_panther',
        title: 'Black Panther: Wakanda Forever',
        description: '',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1531259683007-016a7b628fc3?w=400',
        videoUrl: '',
        year: '2022',
        genres: ['Action'],
        languages: ['English'],
        rating: 7.3,
        duration: '2h 41m',
        cast: [],
      ),
      MovieModel(
        id: 'eternals',
        title: 'Eternals',
        description: '',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1464802686167-b939a6910659?w=400',
        videoUrl: '',
        year: '2021',
        genres: ['Sci-Fi'],
        languages: ['English'],
        rating: 6.3,
        duration: '2h 36m',
        cast: [],
      ),
    ],
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class MovieDetailProvider extends ChangeNotifier {
  // ── Data ──────────────────────────────────────────────────────────────────
  final MovieModel movie = SampleMovies.spiderMan;

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

  MovieDetailProvider() {
    _initPlayer();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(movie.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await _videoController!.initialize();
      _videoController!.addListener(_onVideoUpdate);
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
