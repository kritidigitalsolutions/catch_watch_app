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
    this.createdAt,
    this.updatedAt,
  });

  UserModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? json['_id'];
    phone = json['phone'];
    name = json['name'];
    profileImage = json['profileImage'];
    bio = json['bio'];
    genres = json['genres'] != null ? List<String>.from(json['genres']) : null;
    authProvider = json['authProvider'];
    profileComplete = json['profileComplete'];
    role = json['role'];
    status = json['status'];
    fcmToken = json['fcmToken'];
    username = json['username'];
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
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }
}
