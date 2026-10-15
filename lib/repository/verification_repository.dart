import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../data/exception/app_exception.dart';
import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/plan_model.dart';
import '../models/verification_model.dart';
import '../res/appUrl.dart';
import '../utils/hive_service/hive_service.dart';

class VerificationRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<PlanResponse> getBluetickPlans() async {
    const String marker = '[BLUE_TICK_PLAN_DEBUG]';
    final String url = AppUrl.getBluetickPlans;

    if (kDebugMode) {
      final token = HiveService.getToken();
      final Map<String, dynamic> safeHeaders = {
        'Authorization': token != null && token.isNotEmpty ? '[REDACTED]' : '[REDACTED]',
      };
      debugPrint('$marker ════════════════════════════════════');
      debugPrint('$marker 📡 BLUE TICK PLAN API REQUEST');
      debugPrint('$marker Method: GET');
      debugPrint('$marker URL: $url');
      debugPrint('$marker Headers: $safeHeaders');
      debugPrint('$marker Request Body: null');
      debugPrint('$marker ════════════════════════════════════');
    }

    try {
      dynamic response = await _apiService.getApi(url);

      if (kDebugMode) {
        String prettyResponse;
        try {
          prettyResponse = const JsonEncoder.withIndent('  ').convert(response);
        } catch (_) {
          prettyResponse = response.toString();
        }

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker 📥 BLUE TICK PLAN API RESPONSE');
        debugPrint('$marker Status Code: 200');
        debugPrint('$marker URL: $url');
        debugPrint('$marker Response Body:');
        for (final line in prettyResponse.split('\n')) {
          debugPrint('$marker $line');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

      return PlanResponse.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        String statusCode = 'Error';
        if (e is DioException && e.response?.statusCode != null) {
          statusCode = e.response!.statusCode.toString();
        } else {
          final match = RegExp(r'status code\s*:\s*(\d+)').firstMatch(e.toString());
          if (match != null) {
            statusCode = match.group(1)!;
          }
        }

        String prettyError;
        try {
          if (e is DioException && e.response?.data != null) {
            prettyError = const JsonEncoder.withIndent('  ').convert(e.response!.data);
          } else {
            prettyError = e.toString();
          }
        } catch (_) {
          prettyError = e.toString();
        }

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker ❌ BLUE TICK PLAN API ERROR');
        debugPrint('$marker Status Code: $statusCode');
        debugPrint('$marker URL: $url');
        debugPrint('$marker Error:');
        for (final line in prettyError.split('\n')) {
          debugPrint('$marker $line');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

      rethrow;
    }
  }

  Future<PlanResponse> getOrangetickPlans() async {
    const String marker = '[ORANGE_TICK_PLAN_DEBUG]';
    final String url = AppUrl.getOrangetickPlans;

    if (kDebugMode) {
      final token = HiveService.getToken();
      final Map<String, dynamic> safeHeaders = {
        'Authorization': token != null && token.isNotEmpty ? 'Bearer [REDACTED]' : '[REDACTED]',
      };
      debugPrint('$marker ════════════════════════════════════');
      debugPrint('$marker 📡 ORANGE TICK PLAN API REQUEST');
      debugPrint('$marker Method: GET');
      debugPrint('$marker URL: $url');
      debugPrint('$marker Headers: $safeHeaders');
      debugPrint('$marker Request Body: null');
      debugPrint('$marker ════════════════════════════════════');
    }

    try {
      dynamic response = await _apiService.getApi(url);

      if (kDebugMode) {
        String prettyResponse;
        try {
          prettyResponse = const JsonEncoder.withIndent('  ').convert(response);
        } catch (_) {
          prettyResponse = response.toString();
        }

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker 📥 ORANGE TICK PLAN API RESPONSE');
        debugPrint('$marker Status Code: 200');
        debugPrint('$marker URL: $url');
        debugPrint('$marker Response Body:');
        for (final line in prettyResponse.split('\n')) {
          debugPrint('$marker $line');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

      return PlanResponse.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        String statusCode = 'Error';
        if (e is DioException && e.response?.statusCode != null) {
          statusCode = e.response!.statusCode.toString();
        } else {
          final match = RegExp(r'status code\s*:\s*(\d+)').firstMatch(e.toString());
          if (match != null) {
            statusCode = match.group(1)!;
          }
        }

        String prettyError;
        try {
          if (e is DioException && e.response?.data != null) {
            prettyError = const JsonEncoder.withIndent('  ').convert(e.response!.data);
          } else {
            prettyError = e.toString();
          }
        } catch (_) {
          prettyError = e.toString();
        }

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker ❌ ORANGE TICK PLAN API ERROR');
        debugPrint('$marker Status Code: $statusCode');
        debugPrint('$marker URL: $url');
        debugPrint('$marker Error:');
        for (final line in prettyError.split('\n')) {
          debugPrint('$marker $line');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

      rethrow;
    }
  }

  Future<dynamic> applyVerification(FormData data) async {
    const String marker = '[VERIFICATION_APPLY_DEBUG]';
    final String url = AppUrl.applyVerification;
    if (kDebugMode) {
      final token = HiveService.getToken();
      final Map<String, dynamic> safeHeaders = {
        'Authorization': token != null && token.isNotEmpty ? 'Bearer [REDACTED]' : '[REDACTED]',
      };

      final Map<String, String> fieldMap = {
        for (var f in data.fields) f.key: f.value,
      };

      String maskIdNumber(String? id) {
        if (id == null || id.isEmpty) return '-';
        if (id.length <= 4) return '****';
        return '********${id.substring(id.length - 4)}';
      }

      debugPrint('$marker ════════════════════════════════════');
      debugPrint('$marker REQUEST');
      debugPrint('$marker Method: POST');
      debugPrint('$marker URL: $url');
      debugPrint('$marker Headers: $safeHeaders');
      debugPrint('$marker Body fields:');
      debugPrint('$marker - fullName: ${fieldMap['fullName'] ?? '-'}');
      debugPrint('$marker - username: ${fieldMap['username'] ?? '-'}');
      debugPrint('$marker - governmentIdType: ${fieldMap['governmentIdType'] ?? '-'}');
      debugPrint('$marker - governmentIdNumber: ${maskIdNumber(fieldMap['governmentIdNumber'])}');
      debugPrint('$marker - planId: ${fieldMap['planId'] ?? '-'}');
      debugPrint('$marker - website: ${fieldMap['website'] ?? '-'}');
      debugPrint('$marker - instagram: ${fieldMap['instagram'] ?? '-'}');
      debugPrint('$marker - facebook: ${fieldMap['facebook'] ?? '-'}');
      debugPrint('$marker - youtube: ${fieldMap['youtube'] ?? '-'}');
      debugPrint('$marker - twitter: ${fieldMap['twitter'] ?? '-'}');
      debugPrint('$marker - linkedin: ${fieldMap['linkedin'] ?? '-'}');
      debugPrint('$marker - reason: ${fieldMap['reason'] ?? '-'}');
      debugPrint('$marker - confirmation: ${fieldMap['confirmation'] ?? '-'}');
      if (fieldMap.containsKey('paymentId')) {
        debugPrint('$marker - paymentId: ${fieldMap['paymentId']}');
      }
      if (fieldMap.containsKey('transactionId')) {
        debugPrint('$marker - transactionId: ${fieldMap['transactionId']}');
      }
      if (fieldMap.containsKey('orderId')) {
        debugPrint('$marker - orderId: ${fieldMap['orderId']}');
      }
      debugPrint('$marker Files:');
      for (final file in data.files) {
        debugPrint('$marker - ${file.key} (${file.value.filename})');
      }
      debugPrint('$marker ════════════════════════════════════');
    }

    try {
      dynamic response = await _apiService.postApi(url, data);

      if (kDebugMode) {
        String prettyResponse;
        try {
          prettyResponse = const JsonEncoder.withIndent('  ').convert(response);
        } catch (_) {
          prettyResponse = response.toString();
        }

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker SUCCESS RESPONSE');
        debugPrint('$marker Status Code: 200');
        debugPrint('$marker URL: $url');
        debugPrint('$marker Response Body:');
        for (final line in prettyResponse.split('\n')) {
          debugPrint('$marker $line');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        int? statusCode;
        dynamic responseData;
        Map<String, dynamic>? responseHeaders;

        if (e is DioException) {
          statusCode = e.response?.statusCode;
          responseData = e.response?.data;
          responseHeaders = e.response?.headers.map;
        } else if (e is AppException) {
          statusCode = e.statusCode ?? 400;
          responseData = e.data;
          responseHeaders = e.responseHeaders;
        }

        final String statusStr = statusCode?.toString() ?? '400';
        String prettyBody;
        try {
          if (responseData != null) {
            prettyBody = const JsonEncoder.withIndent('  ').convert(responseData);
          } else {
            prettyBody = e.toString();
          }
        } catch (_) {
          prettyBody = responseData?.toString() ?? e.toString();
        }

        final safeRespHeaders = responseHeaders != null
            ? (Map<String, dynamic>.from(responseHeaders)
              ..removeWhere((k, _) {
                final lower = k.toLowerCase();
                return lower.contains('auth') || lower.contains('cookie') || lower.contains('token');
              }))
            : null;

        debugPrint('$marker ════════════════════════════════════');
        debugPrint('$marker ERROR RESPONSE');
        debugPrint('$marker Status Code: $statusStr');
        debugPrint('$marker Response Body:');
        for (final line in prettyBody.split('\n')) {
          debugPrint('$marker $line');
        }
        if (safeRespHeaders != null && safeRespHeaders.isNotEmpty) {
          debugPrint('$marker Response Headers: $safeRespHeaders');
        }
        debugPrint('$marker ════════════════════════════════════');
      }

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

  Future<dynamic> updateVerification(FormData data) async {
    try {
      dynamic response = await _apiService.putApi(AppUrl.updateVerification, data);
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
