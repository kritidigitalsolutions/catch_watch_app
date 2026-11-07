int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

class WalletSummary {
  final bool? success;
  final int? totalPoints;
  final int? redeemedPoints;
  final int? availablePoints;

  WalletSummary({
    this.success,
    this.totalPoints,
    this.redeemedPoints,
    this.availablePoints,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      success: _asBool(json['success']),
      totalPoints: _asInt(json['totalPoints']),
      redeemedPoints: _asInt(json['redeemedPoints']),
      availablePoints: _asInt(json['availablePoints']),
    );
  }
}

class PointsSummary {
  final bool? success;
  final int? todayPoints;
  final int? weeklyPoints;
  final int? monthlyPoints;
  final int? totalPoints;

  PointsSummary({
    this.success,
    this.todayPoints,
    this.weeklyPoints,
    this.monthlyPoints,
    this.totalPoints,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    return PointsSummary(
      success: _asBool(json['success']),
      todayPoints: _asInt(json['todayPoints']),
      weeklyPoints: _asInt(json['weeklyPoints']),
      monthlyPoints: _asInt(json['monthlyPoints']),
      totalPoints: _asInt(json['totalPoints']),
    );
  }
}

class PointHistoryLog {
  final String? id;
  final String? action;
  final int? points;
  final DateTime? createdAt;
  final HistoryUser? user;
  final HistoryReel? reel;

  PointHistoryLog({this.id, this.action, this.points, this.createdAt, this.user, this.reel});

  factory PointHistoryLog.fromJson(Map<String, dynamic> json) {
    return PointHistoryLog(
      id: json['_id']?.toString(),
      action: json['action']?.toString(),
      points: _asInt(json['points']),
      createdAt: _asDate(json['createdAt']),
      user: json['user'] is Map ? HistoryUser.fromJson(json['user']) : null,
      reel: json['reel'] is Map ? HistoryReel.fromJson(json['reel']) : null,
    );
  }
}

class HistoryUser {
  final String? id;
  final String? name;
  final String? profileImage;
  final String? username;

  HistoryUser({this.id, this.name, this.profileImage, this.username});

  factory HistoryUser.fromJson(Map<String, dynamic> json) {
    return HistoryUser(
      id: json['_id']?.toString(),
      name: json['name']?.toString(),
      profileImage: json['profileImage']?.toString(),
      username: json['username']?.toString(),
    );
  }
}

class HistoryReel {
  final String? id;
  final String? thumbnailUrl;
  final String? thumbnail;
  final String? caption;
  final int? viewsCount;
  final int? commentsCount;
  final int? sharesCount;

  HistoryReel({this.id, this.thumbnailUrl, this.thumbnail, this.caption, this.viewsCount, this.commentsCount, this.sharesCount});

  factory HistoryReel.fromJson(Map<String, dynamic> json) {
    return HistoryReel(
      id: json['_id']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      caption: json['caption']?.toString(),
      viewsCount: _asInt(json['viewsCount']),
      commentsCount: _asInt(json['commentsCount']),
      sharesCount: _asInt(json['sharesCount']),
    );
  }
}

class RedeemHistory {
  final String? id;
  final int? points;
  final double? amount;
  final String? status;
  final DateTime? createdAt;
  final PaymentDetails? paymentDetails;
  final String? rejectionReason;
  final String? transactionId;
  final String? adminRemark;

  RedeemHistory({
    this.id,
    this.points,
    this.amount,
    this.status,
    this.createdAt,
    this.paymentDetails,
    this.rejectionReason,
    this.transactionId,
    this.adminRemark,
  });

  factory RedeemHistory.fromJson(Map<String, dynamic> json) {
    return RedeemHistory(
      id: json['_id']?.toString(),
      points: _asInt(json['points']),
      amount: _asDouble(json['amount']) ?? 0,
      status: json['status']?.toString(),
      createdAt: _asDate(json['createdAt']),
      paymentDetails: json['paymentDetails'] is Map
          ? PaymentDetails.fromJson(json['paymentDetails'])
          : null,
      rejectionReason: json['rejectionReason']?.toString(),
      transactionId: json['transactionId']?.toString(),
      adminRemark: json['adminRemark']?.toString(),
    );
  }
}

class PaymentDetails {
  final String? paymentMethod;
  final String? upiId;
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;

  PaymentDetails({
    this.paymentMethod,
    this.upiId,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      paymentMethod: json['paymentMethod']?.toString(),
      upiId: json['upiId']?.toString(),
      accountHolderName: json['accountHolderName']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      ifscCode: json['ifscCode']?.toString(),
      bankName: json['bankName']?.toString(),
    );
  }
}
