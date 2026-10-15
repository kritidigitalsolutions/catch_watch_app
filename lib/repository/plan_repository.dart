import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/plan_model.dart';
import '../res/appUrl.dart';

class PlanRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<PlanResponse> getPlans() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getPlans);
      return PlanResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<PlanResponse> getOrangetickPlans() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getOrangetickPlans);
      return PlanResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<PlanResponse> getBluetickPlans() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getBluetickPlans);
      return PlanResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> subscribe(String planId) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.subscribe, {'planId': planId});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<SubscriptionStatusResponse> getSubscriptionStatus() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.subscriptionStatus);
      return SubscriptionStatusResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> cancelSubscription(String subscriptionId, String userId) async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.cancelSubscription, {
        'subscriptionId': subscriptionId,
        'userId': userId,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createOrder(
    String planId, {
    String? promoCode,
    bool? isUpgrade,
    String? currentSubscriptionId,
  }) async {
    try {
      final Map<String, dynamic> body = {'planId': planId};
      if (promoCode != null) body['promoCode'] = promoCode;
      if (isUpgrade == true) body['isUpgrade'] = true;
      if (currentSubscriptionId != null) {
        body['currentSubscriptionId'] = currentSubscriptionId;
      }
      dynamic response = await _apiService.postApi(AppUrl.createOrder, body);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createPaymentOrder(String planId) async {
    try {
      final body = {'planId': planId};
      dynamic response = await _apiService.postApi(AppUrl.paymentOrder, body);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> verifyPayment(Map<String, dynamic> data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.verifyPayment, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> verifyApplePayment(Map<String, dynamic> data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.verifyApplePayment, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
