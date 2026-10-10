import 'package:dio/dio.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/auth_models.dart';
import '../res/appUrl.dart';

class AuthRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<SendOtpResponse> sendOtp(dynamic data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.sendOtp, data);
      return SendOtpResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<VerifyOtpResponse> verifyOtp(dynamic data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.verifyOtp, data);
      return VerifyOtpResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<CompleteProfileResponse> completeProfile(FormData data) async {
    try {
      dynamic response = await _apiService.postApi(AppUrl.completeProfile, data);
      return CompleteProfileResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getProfile() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getProfile);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateProfile(FormData data) async {
    try {
      dynamic response = await _apiService.patchApi(AppUrl.updateProfile, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete Account
  ///
  /// Integrates with the account deletion API endpoint using [BaseApiService.deleteApi].
  /// Backend API Contract Requirement:
  /// - HTTP Method: DELETE
  /// - URL: [AppUrl.deleteAccount] (`/api/user/delete-account`)
  /// - Headers:
  ///   - Authorization: Bearer <USER_ACCESS_TOKEN>
  ///   - Content-Type: application/json
  /// - Request Body:
  ///   - Passed as [data] if supported/provided; omitted (null) if no body is confirmed.
  /// - Success Response: { "success": true, "message": "..." }
  /// - Error Response: { "success": false, "message": "..." }
  Future<dynamic> deleteAccount({Map<String, dynamic>? data}) async {
    try {
      dynamic response = await _apiService.deleteApi(AppUrl.deleteAccount, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
