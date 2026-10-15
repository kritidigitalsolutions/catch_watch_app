import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/res/appUrl.dart';

class ReelModel {
  String? id;
  ReelUser? user;
  String? videoUrl;
  String? thumbnail;
  String? caption;
  List<String>? hashtags;
  int? viewsCount;
  int? commentsCount;
  int? sharesCount;
  int? likesCount;
  String? userInteraction; // 'LIKE', 'DISLIKE' or null
  bool? isBookmarked;
  String? status;
  String? createdAt;

  // Ad fields
  bool? isAd;
  String? adId;
  String? campaignId;
  String? advertiserId;
  String? adType;
  String? ctaText;
  String? destinationUrl;
  int? durationSeconds;

  ReelModel({
    this.id,
    this.user,
    this.videoUrl,
    this.thumbnail,
    this.caption,
    this.hashtags,
    this.viewsCount,
    this.commentsCount,
    this.sharesCount,
    this.likesCount,
    this.userInteraction,
    this.isBookmarked,
    this.status,
    this.createdAt,
    this.isAd,
    this.adId,
    this.campaignId,
    this.advertiserId,
    this.adType,
    this.ctaText,
    this.destinationUrl,
    this.durationSeconds,
  });

  factory ReelModel.fromContent(Content content) {
    return ReelModel(
      id: content.id,
      videoUrl: content.videoUrl,
      thumbnail: content.poster,
      caption: content.title,
      likesCount: content.likes?.length ?? 0,
      isBookmarked: false, // content doesn't have this field directly
      status: 'published',
    );
  }

  ReelModel.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    if (json['user'] != null) {
      if (json['user'] is Map) {
        user = ReelUser.fromJson(Map<String, dynamic>.from(json['user']));
      } else if (json['user'] is String) {
        user = ReelUser(id: json['user']);
      }
    }
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? 0);
      return 0;
    }

    videoUrl = fixUrl(json['videoUrl'] ?? json['mediaUrl'] ?? json['video'] ?? json['url']);
    thumbnail = fixUrl(json['thumbnail'] ?? json['thumbnailUrl'] ?? json['poster']);
    caption = json['caption'] ?? json['title'] ?? json['description'];
    if (json['hashtags'] != null) {
      if (json['hashtags'] is List) {
        hashtags = (json['hashtags'] as List)
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      } else if (json['hashtags'] is String) {
        hashtags = (json['hashtags'] as String)
            .split(RegExp(r'\s+'))
            .where((h) => h.trim().isNotEmpty)
            .toList();
      } else {
        hashtags = [];
      }
    } else {
      hashtags = [];
    }
    viewsCount = parseInt(json['viewsCount']);
    commentsCount = parseInt(json['commentsCount']);
    sharesCount = parseInt(json['sharesCount']);
    likesCount = parseInt(json['likesCount']);
    userInteraction = json['userInteraction'];
    isBookmarked = json['isBookmarked'] == true || json['isBookmarked']?.toString().toLowerCase() == 'true';
    status = json['status'];
    createdAt = json['createdAt'];

    // Ad mapping
    isAd = json['isAd'] == true || json['isAd']?.toString().toLowerCase() == 'true';
    adId = json['adId'];
    campaignId = json['campaignId'];
    advertiserId = json['advertiserId'];
    adType = json['adType'];
    ctaText = json['ctaText'];
    destinationUrl = json['destinationUrl'];
    durationSeconds = parseInt(json['durationSeconds']);
    
    // If it's an ad and we have an adId, ensure id is set to adId for consistency
    if (isAd == true && adId != null) {
      id = adId;
    }
  }
}

class ReelUser {
  String? id;
  String? name;
  String? profileImage;
  String? username;
  bool? isFollowing;
  bool? isVerified;
  bool? blueTick;
  bool? orangeTick;

  ReelUser({this.id, this.name, this.profileImage, this.username, this.isFollowing, this.isVerified, this.blueTick, this.orangeTick});

  ReelUser.fromJson(Map<dynamic, dynamic> json) {
    id = json['_id'] ?? json['id'];
    name = json['name'];
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }
    
    profileImage = fixUrl(json['profileImage'] ?? json['image']);
    username = json['username'];
    isFollowing = json['isFollowing'] == true || json['isFollowing']?.toString().toLowerCase() == 'true';
    final dynamic ver = json['verification'];
    final bool verIsVerified = ver is Map
        ? (ver['isVerified'] == true || ver['isVerified']?.toString().toLowerCase() == 'true')
        : false;
    final String? verBadge = ver is Map ? ver['badgeType']?.toString().toUpperCase() : null;

    final bool rawOrange = json['orangeTick'] == true || json['orangeTick']?.toString().toLowerCase() == 'true';
    final bool rawBlue = json['blueTick'] == true || json['blueTick']?.toString().toLowerCase() == 'true';

    orangeTick = rawOrange || (verBadge == 'ORANGE' && verIsVerified);
    blueTick = rawBlue || (verBadge == 'BLUE' && verIsVerified);
    isVerified = verIsVerified || (blueTick == true) || (orangeTick == true);
  }

  /// Returns whether the creator has a verified tick (Orange Tick / Blue Tick)
  bool get hasVerifiedTick => (blueTick == true) || (orangeTick == true);
}
