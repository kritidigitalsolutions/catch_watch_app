import 'package:flutter/material.dart';
import '../../models/creator_dashboard_model.dart';
import '../../models/leaderboard_model.dart';
import '../../models/wallet_model.dart';
import '../../repository/wallet_repository.dart';
import 'dart:math';

enum TimeFilter { all, today, week, month, year }
enum DashboardMetric { reels, views, likes, comments, shares, saves, points }

/// Independently tracked async operations of [WalletProvider].
///
/// Each operation owns its own loading counter and error message so that a
/// request in one area (e.g. the dashboard) can never overwrite the loading or
/// error state of another (e.g. the wallet summary).
enum WalletOperation {
  dashboard,
  leaderboard,
  walletSummary,
  pointsSummary,
  pointHistory,
  redeemHistory,
  redeem,
}

class WalletProvider extends ChangeNotifier {
  final WalletRepository _walletRepository = WalletRepository();

  // Per-operation in-flight counters. A counter (rather than a bool) keeps the
  // loading state correct when the same operation is triggered concurrently.
  final Map<WalletOperation, int> _pending = {
    for (final op in WalletOperation.values) op: 0,
  };

  // Per-operation error messages. Only the operation that restarts clears its
  // own error, so a success elsewhere can never wipe it.
  final Map<WalletOperation, String?> _errors = {
    for (final op in WalletOperation.values) op: null,
  };

  void _startOp(WalletOperation op) {
    _pending[op] = (_pending[op] ?? 0) + 1;
    _errors[op] = null;
    notifyListeners();
  }

  void _finishOp(WalletOperation op) {
    final int next = (_pending[op] ?? 1) - 1;
    _pending[op] = next < 0 ? 0 : next;
    notifyListeners();
  }

  bool _isOpLoading(WalletOperation op) => (_pending[op] ?? 0) > 0;

  /// Dashboard (creator stats) loading/error.
  bool get isDashboardLoading => _isOpLoading(WalletOperation.dashboard);
  String? get dashboardError => _errors[WalletOperation.dashboard];

  /// Leaderboard loading/error.
  bool get isLeaderboardLoading => _isOpLoading(WalletOperation.leaderboard);
  String? get leaderboardError => _errors[WalletOperation.leaderboard];

  /// Wallet summary loading/error.
  bool get isWalletSummaryLoading => _isOpLoading(WalletOperation.walletSummary);
  String? get walletSummaryError => _errors[WalletOperation.walletSummary];

  /// Points summary loading/error.
  bool get isPointsSummaryLoading => _isOpLoading(WalletOperation.pointsSummary);
  String? get pointsSummaryError => _errors[WalletOperation.pointsSummary];

  /// Point (transaction) history loading/error.
  bool get isPointHistoryLoading => _isOpLoading(WalletOperation.pointHistory);
  String? get pointHistoryError => _errors[WalletOperation.pointHistory];

  /// Redeem history loading/error.
  bool get isRedeemHistoryLoading => _isOpLoading(WalletOperation.redeemHistory);
  String? get redeemHistoryError => _errors[WalletOperation.redeemHistory];

  /// Points redemption loading/error.
  bool get isRedeeming => _isOpLoading(WalletOperation.redeem);
  String? get redeemError => _errors[WalletOperation.redeem];

  CreatorDashboardData? _dashboardData;
  CreatorDashboardData? get dashboardData => _dashboardData;

  LeaderboardResponse? _leaderboardData;
  LeaderboardResponse? get leaderboardData => _leaderboardData;

  WalletSummary? _walletSummary;
  WalletSummary? get walletSummary => _walletSummary;

  PointsSummary? _pointsSummary;
  PointsSummary? get pointsSummary => _pointsSummary;

  List<PointHistoryLog> _pointHistory = [];
  List<PointHistoryLog> get pointHistory => _pointHistory;

  List<RedeemHistory> _redeemHistory = [];
  List<RedeemHistory> get redeemHistory => _redeemHistory;

  int get availablePoints {
    if (_walletSummary != null) return _walletSummary!.availablePoints ?? 0;
    if (_dashboardData != null) return _dashboardData!.redeemablePoints ?? 0;
    return 0;
  }

  int get periodPoints {
    if (_dashboardData == null) return 0;
    switch (_selectedTimeFilter) {
      case TimeFilter.all: return _dashboardData!.totalPoints ?? 0;
      case TimeFilter.today: return _dashboardData!.todayPoints ?? 0;
      case TimeFilter.week: return _dashboardData!.weeklyPoints ?? 0;
      case TimeFilter.month: return _dashboardData!.monthlyPoints ?? 0;
      // Year is disabled until the backend provides year-scoped data, so this
      // branch is unreachable (see setTimeFilter). The API has no yearly points
      // field, so we deliberately do NOT fall back to the all-time total here.
      // TODO(backend): add year-scoped points to support this filter.
      case TimeFilter.year: return 0;
    }
  }

  DashboardTimeStats get _currentTimeStats {
    if (_dashboardData?.timeStats == null) {
      return DashboardTimeStats(likes: 0, comments: 0, views: 0, saves: 0, shares: 0);
    }
    String key = _selectedTimeFilter.name.toLowerCase();
    if (key == 'all') key = 'total';
    
    return _dashboardData!.timeStats![key] ?? 
           _dashboardData!.timeStats!['total'] ??
           DashboardTimeStats(likes: 0, comments: 0, views: 0, saves: 0, shares: 0);
  }

  int get currentLikes => _currentTimeStats.likes;
  int get currentComments => _currentTimeStats.comments;
  int get currentViews => _currentTimeStats.views;
  int get currentSaves => _currentTimeStats.saves;
  int get currentShares => _currentTimeStats.shares;

  TimeFilter _selectedTimeFilter = TimeFilter.all;
  TimeFilter get selectedTimeFilter => _selectedTimeFilter;

  DashboardMetric _selectedGraphMetric = DashboardMetric.views;
  DashboardMetric get selectedGraphMetric => _selectedGraphMetric;

  void setTimeFilter(TimeFilter filter) {
    // Year is not supported by the backend yet (no year-scoped data). Ignore it
    // so all-time values are never aliased under the Year filter.
    if (filter == TimeFilter.year) return;
    _selectedTimeFilter = filter;
    // fetchDashboardData() notifies synchronously at its start, so the filter
    // change is reflected without an extra (premature) notification here.
    fetchDashboardData();
  }

  void setGraphMetric(DashboardMetric metric) {
    _selectedGraphMetric = metric;
    notifyListeners();
  }

  // List<double> getGraphData() {
  //   // In a real app, this would use data from _dashboardData?.graph
  //   // For now, if graph data is available from API, we use it, otherwise dummy
  //   if (_dashboardData?.graph != null && _dashboardData!.graph!.isNotEmpty) {
  //     return _dashboardData!.graph!.map((e) => e.value).toList();
  //   }
  //
  //   final Random random = Random();
  //   int count = 7;
  //   double baseValue = 50.0;
  //
  //   switch (_selectedTimeFilter) {
  //     case TimeFilter.today: count = 12; break;
  //     case TimeFilter.week: count = 7; break;
  //     case TimeFilter.month: count = 4; break;
  //     case TimeFilter.year: count = 12; break;
  //   }
  //
  //   switch (_selectedGraphMetric) {
  //     case DashboardMetric.reels: baseValue = 10.0; break;
  //     case DashboardMetric.views: baseValue = 500.0; break;
  //     case DashboardMetric.likes: baseValue = 100.0; break;
  //     case DashboardMetric.comments: baseValue = 30.0; break;
  //     case DashboardMetric.shares: baseValue = 20.0; break;
  //     case DashboardMetric.saves: baseValue = 15.0; break;
  //     case DashboardMetric.points: baseValue = 1000.0; break;
  //   }
  //
  //   return List.generate(count, (i) => baseValue + random.nextDouble() * (baseValue / 2));
  // }

  Future<void> fetchDashboardData() async {
    _startOp(WalletOperation.dashboard);

    try {
      _dashboardData = await _walletRepository.getDashboardData(range: _selectedTimeFilter.name.toLowerCase());
      // NOTE: the dashboard payload keeps its own pointHistory; it is exposed via
      // `dashboardData.pointHistory` and never copied into the wallet's
      // `pointHistory` list, so the two data sets stay independent.
    } catch (e) {
      _errors[WalletOperation.dashboard] = e.toString();
    } finally {
      _finishOp(WalletOperation.dashboard);
    }
  }

  String _selectedLeaderboardTimeframe = 'all';
  String get selectedLeaderboardTimeframe => _selectedLeaderboardTimeframe;

  Future<void> fetchLeaderboard({String range = 'all'}) async {
    _selectedLeaderboardTimeframe = range;
    // Clear stale results before notifying so the loading frame shows no old data.
    _leaderboardData = null;
    _startOp(WalletOperation.leaderboard);

    try {
      debugPrint("Fetching Leaderboard for timeframe: $range");

      _leaderboardData = await _walletRepository.getLeaderboard(range: range);

      debugPrint("Leaderboard fetch success: ${_leaderboardData?.leaderboard?.length} users");
    } catch (e) {
      _errors[WalletOperation.leaderboard] = e.toString();
      debugPrint("Leaderboard fetch error: $e");
    } finally {
      _finishOp(WalletOperation.leaderboard);
    }
  }

  Future<void> fetchWalletSummary() async {
    _startOp(WalletOperation.walletSummary);

    try {
      _walletSummary = await _walletRepository.getWalletSummary();
    } catch (e) {
      _errors[WalletOperation.walletSummary] = e.toString();
    } finally {
      _finishOp(WalletOperation.walletSummary);
    }
  }

  Future<void> fetchPointsSummary() async {
    _startOp(WalletOperation.pointsSummary);

    try {
      _pointsSummary = await _walletRepository.getPointsSummary();
    } catch (e) {
      _errors[WalletOperation.pointsSummary] = e.toString();
    } finally {
      _finishOp(WalletOperation.pointsSummary);
    }
  }

  Future<void> fetchPointHistory() async {
    _startOp(WalletOperation.pointHistory);

    try {
      _pointHistory = await _walletRepository.getPointHistory();
    } catch (e) {
      _errors[WalletOperation.pointHistory] = e.toString();
    } finally {
      _finishOp(WalletOperation.pointHistory);
    }
  }

  List<RedeemHistory> _redeemRequests = [];
  List<RedeemHistory> get redeemRequests => _redeemRequests;

  Future<void> fetchRedeemHistory() async {
    _startOp(WalletOperation.redeemHistory);

    try {
      final response = await _walletRepository.getRedeemHistory();
      _redeemHistory = response['history'] ?? [];
      _redeemRequests = response['requests'] ?? [];
    } catch (e) {
      _errors[WalletOperation.redeemHistory] = e.toString();
    } finally {
      _finishOp(WalletOperation.redeemHistory);
    }
  }

  Future<bool> redeemPoints({
    required int points,
    required String paymentMethod,
    String? upiId,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
  }) async {
    _startOp(WalletOperation.redeem);

    try {
      final Map<String, dynamic> data = {
        'points': points,
        'paymentMethod': paymentMethod,
      };

      if (paymentMethod == 'UPI') {
        data['upiId'] = upiId;
        data['accountHolderName'] = accountHolderName;
      } else {
        data['accountHolderName'] = accountHolderName;
        data['accountNumber'] = accountNumber;
        data['ifscCode'] = ifscCode;
        data['bankName'] = bankName;
      }

      final response = await _walletRepository.redeemPoints(data);
      if (response['success'] == true) {
        await fetchWalletSummary();
        await fetchPointsSummary();
        await fetchPointHistory();
        return true;
      }
      _errors[WalletOperation.redeem] = response['message'] ?? 'Redeem failed';
      return false;
    } catch (e) {
      _errors[WalletOperation.redeem] = e.toString();
      return false;
    } finally {
      _finishOp(WalletOperation.redeem);
    }
  }
}
