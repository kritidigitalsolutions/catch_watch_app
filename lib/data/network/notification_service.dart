import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Prevent duplicate initialization of notification listeners
  static bool _initialized = false;

  /// Cached FCM token to ensure deferred / post-login synchronization
  static String? _cachedFcmToken;

  /// Tracks whether the active FCM token has been synchronized to the backend
  static bool _tokenSynced = false;

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
    final String uuid = const Uuid().v5(
      Uuid.NAMESPACE_URL,
      callId,
    );
    _persistCallIdMapping(callId, uuid);
    return uuid;
  }

  static void _persistCallIdMapping(String callId, String uuid) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('call_uuid_$uuid', callId);
      prefs.setString('last_incoming_call_id', callId);
    }).catchError((_) {});
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
    dynamic value = data['callId'] ??
        data['call_id'] ??
        data['_id'] ??
        data['id'];

    if (value == null && data['call'] != null) {
      if (data['call'] is Map) {
        value = data['call']['_id'] ?? data['call']['id'] ?? data['call']['callId'];
      }
    }

    if (value == null && data['data'] != null) {
      if (data['data'] is Map) {
        value = data['data']['callId'] ?? data['data']['_id'] ?? data['data']['id'];
      }
    }

    if (value == null) {
      return null;
    }

    final String result = value.toString().trim();
    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  static bool _isIncomingCall(
      Map<String, dynamic> data,
      ) {
    final String type = (data['type'] ?? data['notificationType'] ?? data['event'])
            ?.toString()
            .toUpperCase() ??
        '';

    final String callType = (data['callType'] ?? '')?.toString().toUpperCase() ?? '';
    final bool hasCallId = _extractCallId(data) != null;

    return type == callType ||
        type == incomingCallType ||
        type == 'CALL_INCOMING' ||
        type == 'VIDEO_CALL' ||
        type == 'AUDIO_CALL' ||
        (hasCallId && (type == 'VIDEO' || type == 'AUDIO' || callType == 'VIDEO' || callType == 'AUDIO'));
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

          // Use high-priority notification for incoming calls to comply with Play Store policy
          isFullScreen: false, 

          isImportant: true,

          isShowFullLockedScreen: false,

          incomingCallNotificationChannelName:
          'high_importance_channel_catch_watch_calls',

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
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('🔔 [NotificationService] Already initialized; checking token sync state.');
      }
      if (HiveService.isLogin() && !_tokenSynced) {
        await syncTokenToServer();
      }
      return;
    }
    _initialized = true;

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
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );

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

          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data =
                  Map<String, dynamic>.from(jsonDecode(response.payload!));
              _foregroundMessageController.add(
                RemoteMessage(data: data),
              );
            } catch (e) {
              debugPrint('Error routing local notification tap payload: $e');
            }
          }
        },
      );

      // --------------------------------------------------------
      // NOTIFICATION PERMISSIONS
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

        // CREATE INCOMING CALL CHANNEL
        await androidImplementation
            ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel_catch_watch_calls',
            incomingCallChannelName,
            description: 'Incoming call notifications',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // CREATE MISSED CALL CHANNEL
        await androidImplementation
            ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'missed_call_channel_id',
            missedCallChannelName,
            description: 'Missed call notifications',
            importance: Importance.max,
            playSound: true,
          ),
        );
      } else if (Platform.isIOS) {
        final NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        if (kDebugMode) {
          debugPrint('iOS Notification requestPermission() result: ${settings.authorizationStatus}');
        }

        final NotificationSettings currentSettings =
            await _messaging.getNotificationSettings();

        debugPrint('🔔 [iOS Notification Settings - getNotificationSettings()]');
        debugPrint('  - authorizationStatus: ${currentSettings.authorizationStatus}');
        debugPrint('  - alert: ${currentSettings.alert}');
        debugPrint('  - sound: ${currentSettings.sound}');
        debugPrint('  - badge: ${currentSettings.badge}');
        debugPrint('  - lockScreen: ${currentSettings.lockScreen}');
        debugPrint('  - notificationCenter: ${currentSettings.notificationCenter}');
        debugPrint('  - showPreviews: ${currentSettings.showPreviews}');
        debugPrint('  - criticalAlert: ${currentSettings.criticalAlert}');

        final IOSFlutterLocalNotificationsPlugin? iosLocalPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosLocalPlugin != null) {
          try {
            final NotificationsEnabledOptions? localPerms =
                await iosLocalPlugin.checkPermissions();
            debugPrint('🔔 [iOS Local Notifications - checkPermissions()]');
            debugPrint('  - isEnabled: ${localPerms?.isEnabled}');
            debugPrint('  - isAlertEnabled: ${localPerms?.isAlertEnabled}');
            debugPrint('  - isSoundEnabled: ${localPerms?.isSoundEnabled}');
            debugPrint('  - isBadgeEnabled: ${localPerms?.isBadgeEnabled}');
            debugPrint('  - isProvisionalEnabled: ${localPerms?.isProvisionalEnabled}');
            debugPrint('  - isCriticalEnabled: ${localPerms?.isCriticalEnabled}');
          } catch (e) {
            debugPrint('⚠️ [iOS Local Notifications] Error querying checkPermissions(): $e');
          }
        }

        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // --------------------------------------------------------
      // FCM TOKEN RETRIEVAL & DEFERRED REGISTRATION
      // --------------------------------------------------------

      // Non-blocking deferred token registration so startup and runApp()
      // are never blocked by APNs readiness or remote server syncing.
      _retrieveAndSyncTokenWithRetry();

      // --------------------------------------------------------
      // FCM TOKEN REFRESH
      // --------------------------------------------------------

      _messaging.onTokenRefresh.listen(
            (newToken) {
          if (newToken.isNotEmpty) {
            debugPrint('CURRENT_FCM_TOKEN: $newToken');
          }
          if (kDebugMode) {
            debugPrint('🔄 FCM TOKEN REFRESHED (available: ${newToken.isNotEmpty}, length: ${newToken.length})');
          }

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
              debugPrint('📲 Foreground incoming call: piping to CallProvider stream');
              _foregroundMessageController.add(
                message,
              );
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
      await _messaging.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

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
      // REQUEST PERMISSIONS (Android CallKit)
      // --------------------------------------------------------

      if (Platform.isAndroid) {
        await requestPermission();
      }

      if (kDebugMode) {
        debugPrint(
          '✅ NotificationService initialized',
        );
      }
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
      }
    } catch (e) {
      debugPrint(
        '❌ Permission error: $e',
      );
    }
  }

  // ============================================================
  // DEFERRED TOKEN RETRIEVAL & RETRY
  // ============================================================

  static Future<String?> _getFcmTokenSafely() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          if (kDebugMode) {
            debugPrint('ℹ️ [FCM_GET] APNs token not yet available on iOS; deferring getToken().');
          }
          return null;
        }
      }
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM_GET] Notice: FCM getToken() deferred: $e');
      }
      return null;
    }
  }

  static Future<void> _retrieveAndSyncTokenWithRetry() async {
    try {
      String? token;
      if (Platform.isIOS) {
        // Poll for APNs token readiness with bounded stepped backoff (up to 6 attempts: 1s, 2s, 3s, 4s, 5s, 6s)
        int retry = 0;
        const int maxRetries = 6;
        while (retry < maxRetries) {
          try {
            final apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null && apnsToken.isNotEmpty) {
              if (kDebugMode) {
                debugPrint('✅ [APNs] APNs token ready on attempt ${retry + 1} (length: ${apnsToken.length})');
              }
              break;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('ℹ️ [APNs] Query attempt ${retry + 1}: $e');
            }
          }
          retry++;
          await Future.delayed(Duration(seconds: retry));
        }
      }

      token = await _getFcmTokenSafely();
      if (token == null && !Platform.isIOS) {
        try {
          token = await _messaging.getToken();
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        debugPrint('CURRENT_FCM_TOKEN: $token');
        if (kDebugMode) {
          debugPrint('🔥 [FCM] FCM token retrieved successfully (length: ${token.length})');
        }
        await syncTokenToServer(token);
      } else {
        debugPrint('CURRENT_FCM_TOKEN: null (FCM token retrieval deferred or APNs token not yet ready)');
        if (kDebugMode) {
          debugPrint('⚠️ [FCM] FCM token unavailable after initial launch attempts. Will synchronize on authentication or token refresh.');
        }
      }
    } catch (e) {
      debugPrint('CURRENT_FCM_TOKEN: Error retrieving token: $e');
      if (kDebugMode) {
        debugPrint('⚠️ [FCM] Error during deferred FCM token retrieval/sync: $e');
      }
    }
  }

  // ============================================================
  // TOKEN SYNC
  // ============================================================

  static Future<void> syncTokenToServer([
      String? token,
      ]) async {
    try {
      final effectiveToken = token ?? _cachedFcmToken ?? await _getFcmTokenSafely();

      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        _cachedFcmToken = effectiveToken;
        debugPrint('CURRENT_FCM_TOKEN: $effectiveToken');
      }

      if (!HiveService.isLogin()) {
        if (kDebugMode) {
          debugPrint('ℹ️ [FCM_SYNC] User not logged in. Caching FCM token for post-login sync (len: ${effectiveToken?.length ?? 0}).');
        }
        return;
      }

      if (effectiveToken == null || effectiveToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM_SYNC] FCM token not available yet. Skipping backend sync.');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🔥 [FCM_SYNC] Syncing FCM token to backend (length: ${effectiveToken.length})...');
      }

      await _apiService.patchApi(
        AppUrl.updateFcmToken,
        {
          'fcmToken': effectiveToken,
        },
      );

      _tokenSynced = true;
      if (kDebugMode) {
        debugPrint('✅ [FCM_SYNC] FCM token synced successfully to backend');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [FCM_SYNC] Error syncing FCM token: $e',
        );
      }
    }
  }

  static Future<void> clearTokenOnLogout() async {
    try {
      _tokenSynced = false;
      if (!HiveService.isLogin()) {
        return;
      }
      await _apiService.patchApi(
        AppUrl.updateFcmToken,
        {
          'fcmToken': '',
        },
      );
      if (kDebugMode) {
        debugPrint('✅ [FCM_SYNC] Cleared FCM token on server on logout');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM_SYNC] Error clearing FCM token on logout: $e');
      }
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

          final String downloadedPath =
          await _downloadAndSaveFile(
            imageUrl,
            fileName,
          );

          localImagePath = downloadedPath;

          bigPictureStyleInformation =
              BigPictureStyleInformation(
                FilePathAndroidBitmap(
                  downloadedPath,
                ),
                largeIcon:
                FilePathAndroidBitmap(
                  downloadedPath,
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
        largeIcon: localImagePath != null && localImagePath.isNotEmpty
            ? FilePathAndroidBitmap(
          localImagePath,
        )
            : null,
        category:
        AndroidNotificationCategory.message,
      );

      final String? finalAttachmentPath = localImagePath;

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
            interruptionLevel: InterruptionLevel.active,
            threadIdentifier: conversationId,
            attachments:
            finalAttachmentPath != null && finalAttachmentPath.isNotEmpty
                ? [
              DarwinNotificationAttachment(
                finalAttachmentPath,
              ),
            ]
                : null,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint(
        '❌ Normal notification error: $e',
      );
    }
  }

  // ============================================================
  // LOCAL CHAT NOTIFICATION (FOREGROUND SOCKET.IO FLOW)
  // ============================================================

  /// Set of message IDs that have already triggered a notification display to prevent duplicates.
  static final Set<String> _notifiedChatMsgIds = <String>{};

  /// Shows a local notification for an incoming chat message received via Socket.IO
  /// when the app is in the foreground and the user is not actively viewing that conversation.
  static Future<void> showLocalChatNotification({
    required String messageId,
    required String conversationId,
    required String senderName,
    required String body,
    String? senderId,
    String? senderImage,
    String? groupName,
  }) async {
    try {
      final String lifecycleState =
          WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
      final bool isActiveMatch =
          activeChatId != null && activeChatId == conversationId;

      debugPrint(
        '🔔 [ChatNotification] Received incoming chat msg: ID=$messageId, convId=$conversationId, lifecycleState=$lifecycleState, isActiveMatch=$isActiveMatch',
      );

      // 1. Suppress if current active conversation matches
      if (isActiveMatch) {
        debugPrint(
          '🚫 [ChatNotification] Suppressed: conversation $conversationId is currently active.',
        );
        return;
      }

      // 2. Suppress if message was sent by the current user
      final currentUserId = HiveService.userId;
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          senderId != null &&
          senderId == currentUserId) {
        debugPrint(
          '🚫 [ChatNotification] Suppressed: message was sent by self ($senderId).',
        );
        return;
      }

      // 3. Deduplication check
      if (messageId.isNotEmpty) {
        if (_notifiedChatMsgIds.contains(messageId)) {
          debugPrint(
            '🚫 [ChatNotification] Suppressed: duplicate notification for messageId $messageId',
          );
          return;
        }
        _notifiedChatMsgIds.add(messageId);
        if (_notifiedChatMsgIds.length > 500) {
          _notifiedChatMsgIds.remove(_notifiedChatMsgIds.first);
        }
      }

      final String title = senderName.trim().isNotEmpty ? senderName.trim() : 'CatchWatch';
      final String displayBody = body.trim().isNotEmpty ? body.trim() : 'New message';

      debugPrint(
        '📲 [ChatNotification] Attempting local notification display for messageId: $messageId',
      );

      final Person person = Person(
        name: title,
        key: senderId,
      );

      final MessagingStyleInformation messagingStyle = MessagingStyleInformation(
        person,
        conversationTitle: groupName,
        messages: [
          Message(
            displayBody,
            DateTime.now(),
            person,
          ),
        ],
      );

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: messagingStyle,
        category: AndroidNotificationCategory.message,
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
        threadIdentifier: conversationId,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final Map<String, dynamic> payloadMap = {
        'type': 'CHAT_MESSAGE',
        'conversationId': conversationId,
        'messageId': messageId,
        'senderId': senderId ?? '',
        'senderName': senderName,
      };

      await _localNotifications.show(
        messageId.hashCode,
        title,
        displayBody,
        platformDetails,
        payload: jsonEncode(payloadMap),
      );

      debugPrint(
        '✅ [ChatNotification] Local notification shown successfully for messageId: $messageId',
      );
    } catch (e, st) {
      debugPrint(
        '❌ [ChatNotification] Notification plugin error: $e',
      );
      if (kDebugMode) {
        debugPrint('$st');
      }
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