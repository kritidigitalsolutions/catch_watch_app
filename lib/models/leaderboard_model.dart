class LeaderboardResponse {
  final bool? success;
  final String? timeframe;
  final int? totalCount;
  final List<LeaderboardUser>? leaderboard;
  final int? currentUserRank;

  LeaderboardResponse({
    this.success,
    this.timeframe,
    this.totalCount,
    this.leaderboard,
    this.currentUserRank,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      if (value is Map) {
        // If it's a map, try to find a rank or total field
        return parseInt(value['rank'] ?? value['total'] ?? value['value']);
      }
      return null;
    }

    var leaderboardList = <LeaderboardUser>[];
    if (json['leaderboard'] != null && json['leaderboard'] is List) {
      leaderboardList = (json['leaderboard'] as List)
          .map((i) => LeaderboardUser.fromJson(i))
          .toList();
    }

    return LeaderboardResponse(
      success: json['success'] ?? false,
      timeframe: json['timeframe'],
      totalCount: parseInt(json['totalCount']),
      leaderboard: leaderboardList,
      currentUserRank: parseInt(json['currentUserRank']),
    );
  }
}

class LeaderboardUser {
  final int? rank;
  final String? id;
  final String? name;
  final String? username;
  final String? profileImage;
  final bool? blueTick;
  final int? qualityScore;
  final String? creatorLevel;
  final int? totalPoints;
  final int? periodPoints;
  final int? qualifiedViews;
  final int? watchMinutes;
  final int? reelsCount;
  final int? followersCount;
  final List<String>? badges;

  LeaderboardUser({
    this.rank,
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.blueTick,
    this.qualityScore,
    this.creatorLevel,
    this.totalPoints,
    this.periodPoints,
    this.qualifiedViews,
    this.watchMinutes,
    this.reelsCount,
    this.followersCount,
    this.badges,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is Map) {
         return parseInt(value['rank'] ?? value['total'] ?? value['value'] ?? value['count']);
      }
      return 0;
    }

    return LeaderboardUser(
      rank: parseInt(json['rank']),
      id: json['_id'],
      name: json['name'],
      username: json['username'],
      profileImage: json['profileImage'],
      blueTick: json['blueTick'] ?? false,
      qualityScore: parseInt(json['qualityScore']),
      creatorLevel: json['creatorLevel'],
      totalPoints: parseInt(json['totalPoints']),
      periodPoints: parseInt(json['periodPoints']),
      qualifiedViews: parseInt(json['qualifiedViews']),
      watchMinutes: parseInt(json['watchMinutes']),
      reelsCount: parseInt(json['reelsCount']),
      followersCount: parseInt(json['followersCount']),
      badges: json['badges'] != null ? List<String>.from(json['badges']) : [],
    );
  }
}
