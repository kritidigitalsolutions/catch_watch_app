import 'user_model.dart';

class SendOtpResponse {
  bool? success;
  String? message;
  bool? isNewUser;
  String? otp;

  SendOtpResponse({this.success, this.message, this.isNewUser, this.otp});

  SendOtpResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    isNewUser = json['isNewUser'];
    otp = json['otp'];
  }
}

class VerifyOtpResponse {
  bool? success;
  String? message;
  bool? isNewUser;
  String? token;
  UserModel? user;

  VerifyOtpResponse({this.success, this.message, this.isNewUser, this.token, this.user});

  VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    isNewUser = json['isNewUser'];
    token = json['token'];
    user = json['user'] != null ? UserModel.fromJson(json['user']) : null;
  }
}

class CompleteProfileResponse {
  bool? success;
  String? message;
  String? token;
  UserModel? user;

  CompleteProfileResponse({this.success, this.message, this.token, this.user});

  CompleteProfileResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    message = json['message'];
    token = json['token'];
    user = json['user'] != null ? UserModel.fromJson(json['user']) : null;
  }
}
