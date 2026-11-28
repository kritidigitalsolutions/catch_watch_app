import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/live_match_model.dart';
import '../../repository/live_cricket_repository.dart';

/// State management for Live Cricket features.
///
/// Manages independent states for:
/// - Featured match
/// - Live matches
/// - Upcoming matches
/// - Completed matches
/// - Match details and live scoreboard
/// - 25-second live score polling with duplicate request prevention
/// - Primary/backup stream switching
/// - Lifecycle-aware pause/resume and disposal
class LiveCricketProvider with ChangeNotifier, WidgetsBindingObserver {
  final LiveCricketRepository _repository;

  LiveCricketProvider({LiveCricketRepository? repository})
      : _repository = repository ?? LiveCricketRepository() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isDisposed = false;

  // --- Featured Match State ---
  LiveMatchModel? _featuredMatch;
  bool _isFeaturedLoading = false;
  String? _featuredError;

  LiveMatchModel? get featuredMatch => _featuredMatch;
  bool get isFeaturedLoading => _isFeaturedLoading;
  String? get featuredError => _featuredError;
  bool get hasFeaturedMatch => _featuredMatch != null;

  // --- Live Matches State ---
  List<LiveMatchModel> _liveMatches = <LiveMatchModel>[];
  bool _isLiveLoading = false;
  String? _liveError;

  List<LiveMatchModel> get liveMatches => List.unmodifiable(_liveMatches);
  bool get isLiveLoading => _isLiveLoading;
  String? get liveError => _liveError;
  bool get hasLiveMatches => _liveMatches.isNotEmpty;

  // --- Upcoming Matches State ---
  List<LiveMatchModel> _upcomingMatches = <LiveMatchModel>[];
  bool _isUpcomingLoading = false;
  String? _upcomingError;

  List<LiveMatchModel> get upcomingMatches => List.unmodifiable(_upcomingMatches);
  bool get isUpcomingLoading => _isUpcomingLoading;
  String? get upcomingError => _upcomingError;
  bool get hasUpcomingMatches => _upcomingMatches.isNotEmpty;

  // --- Completed Matches State ---
  List<LiveMatchModel> _completedMatches = <LiveMatchModel>[];
  bool _isCompletedLoading = false;
  String? _completedError;

  List<LiveMatchModel> get completedMatches => List.unmodifiable(_completedMatches);
  bool get isCompletedLoading => _isCompletedLoading;
  String? get completedError => _completedError;
  bool get hasCompletedMatches => _completedMatches.isNotEmpty;

  // --- Match Details State ---
  LiveMatchModel? _selectedMatch;
  bool _isDetailLoading = false;
  String? _detailError;

  LiveMatchModel? get selectedMatch => _selectedMatch;
  bool get isDetailLoading => _isDetailLoading;
  String? get detailError => _detailError;

  Map<String, dynamic>? _liveActivity;
  Map<String, dynamic>? get liveActivity => _liveActivity;

  Map<String, dynamic>? _scorecard;
  Map<String, dynamic>? get scorecard => _scorecard;

  Map<String, dynamic>? _commentary;
  Map<String, dynamic>? get commentary => _commentary;

  Map<String, dynamic>? _squads;
  Map<String, dynamic>? get squads => _squads;

  // --- Primary / Backup Stream Switching ---
  bool _useBackupStream = false;
  bool get useBackupStream => _useBackupStream;

  String? get activeStreamUrl {
    if (_selectedMatch == null) return null;
    if (_useBackupStream && _selectedMatch!.hasBackupStream) {
      return _selectedMatch!.backupStreamUrl;
    }
    return _selectedMatch!.streamUrl;
  }

  void switchToBackupStream() {
    if (_selectedMatch != null &&
        _selectedMatch!.hasBackupStream &&
        !_useBackupStream) {
      _useBackupStream = true;
      notifyListeners();
    }
  }

  void resetStreamSelection() {
    if (_useBackupStream) {
      _useBackupStream = false;
      notifyListeners();
    }
  }

  // --- Polling State & Management (3-second interval) ---
  static const Duration pollingInterval = Duration(seconds: 3);
  Timer? _pollingTimer;
  String? _pollingMatchId;
  bool _isPollingPaused = false;
  bool _isPollingInFlight = false;

  bool get isPollingActive =>
      _pollingTimer != null && _pollingTimer!.isActive && !_isPollingPaused;
  String? get pollingMatchId => _pollingMatchId;

  /// Starts or rebinds live score polling for [matchId] at 25-second intervals.
  void startLiveScorePolling(String matchId) {
    final cleanId = matchId.trim();
    if (cleanId.isEmpty) return;

    if (_pollingMatchId == cleanId && _pollingTimer != null) {
      // Already polling for this match
      return;
    }

    stopLiveScorePolling();
    _pollingMatchId = cleanId;
    _isPollingPaused = false;

    // Trigger immediate refresh then schedule recurring timer
    _executePoll();

    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      if (!_isPollingPaused && !_isPollingInFlight) {
        _executePoll();
      }
    });
  }

  /// Pauses polling timer (e.g. app moved to background or screen obscured).
  void pausePolling() {
    _isPollingPaused = true;
  }

  /// Resumes polling timer (e.g. app returned to foreground).
  void resumePolling() {
    if (_isPollingPaused) {
      _isPollingPaused = false;
      if (_pollingMatchId != null && !_isPollingInFlight) {
        _executePoll();
      }
    }
  }

  /// Stops polling and releases timer resources.
  void stopLiveScorePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingMatchId = null;
    _isPollingPaused = false;
    _isPollingInFlight = false;
  }

  Future<void> _executePoll() async {
    final matchId = _pollingMatchId;
    if (matchId == null || _isPollingInFlight) return;

    _isPollingInFlight = true;
    try {
      final results = await Future.wait([
        _repository.getLiveMatchDetails(matchId),
        _repository.getLiveMatchActivity(matchId),
      ]);
      final updatedMatch = results[0] as LiveMatchModel?;
      final activity = results[1] as Map<String, dynamic>?;

      if (!_isDisposed) {
        if (updatedMatch != null) {
          _selectedMatch = updatedMatch;
          _syncMatchInLists(updatedMatch);
        }
        if (activity != null) {
          _liveActivity = activity;
        }
        _detailError = null;
        notifyListeners();
      }
    } catch (e) {
      // Polling network drop: retain current scoreboard without clearing state
    } finally {
      _isPollingInFlight = false;
    }
  }

  void _syncMatchInLists(LiveMatchModel updated) {
    if (_featuredMatch?.id == updated.id) {
      _featuredMatch = updated;
    }

    final liveIdx = _liveMatches.indexWhere((m) => m.id == updated.id);
    if (liveIdx != -1) {
      _liveMatches[liveIdx] = updated;
    }

    final upcomingIdx = _upcomingMatches.indexWhere((m) => m.id == updated.id);
    if (upcomingIdx != -1) {
      _upcomingMatches[upcomingIdx] = updated;
    }

    final completedIdx = _completedMatches.indexWhere((m) => m.id == updated.id);
    if (completedIdx != -1) {
      _completedMatches[completedIdx] = updated;
    }
  }

  // --- Data Fetching Methods ---

  /// Fetches all cricket sections in parallel with independent failure isolation.
  Future<void> fetchAllCricketData() async {
    await Future.wait(<Future<void>>[
      fetchFeaturedMatch(),
      fetchLiveMatches(),
      fetchUpcomingMatches(),
      fetchCompletedMatches(),
    ]);
  }

  /// Fetches the featured match.
  Future<void> fetchFeaturedMatch() async {
    _isFeaturedLoading = true;
    _featuredError = null;
    notifyListeners();

    try {
      _featuredMatch = await _repository.getFeaturedLiveMatch();
      _featuredError = null;
    } catch (e) {
      _featuredError = e.toString();
      _featuredMatch = null;
    } finally {
      _isFeaturedLoading = false;
      notifyListeners();
    }
  }

  /// Fetches live matches (`status=LIVE`).
  Future<void> fetchLiveMatches() async {
    _isLiveLoading = true;
    _liveError = null;
    notifyListeners();

    try {
      _liveMatches = await _repository.getLiveMatches(status: 'LIVE');
      _liveError = null;
    } catch (e) {
      _liveError = e.toString();
      _liveMatches = <LiveMatchModel>[];
    } finally {
      _isLiveLoading = false;
      notifyListeners();
    }
  }

  /// Fetches upcoming matches (`status=UPCOMING`).
  Future<void> fetchUpcomingMatches() async {
    _isUpcomingLoading = true;
    _upcomingError = null;
    notifyListeners();

    try {
      _upcomingMatches = await _repository.getLiveMatches(status: 'UPCOMING');
      _upcomingError = null;
    } catch (e) {
      _upcomingError = e.toString();
      _upcomingMatches = <LiveMatchModel>[];
    } finally {
      _isUpcomingLoading = false;
      notifyListeners();
    }
  }

  /// Fetches completed matches (`status=COMPLETED`).
  Future<void> fetchCompletedMatches() async {
    _isCompletedLoading = true;
    _completedError = null;
    notifyListeners();

    try {
      _completedMatches = await _repository.getLiveMatches(status: 'COMPLETED');
      _completedError = null;
    } catch (e) {
      _completedError = e.toString();
      _completedMatches = <LiveMatchModel>[];
    } finally {
      _isCompletedLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMatchSubData(String matchId) async {
    final cleanId = matchId.trim();
    if (cleanId.isEmpty) return;
    try {
      final results = await Future.wait([
        _repository.getLiveMatchActivity(cleanId),
        _repository.getMatchScorecard(cleanId),
        _repository.getMatchCommentary(cleanId),
        _repository.getMatchSquads(cleanId),
      ]);
      _liveActivity = results[0];
      _scorecard = results[1];
      _commentary = results[2];
      _squads = results[3];
      notifyListeners();
    } catch (_) {}
  }

  /// Fetches details for a single match and resets stream selection.
  Future<void> fetchMatchDetails(String matchId) async {
    final cleanId = matchId.trim();
    if (cleanId.isEmpty) return;

    _isDetailLoading = true;
    _detailError = null;
    _useBackupStream = false;
    notifyListeners();

    try {
      _selectedMatch = await _repository.getLiveMatchDetails(cleanId);
      _detailError = null;
      notifyListeners();
      await fetchMatchSubData(cleanId);
    } catch (e) {
      _detailError = e.toString();
      _selectedMatch = null;
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  /// Manually sets selected match from an existing list item.
  void setSelectedMatch(LiveMatchModel match) {
    _selectedMatch = match;
    _useBackupStream = false;
    _detailError = null;
    notifyListeners();
    fetchMatchSubData(match.id);
  }

  /// Clears selected match state when exiting the player or details screen.
  void clearSelectedMatch() {
    stopLiveScorePolling();
    _selectedMatch = null;
    _detailError = null;
    _liveActivity = null;
    _scorecard = null;
    _commentary = null;
    _squads = null;
    _useBackupStream = false;
    notifyListeners();
  }

  /// Records single-shot viewer registration on video start.
  Future<bool> recordViewer(String matchId) async {
    final cleanId = matchId.trim();
    if (cleanId.isEmpty) return false;
    return _repository.recordLiveMatchView(cleanId);
  }

  // --- Lifecycle & Disposal ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      resumePolling();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    stopLiveScorePolling();
    super.dispose();
  }
}
