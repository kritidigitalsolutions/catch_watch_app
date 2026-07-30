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
  String? createdAt;
  String? updatedAt;

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
    this.createdAt,
    this.updatedAt,
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
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
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
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }
}
