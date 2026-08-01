import 'package:flutter/material.dart';
import '../../models/creator_dashboard_model.dart';
import '../../models/wallet_model.dart';
import '../../repository/wallet_repository.dart';
import 'dart:math';

enum TimeFilter { today, week, month, year }
enum DashboardMetric { reels, views, likes, comments, shares, saves, points }

class WalletProvider extends ChangeNotifier {
  final WalletRepository _walletRepository = WalletRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  CreatorDashboardData? _dashboardData;
  CreatorDashboardData? get dashboardData => _dashboardData;

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

  TimeFilter _selectedTimeFilter = TimeFilter.week;
  TimeFilter get selectedTimeFilter => _selectedTimeFilter;

  DashboardMetric _selectedGraphMetric = DashboardMetric.views;
  DashboardMetric get selectedGraphMetric => _selectedGraphMetric;

  void setTimeFilter(TimeFilter filter) {
    _selectedTimeFilter = filter;
    fetchDashboardData();
    notifyListeners();
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardData = await _walletRepository.getDashboardData();
      if (_dashboardData?.pointHistory != null) {
        _pointHistory = _dashboardData!.pointHistory!;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchWalletSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _walletSummary = await _walletRepository.getWalletSummary();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPointsSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pointsSummary = await _walletRepository.getPointsSummary();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPointHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pointHistory = await _walletRepository.getPointHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<RedeemHistory> _redeemRequests = [];
  List<RedeemHistory> get redeemRequests => _redeemRequests;

  Future<void> fetchRedeemHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _walletRepository.getRedeemHistory();
      _redeemHistory = response['history'] ?? [];
      _redeemRequests = response['requests'] ?? [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _error = null;
    notifyListeners();

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
      _error = response['message'] ?? 'Redeem failed';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
