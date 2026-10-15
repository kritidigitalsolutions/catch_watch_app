import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/models/call_model.dart';
import 'package:catch_watch/repository/call_repository.dart';
import 'package:catch_watch/utils/agora_config.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/views/after_login_pages/message/active_call_screen.dart';
import 'package:catch_watch/views/after_login_pages/message/incoming_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/chat_model.dart';

enum CallStatus {
  idle,
  ringing,
  active,
  ended,
}

class CallProvider extends ChangeNotifier with WidgetsBindingObserver {
  final CallRepository _callRepository =
  CallRepository();

  final SocketService _socketService =
  SocketService();

  RtcEngine? _engine;
  bool _isEngineInitialized = false;
  Future<bool>? _engineInitCompleter;

  CallModel? _currentCall;

  CallStatus _status =
      CallStatus.idle;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _remoteVideoMuted = false;

  int? _remoteUid;

  bool _isAccepting = false;
  bool _isEnding = false;
  bool _isRejecting = false;

  bool _isJoiningChannel = false;
  bool _isChannelJoined = false;

  bool _isInCallScreen = false;

  bool _isCaller = false;

  List<CallModel> _callHistory = [];

  bool _isHistoryLoading = false;

  int _historyPage = 1;

  bool _hasMoreHistory = true;

  // ============================================================
  // TIMERS
  // ============================================================

  static const Duration ringingDuration =
  Duration(seconds: 30);

  Timer? _callTimer;

  Timer? _ringingTimer;

  int _durationSeconds = 0;

  // ============================================================
  // NAVIGATOR
  // ============================================================

  final GlobalKey<NavigatorState>
  navigatorKey =
  GlobalKey<NavigatorState>();

  // ============================================================
  // GETTERS
  // ============================================================

  RtcEngine? get engine =>
      _isEngineInitialized ? _engine : null;

  CallModel? get currentCall =>
      _currentCall;

  CallStatus get status =>
      _status;

  bool get isMuted =>
      _isMuted;

  bool get isVideoOff =>
      _isVideoOff;

  bool get isSpeakerOn =>
      _isSpeakerOn;

  bool get remoteVideoMuted =>
      _remoteVideoMuted;

  int? get remoteUid =>
      _remoteUid;

  bool get isAccepting =>
      _isAccepting;

  bool get isInCallScreen =>
      _isInCallScreen;

  bool get isCaller =>
      _isCaller;

  int get durationSeconds =>
      _durationSeconds;

  List<CallModel> get callHistory =>
      _callHistory;

  bool get isHistoryLoading =>
      _isHistoryLoading;

  String get formattedDuration {
    final int minutes =
    (_durationSeconds ~/ 60);

    final int seconds =
    (_durationSeconds % 60);

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  CallProvider() {
    WidgetsBinding.instance.addObserver(this);
    if (HiveService.isLogin()) {
      _socketService.connect();
    }
    _initSocketListeners();
    _initNotificationListener();
    _initCallKitListener();
    _checkActiveCalls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, checking for active calls...');
      if (HiveService.isLogin()) {
        _socketService.connect();
      }
      _checkActiveCalls();
    }
  }

  Future<void> _checkActiveCalls() async {
    // Retry a few times because at cold start, 
    // the plugin might not report calls immediately.
    int retryCount = 0;
    while (retryCount < 5) {
      try {
        final calls = await FlutterCallkitIncoming.activeCalls();
        if (calls is List && calls.isNotEmpty) {
          debugPrint('📞 Found active CallKit calls: ${calls.length}');
          
          if (_status == CallStatus.idle) {
            final callData = calls.first;
            final String? rawCallId = _extractCallIdFromCallKitData(callData);
            final String? callId = await _resolveCallIdAsync(rawCallId);
            
            if (callId != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(callId)) {
              debugPrint('📥 Cold start: Transitioning to call screen for $callId');
              
              _isCaller = false;
              
              try {
                final CallModel call = await _callRepository.getCallDetails(callId);
                call.sId = callId;
                _currentCall = call;
                _status = CallStatus.ringing;
                
                // Patch name/image from CallKit data if missing
                if (_currentCall!.caller == null) {
                  _currentCall!.caller = Sender();
                }
                if (_currentCall!.caller!.name == null || _currentCall!.caller!.name!.isEmpty) {
                  _currentCall!.caller!.name = callData.nameCaller ?? 
                                               (callData.extra?['callerName']?.toString());
                }
                if (_currentCall!.caller!.profileImage == null || _currentCall!.caller!.profileImage!.isEmpty) {
                  _currentCall!.caller!.profileImage = callData.avatar ?? 
                                                       (callData.extra?['callerImage']?.toString());
                }
                
                notifyListeners();
                _showIncomingCallScreen();
                return; // Success
              } catch (e) {
                debugPrint('❌ Error fetching call details: $e');
              }
            } else if (rawCallId != null) {
              debugPrint('⚠️ Cold start: Active CallKit call found but cannot resolve ID ($rawCallId)');
            }
          } else {
            return; // Already in a call state
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking active calls: $e');
      }
      
      retryCount++;
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  String? _extractCallIdFromCallKitData(dynamic data) {
    if (data is Map) {
      final extra = data['extra'];
      if (extra is Map) {
        return extra['callId']?.toString();
      }
      return data['callId']?.toString() ?? data['id']?.toString();
    } else if (data is CallKitParams) {
      return data.extra?['callId']?.toString() ?? data.id;
    }
    return null;
  }

  // ============================================================
  // CALL TIMER
  // ============================================================

  void _startTimer() {
    _durationSeconds = 0;

    _callTimer?.cancel();

    _callTimer =
        Timer.periodic(
          const Duration(seconds: 1),
              (timer) {
            _durationSeconds++;

            notifyListeners();
          },
        );
  }

  void _stopTimer() {
    _callTimer?.cancel();

    _callTimer = null;
  }

  // ============================================================
  // RINGING TIMER
  // ============================================================

  void _startRingingTimer() {
    _ringingTimer?.cancel();

    _ringingTimer =
        Timer(
          ringingDuration,
              () async {
            debugPrint(
              '⏳ Incoming call timeout',
            );

            if (_status ==
                CallStatus.ringing) {
              if (_isCaller) {
                await endCall();
              } else {
                await rejectCall();
              }
            }
          },
        );
  }

  void _stopRingingTimer() {
    _ringingTimer?.cancel();

    _ringingTimer = null;
  }

  // ============================================================
  // CALL SCREEN STATE
  // ============================================================

  void setInCallScreen(
      bool value,
      ) {
    _isInCallScreen = value;

    notifyListeners();
  }

  // ============================================================
  // UUID & CALL ID RESOLUTION
  // ============================================================

  static final Map<String, String> _uuidToCallIdMap = {};

  static void registerCallId(String callId, [String? uuid]) {
    final String computedUuid = uuid ?? _getUuidFromCallIdStatic(callId);
    _uuidToCallIdMap[computedUuid] = callId;
    _uuidToCallIdMap[callId] = callId;
  }

  static String _getUuidFromCallIdStatic(String callId) {
    return const Uuid().v5(
      Uuid.NAMESPACE_URL,
      callId,
    );
  }

  String _getUuidFromCallId(
      String callId,
      ) {
    final String uuid = const Uuid().v5(
      Uuid.NAMESPACE_URL,
      callId,
    );
    _uuidToCallIdMap[uuid] = callId;
    _uuidToCallIdMap[callId] = callId;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('call_uuid_$uuid', callId);
      prefs.setString('last_incoming_call_id', callId);
    }).catchError((_) {});
    return uuid;
  }

  String? _resolveCallId(String? idOrUuid) {
    if (idOrUuid == null || idOrUuid.trim().isEmpty) return null;
    final String trimmed = idOrUuid.trim();

    // 1. Direct cache lookup
    if (_uuidToCallIdMap.containsKey(trimmed)) {
      return _uuidToCallIdMap[trimmed];
    }

    // 2. Check if _currentCall matches either directly or by UUID
    if (_currentCall?.sId != null && _currentCall!.sId!.isNotEmpty) {
      final String currentSid = _currentCall!.sId!;
      if (currentSid == trimmed || _getUuidFromCallId(currentSid) == trimmed) {
        return currentSid;
      }
    }

    // 3. If already a 24-character hexadecimal MongoDB ObjectId
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 4. Fallback to _currentCall.sId if present
    if (_currentCall?.sId != null && _currentCall!.sId!.isNotEmpty) {
      return _currentCall!.sId;
    }

    return trimmed;
  }

  Future<String?> _resolveCallIdAsync(String? idOrUuid) async {
    final String? resolvedSync = _resolveCallId(idOrUuid);
    if (resolvedSync != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(resolvedSync)) {
      return resolvedSync;
    }

    if (idOrUuid != null && idOrUuid.isNotEmpty) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? stored = prefs.getString('call_uuid_$idOrUuid') ?? prefs.getString('last_incoming_call_id');
        if (stored != null && stored.isNotEmpty) {
          _uuidToCallIdMap[idOrUuid] = stored;
          return stored;
        }
      } catch (_) {}
    }

    return resolvedSync;
  }

  // ============================================================
  // CALLKIT EVENTS
  // ============================================================

  void _initCallKitListener() {
    FlutterCallkitIncoming
        .onEvent
        .listen(
          (event) async {
        if (event == null) {
          return;
        }

        debugPrint(
          '📞 CallKit Event: '
              '${event.eventName}',
        );

        // debugPrint(
        //   'CallKit body: ${event.body}',
        // );

        // ------------------------------------------------------
        // ACCEPT
        // ------------------------------------------------------

        if (event
        is CallEventActionCallAccept) {
          await _handleCallKitAccept(
            event,
          );

          return;
        }

        // ------------------------------------------------------
        // DECLINE
        // ------------------------------------------------------

        if (event
        is CallEventActionCallDecline) {
          await _handleCallKitDecline(
            event,
          );

          return;
        }

        // ------------------------------------------------------
        // CALLBACK (TAP ON NOTIFICATION BODY)
        // ------------------------------------------------------

        if (event is CallEventActionCallCallback) {
          debugPrint('📞 CallKit Callback (Notification Tapped)');
          _showIncomingCallScreen();
          return;
        }

        // ------------------------------------------------------
        // END
        // ------------------------------------------------------

        if (event
        is CallEventActionCallEnded) {
          debugPrint(
            '📞 CallKit ended call',
          );

          if (_status !=
              CallStatus.idle) {
            await endCall();
          }

          return;
        }

        // ------------------------------------------------------
        // TIMEOUT
        // ------------------------------------------------------

        if (event
        is CallEventActionCallTimeout) {
          debugPrint(
            '⏰ CallKit timeout',
          );

          if (_status ==
              CallStatus.ringing) {
            await rejectCall();
          }

          return;
        }
      },
    );
  }

  // ============================================================
  // CALLKIT ACCEPT
  // ============================================================

  Future<void> _handleCallKitAccept(
      CallEventActionCallAccept event,
      ) async {
    final String? rawCallId =
    _extractCallIdFromCallKitEvent(
      event,
    );
    try {
      debugPrint(
        '📞 CallKit ACCEPT Event Received: rawCallId=$rawCallId',
      );

      // Guard against duplicate / re-entrant accept calls.
      // On iOS, setCallConnected() causes CXAnswerCallAction to re-emit ACTION_CALL_ACCEPT.
      if (_status == CallStatus.active || _isAccepting) {
        debugPrint(
          '⚠️ Call already active or accepting, ignoring duplicate CallKit accept',
        );
        return;
      }

      // Wait a moment for navigator to be ready if app was cold started
      int retry = 0;
      while (navigatorKey.currentState == null && retry < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        retry++;
      }

      final String? callId = await _resolveCallIdAsync(rawCallId);

      // --------------------------------------------------------
      // If current call is already loaded, use it.
      // --------------------------------------------------------

      if (_currentCall != null &&
          (_currentCall!.sId == callId ||
           callId == null ||
           (rawCallId != null && _currentCall!.sId != null && _getUuidFromCallId(_currentCall!.sId!) == rawCallId))) {
        await acceptCall();
        return;
      }

      // --------------------------------------------------------
      // Otherwise fetch call details.
      // --------------------------------------------------------

      if (callId == null || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(callId)) {
        debugPrint(
          '❌ CallKit accept: cannot resolve to valid MongoDB call ID ($rawCallId -> $callId)',
        );
        _showError('Unable to identify incoming call.');
        if (rawCallId != null) {
          await FlutterCallkitIncoming.endCall(rawCallId);
        }
        await FlutterCallkitIncoming.endAllCalls();
        _endCallLocally();
        return;
      }

      debugPrint(
        '📥 Fetching call details for $callId',
      );

      final CallModel call =
      await _callRepository
          .getCallDetails(
        callId,
      );

      call.sId ??= callId;

      _currentCall = call;

      // Patch name/image from CallKit data if missing
      final params = event.callKitParams;
      if (_currentCall!.caller == null) {
        _currentCall!.caller = Sender();
      }
      if (_currentCall!.caller!.name == null || _currentCall!.caller!.name!.isEmpty) {
        _currentCall!.caller!.name = params.nameCaller ?? 
                                     (params.extra?['callerName']?.toString());
      }
      if (_currentCall!.caller!.profileImage == null || _currentCall!.caller!.profileImage!.isEmpty) {
        _currentCall!.caller!.profileImage = params.avatar ?? 
                                             (params.extra?['callerImage']?.toString());
      }

      _isCaller = false;

      _status =
          CallStatus.ringing;

      notifyListeners();

      await acceptCall();
    } catch (e, stackTrace) {
      debugPrint(
        '❌ CallKit accept error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _showError('Failed to accept call: $e');

      // Dismiss CallKit to ensure native screen does not remain stuck at "Ringing..."
      if (rawCallId != null) {
        try {
          await FlutterCallkitIncoming.endCall(rawCallId);
        } catch (_) {}
      }
      await FlutterCallkitIncoming.endAllCalls();
      _endCallLocally();
    }
  }

  // ============================================================
  // CALLKIT DECLINE
  // ============================================================

  Future<void> _handleCallKitDecline(
      CallEventActionCallDecline event,
      ) async {
    final String? rawCallId =
    _extractCallIdFromCallKitEvent(
      event,
    );
    try {
      debugPrint(
        '📞 CallKit DECLINE: rawCallId=$rawCallId',
      );

      final String? callId = _resolveCallId(rawCallId);

      if (_currentCall == null &&
          callId != null &&
          RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(callId)) {
        try {
          final CallModel call =
          await _callRepository
              .getCallDetails(
            callId,
          );

          call.sId ??= callId;

          _currentCall = call;
        } catch (e) {
          debugPrint(
            'Could not fetch call details '
                'for decline: $e',
          );
        }
      }

      await rejectCall();
    } catch (e, stackTrace) {
      debugPrint(
        '❌ CallKit decline error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (rawCallId != null) {
        try {
          await FlutterCallkitIncoming.endCall(rawCallId);
        } catch (_) {}
      }
      await FlutterCallkitIncoming.endAllCalls();
      _endCallLocally();
    }
  }

  // ============================================================
  // EXTRACT CALL ID FROM CALLKIT EVENT
  // ============================================================

  String? _extractCallIdFromCallKitEvent(
      dynamic event,
      ) {
    try {
      if (event is CallEventActionCallIncoming) return event.callKitParams.extra?['callId']?.toString() ?? event.callKitParams.id;
      if (event is CallEventActionCallStart) return event.callKitParams.extra?['callId']?.toString() ?? event.callKitParams.id;
      if (event is CallEventActionCallAccept) return event.callKitParams.extra?['callId']?.toString() ?? event.callKitParams.id;
      if (event is CallEventActionCallDecline) return event.callKitParams.extra?['callId']?.toString() ?? event.callKitParams.id;
      if (event is CallEventActionCallEnded) return event.callKitParams.extra?['callId']?.toString() ?? event.callKitParams.id;
      if (event is CallEventActionCallTimeout) return event.id;
      if (event is CallEventActionCallCallback) return event.id;

      final dynamic body = (event as dynamic).body;

      if (body is Map) {
        final dynamic extra =
        body['extra'];

        if (extra is Map) {
          final dynamic callId =
          extra['callId'];

          if (callId != null) {
            return callId.toString();
          }
        }

        final dynamic callId =
            body['callId'] ??
                body['id'];

        if (callId != null) {
          return callId.toString();
        }
      }

      // Some versions expose UUID as body['id'].
      //
      // We intentionally do NOT convert the UUID back to
      // callId because UUID -> callId is not reversible.
      //
      // Therefore, your CallKit extra.callId is important.

      return null;
    } catch (e) {
      debugPrint(
        '❌ Error extracting CallKit call ID: $e',
      );

      return null;
    }
  }

  // ============================================================
  // FOREGROUND FCM LISTENER
  // ============================================================

  void _initNotificationListener() {
    NotificationService
        .foregroundMessageStream
        .listen(
          (message) {
        debugPrint(
          'CallProvider FCM: '
              '${message.data}',
        );

        final String type =
            message.data['type']
                ?.toString()
                .toUpperCase() ??
                '';

        // ------------------------------------------------------
        // IMPORTANT:
        //
        // Incoming calls are already displayed by CallKit.
        //
        // Do NOT call _handleIncomingCall() here.
        // ------------------------------------------------------

        if (type == 'CALL' ||
            type == 'INCOMING_CALL') {
          debugPrint(
            '📞 Foreground Incoming call: showing UI',
          );

          _handleIncomingCall(
            message.data,
          );

          return;
        }

        // ------------------------------------------------------
        // CALL TERMINATION FROM FCM
        // ------------------------------------------------------

        if (type == 'CALL_CANCELLED' ||
            type == 'CALL_ENDED' ||
            type == 'CALL_REJECTED' ||
            type == 'CALL_BUSY' ||
            type == 'CANCEL' ||
            type == 'REJECTED' ||
            type == 'ENDED' ||
            type == 'BUSY') {
          debugPrint(
            '📴 Call termination received via FCM: $type',
          );

          _handleCallEnd(
            message.data,
          );

          return;
        }

        // Other FCM messages can continue here.
      },
    );
  }

  // ============================================================
  // SOCKET LISTENERS
  // ============================================================

  void _initSocketListeners() {
    _socketService.messageStream.listen(
          (eventData) {
        final dynamic event =
        eventData['event'];

        final dynamic data =
        eventData['data'];

        debugPrint(
          'Call Socket Event: $event',
        );

        debugPrint(
          'Call Socket Data: $data',
        );

        switch (event) {
          case 'incoming_call':
            _handleIncomingCall(
              data,
            );
            break;

          case 'call_accepted':
            _handleCallAccepted(
              data,
            );
            break;

          case 'call_rejected':
          case 'call_ended':
          case 'call_cancelled':
          case 'call_busy':
          case 'call_missed':
            _handleCallEnd(
              data,
            );
            break;
        }
      },
    );
  }

  // ============================================================
  // EXTRACT CALL ID
  // ============================================================

  String? _extractCallId(
      dynamic data,
      ) {
    if (data == null) {
      return null;
    }

    if (data is String) {
      return data;
    }

    if (data is Map) {
      return (
          data['_id'] ??
              data['id'] ??
              data['callId']
      )?.toString();
    }

    return null;
  }

  // ============================================================
  // SOCKET INCOMING CALL
  // ============================================================

  Future<void> _handleIncomingCall(
      dynamic data,
      ) async {
    debugPrint(
      '📞 SOCKET incoming call: $data',
    );

    final String? incomingCallId =
    _extractCallId(data);

    if (incomingCallId == null) {
      debugPrint(
        '❌ Could not extract call ID',
      );

      return;
    }

    _getUuidFromCallId(incomingCallId);

    // ----------------------------------------------------------
    // DUPLICATE
    // ----------------------------------------------------------

    if (_currentCall?.sId ==
        incomingCallId) {
      debugPrint(
        '⚠️ Duplicate incoming call ignored',
      );

      return;
    }

    // ----------------------------------------------------------
    // BUSY
    // ----------------------------------------------------------

    if (_status !=
        CallStatus.idle) {
      debugPrint(
        '📵 Already in another call',
      );

      await _callRepository
          .busyCall(
        incomingCallId,
      );

      return;
    }

    _isCaller = false;

    // ----------------------------------------------------------
    // CREATE CURRENT CALL
    // ----------------------------------------------------------

    if (data is Map) {
      _currentCall =
          CallModel.fromJson(
            Map<String, dynamic>.from(
              data,
            ),
          );

      _currentCall!.sId ??=
          incomingCallId;
          
      // Ensure caller name and image are populated from top-level data if missing in caller object
      if (_currentCall!.caller == null) {
        _currentCall!.caller = Sender(
          sId: (data['callerId'] ?? data['senderId'])?.toString(),
          id: (data['callerId'] ?? data['senderId'])?.toString(),
        );
      }
      
      if (_currentCall!.caller!.name == null || _currentCall!.caller!.name!.isEmpty) {
        _currentCall!.caller!.name = (data['callerName'] ?? data['senderName'])?.toString();
      }
      
      if (_currentCall!.caller!.profileImage == null || _currentCall!.caller!.profileImage!.isEmpty) {
        _currentCall!.caller!.profileImage = (data['callerImage'] ?? data['senderImage'])?.toString();
      }
    } else {
      try {
        _currentCall =
        await _callRepository
            .getCallDetails(
          incomingCallId,
        );

        _currentCall!.sId ??=
            incomingCallId;
      } catch (e) {
        debugPrint(
          '❌ Error getting call details: $e',
        );

        return;
      }
    }

    _status =
        CallStatus.ringing;

    _startRingingTimer();
    _startRinging();

    notifyListeners();

    // Trigger Incoming UI in foreground
    _showIncomingCallScreen();

    debugPrint(
      '✅ Socket incoming call prepared',
    );
  }

  // ============================================================
  // CALL ACCEPTED FROM SOCKET
  // ============================================================

  void _handleCallAccepted(
      dynamic data,
      ) {
    final String? acceptedCallId =
    _extractCallId(data);

    debugPrint(
      '📞 Call accepted: '
          '$acceptedCallId',
    );

    if (_currentCall?.sId ==
        acceptedCallId ||
        acceptedCallId != null) {
      _status =
          CallStatus.active;
      
      WakelockPlus.enable();

      if (acceptedCallId != null) {
        FlutterCallkitIncoming
            .setCallConnected(
          _getUuidFromCallId(
            acceptedCallId,
          ),
        );
      }

      _stopRinging();
      _stopRingingTimer();

      _startTimer();

      // Only the caller joins here. The receiver joins via acceptCall().
      if (_isCaller && !_isChannelJoined && !_isJoiningChannel) {
        _joinChannel();
      }

      notifyListeners();

      // If we are the receiver and were on incoming screen, transition to active screen
      if (!_isCaller && _status == CallStatus.active && _isInCallScreen) {
        final NavigatorState? navigator = navigatorKey.currentState;
        if (navigator != null) {
         // Clean up any call screens before pushing active screen
          navigator.popUntil((route) => 
            route.settings.name != '/call' && 
            route.settings.name != '/incoming-call'
          );

          navigator.push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/call'),
              builder: (context) => const ActiveCallScreen(),
            ),
          );
        }
      }
    }
  }

  // ============================================================
  // CALL END SOCKET
  // ============================================================

  void _handleCallEnd(
      dynamic data,
      ) {
    final String? endedCallId =
    _extractCallId(data);

    debugPrint(
      '📴 Call ended/rejected: '
          '$endedCallId',
    );

    // If we have an active call and receive a termination signal, 
    // end it even if the ID is missing in the payload (safety fallback)
    if (_currentCall?.sId == endedCallId || 
        (_currentCall != null && (endedCallId == null || endedCallId.isEmpty))) {
      debugPrint(
        '📴 Ending call locally: '
            '${_currentCall?.sId}',
      );

      if (endedCallId != null) {
        FlutterCallkitIncoming
            .endCall(
          _getUuidFromCallId(
            endedCallId,
          ),
        );
      } else if (_currentCall?.sId !=
          null) {
        FlutterCallkitIncoming
            .endCall(
          _getUuidFromCallId(
            _currentCall!.sId!,
          ),
        );
      }

      FlutterCallkitIncoming
          .endAllCalls();

      _stopRinging();

      _stopRingingTimer();

      _stopTimer();

      _endCallLocally();

      _removeCallScreen();

      notifyListeners();
    }
  }

  // ============================================================
  // END LOCALLY
  // ============================================================

  void _endCallLocally() {
    _status =
        CallStatus.ended;
    _isAccepting = false;
    _isJoiningChannel = false;
    _isChannelJoined = false;
    _isCaller = false;

    // Reset media controls to default state for future calls
    _isMuted = false;
    _isVideoOff = false;
    _isSpeakerOn = true;
    _remoteVideoMuted = false;
    
    WakelockPlus.disable();

    // Immediately leave and dispose RTC engine to prevent error -17 on rapid reconnect or new calls
    _disposeEngine();

    notifyListeners();

    Future.delayed(
      const Duration(seconds: 2),
          () {
        if (_status ==
            CallStatus.ended) {
          _status =
              CallStatus.idle;

          _currentCall = null;

          _remoteUid = null;

          _durationSeconds = 0;

          notifyListeners();
        }
      },
    );
  }

  // ============================================================
  // START CALL
  // ============================================================

  Future<void> startCall(
      String receiverId,
      String type, {
        String? partnerName,
        String? partnerImage,
      }) async {
    try {
      debugPrint(
        '📞 Starting $type call '
            'to $receiverId',
      );

      final bool isVideo = type == 'video';
      final bool permissionsGranted = await _checkCallPermissions(isVideoCall: isVideo);
      if (!permissionsGranted) {
        debugPrint('❌ Outgoing call aborted: required permissions not granted');
        _status = CallStatus.idle;
        _isCaller = false;
        notifyListeners();
        return;
      }

      _isCaller = true;

      _status =
          CallStatus.ringing;

      notifyListeners();

      final CallModel call =
      await _callRepository.startCall(
        receiverId,
        type,
      );

      final token = call.agoraToken?.trim();
      final uid = call.agoraUid;
      if (token == null || token.isEmpty || uid == null || uid <= 0) {
        throw Exception('Server did not provide required call credentials (token/UID).');
      }

      _currentCall = call;

      if (_currentCall?.receiver !=
          null &&
          partnerName != null) {
        _currentCall!.receiver!.name =
            partnerName;

        _currentCall!.receiver!
            .profileImage =
            partnerImage;
      }

      debugPrint(
        '📞 Call started: '
            '${_currentCall?.sId}',
      );

      // --------------------------------------------------------
      // OUTGOING CALLKIT
      // --------------------------------------------------------

      if (_currentCall?.sId != null) {
        final CallKitParams params =
        CallKitParams(
          id: _getUuidFromCallId(
            _currentCall!.sId!,
          ),
          nameCaller:
          partnerName ??
              'Calling...',
          handle: 'Outgoing call',
          type: type == 'video'
              ? 1
              : 0,

          extra: <String, dynamic>{
            'callId':
            _currentCall!.sId,
          },

          duration:
          ringingDuration
              .inMilliseconds,

          android:
          const AndroidParams(
            isCustomNotification:
            false,
            isImportant: true,
            isFullScreen: false,
          ),

          ios: const IOSParams(
            handleType: 'generic',
            supportsVideo: true,
          ),
        );

        await FlutterCallkitIncoming
            .startCall(
          params,
        );
      }

      _isInCallScreen = true;

      _startRingingTimer();

      // --------------------------------------------------------
      // OUTGOING SCREEN
      // --------------------------------------------------------

      navigatorKey.currentState
          ?.push(
        MaterialPageRoute(
          settings:
          const RouteSettings(
            name: '/call',
          ),
          builder: (context) =>
          const ActiveCallScreen(),
        ),
      );

      // --------------------------------------------------------
      // AGORA
      // --------------------------------------------------------

      final bool initialized = await _initEngine();
      if (!initialized) {
        debugPrint(
          '❌ Outgoing call aborted: required permissions not granted',
        );
        endCall();
        return;
      }
      debugPrint(
        '✅ Agora initialized',
      );

      notifyListeners();
    } catch (e) {
      _status =
          CallStatus.idle;

      notifyListeners();

      debugPrint(
        '❌ Start call error: $e',
      );

      _showError(
        e.toString(),
      );
    }
  }

  // ============================================================
  // ACCEPT CALL
  // ============================================================

  Future<void> acceptCall() async {
    if (_isAccepting || _status == CallStatus.active || _isChannelJoined) {
      debugPrint('⚠️ Accept call ignored: already accepting, active, or joined');
      return;
    }

    if (_currentCall == null) {
      debugPrint(
        '❌ Accept aborted: current call is null',
      );

      return;
    }

    final String? callId =
        _currentCall!.sId;

    if (callId == null ||
        callId.isEmpty) {
      debugPrint(
        '❌ Accept aborted: missing call ID',
      );

      return;
    }

    try {
      _isAccepting = true;
      _isCaller = false;

      notifyListeners();

      debugPrint(
        '📞 Accepting call: $callId',
      );

      // --------------------------------------------------------
      // ACCEPT API
      // --------------------------------------------------------

      final CallModel updatedCall =
      await _callRepository
          .acceptCall(
        callId,
      );

      final token = updatedCall.agoraToken?.trim();
      final uid = updatedCall.agoraUid;
      if (token == null || token.isEmpty || uid == null || uid <= 0) {
        debugPrint('❌ Accept call failed: server did not return valid token/UID');
        _isAccepting = false;
        _showError('Unable to connect call: invalid server credentials.');
        await endCall();
        notifyListeners();
        return;
      }

      _currentCall =
          updatedCall;

      _currentCall!.sId ??=
          callId;

      _status =
          CallStatus.active;

      _stopRinging();

      _stopRingingTimer();
      
      WakelockPlus.enable();

      // --------------------------------------------------------
      // CALLKIT CONNECTED
      // --------------------------------------------------------

      await FlutterCallkitIncoming
          .setCallConnected(
        _getUuidFromCallId(
          callId,
        ),
      );

      // --------------------------------------------------------
      // AGORA
      // --------------------------------------------------------

      debugPrint(
        '🎧 Initializing Agora',
      );

      final bool initialized = await _initEngine();
      if (!initialized) {
        debugPrint(
          '❌ Cannot join channel: required permissions not granted',
        );
        _isAccepting = false;
        await endCall();
        notifyListeners();
        return;
      }

      debugPrint(
        '🎧 Joining channel: '
            '${_currentCall!.channelName}',
      );

      await _joinChannel();

      _startTimer();

      _isAccepting = false;

      notifyListeners();

      // --------------------------------------------------------
      // SHOW ACTIVE SCREEN
      // --------------------------------------------------------
      
      final NavigatorState? navigator = navigatorKey.currentState;
      if (navigator != null) {
        _isInCallScreen = true;
        
        // Remove any existing call screens before pushing the active one
        // We pop until we hit a non-call route (like home), then push on top.
        navigator.popUntil((route) => 
          route.settings.name != '/call' && 
          route.settings.name != '/incoming-call'
        );

        navigator.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/call'),
            builder: (context) => const ActiveCallScreen(),
          ),
        );
      }
    } catch (e, stackTrace) {
      _isAccepting = false;

      notifyListeners();

      debugPrint(
        '❌ Accept call error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      _showError(
        'Failed to accept call: $e',
      );

      try {
        await FlutterCallkitIncoming
            .endCall(
          _getUuidFromCallId(
            callId,
          ),
        );
      } catch (_) {}
      await FlutterCallkitIncoming.endAllCalls();
      _endCallLocally();
      _removeCallScreen();
    }
  }

  // ============================================================
  // SHOW INCOMING CALL SCREEN
  // ============================================================

  Future<void> _showIncomingCallScreen() async {
    // Wait for navigator to be ready if app is just launching
    int retry = 0;
    while (navigatorKey.currentState == null && retry < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }

    final NavigatorState? navigator = navigatorKey.currentState;

    if (navigator == null) {
      debugPrint('⚠️ Navigator not available even after retries');
      return;
    }

    _isInCallScreen = true;

    // Avoid pushing duplicate screens
    bool alreadyOnScreen = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/incoming-call' || route.settings.name == '/call') {
        alreadyOnScreen = true;
      }
      return true; // We don't actually want to pop anything here, just check
    });

    if (alreadyOnScreen) {
      debugPrint('ℹ️ Already on call screen, skipping navigation');
      return;
    }

    debugPrint('🚀 Navigating to IncomingCallScreen');
    navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/incoming-call'),
        builder: (context) => const IncomingCallScreen(),
      ),
    );
  }

  // ============================================================
  // SHOW ACTIVE CALL SCREEN
  // ============================================================

  void _showActiveCallScreen() {
    final NavigatorState? navigator =
        navigatorKey.currentState;

    if (navigator == null) {
      debugPrint(
        '⚠️ Navigator not available',
      );

      return;
    }

    _isInCallScreen = true;

    // Avoid pushing duplicate call screens.
    bool alreadyOnCallScreen =
    false;

    navigator.popUntil(
          (route) {
        if (route.settings.name ==
            '/call') {
          alreadyOnCallScreen = true;
        }

        return true;
      },
    );

    if (alreadyOnCallScreen) {
      return;
    }

    navigator.push(
      MaterialPageRoute(
        settings:
        const RouteSettings(
          name: '/call',
        ),
        builder: (context) =>
        const ActiveCallScreen(),
      ),
    );
  }

  // ============================================================
  // REJECT CALL
  // ============================================================

  Future<void> rejectCall() async {
    if (_isRejecting) return;
    
    final String? callId =
        _currentCall?.sId;

    debugPrint(
      '📵 Rejecting call: $callId',
    );

    try {
      _isRejecting = true;
      notifyListeners();

      _stopRinging();
      _stopRingingTimer();

      if (callId == null || callId.isEmpty) {
        debugPrint('⚠️ No call ID while rejecting');
        FlutterCallkitIncoming.endAllCalls();
        _endCallLocally();
        _removeCallScreen();
        return;
      }

      // --------------------------------------------------------
      // STOP CALLKIT
      // --------------------------------------------------------
      await FlutterCallkitIncoming.endCall(
        _getUuidFromCallId(callId),
      );

      // --------------------------------------------------------
      // REJECT API
      // --------------------------------------------------------
      await _callRepository.rejectCall(callId);

      _endCallLocally();
      _removeCallScreen();
    } catch (e) {
      debugPrint('❌ Reject call error: $e');
      _endCallLocally();
      _removeCallScreen();
    } finally {
      _isRejecting = false;
      notifyListeners();
    }
  }

  // ============================================================
  // END CALL
  // ============================================================

  Future<void> endCall() async {
    if (_isEnding) return;

    final String? callId =
        _currentCall?.sId;

    debugPrint(
      '📴 Ending call: $callId',
    );

    try {
      _isEnding = true;
      notifyListeners();
      
      _stopRinging();
      _stopRingingTimer();

      if (callId == null || callId.isEmpty) {
        FlutterCallkitIncoming.endAllCalls();
        _endCallLocally();
        _removeCallScreen();
        return;
      }

      await FlutterCallkitIncoming.endCall(
        _getUuidFromCallId(callId),
      );

      await _callRepository.endCall(callId);

      _endCallLocally();
      _removeCallScreen();
    } catch (e) {
      debugPrint('❌ End call error: $e');
      _endCallLocally();
      _removeCallScreen();
    } finally {
      _isEnding = false;
      notifyListeners();
    }
  }

  // ============================================================
  // REMOVE CALL SCREEN
  // ============================================================

  void _removeCallScreen() {
    final NavigatorState? navigator =
        navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    try {
      // Safety: pop until we reach a non-call route (e.g., home or chat)
      navigator.popUntil((route) {
        final String? name = route.settings.name;
        // If we hit something that ISN'T a call screen, stop popping.
        // This ensures we always leave at least one route (Home) in the stack.
        return name != '/call' && name != '/incoming-call';
      });
    } catch (e) {
      debugPrint('⚠️ Error popping call screen: $e');
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    _isInCallScreen = false;
  }

  // ============================================================
  // RINGING
  // ============================================================

  void _startRinging() {
    try {
      FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
      );
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
    } catch (e) {
      debugPrint('❌ Error starting ringtone/vibration: $e');
    }
  }

  void _stopRinging() {
    try {
      FlutterRingtonePlayer().stop();
      Vibration.cancel();
    } catch (_) {}

    debugPrint(
      '🔕 Ringing stopped',
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final BuildContext? context =
        navigatorKey.currentContext;

    if (context == null) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior:
        SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  // ============================================================
  // CALL HISTORY
  // ============================================================

  Future<void> fetchHistory({
    bool isRefresh = false,
  }) async {
    if (isRefresh) {
      _historyPage = 1;

      _hasMoreHistory = true;

      _callHistory = [];
    }

    if (!_hasMoreHistory ||
        _isHistoryLoading) {
      return;
    }

    _isHistoryLoading = true;

    notifyListeners();

    try {
      final response =
      await _callRepository
          .fetchCallHistory(
        page: _historyPage,
      );

      if (response['success'] ==
          true) {
        final List<dynamic>
        callsData =
        response['calls'];

        final List<CallModel>
        newCalls =
        callsData
            .map(
              (e) =>
              CallModel.fromJson(e),
        )
            .toList();

        if (newCalls.isEmpty) {
          _hasMoreHistory = false;
        } else {
          _callHistory.addAll(
            newCalls,
          );

          final Map<String, CallModel>
          callMap =
          {};

          for (final CallModel call
          in _callHistory) {
            if (call.sId != null) {
              callMap[call.sId!] =
                  call;
            }
          }

          _callHistory =
              callMap.values.toList();

          _callHistory.sort(
                (a, b) {
              final DateTime aTime =
                  DateTime.tryParse(
                    a.createdAt ?? '',
                  ) ??
                      DateTime(0);

              final DateTime bTime =
                  DateTime.tryParse(
                    b.createdAt ?? '',
                  ) ??
                      DateTime(0);

              return bTime.compareTo(
                aTime,
              );
            },
          );

          _historyPage++;
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Error fetching call history: $e',
      );
    } finally {
      _isHistoryLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // AGORA INITIALIZATION
  // ============================================================

  Future<bool> _checkCallPermissions({required bool isVideoCall}) async {
    final List<Permission> permissionsToRequest = [
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];

    try {
      final Map<Permission, PermissionStatus> statuses =
          await permissionsToRequest.request();

      final micStatus = statuses[Permission.microphone];
      final camStatus = statuses[Permission.camera];

      final bool micGranted = micStatus?.isGranted == true;
      final bool cameraGranted = !isVideoCall || (camStatus?.isGranted == true);

      if (!micGranted || !cameraGranted) {
        final bool micPermanentlyDenied = micStatus?.isPermanentlyDenied == true || micStatus?.isRestricted == true;
        final bool camPermanentlyDenied = isVideoCall && (camStatus?.isPermanentlyDenied == true || camStatus?.isRestricted == true);

        final String missing = !micGranted && !cameraGranted
            ? 'Microphone and Camera permissions are'
            : !micGranted
                ? 'Microphone permission is'
                : 'Camera permission is';

        if (micPermanentlyDenied || camPermanentlyDenied) {
          _showError(
            '$missing permanently denied or restricted. Please enable access in Settings to continue.',
            actionLabel: 'Settings',
            onAction: openAppSettings,
          );
        } else {
          _showError('$missing required to make or receive calls.');
        }

        debugPrint('❌ Call permission check failed: mic=$micGranted, cam=$cameraGranted');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting call permissions: $e');
      _showError('Unable to request required call permissions: $e');
      return false;
    }
  }

  Future<bool> _initEngine() async {
    // If already fully initialized and live, return immediately.
    if (_isEngineInitialized && _engine != null) {
      return true;
    }

    // If an initialization is currently in flight, await the existing future to prevent races.
    if (_engineInitCompleter != null) {
      debugPrint('⏳ [AGORA_RTC_STAGE] Engine initialization already in flight, awaiting existing lifecycle');
      return await _engineInitCompleter!;
    }

    _engineInitCompleter = _performEngineInit();
    try {
      final bool success = await _engineInitCompleter!;
      return success;
    } finally {
      _engineInitCompleter = null;
    }
  }

  Future<bool> _performEngineInit() async {
    debugPrint('🚀 [AGORA_RTC_STAGE] Stage 1: Checking permissions');
    final bool isVideoCall = _currentCall?.type == 'video';
    final bool permissionsGranted = await _checkCallPermissions(isVideoCall: isVideoCall);
    if (!permissionsGranted) {
      debugPrint('❌ [AGORA_RTC_STAGE] Stage 1 Failed: Required permissions not granted');
      return false;
    }

    // Clean up any stale or lingering engine instance before creating a fresh one
    if (_engine != null) {
      debugPrint('🧹 [AGORA_RTC_STAGE] Cleaning up stale RTC engine instance before fresh initialization');
      await _disposeEngine();
    }

    RtcEngine? newEngine;
    try {
      debugPrint('🚀 [AGORA_RTC_STAGE] Stage 2: Creating and initializing RtcEngine');
      newEngine = createAgoraRtcEngine();

      await newEngine.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.appId,
          channelProfile:
              ChannelProfileType.channelProfileCommunication,
        ),
      );

      debugPrint('🚀 [AGORA_RTC_STAGE] Stage 3: Registering event handlers');
      newEngine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess:
              (
              RtcConnection connection,
              int elapsed,
              ) {
            debugPrint(
              '✅ [AGORA_RTC] Local user ${connection.localUid} joined channel (elapsed: ${elapsed}ms)',
            );

            _isChannelJoined = true;
            _isJoiningChannel = false;

            newEngine
                ?.setEnableSpeakerphone(
              _isSpeakerOn,
            )
                .then((_) {
              debugPrint(
                '🔊 [AGORA_RTC] Speakerphone set to $_isSpeakerOn on join',
              );
            })
                .catchError(
                  (e) {
                debugPrint(
                  '❌ [AGORA_RTC] Speaker error on join: $e',
                );
              },
            );
          },
          onUserJoined:
              (
              RtcConnection connection,
              int remoteUid,
              int elapsed,
              ) {
            debugPrint(
              '👤 [AGORA_RTC] Remote user joined: $remoteUid (elapsed: ${elapsed}ms)',
            );

            _remoteUid =
                remoteUid;

            notifyListeners();
          },
          onUserOffline:
              (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
              ) {
            debugPrint(
              '👤 [AGORA_RTC] Remote user left: $remoteUid (reason: $reason)',
            );

            _remoteUid = null;
            _remoteVideoMuted = false;

            notifyListeners();

            if (_status ==
                CallStatus.active) {
              endCall();
            }
          },
          onUserMuteAudio: (connection, remoteUid, muted) {
            debugPrint('👤 [AGORA_RTC] Remote user $remoteUid audio muted: $muted');
          },
          onUserMuteVideo: (connection, remoteUid, muted) {
            debugPrint('👤 [AGORA_RTC] Remote user $remoteUid video muted: $muted');
            if (_remoteUid == remoteUid) {
              _remoteVideoMuted = muted;
              notifyListeners();
            }
          },
          onAudioRoutingChanged: (int routing) {
            debugPrint(
              '🔊 [AGORA_RTC] Audio routing changed: $routing (1: earpiece, 3: speakerphone, 4: headset)',
            );
          },
          onFirstRemoteAudioFrame: (connection, userId, elapsed) {
            debugPrint(
              '🎧 [AGORA_RTC] First remote audio frame decoded from user: $userId (elapsed: ${elapsed}ms)',
            );
          },
          onLeaveChannel:
              (
              RtcConnection connection,
              RtcStats stats,
              ) {
            debugPrint(
              '📴 [AGORA_RTC] Local user left channel: ${connection.channelId}',
            );
            _isChannelJoined = false;
            _isJoiningChannel = false;
          },
          onError: (ErrorCodeType err, String msg) async {
            debugPrint('❌ [AGORA_RTC] Engine error: $err - $msg');
            if (err == ErrorCodeType.errTokenExpired ||
                err == ErrorCodeType.errInvalidToken) {
              final success = await _refreshRtcToken();
              if (!success) {
                _showError('Call authentication failed: $msg');
                await endCall();
              }
            }
          },
          onTokenPrivilegeWillExpire:
              (RtcConnection connection, String token) async {
            debugPrint('⚠️ [AGORA_RTC] Token privilege will expire soon');
            await _refreshRtcToken();
          },
          onRequestToken: (RtcConnection connection) async {
            debugPrint('⚠️ [AGORA_RTC] Token expired, requesting fresh token');
            final success = await _refreshRtcToken();
            if (!success) {
              _showError('Call disconnected: authentication token expired.');
              await endCall();
            }
          },
          onConnectionStateChanged: (
            RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason,
          ) async {
            debugPrint('🌐 [AGORA_RTC] Connection state: $state, reason: $reason');
            if (reason ==
                    ConnectionChangedReasonType.connectionChangedTokenExpired ||
                reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidToken) {
              debugPrint(
                '⚠️ [AGORA_RTC] Token expired/invalid reported by connection state change',
              );
              final success = await _refreshRtcToken();
              if (!success) {
                _showError('Call connection lost: invalid or expired session token.');
                await endCall();
              }
            } else if (state == ConnectionStateType.connectionStateFailed) {
              debugPrint('❌ [AGORA_RTC] Connection failed');
              _showError(
                'Call connection failed. Please check your network and try again.',
              );
              await endCall();
            }
          },
        ),
      );

      debugPrint('🚀 [AGORA_RTC_STAGE] Stage 4: Configuring audio subsystems');
      await newEngine.enableAudio();
      await newEngine.enableLocalAudio(true);
      await newEngine.muteLocalAudioStream(_isMuted);
      await newEngine.muteAllRemoteAudioStreams(false);
      await newEngine.adjustRecordingSignalVolume(100);
      await newEngine.adjustPlaybackSignalVolume(100);

      try {
        await newEngine.setDefaultAudioRouteToSpeakerphone(_isSpeakerOn);
      } catch (e) {
        debugPrint('⚠️ [AGORA_RTC_STAGE] Pre-join setDefaultAudioRouteToSpeakerphone warning: $e');
      }

      debugPrint('🚀 [AGORA_RTC_STAGE] Stage 5: Configuring video subsystems (isVideo: $isVideoCall)');
      if (isVideoCall) {
        await newEngine.enableVideo();
        await newEngine.startPreview();
      } else {
        await newEngine.disableVideo();
      }

      // Only assign the initialized instance once all setup stages succeed
      _engine = newEngine;
      _isEngineInitialized = true;
      debugPrint('✅ [AGORA_RTC_STAGE] RTC engine initialization completed successfully');
      return true;
    } catch (e, stack) {
      debugPrint('❌ [AGORA_RTC_STAGE] Engine initialization failed: $e\n$stack');
      _isEngineInitialized = false;
      _engine = null;
      if (newEngine != null) {
        try {
          await newEngine.release();
        } catch (_) {}
      }
      return false;
    }
  }

  // ============================================================
  // REFRESH RTC TOKEN
  // ============================================================

  bool _isRefreshingRtcToken = false;

  Future<bool> _refreshRtcToken() async {
    final callId = _currentCall?.sId;
    if (callId == null || callId.isEmpty) {
      debugPrint('❌ [AGORA_RTC] Cannot refresh token: missing callId');
      return false;
    }

    if (_isRefreshingRtcToken) {
      debugPrint(
        '⏳ [AGORA_RTC] Token refresh already in progress, skipping duplicate request',
      );
      return false;
    }

    _isRefreshingRtcToken = true;
    try {
      debugPrint('🔄 [AGORA_RTC] Fetching fresh token for call: $callId');
      final String freshToken = await _callRepository.getCallToken(callId);
      final trimmedToken = freshToken.trim();

      if (trimmedToken.isEmpty) {
        throw Exception('Received empty token from backend');
      }

      // Ensure current call is still active and unchanged
      if (_currentCall?.sId != callId) {
        debugPrint(
          '⚠️ [AGORA_RTC] Call changed or ended during token refresh. Discarding token.',
        );
        return false;
      }

      _currentCall!.agoraToken = trimmedToken;

      if (_engine != null) {
        await _engine!.renewToken(trimmedToken);
        debugPrint('✅ [AGORA_RTC] Renewed Agora RTC token successfully');
      }
      return true;
    } catch (e) {
      debugPrint('❌ [AGORA_RTC] Failed to refresh token: $e');
      return false;
    } finally {
      _isRefreshingRtcToken = false;
    }
  }

  // ============================================================
  // JOIN AGORA CHANNEL
  // ============================================================

  Future<void> _joinChannel() async {
    if (_currentCall == null) {
      return;
    }

    if (_isChannelJoined || _isJoiningChannel) {
      debugPrint('⚠️ [AGORA_RTC_STAGE] Channel already joined or join in progress, skipping duplicate');
      return;
    }

    // Stage 1: Engine readiness verification
    if (!_isEngineInitialized || _engine == null) {
      debugPrint('🎧 [AGORA_RTC_STAGE] Engine not initialized prior to join, initializing now...');
      final initialized = await _initEngine();
      if (!initialized || _engine == null) {
        debugPrint(
          '❌ [AGORA_RTC_STAGE] Stage 1 Failed: Cannot join channel because engine initialization failed',
        );
        _showError('Unable to initialize call engine. Please check permissions and try again.');
        await endCall();
        return;
      }
    }

    // Stage 2: Media & Token validation
    final String? channelName = _currentCall!.channelName;
    if (channelName == null || channelName.trim().isEmpty) {
      debugPrint('❌ [AGORA_RTC_STAGE] Stage 2 Failed: missing channelName');
      _showError('Unable to connect call: channel name missing.');
      await endCall();
      return;
    }

    var token = _currentCall!.agoraToken?.trim();
    if (token == null || token.isEmpty) {
      final callId = _currentCall!.sId;
      if (callId != null && callId.isNotEmpty) {
        debugPrint(
          '⚠️ [AGORA_RTC_STAGE] agoraToken missing on joinChannel, attempting recovery fetch...',
        );
        final refreshed = await _refreshRtcToken();
        if (refreshed) {
          token = _currentCall!.agoraToken?.trim();
        }
      }
    }

    if (token == null || token.isEmpty) {
      debugPrint(
        '❌ [AGORA_RTC_STAGE] Stage 2 Failed: agoraToken is missing or empty',
      );
      _showError('Unable to connect call: authentication token missing.');
      await endCall();
      return;
    }

    final int? uid = _currentCall!.agoraUid;
    if (uid == null || uid <= 0) {
      debugPrint(
        '❌ [AGORA_RTC_STAGE] Stage 2 Failed: agoraUid missing or invalid ($uid)',
      );
      _showError('Unable to connect call: valid user identifier missing.');
      await endCall();
      return;
    }

    _isJoiningChannel = true;

    // Stage 3: Audio Pre-Routing (Non-fatal if audio routing throws prior to active channel)
    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(_isSpeakerOn);
      debugPrint('🔊 [AGORA_RTC_STAGE] Stage 3: Default audio route configured to speaker: $_isSpeakerOn');
    } catch (e) {
      debugPrint('⚠️ [AGORA_RTC_STAGE] Stage 3 Non-fatal: Pre-join speakerphone warning: $e');
    }

    // Stage 4: Channel Join Execution
    try {
      debugPrint(
        '🎧 [AGORA_RTC_STAGE] Stage 4: Executing joinChannel (channel: ${channelName.trim()}, uid: $uid)',
      );
      final bool isVideo = _currentCall?.type == 'video';

      await _engine!.joinChannel(
        token: token,
        channelId: channelName.trim(),
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: !_isMuted,
          publishCameraTrack: isVideo && !_isVideoOff,
          autoSubscribeAudio: true,
          autoSubscribeVideo: isVideo,
          enableAudioRecordingOrPlayout: true,
        ),
      );
      _isChannelJoined = true;
      _isJoiningChannel = false;
      debugPrint('✅ [AGORA_RTC_STAGE] Stage 4 Success: Joined channel: ${channelName.trim()}');
    } on AgoraRtcException catch (e) {
      _isJoiningChannel = false;
      _isChannelJoined = false;
      debugPrint('❌ [AGORA_RTC_STAGE] Stage 4 AgoraRtcException: code ${e.code}, message: ${e.message}');
      _showError('Failed to join call channel (error ${e.code}).');
      await endCall();
      return;
    } catch (e) {
      _isJoiningChannel = false;
      _isChannelJoined = false;
      debugPrint('❌ [AGORA_RTC_STAGE] Stage 4 Generic Exception: $e');
      _showError('Failed to join call channel: $e');
      await endCall();
      return;
    }

    // Stage 5: Post-Join Speakerphone Enforcement
    try {
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
      debugPrint('🔊 [AGORA_RTC_STAGE] Stage 5: Post-join speakerphone set to $_isSpeakerOn');
    } catch (e) {
      debugPrint('⚠️ [AGORA_RTC_STAGE] Stage 5 Non-fatal: Post-join speakerphone warning: $e');
    }
  }

  // ============================================================
  // MUTE
  // ============================================================

  void toggleMute() {
    _isMuted = !_isMuted;
    debugPrint('🎤 [CALL] Toggling mute: $_isMuted');

    _engine
        ?.muteLocalAudioStream(_isMuted)
        .then((_) {
      debugPrint('🎤 [CALL] Mute updated successfully: $_isMuted');
    }).catchError((e) {
      debugPrint('❌ [CALL] Mute toggle error: $e');
    });

    notifyListeners();
  }

  // ============================================================
  // VIDEO
  // ============================================================

  void toggleVideo() {
    if (_engine == null) return;

    _isVideoOff = !_isVideoOff;
    debugPrint('📹 [CALL] Toggling video: $_isVideoOff');

    () async {
      try {
        if (_isVideoOff) {
          await _engine?.stopPreview();
          await _engine?.enableLocalVideo(false);
        } else {
          await _engine?.enableLocalVideo(true);
          await _engine?.startPreview();
        }

        await _engine?.muteLocalVideoStream(_isVideoOff);
      } catch (e) {
        debugPrint('❌ [CALL] Video toggle error: $e');
      }
    }();

    notifyListeners();
  }

  // ============================================================
  // SPEAKER
  // ============================================================

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    debugPrint('🔊 [CALL] Toggling speaker: $_isSpeakerOn');

    _engine
        ?.setEnableSpeakerphone(_isSpeakerOn)
        .then((_) {
      debugPrint('🔊 [CALL] Speakerphone set to $_isSpeakerOn');
    }).catchError((e) {
      debugPrint('❌ [CALL] Speaker toggle error: $e');
    });

    notifyListeners();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  void switchCamera() {
    debugPrint('📷 [CALL] Switching camera');
    _engine?.switchCamera().then((_) {
      debugPrint('📷 [CALL] Camera switched successfully');
    }).catchError((e) {
      debugPrint('❌ [CALL] Switch camera error: $e');
    });
  }

  // ============================================================
  // DISPOSE AGORA
  // ============================================================

  Future<void> _disposeEngine() async {
    _isEngineInitialized = false;
    final engineToDispose = _engine;
    _engine = null;
    _isChannelJoined = false;
    _isJoiningChannel = false;

    if (engineToDispose != null) {
      try {
        await engineToDispose.leaveChannel();
      } catch (_) {}

      try {
        await engineToDispose.release();
      } catch (_) {}
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callTimer?.cancel();

    _ringingTimer?.cancel();

    _disposeEngine();

    super.dispose();
  }
}