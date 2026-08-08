import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/utils/hive_service/userdetail.g.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String boxName = 'userBox';
  static const String userKey = 'user';
  static const String historyBoxName = 'historyBox';
  static const String likesBoxName = 'likesBox';
  static const String statsBoxName = 'statsBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserDetailsAdapter());
    }
    await Hive.openBox<UserDetails>(boxName);
    await Hive.openBox(historyBoxName);
    await Hive.openBox(likesBoxName);
    await Hive.openBox(statsBoxName);
  }

  static Box<UserDetails> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<UserDetails>(boxName);
  }

  static Box get _historyBox => Hive.box(historyBoxName);
  static Box get _likesBox => Hive.box(likesBoxName);
  static Box get _statsBox => Hive.box(statsBoxName);

  static Future<void> saveUser(UserDetails user) async {
    await _box.put(userKey, user);
  }

  // --- Likes ---
  static Future<void> toggleLikeLocal(String contentId, bool isLiked) async {
    if (isLiked) {
      await _likesBox.put(contentId, true);
    } else {
      await _likesBox.delete(contentId);
    }
  }

  static Set<String> getLikedIds() {
    return _likesBox.keys.map((e) => e.toString()).toSet();
  }

  // --- Watch History ---
  static Future<void> saveWatchHistory(String contentId, Map<String, dynamic> data) async {
    await _historyBox.put(contentId, data);
  }

  static Future<void> removeFromWatchHistory(String contentId) async {
    await _historyBox.delete(contentId);
  }

  static Map<dynamic, dynamic> getWatchHistory() {
    return _historyBox.toMap();
  }

  static UserDetails? getUser() {
    return _box.get(userKey);
  }

  static String? getToken() {
    return _box.get(userKey)?.token;
  }

  static String? get userId {
    return _box.get(userKey)?.sId;
  }

  static Future<void> logout() async {
    await _box.clear();
    await _historyBox.clear();
    await _likesBox.clear();
    await _statsBox.clear();
  }

  // --- User Stats Cache ---
  static Future<void> saveUserStats(String userId, int followers, int following, int reels) async {
    await _statsBox.put(userId, {
      'followers': followers,
      'following': following,
      'reels': reels,
    });
  }

  static Map<String, int>? getUserStats(String userId) {
    final data = _statsBox.get(userId);
    if (data == null) return null;
    return Map<String, int>.from(data);
  }

  static bool isLogin() {
    final user = getUser();
    return user != null && user.token != null && user.token!.isNotEmpty;
  }

  static bool isProfileComplete() {
    final user = getUser();
    return user != null && user.isNewUser == false;
  }
}
