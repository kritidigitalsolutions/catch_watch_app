import 'package:flutter/material.dart';
import '../views/after_login_pages/profile_page/profile_screen.dart';
import '../views/after_login_pages/profile_page/user_profile_screen.dart';
import 'hive_service/hive_service.dart';

bool isSelfUser({String? userId, String? username, String? name}) {
  final currentUserId = HiveService.userId ?? HiveService.getUser()?.sId;
  final currentUser = HiveService.getUser();

  if (currentUserId != null && currentUserId.isNotEmpty) {
    if (userId != null && userId.isNotEmpty && userId.trim().toLowerCase() == currentUserId.trim().toLowerCase()) {
      return true;
    }
    if (username != null && username.isNotEmpty) {
      final cleanUsername = username.trim().replaceAll('@', '').toLowerCase();
      final cleanUserId = currentUserId.trim().toLowerCase();
      if (cleanUsername == cleanUserId) return true;
    }
  }

  if (currentUser != null) {
    final cName = currentUser.name?.trim().toLowerCase();
    final cEmail = currentUser.email?.trim().toLowerCase();

    final cleanUsername = username?.trim().replaceAll('@', '').toLowerCase();
    final cleanName = name?.trim().toLowerCase();

    if (cleanUsername != null && cleanUsername.isNotEmpty) {
      if (cName != null && cName.isNotEmpty && (cleanUsername == cName || cleanUsername == cName.replaceAll(' ', ''))) {
        return true;
      }
      if (cEmail != null && cEmail.isNotEmpty && (cleanUsername == cEmail || cleanUsername == cEmail.split('@').first)) {
        return true;
      }
    }
    if (cleanName != null && cleanName.isNotEmpty) {
      if (cName != null && cName.isNotEmpty && cleanName == cName) {
        return true;
      }
    }
  }

  return false;
}

void navigateToProfile(BuildContext context, {String? userId, String? username, String? name}) {
  final bool isSelf = isSelfUser(userId: userId, username: username, name: name);

  if (isSelf) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  } else {
    final target = username != null && username.isNotEmpty ? username.replaceAll('@', '') : userId;
    if (target != null && target.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(username: target)),
      );
    }
  }
}
