import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:timezone/data/latest.dart' as tz_latest;
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final BaseApiService _apiService = NetworkApiService();

  // 🔥 BACKGROUND HANDLE
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint("📩 BACKGROUND MESSAGE RECEIVED: ${message.messageId}");
    
    // We only show local notification if it's a data-only message
    // or if we want to customize the look (like with images)
    _showNotificationInternal(message);
  }

  // 🔥 INIT
  static Future<void> init() async {
    tz_latest.initializeTimeZones();
    
    // ✅ Local Notification Init
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
    debugPrint("👉 LOCAL NOTIFICATION CLICKED");
    debugPrint("👉 Payload: ${response.payload}");
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }

    // ✅ Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ✅ TOKEN DEBUG
    String? token = await _messaging.getToken();
    debugPrint("🔥 FCM TOKEN: $token");
    if (token != null) {
      await syncTokenToServer(token);
    }

    // ✅ TOKEN REFRESH
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 TOKEN REFRESHED: $newToken");
      syncTokenToServer(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 FOREGROUND MESSAGE RECEIVED");
      _showNotificationInternal(message);
    });

    // ✅ BACKGROUND CLICK (APP OPEN FROM NOTIFICATION)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📲 NOTIFICATION CLICKED (BACKGROUND)");
    });

    // Request permission
    await requestPermission();
  }

  // 🔥 REQUEST PERMISSION
  static Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }


  // 🔥 PUBLIC METHOD TO SYNC TOKEN
  static Future<void> syncTokenToServer(String? token) async {
    try {
      if (HiveService.isLogin()) {
        String? fcmToken = token ?? await _messaging.getToken();
        if (fcmToken != null) {
          debugPrint("🔥 Syncing FCM Token: $fcmToken");
          await _apiService.postApi(AppUrl.updateFcmToken, {
            'fcmToken': fcmToken
          });
        }
      }
    } catch (e) {
      debugPrint("Error syncing token: $e");
    }
  }

  // 🔥 SHOW NOTIFICATION INTERNAL
  static Future<void> _showNotificationInternal(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    String title = notification?.title ?? message.data['title'] ?? "CatchWatch";
    String body =
        notification?.body ?? message.data['message'] ?? message.data['body'] ?? "";

    String? imageUrl = message.data['image'] ??
                      message.data['imageUrl'] ??
                      notification?.android?.imageUrl ??
                      notification?.apple?.imageUrl;

    if (title.isEmpty && body.isEmpty) {
      debugPrint("⚠️ Title and Body are empty, skipping notification.");
      return;
    }

    BigPictureStyleInformation? bigPictureStyleInformation;
    String? localImagePath;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String fileName = 'notification_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        localImagePath = await _downloadAndSaveFile(imageUrl, fileName);

        bigPictureStyleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          largeIcon: FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
        );
      } catch (e) {
        debugPrint("❌ Error downloading image: $e");
      }
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: bigPictureStyleInformation,
      largeIcon: localImagePath != null ? FilePathAndroidBitmap(localImagePath) : null,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          attachments: localImagePath != null
              ? [DarwinNotificationAttachment(localImagePath)]
              : null,
        ),
      ),
    );
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }
}
