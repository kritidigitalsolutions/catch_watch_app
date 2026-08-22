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
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

enum CallStatus {
  idle,
  ringing,
  active,
  ended,
}

class CallProvider extends ChangeNotifier {
  final CallRepository _callRepository =
  CallRepository();

  final SocketService _socketService =
  SocketService();

  RtcEngine? _engine;

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
      _engine;

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
    _initSocketListeners();
    _initNotificationListener();
    _initCallKitListener();
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
  // UUID
  // ============================================================

  String _getUuidFromCallId(
      String callId,
      ) {
    return const Uuid().v5(
      Uuid.NAMESPACE_URL,
      callId,
    );
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
    try {
      final String? callId =
      _extractCallIdFromCallKitEvent(
        event,
      );

      debugPrint(
        '📞 CallKit ACCEPT',
      );

      debugPrint(
        'Call ID: $callId',
      );

      // --------------------------------------------------------
      // If current call is already loaded, use it.
      // --------------------------------------------------------

      if (_currentCall != null &&
          _currentCall!.sId != null) {
        await acceptCall();

        return;
      }

      // --------------------------------------------------------
      // Otherwise fetch call details.
      // This is important when the app was terminated.
      // --------------------------------------------------------

      if (callId == null) {
        debugPrint(
          '❌ CallKit accept: no call ID',
        );

        return;
      }

      debugPrint(
        '📥 Fetching call details for '
            '$callId',
      );

      final CallModel call =
      await _callRepository
          .getCallDetails(
        callId,
      );

      call.sId ??= callId;

      _currentCall = call;

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
    }
  }

  // ============================================================
  // CALLKIT DECLINE
  // ============================================================

  Future<void> _handleCallKitDecline(
      CallEventActionCallDecline event,
      ) async {
    try {
      debugPrint(
        '📞 CallKit DECLINE',
      );

      final String? callId =
      _extractCallIdFromCallKitEvent(
        event,
      );

      if (_currentCall == null &&
          callId != null) {
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
    }
  }

  // ============================================================
  // EXTRACT CALL ID FROM CALLKIT EVENT
  // ============================================================

  String? _extractCallIdFromCallKitEvent(
      dynamic event,
      ) {
    try {
      final dynamic body =
          event.body;

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
            '📞 Incoming call already handled '
                'by CallKit',
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

      _joinChannel();

      notifyListeners();

      // If we are the receiver and were on incoming screen, transition to active screen
      if (!_isCaller && _status == CallStatus.active && _isInCallScreen) {
        final NavigatorState? navigator = navigatorKey.currentState;
        if (navigator != null) {
          bool onIncoming = false;
          navigator.popUntil((route) {
            if (route.settings.name == '/incoming-call') {
              onIncoming = true;
            }
            return true;
          });

          if (onIncoming) {
            navigator.pushReplacement(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/call'),
                builder: (context) => const ActiveCallScreen(),
              ),
            );
          }
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

      if (_isInCallScreen) {
        navigatorKey.currentState
            ?.popUntil(
              (route) =>
          route.settings.name !=
              '/call',
        );

        _isInCallScreen = false;
      }

      notifyListeners();
    }
  }

  // ============================================================
  // END LOCALLY
  // ============================================================

  void _endCallLocally() {
    _status =
        CallStatus.ended;

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

          _disposeEngine();

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

      _isCaller = true;

      _status =
          CallStatus.ringing;

      notifyListeners();

      final CallModel call =
      await _callRepository.startCall(
        receiverId,
        type,
      );

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

      _initEngine()
          .then(
            (_) {
          debugPrint(
            '✅ Agora initialized',
          );
        },
      )
          .catchError(
            (e) {
          debugPrint(
            '❌ Agora init error: $e',
          );
        },
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
    if (_isAccepting) {
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

      _currentCall =
          updatedCall;

      _currentCall!.sId ??=
          callId;

      _status =
          CallStatus.active;

      _stopRinging();

      _stopRingingTimer();

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

      await _initEngine();

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
        navigator.pushReplacement(
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
    }
  }

  // ============================================================
  // SHOW INCOMING CALL SCREEN
  // ============================================================

  void _showIncomingCallScreen() {
    final NavigatorState? navigator = navigatorKey.currentState;

    if (navigator == null) {
      debugPrint('⚠️ Navigator not available');
      return;
    }

    _isInCallScreen = true;

    // Avoid pushing duplicate screens
    bool alreadyOnScreen = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/incoming-call' || route.settings.name == '/call') {
        alreadyOnScreen = true;
      }
      return true;
    });

    if (alreadyOnScreen) return;

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

    if (!_isInCallScreen) {
      return;
    }

    navigator.popUntil(
          (route) =>
      route.settings.name != '/call' && route.settings.name != '/incoming-call',
    );

    _isInCallScreen = false;
  }

  // ============================================================
  // RINGING
  // ============================================================

  void _startRinging() {
    // DO NOT start FlutterRingtonePlayer here.
    //
    // flutter_callkit_incoming is responsible for:
    //
    // - ringtone
    // - vibration
    // - lock screen
    // - full screen
    //
    // Keeping another ringtone here can cause double ringtone
    // or fail when the Flutter process is terminated.
    debugPrint(
      '🔔 Ringtone handled by CallKit',
    );
  }

  void _stopRinging() {
    // CallKit handles the ringtone.
    //
    // Keep vibration cancellation as a safety cleanup.
    try {
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
      String message,
      ) {
    final BuildContext? context =
        navigatorKey.currentContext;

    if (context == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior:
        SnackBarBehavior.floating,
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

  Future<void> _initEngine() async {
    if (_engine != null) {
      return;
    }

    await [
      Permission.microphone,
      Permission.camera,
    ].request();

    _engine =
        createAgoraRtcEngine();

    await _engine!.initialize(
      const RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile:
        ChannelProfileType
            .channelProfileCommunication,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess:
            (
            RtcConnection connection,
            int elapsed,
            ) {
          debugPrint(
            '✅ Local user '
                '${connection.localUid} joined',
          );

          _engine!
              .setEnableSpeakerphone(
            _isSpeakerOn,
          )
              .catchError(
                (e) {
              debugPrint(
                '❌ Speaker error: $e',
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
            '👤 Remote user joined: '
                '$remoteUid',
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
            '👤 Remote user left: '
                '$remoteUid',
          );

          _remoteUid = null;
          _remoteVideoMuted = false;

          notifyListeners();

          if (_status ==
              CallStatus.active) {
            endCall();
          }
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          debugPrint('👤 Remote user video mute: $muted');
          if (_remoteUid == remoteUid) {
            _remoteVideoMuted = muted;
            notifyListeners();
          }
        },
        onLeaveChannel:
            (
            RtcConnection connection,
            RtcStats stats,
            ) {
          debugPrint(
            '📴 Local user left channel',
          );
        },
      ),
    );

    // ----------------------------------------------------------
    // VIDEO
    // ----------------------------------------------------------

    if (_currentCall?.type ==
        'video') {
      await _engine!.enableVideo();

      await _engine!
          .startPreview();
    } else {
      await _engine!
          .disableVideo();
    }
  }

  // ============================================================
  // JOIN AGORA CHANNEL
  // ============================================================

  Future<void> _joinChannel() async {
    if (_engine == null ||
        _currentCall == null) {
      return;
    }

    final String? channelName =
        _currentCall!.channelName;

    if (channelName == null ||
        channelName.isEmpty) {
      throw Exception(
        'Agora channel name is missing',
      );
    }

    await _engine!.joinChannel(
      token:
      _currentCall!.agoraToken ??
          '',
      channelId:
      channelName,
      uid:
      _currentCall!.agoraUid ??
          (int.tryParse(
            HiveService.userId ??
                '0',
          ) ??
              0),
      options:
      const ChannelMediaOptions(),
    );
  }

  // ============================================================
  // MUTE
  // ============================================================

  void toggleMute() {
    _isMuted =
    !_isMuted;

    _engine
        ?.muteLocalAudioStream(
      _isMuted,
    );

    notifyListeners();
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Future<void> toggleVideo() async {
    if (_engine == null) return;
    
    _isVideoOff = !_isVideoOff;

    if (_isVideoOff) {
      await _engine?.stopPreview();
      await _engine?.enableLocalVideo(false);
    } else {
      await _engine?.enableLocalVideo(true);
      await _engine?.startPreview();
    }

    await _engine?.muteLocalVideoStream(_isVideoOff);

    notifyListeners();
  }

  // ============================================================
  // SPEAKER
  // ============================================================

  void toggleSpeaker() {
    _isSpeakerOn =
    !_isSpeakerOn;

    debugPrint('🔊 Toggling speaker: $_isSpeakerOn');

    _engine
        ?.setEnableSpeakerphone(
      _isSpeakerOn,
    )
        .then((_) {
      debugPrint('🔊 Speakerphone set to $_isSpeakerOn');
    })
        .catchError((e) {
      debugPrint('❌ Speaker toggle error: $e');
    });

    notifyListeners();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  void switchCamera() {
    _engine?.switchCamera();
  }

  // ============================================================
  // DISPOSE AGORA
  // ============================================================

  void _disposeEngine() {
    try {
      _engine?.leaveChannel();
    } catch (_) {}

    try {
      _engine?.release();
    } catch (_) {}

    _engine = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _callTimer?.cancel();

    _ringingTimer?.cancel();

    _disposeEngine();

    super.dispose();
  }
}