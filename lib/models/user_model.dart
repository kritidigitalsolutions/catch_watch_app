import 'package:catch_watch/res/appUrl.dart';

class UserModel {
  String? id;
  String? phone;
  String? name;
  String? profileImage;
  String? bio;
  List<String>? genres;
  String? authProvider;
  bool? profileComplete;
  String? role;
  String? status;
  String? fcmToken;
  String? username;
  int? followersCount;
  int? followingCount;
  int? reelsCount;
  bool? isFollowing;
  bool? isVerified;
  bool? blueTick;
  String? createdAt;
  String? updatedAt;

  // Creator fields
  bool? isCreator;
  String? creatorStatus;
  String? creatorCategory;
  int? qualityScore;
  String? creatorLevel;
  int? totalEngagementPoints;
  int? totalQualifiedViews;
  int? totalWatchMinutes;
  int? totalCreatorFollowers;
  String? creatorJoinedAt;
  
  // Subscription & Verification
  bool? isPremium;
  String? verificationType;
  String? planId;

  UserModel({
    this.id,
    this.phone,
    this.name,
    this.profileImage,
    this.bio,
    this.genres,
    this.authProvider,
    this.profileComplete,
    this.role,
    this.status,
    this.fcmToken,
    this.username,
    this.followersCount,
    this.followingCount,
    this.reelsCount,
    this.isFollowing,
    this.isVerified,
    this.blueTick,
    this.createdAt,
    this.updatedAt,
    this.isCreator,
    this.creatorStatus,
    this.creatorCategory,
    this.qualityScore,
    this.creatorLevel,
    this.totalEngagementPoints,
    this.totalQualifiedViews,
    this.totalWatchMinutes,
    this.totalCreatorFollowers,
    this.creatorJoinedAt,
    this.isPremium,
    this.verificationType,
    this.planId,
  });

  UserModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? json['_id'];
    phone = json['phone'];
    name = json['name'];
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    profileImage = fixUrl(json['profileImage']);
    bio = json['bio'];
    genres = json['genres'] != null ? List<String>.from(json['genres']) : null;
    authProvider = json['authProvider'];
    profileComplete = json['profileComplete'];
    role = json['role'];
    status = json['status'];
    fcmToken = json['fcmToken'];
    username = json['username'];
    followersCount = parseInt(json['followersCount'] ?? json['followers']);
    followingCount = parseInt(json['followingCount'] ?? json['following']);
    reelsCount = parseInt(json['reelsCount'] ?? json['postsCount'] ?? json['totalReels']);
    isFollowing = json['isFollowing'] ?? false;
    isVerified = json['isVerified'] ?? json['verification']?['isVerified'] ?? false;
    blueTick = json['blueTick'] ?? (json['verification']?['badgeType'] == 'BLUE' && json['verification']?['isVerified'] == true) ?? false;
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];

    // Creator mapping
    isCreator = json['isCreator'] ?? false;
    creatorStatus = json['creatorStatus'];
    creatorCategory = json['creatorCategory'];
    qualityScore = parseInt(json['qualityScore']);
    creatorLevel = json['creatorLevel'];
    totalEngagementPoints = parseInt(json['totalEngagementPoints']);
    totalQualifiedViews = parseInt(json['totalQualifiedViews']);
    totalWatchMinutes = parseInt(json['totalWatchMinutes']);
    totalCreatorFollowers = parseInt(json['totalCreatorFollowers']);
    creatorJoinedAt = json['creatorJoinedAt'];

    // Other mapping
    isPremium = json['isPremium'] ?? false;
    verificationType = json['verificationType'];
    planId = json['planId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['phone'] = phone;
    data['name'] = name;
    data['profileImage'] = profileImage;
    data['bio'] = bio;
    data['genres'] = genres;
    data['authProvider'] = authProvider;
    data['profileComplete'] = profileComplete;
    data['role'] = role;
    data['status'] = status;
    data['fcmToken'] = fcmToken;
    data['username'] = username;
    data['followersCount'] = followersCount;
    data['followingCount'] = followingCount;
    data['reelsCount'] = reelsCount;
    data['isFollowing'] = isFollowing;
    data['isVerified'] = isVerified;
    data['blueTick'] = blueTick;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['isCreator'] = isCreator;
    data['creatorStatus'] = creatorStatus;
    data['creatorCategory'] = creatorCategory;
    data['qualityScore'] = qualityScore;
    data['creatorLevel'] = creatorLevel;
    data['totalEngagementPoints'] = totalEngagementPoints;
    data['totalQualifiedViews'] = totalQualifiedViews;
    data['totalWatchMinutes'] = totalWatchMinutes;
    data['totalCreatorFollowers'] = totalCreatorFollowers;
    data['creatorJoinedAt'] = creatorJoinedAt;
    data['isPremium'] = isPremium;
    data['verificationType'] = verificationType;
    data['planId'] = planId;
    return data;
  }
}
