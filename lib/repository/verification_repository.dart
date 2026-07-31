import 'package:dio/dio.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/plan_model.dart';
import '../models/verification_model.dart';
import '../res/appUrl.dart';

class VerificationRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<PlanResponse> getBluetickPlans() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getBluetickPlans);
      return PlanResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> applyVerification(FormData data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.applyVerification, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<VerificationStatusResponse> getVerificationStatus() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.verificationStatus);
      return VerificationStatusResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> cancelVerification() async {
    try {
      dynamic response = await _apiService.putApi(AppUrl.cancelVerification, {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateVerification(FormData data) async {
    try {
      dynamic response = await _apiService.putApi(AppUrl.updateVerification, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
