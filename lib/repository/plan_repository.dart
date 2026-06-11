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
}
