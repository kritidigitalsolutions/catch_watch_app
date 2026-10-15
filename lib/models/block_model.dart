import 'package:catch_watch/res/appUrl.dart';

class BlockedUser {
  final String id;
  final String? name;
  final String? username;
  final String? profileImage;

  BlockedUser({
    required this.id,
    this.name,
    this.username,
    this.profileImage,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    String fixUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) {
        return url.replaceAll('http://localhost:5000', AppUrl.serverUrl);
      }
      return '${AppUrl.serverUrl}/$url';
    }

    final rawId = json['_id'] ?? json['id'] ?? json['userId'];
    return BlockedUser(
      id: rawId?.toString() ?? '',
      name: json['name']?.toString(),
      username: json['username']?.toString(),
      profileImage: fixUrl(json['profileImage']?.toString() ?? json['image']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'username': username,
      'profileImage': profileImage,
    };
  }
}

class BlockResponse {
  final bool success;
  final String message;
  final bool? isBlocked;

  BlockResponse({
    required this.success,
    required this.message,
    this.isBlocked,
  });

  factory BlockResponse.fromJson(Map<String, dynamic> json) {
    return BlockResponse(
      success: json['success'] == true ||
          json['success']?.toString().toLowerCase() == 'true' ||
          json['status'] == 'success' ||
          json['status'] == 200 ||
          json['statusCode'] == 200,
      message: json['message']?.toString() ??
          (json['error']?.toString() ?? 'Operation completed successfully'),
      isBlocked: json['isBlocked'] is bool
          ? json['isBlocked'] as bool
          : (json['isBlocked'] != null
              ? json['isBlocked'].toString().toLowerCase() == 'true'
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'isBlocked': isBlocked,
    };
  }
}

class BlockedUsersResponse {
  final bool success;
  final int count;
  final List<BlockedUser> blockedUsers;
  final String? message;

  BlockedUsersResponse({
    required this.success,
    required this.count,
    required this.blockedUsers,
    this.message,
  });

  factory BlockedUsersResponse.fromJson(Map<String, dynamic> json) {
    final bool isSuccess = json['success'] == true ||
        json['success']?.toString().toLowerCase() == 'true' ||
        json['status'] == 'success' ||
        json['status'] == 200 ||
        json['statusCode'] == 200;

    dynamic rawList = json['blockedUsers'] ?? json['data'] ?? json['users'];
    final List<BlockedUser> list = [];

    if (rawList is List) {
      for (var item in rawList) {
        if (item is Map) {
          try {
            final user = BlockedUser.fromJson(Map<String, dynamic>.from(item));
            if (user.id.isNotEmpty) {
              list.add(user);
            }
          } catch (_) {}
        }
      }
    }

    final int count = json['count'] is int
        ? json['count'] as int
        : (int.tryParse(json['count']?.toString() ?? '') ?? list.length);

    return BlockedUsersResponse(
      success: isSuccess,
      count: count,
      blockedUsers: list,
      message: json['message']?.toString() ?? json['error']?.toString(),
    );
  }
}

class BlockStatusResponse {
  final bool success;
  final bool isBlocked;
  final bool isBlockedBy;
  final String? message;

  BlockStatusResponse({
    required this.success,
    required this.isBlocked,
    required this.isBlockedBy,
    this.message,
  });

  factory BlockStatusResponse.fromJson(Map<String, dynamic> json) {
    return BlockStatusResponse(
      success: json['success'] == true ||
          json['success']?.toString().toLowerCase() == 'true' ||
          json['status'] == 'success' ||
          json['status'] == 200 ||
          json['statusCode'] == 200,
      isBlocked: json['isBlocked'] == true ||
          json['isBlocked']?.toString().toLowerCase() == 'true',
      isBlockedBy: json['isBlockedBy'] == true ||
          json['isBlockedBy']?.toString().toLowerCase() == 'true',
      message: json['message']?.toString(),
    );
  }
}
