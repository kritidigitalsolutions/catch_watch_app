import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:timezone/data/latest.dart' as tz_latest;
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:uuid/uuid.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final BaseApiService _apiService = NetworkApiService();

  // Track the active conversation to suppress notifications
  static String? activeChatId;

  // Stream for foreground message processing
  static final StreamController<RemoteMessage> _foregroundMessageController = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  // 🔥 BACKGROUND HANDLE
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint("📩 BACKGROUND MESSAGE RECEIVED: ${message.messageId}");
    
    final type = message.data['type'];
    if (type == 'CALL' || type == 'INCOMING_CALL' || message.data['callId'] != null) {
      _showIncomingCallKit(message.data);
    } else {
      _showNotificationInternal(message);
    }
  }

  static Future<void> _showIncomingCallKit(Map<String, dynamic> data) async {
    final String uuid = const Uuid().v4();
    final String callerName = data['callerName'] ?? data['senderName'] ?? "Unknown Caller";
    final String callType = data['type'] ?? "audio";
    
    final params = CallKitParams(
      id: uuid,
      nameCaller: callerName,
      appName: 'CatchWatch',
      avatar: data['callerImage'] ?? data['senderImage'],
      handle: data['callerPhone'] ?? 'Calling...',
      type: callType == 'video' ? 1 : 0,
      duration: 30000,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'callId': data['callId'] ?? data['_id']},
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        backgroundColor: '#0955fa',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
      ios: const IOSParams(
        iconName: 'CatchWatch',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
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
      debugPrint("📩 FOREGROUND MESSAGE RECEIVED: ${message.data}");
      _foregroundMessageController.add(message);
      _showNotificationInternal(message);
    });

    // ✅ BACKGROUND CLICK (APP OPEN FROM NOTIFICATION)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📲 NOTIFICATION CLICKED (BACKGROUND): ${message.data}");
      _foregroundMessageController.add(message);
    });

    // Handle initial message (app launched from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint("📲 APP LAUNCHED FROM NOTIFICATION: ${message.data}");
        _foregroundMessageController.add(message);
      }
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
          await _apiService.patchApi(AppUrl.updateFcmToken, {
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

    // Suppression logic: Don't show local notification if the app is already in the specific chat
    String? conversationId = message.data['conversationId'];
    
    if (conversationId != null && activeChatId == conversationId) {
      debugPrint("🚀 Chat active ($conversationId), suppressing notification.");
      return;
    }

    if (title.isEmpty && body.isEmpty) {
      debugPrint("⚠️ Title and Body are empty, skipping notification.");
      return;
    }

    String? senderName = message.data['senderName'] ?? title;
    String? senderImage = message.data['senderImage'];

    MessagingStyleInformation? messagingStyle;
    if (conversationId != null) {
      final person = Person(
        name: senderName,
        key: message.data['senderId'],
        icon: senderImage != null ? BitmapFilePathAndroidIcon(senderImage) : null,
      );
      
      messagingStyle = MessagingStyleInformation(
        person,
        conversationTitle: message.data['groupName'],
        messages: [
          Message(body, DateTime.now(), person),
        ],
      );
    }

    BigPictureStyleInformation? bigPictureStyleInformation;
    String? localImagePath;

    if (imageUrl != null && imageUrl.isNotEmpty && messagingStyle == null) {
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
      styleInformation: messagingStyle ?? bigPictureStyleInformation,
      largeIcon: localImagePath != null ? FilePathAndroidBitmap(localImagePath) : null,
      category: AndroidNotificationCategory.message,
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
