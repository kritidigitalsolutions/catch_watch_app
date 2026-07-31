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
    id = json['_id'];
    if (json['user'] != null) {
      if (json['user'] is Map<String, dynamic>) {
        user = ReelUser.fromJson(json['user']);
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
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    videoUrl = fixUrl(json['videoUrl']);
    thumbnail = fixUrl(json['thumbnail'] ?? json['thumbnailUrl']);
    caption = json['caption'];
    hashtags = json['hashtags'] != null ? List<String>.from(json['hashtags']) : [];
    viewsCount = parseInt(json['viewsCount']);
    commentsCount = parseInt(json['commentsCount']);
    sharesCount = parseInt(json['sharesCount']);
    likesCount = parseInt(json['likesCount']);
    userInteraction = json['userInteraction'];
    isBookmarked = json['isBookmarked'] ?? false;
    status = json['status'];
    createdAt = json['createdAt'];
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

  ReelUser({this.id, this.name, this.profileImage, this.username, this.isFollowing, this.isVerified, this.blueTick});

  ReelUser.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    name = json['name'];
    
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }
    
    profileImage = fixUrl(json['profileImage']);
    username = json['username'];
    isFollowing = json['isFollowing'] ?? false;
    isVerified = json['isVerified'] ?? json['verification']?['isVerified'] ?? false;
    blueTick = json['blueTick'] ?? (json['verification']?['badgeType'] == 'BLUE' && json['verification']?['isVerified'] == true) ?? false;
  }
}
