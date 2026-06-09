import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/utils/hive_service/userdetail.g.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String boxName = 'userBox';
  static const String userKey = 'user';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserDetailsAdapter());
    }
    await Hive.openBox<UserDetails>(boxName);
  }

  static Box<UserDetails> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<UserDetails>(boxName);
  }

  static Future<void> saveUser(UserDetails user) async {
    await _box.put(userKey, user);
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
