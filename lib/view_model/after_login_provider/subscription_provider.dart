import 'package:catch_watch/data/exception/app_exception.dart';
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
  String? _subscriptionStatusError;

  List<Plan> get plans => _plans;
  SubscriptionData? get currentSubscription => _currentSubscription;
  int? get remainingDays => _remainingDays;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get subscriptionStatusError => _subscriptionStatusError;

  /// Clears in-memory subscription state (e.g. upon account deletion or logout)
  void clearSubscriptionState() {
    _currentSubscription = null;
    _remainingDays = null;
    _error = null;
    _subscriptionStatusError = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clears transient error state so subsequent rebuilds or dialog dismissals don't see stale errors
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

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

  Future<bool> fetchSubscriptionStatus({int? expectedMinLevel}) async {
    _isLoading = true;
    _error = null;
    _subscriptionStatusError = null;
    notifyListeners();

    try {
      final response = await _planRepository.getSubscriptionStatus();

      // Case 1: Backend explicitly returned subscription data (success == true)
      if (response.success == true && response.subscription != null) {
        // If an expected minimum tier level is requested (e.g. following a verified upgrade),
        // ensure server has propagated the new tier and does not overwrite with stale lower-tier data.
        if (expectedMinLevel != null &&
            response.subscription!.getEffectiveLevel(_plans) < expectedMinLevel) {
          debugPrint(
            '[SUBSCRIPTION] Server returned status with level ${response.subscription?.getEffectiveLevel(_plans)} '
            'which is below expected min level $expectedMinLevel. Retrying query after brief delay...',
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          final retryResponse = await _planRepository.getSubscriptionStatus();
          if (retryResponse.success == true &&
              retryResponse.subscription != null &&
              retryResponse.subscription!.getEffectiveLevel(_plans) >= expectedMinLevel) {
            _currentSubscription = retryResponse.subscription;
            _remainingDays = retryResponse.remainingDays;
            _subscriptionStatusError = null;
            debugPrint('[SUBSCRIPTION] fetchSubscriptionStatus: active/entitled subscription retrieved after upgrade check (level >= $expectedMinLevel)');
            return true;
          }
          // Server has not yet propagated the upgrade; preserve verified higher-tier entitlement
          debugPrint(
            '[SUBSCRIPTION] Stale status detected from server. Preserving verified higher-tier entitlement.',
          );
          return true;
        }

        _currentSubscription = response.subscription;
        _remainingDays = response.remainingDays;
        _subscriptionStatusError = null;
        debugPrint('[SUBSCRIPTION] fetchSubscriptionStatus: subscription found (status: ${_currentSubscription?.status}, remainingDays: $_remainingDays)');
        return true;
      }

      // Case 2: Backend returned success == true with null subscription, OR
      // backend returned success == false with "No active subscription" / "not subscribed" message.
      // This is a GENUINE SUCCESSFUL status lookup confirming NO entitlement.
      final String? msg = response.message;
      final bool isNoSubMessage = msg != null &&
          (msg.toLowerCase().contains('no active subscription') ||
              msg.toLowerCase().contains('no subscription') ||
              msg.toLowerCase().contains('not subscribed') ||
              msg.toLowerCase().contains('subscription not found'));

      if (response.success == true || isNoSubMessage) {
        debugPrint('[SUBSCRIPTION] fetchSubscriptionStatus: genuine confirmation of NO subscription (message: $msg)');
        _currentSubscription = null;
        _remainingDays = null;
        _subscriptionStatusError = null;
        return true;
      }

      // Case 3: Backend explicitly returned an unhandled error response
      debugPrint('[SUBSCRIPTION] fetchSubscriptionStatus: server returned unexpected failure response (message: $msg)');
      _subscriptionStatusError = msg ?? 'Failed to fetch subscription status';
      if (expectedMinLevel == null) {
        _currentSubscription = null;
        _remainingDays = null;
      }
      return false;
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Subscription Status Exception: $e');

      // Check if this exception is a 404 or BadRequest indicating "No active subscription"
      if (e is AppException) {
        final lowerMsg = e.message.toLowerCase();
        if (lowerMsg.contains('no active subscription') ||
            lowerMsg.contains('no subscription') ||
            lowerMsg.contains('not subscribed') ||
            lowerMsg.contains('subscription not found') ||
            (e is BadRequestException && lowerMsg.contains('resource not found'))) {
          debugPrint('[SUBSCRIPTION] fetchSubscriptionStatus: 404/AppException confirmed NO subscription (${e.message})');
          _currentSubscription = null;
          _remainingDays = null;
          _subscriptionStatusError = null;
          return true;
        }
        _subscriptionStatusError = e.message;
      } else {
        _subscriptionStatusError = e.toString().replaceAll('Exception: ', '').trim();
      }

      if (_subscriptionStatusError == null || _subscriptionStatusError!.isEmpty) {
        _subscriptionStatusError = 'Failed to fetch subscription status';
      }
      if (expectedMinLevel == null) {
        _currentSubscription = null;
        _remainingDays = null;
      }
      return false;
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

  Future<Map<String, dynamic>?> createOrder(
    String planId, {
    String? promoCode,
    bool? isUpgrade,
    String? currentSubscriptionId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.createOrder(
        planId,
        promoCode: promoCode,
        isUpgrade: isUpgrade,
        currentSubscriptionId: currentSubscriptionId,
      );
      if (response['success'] == true) {
        return response;
      } else {
        _error = response['message'] ?? 'Failed to create order';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculates an estimated upgrade quote for the given target plan relative to active subscription
  UpgradeQuote? getUpgradeQuote(Plan targetPlan) {
    if (_currentSubscription == null ||
        !_currentSubscription!.isCurrentlyValid(remainingDays: _remainingDays)) {
      return null;
    }

    Plan activePlan;
    if (_currentSubscription!.plan is Plan) {
      activePlan = _currentSubscription!.plan as Plan;
    } else {
      activePlan = _plans.firstWhere(
        (p) => p.id == _currentSubscription!.planId,
        orElse: () => Plan(
          id: _currentSubscription!.planId,
          name: _currentSubscription!.planName ?? 'Current Plan',
          price: _currentSubscription!.amount ?? 0,
        ),
      );
    }

    return UpgradeQuote.calculateEstimate(
      currentPlan: activePlan,
      targetPlan: targetPlan,
      remainingDays: _remainingDays ?? 0,
    );
  }

  Future<Map<String, dynamic>?> createPaymentOrder(String planId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.createPaymentOrder(planId);
      if (response != null && response['success'] == true) {
        return response;
      } else {
        _error = response?['message'] ?? 'Failed to create payment order';
        return null;
      }
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPayment(Map<String, dynamic> paymentData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.verifyPayment(paymentData);
      if (response['success'] == true) {
        if (paymentData['type'] != 'verification') {
          await fetchSubscriptionStatus();
        }
        return true;
      } else {
        _error = response['message'] ?? 'Payment verification failed';
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

  Future<bool> verifyApplePayment(Map<String, dynamic> paymentData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _planRepository.verifyApplePayment(paymentData);
      if (response != null && response['success'] == true) {
        // Determine expected tier level from productId or target plan
        int? targetLevel;
        final productId = paymentData['productId']?.toString();
        if (productId == 'com.app.catchWatch.sub.premium.yearly') {
          targetLevel = 3;
        } else if (productId == 'com.app.catchWatch.sub.premium.monthly') {
          targetLevel = 2;
        } else if (productId == 'com.app.catchWatch.sub.premium.weekly') {
          targetLevel = 1;
        }

        // If backend verification directly returned the updated subscription, parse it
        final dynamic subJson = response['subscription'] ?? response['data']?['subscription'];
        if (subJson is Map<String, dynamic>) {
          try {
            _currentSubscription = SubscriptionData.fromJson(subJson);
            final remDays = response['remainingDays'] ?? response['data']?['remainingDays'];
            if (remDays != null) {
              _remainingDays = remDays is int ? remDays : int.tryParse(remDays.toString());
            }
          } catch (e) {
            debugPrint('[SUBSCRIPTION] Error parsing subscription from verifyApplePayment: $e');
          }
        }

        if (paymentData['type'] != 'verification') {
          await fetchSubscriptionStatus(expectedMinLevel: targetLevel);
        }
        return true;
      } else {
        _error = response?['message'] ?? 'Apple payment verification failed';
        return false;
      }
    } catch (e) {
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = e.toString();
      }
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
