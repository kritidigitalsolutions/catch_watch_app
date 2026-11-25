import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/live_cricket_model.dart';
import '../../repository/live_cricket_repository.dart';

class LiveCricketProvider extends ChangeNotifier {
  final LiveCricketRepository _repository = LiveCricketRepository();

  bool _isLoading = false;
  String? _error;

  List<CricketMatch> _matches = [];
  CricketMatch? _featuredMatch;
  int _liveCount = 0;
  int _upcomingCount = 0;
  int _completedCount = 0;
  int _totalCount = 0;

  String _selectedStatus = 'ALL';
  String _selectedFormat = 'ALL';

  // Detail screen state
  CricketMatch? _currentMatchDetail;
  bool _isDetailLoading = false;
  LiveCrease? _liveCrease;
  ScorecardModel? _scorecard;
  List<CommentaryItem> _commentary = [];
  SquadsInfo? _squads;
  Timer? _pollingTimer;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CricketMatch> get matches => _matches;
  CricketMatch? get featuredMatch => _featuredMatch;
  int get liveCount => _liveCount;
  int get upcomingCount => _upcomingCount;
  int get completedCount => _completedCount;
  int get totalCount => _totalCount;

  String get selectedStatus => _selectedStatus;
  String get selectedFormat => _selectedFormat;

  CricketMatch? get currentMatchDetail => _currentMatchDetail;
  bool get isDetailLoading => _isDetailLoading;
  LiveCrease? get liveCrease => _liveCrease;
  ScorecardModel? get scorecard => _scorecard;
  List<CommentaryItem> get commentary => _commentary;
  SquadsInfo? get squads => _squads;

  LiveCricketProvider() {
    fetchLiveCricketData();
  }

  Future<void> fetchLiveCricketData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final futures = await Future.wait([
        _repository.getMatches(status: _selectedStatus, format: _selectedFormat),
        _repository.getFeaturedMatch(),
      ]);

      final res = futures[0] as LiveMatchesResponse;
      _matches = res.matches ?? [];
      _totalCount = res.totalCount ?? _matches.length;
      _liveCount = res.liveCount ?? 0;
      _upcomingCount = res.upcomingCount ?? 0;
      _completedCount = res.completedCount ?? 0;

      _featuredMatch = futures[1] as CricketMatch?;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilters({String? status, String? format}) {
    if (status != null) _selectedStatus = status;
    if (format != null) _selectedFormat = format;
    fetchLiveCricketData();
  }

  Future<void> loadMatchDetails(String matchId) async {
    _isDetailLoading = true;
    _currentMatchDetail = null;
    _liveCrease = null;
    _scorecard = null;
    _commentary = [];
    _squads = null;
    notifyListeners();

    try {
      // Ping viewer heartbeat
      _repository.pingViewCount(matchId);

      final results = await Future.wait([
        _repository.getMatchDetails(matchId),
        _repository.getLiveActivity(matchId),
        _repository.getScorecard(matchId),
        _repository.getSquads(matchId),
        _repository.getCommentary(matchId, limit: 30),
      ]);

      _currentMatchDetail = results[0] as CricketMatch?;
      _liveCrease = (results[1] as LiveCrease?) ?? _currentMatchDetail?.liveCrease;

      final sc = results[2] as ScorecardModel?;
      _scorecard = (sc?.innings1 != null ? sc : null) ?? _currentMatchDetail?.scorecard ?? sc;

      final sq = results[3] as SquadsInfo?;
      _squads = (sq?.team1Squad != null ? sq : null) ?? _currentMatchDetail?.squads ?? sq;

      final comms = results[4] as List<CommentaryItem>;
      _commentary = comms.isNotEmpty ? comms : (_currentMatchDetail?.commentary ?? []);

      // Start periodic polling for live activity (every 4s)
      _startPolling(matchId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  void _startPolling(String matchId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final activity = await _repository.getLiveActivity(matchId);
        if (activity != null) {
          _liveCrease = activity;
          notifyListeners();
        }
        final scorecard = await _repository.getScorecard(matchId);
        if (scorecard != null) {
          _scorecard = scorecard;
          notifyListeners();
        }
        final comms = await _repository.getCommentary(matchId, limit: 15);
        if (comms.isNotEmpty) {
          _commentary = comms;
          notifyListeners();
        }
      } catch (_) {
        // Ignore polling errors
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
