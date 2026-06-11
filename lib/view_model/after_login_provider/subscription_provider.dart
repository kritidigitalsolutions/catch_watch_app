import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/repository/plan_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';

class SubscriptionProvider extends ChangeNotifier {
  final PlanRepository _planRepository = PlanRepository();

  List<Plan> _plans = [];
  SubscriptionData? _currentSubscription;
  int? _remainingDays;
  bool _isLoading = false;
  String? _error;

  List<Plan> get plans => _plans;
  SubscriptionData? get currentSubscription => _currentSubscription;
  int? get remainingDays => _remainingDays;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.getPlans();
      if (response.success == true) {
        _plans = response.plans ?? [];
      } else {
        _error = 'Failed to fetch plans';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSubscriptionStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.getSubscriptionStatus();
      if (response.success == true) {
        _currentSubscription = response.subscription;
        _remainingDays = response.remainingDays;
      } else {
        _currentSubscription = null;
        _remainingDays = null;
      }
    } catch (e) {
      debugPrint("Subscription Status Error: $e");
      _currentSubscription = null;
      _remainingDays = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> subscribe(String planId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _planRepository.subscribe(planId);
      if (response['success'] == true) {
        await fetchSubscriptionStatus();
        return true;
      } else {
        _error = response['message'] ?? 'Subscription failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelSubscription() async {
    if (_currentSubscription == null) {
      _error = "No active subscription";
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = HiveService.userId;
      if (userId == null) {
        _error = "User session expired";
        return false;
      }

      final response = await _planRepository.cancelSubscription(
        _currentSubscription!.id!,
        userId,
      );
      
      if (response['success'] == true || (response['message'] != null && response['message'].toString().toLowerCase().contains('success'))) {
        await fetchSubscriptionStatus();
        return true;
      } else {
        _error = response['message'] ?? "Cancellation failed";
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
