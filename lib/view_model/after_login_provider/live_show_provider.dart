import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/live_show_model.dart';
import '../../repository/live_show_repository.dart';

/// State management for Live Shows features.
///
/// Manages independent states for:
/// - Featured live show
/// - Live shows list
/// - Upcoming shows list
/// - Ended shows list
/// - Selected show details
/// - Periodic status polling & viewer heartbeat ping
/// - Lifecycle-aware pause/resume and disposal
class LiveShowProvider with ChangeNotifier, WidgetsBindingObserver {
  final LiveShowRepository _repository;

  LiveShowProvider({LiveShowRepository? repository})
      : _repository = repository ?? LiveShowRepository() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isDisposed = false;

  static final List<LiveShowModel> _fallbackLiveShows = [
    LiveShowModel(
      id: 'show-1',
      title: 'sdgfeg',
      description: 'Exclusive live automotive showcase and Q&A session.',
      category: 'Automotive',
      rawStatus: 'LIVE',
      hostName: 'Alex Rivera',
      viewerCount: 2,
      banner: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf',
      poster: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf',
      startTime: DateTime(2025, 11, 27),
      isFeatured: true,
    ),
  ];

  static final LiveShowModel _fallbackFeaturedShow = _fallbackLiveShows[0];

  // --- Featured Show State ---
  LiveShowModel? _featuredShow = _fallbackFeaturedShow;
  bool _isFeaturedLoading = false;
  String? _featuredError;

  LiveShowModel? get featuredShow => _featuredShow;
  bool get isFeaturedLoading => _isFeaturedLoading;
  String? get featuredError => _featuredError;
  bool get hasFeaturedShow => _featuredShow != null;

  // --- Live Shows State ---
  List<LiveShowModel> _liveShows = <LiveShowModel>[_fallbackLiveShows[0]];
  bool _isLiveLoading = false;
  String? _liveError;

  List<LiveShowModel> get liveShows => List.unmodifiable(_liveShows);
  bool get isLiveLoading => _isLiveLoading;
  String? get liveError => _liveError;
  bool get hasLiveShows => _liveShows.isNotEmpty;

  // --- Upcoming Shows State ---
  List<LiveShowModel> _upcomingShows = <LiveShowModel>[];
  bool _isUpcomingLoading = false;
  String? _upcomingError;

  List<LiveShowModel> get upcomingShows => List.unmodifiable(_upcomingShows);
  bool get isUpcomingLoading => _isUpcomingLoading;
  String? get upcomingError => _upcomingError;
  bool get hasUpcomingShows => _upcomingShows.isNotEmpty;

  // --- Ended Shows State ---
  List<LiveShowModel> _endedShows = <LiveShowModel>[];
  bool _isEndedLoading = false;
  String? _endedError;

  List<LiveShowModel> get endedShows => List.unmodifiable(_endedShows);
  bool get isEndedLoading => _isEndedLoading;
  String? get endedError => _endedError;
  bool get hasEndedShows => _endedShows.isNotEmpty;

  // --- Selected Show Details State ---
  LiveShowModel? _selectedShow;
  bool _isLoadingDetails = false;
  String? _detailsError;

  LiveShowModel? get selectedShow => _selectedShow;
  bool get isLoadingDetails => _isLoadingDetails;
  String? get detailsError => _detailsError;

  // --- Polling & Heartbeat Timers ---
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  bool _isPollingActive = false;
  bool _isHeartbeatActive = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumePolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pausePolling();
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Fetches all live show data (featured show, live shows, upcoming, ended).
  Future<void> fetchAllLiveShowData() async {
    await Future.wait([
      fetchFeaturedShow(),
      fetchLiveShows(),
      fetchUpcomingShows(),
      fetchEndedShows(),
    ]);
  }

  /// Fetches top active featured live show.
  Future<void> fetchFeaturedShow() async {
    _isFeaturedLoading = true;
    _featuredError = null;
    _safeNotifyListeners();

    try {
      final res = await _repository.getFeaturedLiveShow();
      _featuredShow = res ?? _fallbackFeaturedShow;
      _isFeaturedLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isFeaturedLoading = false;
      _featuredError = e.toString();
      _featuredShow ??= _fallbackFeaturedShow;
      _safeNotifyListeners();
    }
  }

  /// Fetches list of live shows (status = LIVE).
  Future<void> fetchLiveShows() async {
    _isLiveLoading = true;
    _liveError = null;
    _safeNotifyListeners();

    try {
      final res = await _repository.getLiveShows(status: 'LIVE');
      _liveShows = res.isNotEmpty ? res : _fallbackLiveShows;
      _isLiveLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isLiveLoading = false;
      _liveError = e.toString();
      if (_liveShows.isEmpty) {
        _liveShows = _fallbackLiveShows;
      }
      _safeNotifyListeners();
    }
  }

  /// Fetches list of upcoming shows (status = UPCOMING).
  Future<void> fetchUpcomingShows() async {
    _isUpcomingLoading = true;
    _upcomingError = null;
    _safeNotifyListeners();

    try {
      _upcomingShows = await _repository.getLiveShows(status: 'UPCOMING');
      _isUpcomingLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isUpcomingLoading = false;
      _upcomingError = e.toString();
      _upcomingShows = <LiveShowModel>[];
      _safeNotifyListeners();
    }
  }

  /// Fetches list of ended shows (status = ENDED).
  Future<void> fetchEndedShows() async {
    _isEndedLoading = true;
    _endedError = null;
    _safeNotifyListeners();

    try {
      _endedShows = await _repository.getLiveShows(status: 'ENDED');
      _isEndedLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isEndedLoading = false;
      _endedError = e.toString();
      _endedShows = <LiveShowModel>[];
      _safeNotifyListeners();
    }
  }

  /// Fetches full details for a single live show and starts polling/heartbeat.
  Future<void> fetchShowDetails(String showId, {bool isBackgroundRefresh = false}) async {
    final cleanId = showId.trim();
    if (cleanId.isEmpty) return;

    if (!isBackgroundRefresh) {
      _isLoadingDetails = true;
      _detailsError = null;
      _safeNotifyListeners();
    }

    try {
      final updatedShow = await _repository.getLiveShowDetails(cleanId);
      if (updatedShow != null) {
        _selectedShow = updatedShow;
        _syncShowInLists(updatedShow);
      }
      _isLoadingDetails = false;
      _detailsError = null;
      _safeNotifyListeners();
    } catch (e) {
      _isLoadingDetails = false;
      if (!isBackgroundRefresh) {
        _detailsError = e.toString();
      }
      _safeNotifyListeners();
    }
  }

  void setSelectedShow(LiveShowModel show) {
    _selectedShow = show;
    _safeNotifyListeners();
  }

  /// Starts periodic background polling for selected show (every 30 seconds).
  void startShowPolling(String showId) {
    if (_isPollingActive) return;
    _isPollingActive = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isDisposed || !_isPollingActive) return;
      await fetchShowDetails(showId, isBackgroundRefresh: true);
    });
  }

  void stopShowPolling() {
    _isPollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Starts viewer heartbeat ping (every 25 seconds while viewing).
  void startViewerHeartbeat(String showId) {
    if (_isHeartbeatActive) return;
    _isHeartbeatActive = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (_isDisposed || !_isHeartbeatActive) return;
      await recordViewPing(showId);
    });
  }

  void stopViewerHeartbeat() {
    _isHeartbeatActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Records single viewer heartbeat ping.
  Future<bool> recordViewPing(String showId) async {
    final cleanId = showId.trim();
    if (cleanId.isEmpty) return false;
    return await _repository.recordLiveShowView(cleanId);
  }

  void _syncShowInLists(LiveShowModel updated) {
    final liveIdx = _liveShows.indexWhere((s) => s.id == updated.id);
    if (liveIdx != -1) {
      _liveShows[liveIdx] = updated;
    }
    final upcomingIdx = _upcomingShows.indexWhere((s) => s.id == updated.id);
    if (upcomingIdx != -1) {
      _upcomingShows[upcomingIdx] = updated;
    }
    final endedIdx = _endedShows.indexWhere((s) => s.id == updated.id);
    if (endedIdx != -1) {
      _endedShows[endedIdx] = updated;
    }
    if (_featuredShow?.id == updated.id) {
      _featuredShow = updated;
    }
  }

  void _resumePolling() {
    if (_selectedShow != null) {
      startShowPolling(_selectedShow!.id);
      startViewerHeartbeat(_selectedShow!.id);
    }
  }

  void _pausePolling() {
    stopShowPolling();
    stopViewerHeartbeat();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    stopShowPolling();
    stopViewerHeartbeat();
    super.dispose();
  }
}
