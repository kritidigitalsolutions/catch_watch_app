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
      success: json['success'],
      totalPoints: json['totalPoints'],
      redeemedPoints: json['redeemedPoints'],
      availablePoints: json['availablePoints'],
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
      success: json['success'],
      todayPoints: json['todayPoints'],
      weeklyPoints: json['weeklyPoints'],
      monthlyPoints: json['monthlyPoints'],
      totalPoints: json['totalPoints'],
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
      id: json['_id'],
      action: json['action'],
      points: json['points'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      user: json['user'] != null ? HistoryUser.fromJson(json['user']) : null,
      reel: json['reel'] != null ? HistoryReel.fromJson(json['reel']) : null,
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
      id: json['_id'],
      name: json['name'],
      profileImage: json['profileImage'],
      username: json['username'],
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
      id: json['_id'],
      thumbnailUrl: json['thumbnailUrl'],
      thumbnail: json['thumbnail'],
      caption: json['caption'],
      viewsCount: json['viewsCount'],
      commentsCount: json['commentsCount'],
      sharesCount: json['sharesCount'],
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
      id: json['_id'],
      points: json['points'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      paymentDetails: json['paymentDetails'] != null ? PaymentDetails.fromJson(json['paymentDetails']) : null,
      rejectionReason: json['rejectionReason'],
      transactionId: json['transactionId'],
      adminRemark: json['adminRemark'],
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
      paymentMethod: json['paymentMethod'],
      upiId: json['upiId'],
      accountHolderName: json['accountHolderName'],
      accountNumber: json['accountNumber'],
      ifscCode: json['ifscCode'],
      bankName: json['bankName'],
    );
  }
}
