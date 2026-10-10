import 'plan_model.dart';

class VerificationStatusResponse {
  bool? success;
  String? status;
  String? message;
  bool? isVerified;
  String? badgeType;
  VerificationApplication? application;

  VerificationStatusResponse({
    this.success,
    this.status,
    this.message,
    this.isVerified,
    this.badgeType,
    this.application,
  });

  VerificationStatusResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'] ??
        (json['status'] != null ||
            json['isVerified'] != null ||
            json['application'] != null ||
            json['data'] != null ||
            json['verification'] != null);

    final dynamic dataObj = json['data'] ?? json['verification'] ?? json['application'];

    status = (json['status'] ??
            (dataObj is Map ? dataObj['status'] : null) ??
            json['verificationStatus'])
        ?.toString();

    final rawIsVerified = json['isVerified'] ?? (dataObj is Map ? dataObj['isVerified'] : null);
    if (rawIsVerified is bool) {
      isVerified = rawIsVerified;
    } else if (rawIsVerified != null) {
      isVerified = rawIsVerified.toString().toLowerCase() == 'true';
    }

    badgeType = (json['badgeType'] ?? (dataObj is Map ? dataObj['badgeType'] : null))?.toString();
    message = json['message']?.toString();

    final appMap = _extractApplicationMap(json);
    if (appMap != null) {
      application = VerificationApplication.fromJson(appMap);
      if (status == null || status!.isEmpty) {
        status = application?.status;
      }
    } else {
      application = null;
    }
  }

  static Map<String, dynamic>? _extractApplicationMap(Map<String, dynamic> json) {
    // 1. Direct 'application' map
    if (json['application'] is Map<String, dynamic>) {
      final appMap = json['application'] as Map<String, dynamic>;
      if (appMap['application'] is Map<String, dynamic>) {
        return appMap['application'] as Map<String, dynamic>;
      }
      return appMap;
    }

    // 2. Under 'data'
    if (json['data'] is Map<String, dynamic>) {
      final dataMap = json['data'] as Map<String, dynamic>;
      if (dataMap['application'] is Map<String, dynamic>) {
        return dataMap['application'] as Map<String, dynamic>;
      }
      if (dataMap['verification'] is Map<String, dynamic>) {
        final verMap = dataMap['verification'] as Map<String, dynamic>;
        if (verMap['application'] is Map<String, dynamic>) {
          return verMap['application'] as Map<String, dynamic>;
        }
        return verMap;
      }
      if (_hasApplicationFields(dataMap)) {
        return dataMap;
      }
    }

    // 3. Under 'verification'
    if (json['verification'] is Map<String, dynamic>) {
      final verMap = json['verification'] as Map<String, dynamic>;
      if (verMap['application'] is Map<String, dynamic>) {
        return verMap['application'] as Map<String, dynamic>;
      }
      return verMap;
    }

    // 4. Root JSON itself has application fields
    if (_hasApplicationFields(json)) {
      return json;
    }

    return null;
  }

  static bool _hasApplicationFields(Map<String, dynamic> map) {
    return map.containsKey('fullName') ||
        map.containsKey('governmentIdType') ||
        map.containsKey('governmentIdNumber') ||
        map.containsKey('idFront') ||
        map.containsKey('idType') ||
        map.containsKey('planId') ||
        map.containsKey('appliedAt') ||
        (map.containsKey('_id') && (map.containsKey('reason') || map.containsKey('plan')));
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
  String? planId;
  bool? isPaid;
  String? paymentId;
  String? orderId;
  String? transactionId;
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
    this.planId,
    this.isPaid,
    this.paymentId,
    this.orderId,
    this.transactionId,
    this.createdAt,
    this.updatedAt,
  });

  VerificationApplication.fromJson(Map<String, dynamic> json) {
    id = (json['_id'] ?? json['id'])?.toString();

    // User parsing
    if (json['user'] is Map<String, dynamic>) {
      final uMap = json['user'] as Map<String, dynamic>;
      user = (uMap['_id'] ?? uMap['id'])?.toString();
      fullName = json['fullName']?.toString() ??
          json['name']?.toString() ??
          json['applicantName']?.toString() ??
          uMap['name']?.toString() ??
          uMap['fullName']?.toString();
      username = json['username']?.toString() ?? uMap['username']?.toString();
    } else {
      user = json['user']?.toString();
      fullName = json['fullName']?.toString() ??
          json['name']?.toString() ??
          json['applicantName']?.toString();
      username = json['username']?.toString();
    }

    governmentIdType = json['governmentIdType']?.toString() ??
        json['idType']?.toString() ??
        json['documentType']?.toString();
    governmentIdNumber = json['governmentIdNumber']?.toString() ??
        json['idNumber']?.toString() ??
        json['documentNumber']?.toString();
    idFront = json['idFront']?.toString();
    idBack = json['idBack']?.toString();
    selfie = json['selfie']?.toString();
    website = json['website']?.toString();
    instagram = json['instagram']?.toString();
    facebook = json['facebook']?.toString();
    youtube = json['youtube']?.toString();
    twitter = json['twitter']?.toString();
    linkedin = json['linkedin']?.toString();
    reason = json['reason']?.toString();
    status = json['status']?.toString() ?? json['verificationStatus']?.toString();

    // Plan parsing
    if (json['planId'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['planId']);
      planId = plan?.id;
    } else if (json['plan'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['plan']);
      planId = plan?.id;
    } else if (json['planId'] != null || json['plan'] != null) {
      final pId = (json['planId'] ?? json['plan']).toString();
      planId = pId;
      plan = Plan(
        id: pId,
        name: json['planName']?.toString(),
      );
    }

    if (json['isPaid'] is bool) {
      isPaid = json['isPaid'] as bool;
    } else if (json['isPaid'] != null) {
      isPaid = json['isPaid'].toString().toLowerCase() == 'true';
    }

    paymentId = json['paymentId']?.toString();
    orderId = json['orderId']?.toString();
    transactionId = json['transactionId']?.toString();
    createdAt = json['createdAt']?.toString() ??
        json['appliedAt']?.toString() ??
        json['created_at']?.toString() ??
        json['date']?.toString() ??
        json['timestamp']?.toString();
    updatedAt = json['updatedAt']?.toString() ?? json['updated_at']?.toString();
  }

  VerificationApplication copyWith({
    String? id,
    String? user,
    String? fullName,
    String? username,
    String? governmentIdType,
    String? governmentIdNumber,
    String? idFront,
    String? idBack,
    String? selfie,
    String? website,
    String? instagram,
    String? facebook,
    String? youtube,
    String? twitter,
    String? linkedin,
    String? reason,
    String? status,
    Plan? plan,
    String? planId,
    bool? isPaid,
    String? paymentId,
    String? orderId,
    String? transactionId,
    String? createdAt,
    String? updatedAt,
  }) {
    return VerificationApplication(
      id: id ?? this.id,
      user: user ?? this.user,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      governmentIdType: governmentIdType ?? this.governmentIdType,
      governmentIdNumber: governmentIdNumber ?? this.governmentIdNumber,
      idFront: idFront ?? this.idFront,
      idBack: idBack ?? this.idBack,
      selfie: selfie ?? this.selfie,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      youtube: youtube ?? this.youtube,
      twitter: twitter ?? this.twitter,
      linkedin: linkedin ?? this.linkedin,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      plan: plan ?? this.plan,
      planId: planId ?? this.planId,
      isPaid: isPaid ?? this.isPaid,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  VerificationApplication mergeWith(VerificationApplication other) {
    Plan? mergedPlan;
    if (other.plan != null && this.plan != null) {
      mergedPlan = Plan(
        id: (other.plan!.id != null && other.plan!.id!.isNotEmpty) ? other.plan!.id : this.plan!.id,
        name: (other.plan!.name != null && other.plan!.name!.isNotEmpty) ? other.plan!.name : this.plan!.name,
        price: other.plan!.price ?? this.plan!.price,
        duration: other.plan!.duration ?? this.plan!.duration,
        category: other.plan!.category ?? this.plan!.category,
        appleProductId: other.plan!.appleProductId ?? this.plan!.appleProductId,
      );
    } else {
      mergedPlan = other.plan ?? this.plan;
    }

    return VerificationApplication(
      id: (other.id != null && other.id!.isNotEmpty) ? other.id : this.id,
      user: (other.user != null && other.user!.isNotEmpty) ? other.user : this.user,
      fullName: (other.fullName != null && other.fullName!.isNotEmpty) ? other.fullName : this.fullName,
      username: (other.username != null && other.username!.isNotEmpty) ? other.username : this.username,
      governmentIdType: (other.governmentIdType != null && other.governmentIdType!.isNotEmpty)
          ? other.governmentIdType
          : this.governmentIdType,
      governmentIdNumber: (other.governmentIdNumber != null && other.governmentIdNumber!.isNotEmpty)
          ? other.governmentIdNumber
          : this.governmentIdNumber,
      idFront: (other.idFront != null && other.idFront!.isNotEmpty) ? other.idFront : this.idFront,
      idBack: (other.idBack != null && other.idBack!.isNotEmpty) ? other.idBack : this.idBack,
      selfie: (other.selfie != null && other.selfie!.isNotEmpty) ? other.selfie : this.selfie,
      website: (other.website != null && other.website!.isNotEmpty) ? other.website : this.website,
      instagram: (other.instagram != null && other.instagram!.isNotEmpty) ? other.instagram : this.instagram,
      facebook: (other.facebook != null && other.facebook!.isNotEmpty) ? other.facebook : this.facebook,
      youtube: (other.youtube != null && other.youtube!.isNotEmpty) ? other.youtube : this.youtube,
      twitter: (other.twitter != null && other.twitter!.isNotEmpty) ? other.twitter : this.twitter,
      linkedin: (other.linkedin != null && other.linkedin!.isNotEmpty) ? other.linkedin : this.linkedin,
      reason: (other.reason != null && other.reason!.isNotEmpty) ? other.reason : this.reason,
      status: (other.status != null && other.status!.isNotEmpty) ? other.status : this.status,
      plan: mergedPlan,
      planId: (other.planId != null && other.planId!.isNotEmpty) ? other.planId : this.planId,
      isPaid: other.isPaid ?? this.isPaid,
      paymentId: (other.paymentId != null && other.paymentId!.isNotEmpty) ? other.paymentId : this.paymentId,
      orderId: (other.orderId != null && other.orderId!.isNotEmpty) ? other.orderId : this.orderId,
      transactionId: (other.transactionId != null && other.transactionId!.isNotEmpty) ? other.transactionId : this.transactionId,
      createdAt: (other.createdAt != null && other.createdAt!.isNotEmpty) ? other.createdAt : this.createdAt,
      updatedAt: (other.updatedAt != null && other.updatedAt!.isNotEmpty) ? other.updatedAt : this.updatedAt,
    );
  }
}
