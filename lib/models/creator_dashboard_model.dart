import 'wallet_model.dart';

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
    if (json['timeStats'] != null) {
      parsedTimeStats = {};
      (json['timeStats'] as Map<String, dynamic>).forEach((key, value) {
        parsedTimeStats![key] = DashboardTimeStats.fromJson(value);
      });
    }

    return CreatorDashboardData(
      success: json['success'],
      creatorLevel: json['creatorLevel'],
      qualityScore: json['qualityScore'],
      totalPoints: json['totalPoints'],
      todayPoints: json['todayPoints'],
      weeklyPoints: json['weeklyPoints'],
      monthlyPoints: json['monthlyPoints'],
      qualifiedViews: json['qualifiedViews'],
      watchMinutes: json['watchMinutes'],
      completionRate: (json['completionRate'] ?? 0).toDouble(),
      likes: json['likes'],
      comments: json['comments'],
      shares: json['shares'],
      saves: json['saves'],
      followers: json['followers'],
      redeemablePoints: json['redeemablePoints'],
      blueTick: json['blueTick'],
      timeStats: parsedTimeStats,
      pointHistory: json['pointHistory'] != null 
          ? (json['pointHistory'] as List).map((i) => PointHistoryLog.fromJson(i)).toList() 
          : null,
      topReels: json['topReels'] != null 
          ? (json['topReels'] as List).map((i) => TopReel.fromJson(i)).toList() 
          : null,
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
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      views: json['views'] ?? 0,
      saves: json['saves'] ?? 0,
      shares: json['shares'] ?? 0,
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
      id: json['_id'],
      caption: json['caption'],
      thumbnailUrl: json['thumbnailUrl'],
      viewsCount: json['viewsCount'],
      sharesCount: json['sharesCount'],
      likesCount: json['likesCount'],
      savesCount: json['savesCount'],
      commentsCount: json['commentsCount'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}
