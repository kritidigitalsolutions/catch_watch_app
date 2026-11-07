import 'wallet_model.dart';

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

/// Parses a JSON list into [T] using [fromJson], validating that every entry is
/// a JSON object.
///
/// Returns `null` when [value] is not a list, so an absent/foreign optional
/// field stays absent rather than becoming a misleading empty list. A list that
/// carries a non-object entry throws a [FormatException] — the malformed
/// response surfaces as an error instead of silently collapsing to empty or
/// partial data.
List<T>? _parseObjectList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
  String field,
) {
  if (value is! List) return null;
  return value.map((dynamic item) {
    if (item is! Map) {
      throw FormatException(
        "Invalid '$field' entry in dashboard response (expected a JSON object)",
      );
    }
    return fromJson(Map<String, dynamic>.from(item));
  }).toList();
}

class CreatorDashboardData {
  final bool? success;
  final String? creatorLevel;
  final int? qualityScore;
  final int? totalPoints;
  final int? todayPoints;
  final int? weeklyPoints;
  final int? monthlyPoints;
  final int? qualifiedViews;
  final int? watchMinutes;
  final double? completionRate;
  final int? likes;
  final int? comments;
  final int? shares;
  final int? saves;
  final int? followers;
  final int? redeemablePoints;
  final bool? blueTick;
  final Map<String, DashboardTimeStats>? timeStats;
  final List<PointHistoryLog>? pointHistory;
  final List<TopReel>? topReels;

  CreatorDashboardData({
    this.success,
    this.creatorLevel,
    this.qualityScore,
    this.totalPoints,
    this.todayPoints,
    this.weeklyPoints,
    this.monthlyPoints,
    this.qualifiedViews,
    this.watchMinutes,
    this.completionRate,
    this.likes,
    this.comments,
    this.shares,
    this.saves,
    this.followers,
    this.redeemablePoints,
    this.blueTick,
    this.timeStats,
    this.pointHistory,
    this.topReels,
  });

  factory CreatorDashboardData.fromJson(Map<String, dynamic> json) {
    Map<String, DashboardTimeStats>? parsedTimeStats;
    if (json['timeStats'] is Map) {
      parsedTimeStats = {};
      (json['timeStats'] as Map).forEach((key, value) {
        if (value is Map) {
          parsedTimeStats![key.toString()] =
              DashboardTimeStats.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    return CreatorDashboardData(
      success: _asBool(json['success']),
      creatorLevel: json['creatorLevel']?.toString(),
      qualityScore: _asInt(json['qualityScore']),
      totalPoints: _asInt(json['totalPoints']),
      todayPoints: _asInt(json['todayPoints']),
      weeklyPoints: _asInt(json['weeklyPoints']),
      monthlyPoints: _asInt(json['monthlyPoints']),
      qualifiedViews: _asInt(json['qualifiedViews']),
      watchMinutes: _asInt(json['watchMinutes']),
      completionRate: _asDouble(json['completionRate']),
      likes: _asInt(json['likes']),
      comments: _asInt(json['comments']),
      shares: _asInt(json['shares']),
      saves: _asInt(json['saves']),
      followers: _asInt(json['followers']),
      redeemablePoints: _asInt(json['redeemablePoints']),
      blueTick: _asBool(json['blueTick']),
      timeStats: parsedTimeStats,
      pointHistory: _parseObjectList(json['pointHistory'], PointHistoryLog.fromJson, 'pointHistory'),
      topReels: _parseObjectList(json['topReels'], TopReel.fromJson, 'topReels'),
    );
  }
}

class DashboardTimeStats {
  final int likes;
  final int comments;
  final int views;
  final int saves;
  final int shares;

  DashboardTimeStats({
    required this.likes,
    required this.comments,
    required this.views,
    required this.saves,
    required this.shares,
  });

  factory DashboardTimeStats.fromJson(Map<String, dynamic> json) {
    return DashboardTimeStats(
      likes: _asInt(json['likes']) ?? 0,
      comments: _asInt(json['comments']) ?? 0,
      views: _asInt(json['views']) ?? 0,
      saves: _asInt(json['saves']) ?? 0,
      shares: _asInt(json['shares']) ?? 0,
    );
  }
}

class TopReel {
  final String? id;
  final String? caption;
  final String? thumbnailUrl;
  final int? viewsCount;
  final int? sharesCount;
  final int? likesCount;
  final int? savesCount;
  final int? commentsCount;
  final DateTime? createdAt;

  TopReel({
    this.id,
    this.caption,
    this.thumbnailUrl,
    this.viewsCount,
    this.sharesCount,
    this.likesCount,
    this.savesCount,
    this.commentsCount,
    this.createdAt,
  });

  factory TopReel.fromJson(Map<String, dynamic> json) {
    return TopReel(
      id: json['_id']?.toString(),
      caption: json['caption']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      viewsCount: _asInt(json['viewsCount']),
      sharesCount: _asInt(json['sharesCount']),
      likesCount: _asInt(json['likesCount']),
      savesCount: _asInt(json['savesCount']),
      commentsCount: _asInt(json['commentsCount']),
      createdAt: _asDate(json['createdAt']),
    );
  }
}
