enum ReportReason {
  spam('Spam', 'SPAM'),
  inappropriateContent('Inappropriate Content', 'INAPPROPRIATE_CONTENT'),
  harassment('Harassment', 'HARASSMENT'),
  hateSpeech('Hate Speech', 'HATE_SPEECH'),
  nudityOrSexual('Nudity or Sexual Content', 'NUDITY_OR_SEXUAL'),
  violence('Violence', 'VIOLENCE'),
  copyrightViolation('Copyright Violation', 'COPYRIGHT_VIOLATION'),
  scamOrFraud('Scam or Fraud', 'SCAM_OR_FRAUD'),
  other('Other', 'OTHER');

  final String label;
  final String apiValue;

  const ReportReason(this.label, this.apiValue);

  static ReportReason fromApiValue(String? value) {
    if (value == null) return ReportReason.other;
    return ReportReason.values.firstWhere(
      (r) => r.apiValue == value,
      orElse: () => ReportReason.other,
    );
  }
}

class ReportResponse {
  final bool success;
  final String message;
  final ReportData? report;

  ReportResponse({
    required this.success,
    required this.message,
    this.report,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ??
          'Report submitted successfully. Thank you for helping keep CatchWatch safe. Our moderation team will review this within 24 hours.',
      report: json['report'] is Map<String, dynamic>
          ? ReportData.fromJson(json['report'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'report': report?.toJson(),
    };
  }
}

class ReportData {
  final String? id;
  final String? reporter;
  final String? targetType;
  final String? targetId;
  final String? reportedUser;
  final String? reason;
  final String? description;
  final String? status;
  final String? actionTaken;

  ReportData({
    this.id,
    this.reporter,
    this.targetType,
    this.targetId,
    this.reportedUser,
    this.reason,
    this.description,
    this.status,
    this.actionTaken,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      reporter: json['reporter']?.toString(),
      targetType: json['targetType']?.toString(),
      targetId: json['targetId']?.toString(),
      reportedUser: json['reportedUser']?.toString(),
      reason: json['reason']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString(),
      actionTaken: json['actionTaken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'reporter': reporter,
      'targetType': targetType,
      'targetId': targetId,
      'reportedUser': reportedUser,
      'reason': reason,
      'description': description,
      'status': status,
      'actionTaken': actionTaken,
    };
  }
}
