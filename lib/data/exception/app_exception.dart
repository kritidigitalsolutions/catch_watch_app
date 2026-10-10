class AppException implements Exception {
  final String message;
  final String prefix;
  final dynamic data;
  final int? statusCode;
  final Map<String, dynamic>? responseHeaders;

  AppException(
    this.message,
    this.prefix, {
    this.data,
    this.statusCode,
    this.responseHeaders,
  });

  @override
  String toString() {
    return message;
  }
}

class FetchDataException extends AppException {
  FetchDataException([
    String? message,
    dynamic data,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
  ]) : super(
         message ?? "Error During Communication",
         "FetchDataException: ",
         data: data,
         statusCode: statusCode,
         responseHeaders: responseHeaders,
       );
}

class BadRequestException extends AppException {
  BadRequestException([
    String? message,
    dynamic data,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
  ]) : super(
         message ?? "Invalid Request",
         "BadRequestException: ",
         data: data,
         statusCode: statusCode,
         responseHeaders: responseHeaders,
       );
}

class UnauthorizedException extends AppException {
  UnauthorizedException([
    String? message,
    dynamic data,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
  ]) : super(
         message ?? "Unauthorized Request",
         "UnauthorizedException: ",
         data: data,
         statusCode: statusCode,
         responseHeaders: responseHeaders,
       );
}

class InvalidInputException extends AppException {
  InvalidInputException([
    String? message,
    dynamic data,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
  ]) : super(
         message ?? "Invalid Input",
         "InvalidInputException: ",
         data: data,
         statusCode: statusCode,
         responseHeaders: responseHeaders,
       );
}
