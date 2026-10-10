import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/hive_service/hive_service.dart';
import '../exception/app_exception.dart';
import 'base_api_service.dart';

class NetworkApiService extends BaseApiService {
  static int _requestCounter = 0;
  late Dio _dio;

  NetworkApiService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 600), // Increased send timeout for large uploads
      ),
    );

    /// Centralized Interceptor for Request ID, Timestamp, Caller Tracing, Redaction, and Debug Logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final reqId = 'REQ-${(++_requestCounter).toString().padLeft(3, '0')}';
          final reqTime = DateTime.now();
          options.extra['reqId'] = reqId;
          options.extra['reqTime'] = reqTime;

          final token = HiveService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }

          final timeStr = _formatTimestamp(reqTime);
          final safeHeaders = _sanitizeHeaders(options.headers);
          final caller = _formatCaller();
          final bodyString = _formatRequestBody(options.data);

          debugPrint('[API_DEBUG] ═══════════════════════════════════════');
          debugPrint('[API_DEBUG][$reqId][$timeStr] ➡️ REQUEST');
          debugPrint('[API_DEBUG] Method: ${options.method}');
          debugPrint('[API_DEBUG] URL: ${options.uri}');
          debugPrint('[API_DEBUG] Headers: $safeHeaders');
          debugPrint('[API_DEBUG] Caller:\n$caller');
          debugPrint('[API_DEBUG] Request Body:\n$bodyString');
          debugPrint('[API_DEBUG] ═══════════════════════════════════════');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          final reqId = response.requestOptions.extra['reqId'] ?? 'REQ-???';
          final timeStr = _formatTimestamp(DateTime.now());
          final safeHeaders = _sanitizeHeaders(response.headers.map);
          final bodyString = _prettyPrintJson(response.data);

          debugPrint('[API_DEBUG] ═══════════════════════════════════════');
          debugPrint('[API_DEBUG][$reqId][$timeStr] ✅ RESPONSE');
          debugPrint('[API_DEBUG] Method: ${response.requestOptions.method}');
          debugPrint('[API_DEBUG] URL: ${response.requestOptions.uri}');
          debugPrint('[API_DEBUG] Status Code: ${response.statusCode}');
          debugPrint('[API_DEBUG] Response Headers: $safeHeaders');
          debugPrint('[API_DEBUG] Response Body:\n$bodyString');
          debugPrint('[API_DEBUG] ═══════════════════════════════════════');

          return handler.next(response);
        },
        onError: (DioException e, handler) {
          final reqId = e.requestOptions.extra['reqId'] ?? 'REQ-???';
          final timeStr = _formatTimestamp(DateTime.now());
          final safeHeaders = e.response != null ? _sanitizeHeaders(e.response!.headers.map) : {};
          final bodyString = _prettyPrintJson(e.response?.data ?? e.message);

          debugPrint('[API_DEBUG] ═══════════════════════════════════════');
          debugPrint('[API_DEBUG][$reqId][$timeStr] ❌ ERROR RESPONSE');
          debugPrint('[API_DEBUG] Method: ${e.requestOptions.method}');
          debugPrint('[API_DEBUG] URL: ${e.requestOptions.uri}');
          debugPrint('[API_DEBUG] Status Code: ${e.response?.statusCode ?? 'N/A'}');
          debugPrint('[API_DEBUG] Response Headers: $safeHeaders');
          debugPrint('[API_DEBUG] Response Body:\n$bodyString');
          debugPrint('[API_DEBUG] ═══════════════════════════════════════');

          return handler.next(e);
        },
      ),
    );
  }

  static String _formatTimestamp([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static String _formatCaller() {
    final lines = StackTrace.current.toString().split('\n');
    final appFrames = <String>[];
    for (final line in lines) {
      if (line.contains('package:catch_watch/') &&
          !line.contains('api_network_service.dart') &&
          !line.contains('base_api_service.dart')) {
        appFrames.add(line.trim());
        if (appFrames.length >= 4) break;
      }
    }
    if (appFrames.isEmpty) return '[API_DEBUG]   (Unknown caller)';
    return appFrames.map((f) => '[API_DEBUG]   → $f').join('\n');
  }

  static Map<String, dynamic> _sanitizeHeaders(Map<dynamic, dynamic> headers) {
    final safe = <String, dynamic>{};
    headers.forEach((key, value) {
      final keyStr = key.toString();
      final lowerKey = keyStr.toLowerCase();
      if (lowerKey == 'authorization') {
        safe[keyStr] = 'Bearer [REDACTED]';
      } else if (lowerKey.contains('cookie') ||
          lowerKey.contains('token') ||
          lowerKey.contains('secret') ||
          lowerKey.contains('password') ||
          lowerKey.contains('key')) {
        safe[keyStr] = '[REDACTED]';
      } else {
        safe[keyStr] = value;
      }
    });
    return safe;
  }

  static String _formatRequestBody(dynamic data) {
    if (data == null) return '[API_DEBUG]   null';
    if (data is FormData) {
      final lines = <String>[];
      lines.add('[API_DEBUG]   FormData (fields: ${data.fields.length}, files: ${data.files.length}):');
      for (final field in data.fields) {
        final lowerKey = field.key.toLowerCase();
        String val = field.value;
        if (lowerKey.contains('idnumber') || lowerKey.contains('governmentid')) {
          val = val.length > 4 ? '********${val.substring(val.length - 4)}' : '****';
        } else if (lowerKey.contains('password') || lowerKey.contains('token') || lowerKey.contains('secret')) {
          val = '[REDACTED]';
        }
        lines.add('[API_DEBUG]   - ${field.key}: $val');
      }
      for (final file in data.files) {
        lines.add('[API_DEBUG]   - ${file.key}: ${file.value.filename} (${file.value.length} bytes)');
      }
      return lines.join('\n');
    }
    return _prettyPrintJson(data);
  }

  static dynamic _sanitizeData(dynamic obj) {
    if (obj is Map) {
      final sanitized = <String, dynamic>{};
      obj.forEach((k, v) {
        final keyLower = k.toString().toLowerCase();
        if (keyLower.contains('password') ||
            keyLower.contains('token') ||
            keyLower.contains('secret') ||
            keyLower.contains('refreshtoken')) {
          sanitized[k.toString()] = '[REDACTED]';
        } else if (keyLower.contains('governmentid') || keyLower.contains('idnumber')) {
          final str = v.toString();
          sanitized[k.toString()] = str.length > 4 ? '********${str.substring(str.length - 4)}' : '****';
        } else {
          sanitized[k.toString()] = _sanitizeData(v);
        }
      });
      return sanitized;
    } else if (obj is List) {
      return obj.map(_sanitizeData).toList();
    }
    return obj;
  }

  static String _prettyPrintJson(dynamic data) {
    if (data == null) return '[API_DEBUG]   null';
    try {
      final sanitized = _sanitizeData(data);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(sanitized);
      return jsonStr.split('\n').map((l) => '[API_DEBUG]   $l').join('\n');
    } catch (_) {
      return '[API_DEBUG]   ${data.toString()}';
    }
  }

  /// 🔑 Set Authorization Token
  void setToken(String token) {
    _dio.options.headers["Authorization"] = "Bearer $token";
    debugPrint("🔐 Token Set: Bearer [REDACTED]");
  }

  /// ❌ Remove Token (Logout)
  void clearToken() {
    _dio.options.headers.remove("Authorization");
    debugPrint("🔓 Token Cleared");
  }

  @override
  Future<dynamic> getApi(String url) async {
    try {
      final response = await _dio.get(url);
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> postApi(String url, dynamic data) async {
    try {
      final response = await _dio.post(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<dynamic> postApiWithProgress(String url, dynamic data, {Function(int, int)? onSendProgress}) async {
    try {
      final options = Options(
        sendTimeout: const Duration(minutes: 20), // 20 minutes for video
        receiveTimeout: const Duration(minutes: 20),
      );

      final response = await _dio.post(
        url,
        data: data,
        onSendProgress: onSendProgress,
        options: options,
      );
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> patchApi(String url, dynamic data) async {
    try {
      final response = await _dio.patch(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> putApi(String url, dynamic data) async {
    try {
      final response = await _dio.put(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> deleteApi(String url, dynamic data) async {
    try {
      final response = await _dio.delete(
        url,
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
          },
        ),
      );
      return returnResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return FetchDataException("Connection timeout");

      case DioExceptionType.connectionError:
        return FetchDataException("No Internet Connection");

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final data = error.response?.data;
        String message = "Unknown error";

        if (data is Map && data.containsKey('message')) {
          message = data['message'].toString();
        } else if (data is Map && data.containsKey('error')) {
          message = data['error'].toString();
        } else {
          message = data?.toString() ?? "Unknown error";
        }

        final headers = error.response?.headers.map;

        if (statusCode == 400) {
          return BadRequestException(message != "Unknown error" ? message : "Invalid request", data, statusCode, headers);
        } else if (statusCode == 401 || statusCode == 403) {
          return UnauthorizedException(message != "Unknown error" ? message : "Unauthorized access", data, statusCode, headers);
        } else if (statusCode == 404) {
          return BadRequestException(message != "Unknown error" ? message : "Resource not found", data, statusCode, headers);
        } else if (statusCode == 409) {
          return FetchDataException(message != "Unknown error" ? message : "Conflict occurred", data, statusCode, headers);
        } else if (statusCode >= 500) {
          return FetchDataException(message != "Unknown error" && message != "Server Error" ? message : "Server Error", data, statusCode, headers);
        } else {
          return FetchDataException(message, data, statusCode, headers);
        }

      case DioExceptionType.cancel:
        return FetchDataException("Request cancelled");

      case DioExceptionType.unknown:
      default:
        final message = error.message ?? "";
        if (message.contains("SocketException")) {
           return FetchDataException("No Internet Connection");
        }
        return FetchDataException("Something went wrong: ${error.error ?? 'Unknown error'}");
    }
  }
}

dynamic returnResponse(Response response) {
  switch (response.statusCode) {
    case 200:
    case 201:
    case 202:
    case 204:
      return response.data;

    case 400:
      throw BadRequestException(response.data?.toString());

    case 401:
    case 403:
      throw UnauthorizedException(response.data?.toString());

    case 404:
      throw BadRequestException(response.data?.toString() ?? "Resource not found");

    case 500:
    default:
      throw FetchDataException(
        "Error occurred with status code : ${response.statusCode}",
      );
  }
}
