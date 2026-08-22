import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz_latest;
import 'package:uuid/uuid.dart';

import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
  _localNotifications =
  FlutterLocalNotificationsPlugin();

  static final BaseApiService _apiService =
  NetworkApiService();

  /// Current active chat.
  /// Used to suppress normal chat notifications.
  static String? activeChatId;

  /// Foreground message stream.
  ///
  /// IMPORTANT:
  /// Incoming calls are handled by CallKit and are NOT
  /// sent through this stream.
  static final StreamController<RemoteMessage>
  _foregroundMessageController =
  StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage>
  get foregroundMessageStream =>
      _foregroundMessageController.stream;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const String incomingCallType = 'INCOMING_CALL';
  static const String callType = 'CALL';

  static const String callCancelledType = 'CALL_CANCELLED';
  static const String callEndedType = 'CALL_ENDED';
  static const String cancelType = 'CANCEL';
  static const String rejectedType = 'REJECTED';
  static const String endedType = 'ENDED';

  static const String notificationChannelId =
      'high_importance_channel_catch_watch';

  static const String notificationChannelName =
      'Catch Watch Notifications';

  static const String incomingCallChannelName =
      'Incoming Calls';

  static const String missedCallChannelName =
      'Missed Calls';

  static const Duration incomingCallDuration =
  Duration(seconds: 30);

  // ============================================================
  // UUID
  // ============================================================

  static String _getUuidFromCallId(String callId) {
    return const Uuid().v5(
      Uuid.NAMESPACE_URL,
      callId,
    );
  }

  // ============================================================
  // BACKGROUND FCM HANDLER
  // ============================================================

  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(
      RemoteMessage message,
      ) async {
    try {
      await Firebase.initializeApp();
      await HiveService.init();

      debugPrint(
        '📩 BACKGROUND FCM RECEIVED',
      );

      debugPrint(
        'Message ID: ${message.messageId}',
      );

      debugPrint(
        'Data: ${message.data}',
      );

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        message.data,
      );

      final String type =
          data['type']
              ?.toString()
              .toUpperCase() ??
              '';

      final String? callId =
      _extractCallId(data);

      // ----------------------------------------------------------
      // CALL ENDED / CANCELLED / REJECTED
      // ----------------------------------------------------------

      if (_isCallEndType(type)) {
        await _endCallFromBackground(
          callId,
        );

        return;
      }

      // ----------------------------------------------------------
      // INCOMING CALL
      // ----------------------------------------------------------

      if (_isIncomingCall(data)) {
        await _showIncomingCallKit(
          data,
        );

        return;
      }

      // ----------------------------------------------------------
      // NORMAL NOTIFICATION
      // ----------------------------------------------------------

      await _showNotificationInternal(
        message,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Background FCM error: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ============================================================
  // CALL DATA HELPERS
  // ============================================================

  static String? _extractCallId(
      Map<String, dynamic> data,
      ) {
    final dynamic value =
        data['callId'] ??
            data['_id'] ??
            data['id'];

    if (value == null) {
      return null;
    }

    final String result =
    value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  static bool _isIncomingCall(
      Map<String, dynamic> data,
      ) {
    final String type =
        data['type']
            ?.toString()
            .toUpperCase() ??
            '';

    final String? callId =
    _extractCallId(data);

    return type == callType ||
        type == incomingCallType;
  }

  static bool _isCallEndType(
      String type,
      ) {
    return type == callCancelledType ||
        type == callEndedType ||
        type == cancelType ||
        type == rejectedType ||
        type == endedType ||
        type == 'CALL_REJECTED' ||
        type == 'CALL_BUSY' ||
        type == 'BUSY';
  }

  // ============================================================
  // END CALL FROM BACKGROUND
  // ============================================================

  static Future<void> _endCallFromBackground(
      String? callId,
      ) async {
    try {
      if (callId != null) {
        final String uuid =
        _getUuidFromCallId(callId);

        await FlutterCallkitIncoming.endCall(
          uuid,
        );

        debugPrint(
          '🛑 CallKit call ended: $callId',
        );
      }

      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint(
        '❌ Error ending CallKit call: $e',
      );
    }
  }

  // ============================================================
  // SHOW INCOMING CALL
  // ============================================================

  static Future<void> _showIncomingCallKit(
      Map<String, dynamic> data, {
        bool isForeground = false,
      }) async {
    try {
      final String? extractedCallId =
      _extractCallId(data);

      if (extractedCallId == null) {
        debugPrint(
          '❌ Incoming call has no callId',
        );

        return;
      }

      final String callId =
          extractedCallId;

      // ----------------------------------------------------------
      // SELF-NOTIFICATION FILTERING
      // ----------------------------------------------------------
      final String? callerId =
          data['callerId']?.toString() ??
              data['senderId']?.toString();

      if (callerId != null &&
          callerId == HiveService.userId) {
        debugPrint(
          '🚫 Ignoring self-call notification',
        );

        return;
      }

      final String uuid =
      _getUuidFromCallId(callId);

      final String callerName =
      data['callerName']
          ?.toString()
          .trim()
          .isNotEmpty ==
          true
          ? data['callerName'].toString()
          : data['senderName']
          ?.toString()
          .trim()
          .isNotEmpty ==
          true
          ? data['senderName'].toString()
          : 'Unknown Caller';

      final String callType =
          data['callType']
              ?.toString()
              .toLowerCase() ??
              data['type']
                  ?.toString()
                  .toLowerCase() ??
              'audio';

      final String? callerImage =
          data['callerImage']?.toString() ??
              data['senderImage']?.toString();

      final String? callerPhone =
      data['callerPhone']?.toString();

      // ----------------------------------------------------------
      // IMPORTANT
      // ----------------------------------------------------------
      //
      // CallKit is responsible for:
      //
      // - ringtone
      // - vibration
      // - lock-screen UI
      // - full-screen UI
      // - accept
      // - reject
      //
      // We don't start FlutterRingtonePlayer here.
      // ----------------------------------------------------------

      final Map<String, dynamic> extraData =
      <String, dynamic>{
        'callId': callId,
        'callerName': callerName,
        'callerImage': callerImage,
        'callerPhone': callerPhone,
        'callType': callType,

        // Preserve values from backend if they exist.
        'channelName':
        data['channelName'],
        'agoraToken':
        data['agoraToken'],
        'agoraUid':
        data['agoraUid'],
        'receiverId':
        data['receiverId'],
        'callerId':
        data['callerId'],
      };

      final CallKitParams params =
      CallKitParams(
        id: uuid,
        nameCaller: callerName,
        appName: 'CatchWatch',
        avatar: callerImage,
        handle:
        callerPhone ??
            'Incoming call',
        type: callType == 'video'
            ? 1
            : 0,

        duration:
        incomingCallDuration.inMilliseconds,

        missedCallNotification:
        const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),

        extra: extraData,

        headers: const <String, dynamic>{
          'platform': 'flutter',
        },

        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          isCustomSmallExNotification: true,

          ringtonePath:
          'system_ringtone_default',

          backgroundColor:
          '#641dff', // Your App's Primary Color

          actionColor:
          '#4CAF50',

          textAccept: 'Accept',
          textDecline: 'Decline',

          // Always use full-screen intent for incoming calls to ensure UI shows up
          isFullScreen: true, 

          isImportant: true,

          isShowFullLockedScreen: true,

          incomingCallNotificationChannelName:
          incomingCallChannelName,

          missedCallNotificationChannelName:
          missedCallChannelName,
        ),

        ios: const IOSParams(
          iconName: 'CatchWatch',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate:
          44100.0,
          audioSessionPreferredIOBufferDuration:
          0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath:
          'system_ringtone_default',
        ),
      );

      debugPrint(
        '📞 SHOWING CALLKIT INCOMING CALL',
      );

      debugPrint(
        'Call ID: $callId',
      );

      debugPrint(
        'UUID: $uuid',
      );

      debugPrint(
        'Caller: $callerName',
      );

      await FlutterCallkitIncoming
          .showCallkitIncoming(
        params,
      );

      debugPrint(
        '✅ CallKit incoming call shown',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Error showing CallKit incoming call: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> init() async {
    try {
      tz_latest.initializeTimeZones();

      // --------------------------------------------------------
      // LOCAL NOTIFICATION INITIALIZATION
      // --------------------------------------------------------

      const AndroidInitializationSettings
      android =
      AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const DarwinInitializationSettings
      ios =
      DarwinInitializationSettings();

      await _localNotifications.initialize(
        const InitializationSettings(
          android: android,
          iOS: ios,
        ),
        onDidReceiveNotificationResponse:
            (response) {
          debugPrint(
            '👉 LOCAL NOTIFICATION CLICKED',
          );

          debugPrint(
            'Payload: ${response.payload}',
          );
        },
      );

      // --------------------------------------------------------
      // ANDROID NOTIFICATION PERMISSION
      // --------------------------------------------------------

      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin?
        androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation
            ?.requestNotificationsPermission();

        await androidImplementation
            ?.createNotificationChannel(
          const AndroidNotificationChannel(
            notificationChannelId,
            notificationChannelName,
            description:
            'This channel is used for important notifications.',
            importance:
            Importance.max,
            playSound: true,
          ),
        );
      }

      // --------------------------------------------------------
      // FCM TOKEN
      // --------------------------------------------------------

      final String? token =
      await _messaging.getToken();

      debugPrint(
        '🔥 FCM TOKEN: $token',
      );

      if (token != null) {
        await syncTokenToServer(
          token,
        );
      }

      // --------------------------------------------------------
      // FCM TOKEN REFRESH
      // --------------------------------------------------------

      _messaging.onTokenRefresh.listen(
            (newToken) {
          debugPrint(
            '🔄 FCM TOKEN REFRESHED: $newToken',
          );

          syncTokenToServer(
            newToken,
          );
        },
      );

      // --------------------------------------------------------
      // FOREGROUND FCM
      // --------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
            (RemoteMessage message) async {
          try {
            debugPrint(
              '📩 FOREGROUND FCM RECEIVED',
            );

            debugPrint(
              'Data: ${message.data}',
            );

            final Map<String, dynamic> data =
            Map<String, dynamic>.from(
              message.data,
            );

            final String type =
                data['type']
                    ?.toString()
                    .toUpperCase() ??
                    '';

            final String? callId =
            _extractCallId(data);

            // --------------------------------------------------
            // CALL ENDED
            // --------------------------------------------------

            if (_isCallEndType(type)) {
              await _endCallFromBackground(
                callId,
              );

              _foregroundMessageController.add(
                message,
              );

              return;
            }

            // --------------------------------------------------
            // INCOMING CALL
            // --------------------------------------------------

            if (_isIncomingCall(data)) {
              await _showIncomingCallKit(
                data,
                isForeground: true,
              );

              // VERY IMPORTANT:
              //
              // Do not show the same call as a normal
              // notification.
              //
              // Do not send it to the normal foreground
              // notification stream.
              return;
            }

            // --------------------------------------------------
            // NORMAL FCM MESSAGE
            // --------------------------------------------------

            _foregroundMessageController.add(
              message,
            );

            await _showNotificationInternal(
              message,
            );
          } catch (e) {
            debugPrint(
              '❌ Foreground FCM error: $e',
            );
          }
        },
      );

      // --------------------------------------------------------
      // NOTIFICATION CLICKED WHILE BACKGROUND
      // --------------------------------------------------------

      FirebaseMessaging.onMessageOpenedApp.listen(
            (RemoteMessage message) {
          debugPrint(
            '📲 NOTIFICATION CLICKED FROM BACKGROUND',
          );

          debugPrint(
            'Data: ${message.data}',
          );

          final String type =
              message.data['type']
                  ?.toString()
                  .toUpperCase() ??
                  '';

          // Don't route incoming call through normal
          // notification navigation.
          if (_isIncomingCall(
            message.data,
          )) {
            return;
          }

          _foregroundMessageController.add(
            message,
          );
        },
      );

      // --------------------------------------------------------
      // APP LAUNCHED FROM NOTIFICATION
      // --------------------------------------------------------

      final RemoteMessage? initialMessage =
      await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint(
          '📲 APP LAUNCHED FROM NOTIFICATION',
        );

        debugPrint(
          'Data: ${initialMessage.data}',
        );

        if (!_isIncomingCall(
          initialMessage.data,
        )) {
          _foregroundMessageController.add(
            initialMessage,
          );
        }
      }

      // --------------------------------------------------------
      // REQUEST PERMISSIONS
      // --------------------------------------------------------

      await requestPermission();

      debugPrint(
        '✅ NotificationService initialized',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationService init error: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  static Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (Platform.isAndroid) {
        // Android 13+
        await FlutterCallkitIncoming
            .requestNotificationPermission({
          'title':
          'Notification permission',
          'rationaleMessagePermission':
          'Notification permission is required to show incoming calls.',
          'postNotificationMessageRequired':
          'Notification permission is required. Please allow notification permission from settings.',
        });

        // Android 14+
        try {
          final bool canUseFullIntent =
          await FlutterCallkitIncoming
              .canUseFullScreenIntent();

          debugPrint(
            'Full screen intent allowed: $canUseFullIntent',
          );

          if (!canUseFullIntent) {
            await FlutterCallkitIncoming
                .requestFullIntentPermission();
          }
        } catch (e) {
          debugPrint(
            '⚠️ Full screen intent permission error: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Permission error: $e',
      );
    }
  }

  // ============================================================
  // TOKEN SYNC
  // ============================================================

  static Future<void> syncTokenToServer(
      String? token,
      ) async {
    try {
      if (!HiveService.isLogin()) {
        return;
      }

      final String? fcmToken =
          token ?? await _messaging.getToken();

      if (fcmToken == null) {
        return;
      }

      debugPrint(
        '🔥 Syncing FCM token',
      );

      await _apiService.patchApi(
        AppUrl.updateFcmToken,
        {
          'fcmToken': fcmToken,
        },
      );
    } catch (e) {
      debugPrint(
        '❌ Error syncing FCM token: $e',
      );
    }
  }

  // ============================================================
  // NORMAL NOTIFICATION
  // ============================================================

  static Future<void> _showNotificationInternal(
      RemoteMessage message,
      ) async {
    try {
      final RemoteNotification? notification =
          message.notification;

      final String title =
          notification?.title ??
              message.data['title'] ??
              'CatchWatch';

      final String body =
          notification?.body ??
              message.data['message'] ??
              message.data['body'] ??
              '';

      final String? imageUrl =
          message.data['image'] ??
              message.data['imageUrl'] ??
              notification?.android?.imageUrl ??
              notification?.apple?.imageUrl;

      // --------------------------------------------------------
      // CHAT SUPPRESSION
      // --------------------------------------------------------

      final String? conversationId =
      message.data['conversationId'];

      if (conversationId != null &&
          activeChatId == conversationId) {
        debugPrint(
          '🚀 Chat active: $conversationId',
        );

        debugPrint(
          'Suppressing notification',
        );

        return;
      }

      if (title.isEmpty && body.isEmpty) {
        return;
      }

      String? senderName =
          message.data['senderName'] ??
              title;

      String? senderImage =
      message.data['senderImage'];

      MessagingStyleInformation?
      messagingStyle;

      if (conversationId != null) {
        final Person person =
        Person(
          name: senderName,
          key: message.data['senderId'],
          icon: senderImage != null
              ? BitmapFilePathAndroidIcon(
            senderImage,
          )
              : null,
        );

        messagingStyle =
            MessagingStyleInformation(
              person,
              conversationTitle:
              message.data['groupName'],
              messages: [
                Message(
                  body,
                  DateTime.now(),
                  person,
                ),
              ],
            );
      }

      BigPictureStyleInformation?
      bigPictureStyleInformation;

      String? localImagePath;

      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          messagingStyle == null) {
        try {
          final String fileName =
              'notification_img_'
              '${DateTime.now().millisecondsSinceEpoch}.jpg';

          localImagePath =
          await _downloadAndSaveFile(
            imageUrl,
            fileName,
          );

          bigPictureStyleInformation =
              BigPictureStyleInformation(
                FilePathAndroidBitmap(
                  localImagePath,
                ),
                largeIcon:
                FilePathAndroidBitmap(
                  localImagePath,
                ),
                contentTitle: title,
                summaryText: body,
              );
        } catch (e) {
          debugPrint(
            '❌ Notification image error: $e',
          );
        }
      }

      final AndroidNotificationDetails
      androidDetails =
      AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation:
        messagingStyle ??
            bigPictureStyleInformation,
        largeIcon: localImagePath != null
            ? FilePathAndroidBitmap(
          localImagePath,
        )
            : null,
        category:
        AndroidNotificationCategory.message,
      );

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            attachments:
            localImagePath != null
                ? [
              DarwinNotificationAttachment(
                localImagePath,
              ),
            ]
                : null,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '❌ Normal notification error: $e',
      );
    }
  }

  // ============================================================
  // DOWNLOAD IMAGE
  // ============================================================

  static Future<String> _downloadAndSaveFile(
      String url,
      String fileName,
      ) async {
    final Directory directory =
    await getApplicationDocumentsDirectory();

    final String filePath =
        '${directory.path}/$fileName';

    final http.Response response =
    await http
        .get(Uri.parse(url))
        .timeout(
      const Duration(seconds: 10),
    );

    final File file =
    File(filePath);

    await file.writeAsBytes(
      response.bodyBytes,
    );

    return filePath;
  }
}