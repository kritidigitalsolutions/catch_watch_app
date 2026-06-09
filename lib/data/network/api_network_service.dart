import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/hive_service/hive_service.dart';
import '../exception/app_exception.dart';
import 'base_api_service.dart';

class NetworkApiService extends BaseApiService {
  late Dio _dio;

  NetworkApiService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        // headers: {"Content-Type": "application/json"},
      ),
    );

    /// Interceptor for logging and Authorization
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = HiveService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          debugPrint("➡️ REQUEST [${options.method}] => ${options.uri}");
          debugPrint("Headers: ${options.headers}");
          debugPrint("Data: ${options.data}");
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint("✅ RESPONSE [${response.statusCode}] => ${response.data}");
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          debugPrint("❌ ERROR [${e.response?.statusCode}] => Type: ${e.type}, Message: ${e.message}, Error: ${e.error}");
          return handler.next(e);
        },
      ),
    );
  }

  /// 🔑 Set Authorization Token
  void setToken(String token) {
    _dio.options.headers["Authorization"] = "Bearer $token";
    debugPrint("🔐 Token Set: Bearer $token");
  }

  /// ❌ Remove Token (Logout)
  void clearToken() {
    _dio.options.headers.remove("Authorization");
    debugPrint("🔓 Token Cleared");
  }

  @override
  Future<dynamic> getApi(String url) async {
    try {
      debugPrint("GET API CALL => $url");
      final response = await _dio.get(url);
      return returnResponse(response);
    } on DioException catch (e) {
      debugPrint("GET API ERROR => ${e.message}");
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> postApi(String url, dynamic data) async {
    try {
      debugPrint("POST API CALL => $url");
      debugPrint("POST DATA => $data");

      final response = await _dio.post(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      debugPrint("POST API ERROR => ${e.message}");
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> patchApi(String url, dynamic data) async {
    try {
      debugPrint("PATCH API CALL => $url");
      debugPrint("PATCH DATA => $data");

      final response = await _dio.patch(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      debugPrint("PATCH API ERROR => ${e.message}");
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> putApi(String url, dynamic data) async {
    try {
      debugPrint("PUT API CALL => $url");
      debugPrint("PUT DATA => $data");

      final response = await _dio.put(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      debugPrint("PUT API ERROR => ${e.message}");
      throw _handleDioError(e);
    }
  }

  @override
  Future<dynamic> deleteApi(String url, dynamic data) async {
    try {
      debugPrint("DELETE API CALL => $url");

      final response = await _dio.delete(url, data: data);
      return returnResponse(response);
    } on DioException catch (e) {
      debugPrint("DELETE API ERROR => ${e.message}");
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException error) {
    debugPrint("HANDLE ERROR => ${error.response?.data}");

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return FetchDataException("Connection timeout");

      case DioExceptionType.connectionError:
        return FetchDataException("Connection error: ${error.message ?? 'Check your internet or server IP'}");

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = error.response?.data.toString() ?? "Unknown error";

        if (statusCode == 400) {
          return BadRequestException(message);
        } else if (statusCode == 401 || statusCode == 403) {
          return UnauthorizedException(message);
        } else if (statusCode == 500) {
          return FetchDataException("Server Error");
        } else {
          return FetchDataException(
            "Error occurred with status code : $statusCode",
          );
        }

      case DioExceptionType.cancel:
        return FetchDataException("Request cancelled");

      case DioExceptionType.unknown:
      default:
        return FetchDataException("No Internet Connection");
    }
  }
}

dynamic returnResponse(Response response) {
  switch (response.statusCode) {
    case 200:
    case 201:
      return response.data;

    case 400:
      throw BadRequestException(response.data.toString());

    case 401:
    case 403:
      throw UnauthorizedException(response.data.toString());

    case 500:
    default:
      throw FetchDataException(
        "Error occurred with status code : ${response.statusCode}",
      );
  }
}
