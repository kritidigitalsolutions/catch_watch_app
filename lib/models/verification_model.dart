import 'plan_model.dart';

class VerificationStatusResponse {
  bool? success;
  VerificationApplication? application;

  VerificationStatusResponse({this.success, this.application});

  VerificationStatusResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    application = json['application'] != null
        ? VerificationApplication.fromJson(json['application'])
        : null;
  }
}

class VerificationApplication {
  String? id;
  String? user;
  String? fullName;
  String? username;
  String? governmentIdType;
  String? governmentIdNumber;
  String? idFront;
  String? idBack;
  String? selfie;
  String? website;
  String? instagram;
  String? facebook;
  String? youtube;
  String? twitter;
  String? linkedin;
  String? reason;
  String? status;
  Plan? plan;
  bool? isPaid;
  String? createdAt;
  String? updatedAt;

  VerificationApplication({
    this.id,
    this.user,
    this.fullName,
    this.username,
    this.governmentIdType,
    this.governmentIdNumber,
    this.idFront,
    this.idBack,
    this.selfie,
    this.website,
    this.instagram,
    this.facebook,
    this.youtube,
    this.twitter,
    this.linkedin,
    this.reason,
    this.status,
    this.plan,
    this.isPaid,
    this.createdAt,
    this.updatedAt,
  });

  VerificationApplication.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    fullName = json['fullName'];
    username = json['username'];
    governmentIdType = json['governmentIdType'];
    governmentIdNumber = json['governmentIdNumber'];
    idFront = json['idFront'];
    idBack = json['idBack'];
    selfie = json['selfie'];
    website = json['website'];
    instagram = json['instagram'];
    facebook = json['facebook'];
    youtube = json['youtube'];
    twitter = json['twitter'];
    linkedin = json['linkedin'];
    reason = json['reason'];
    status = json['status'];
    if (json['planId'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['planId']);
    } else if (json['plan'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['plan']);
    }
    isPaid = json['isPaid'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }
}
