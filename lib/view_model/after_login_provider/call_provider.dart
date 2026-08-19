import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/models/call_model.dart';
import 'package:catch_watch/repository/call_repository.dart';
import 'package:catch_watch/utils/agora_config.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/views/after_login_pages/message/active_call_screen.dart';
import 'package:catch_watch/views/after_login_pages/message/incoming_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';

enum CallStatus { idle, ringing, active, ended }

class CallProvider extends ChangeNotifier {
  final CallRepository _callRepository = CallRepository();
  final SocketService _socketService = SocketService();

  RtcEngine? _engine;
  CallModel? _currentCall;
  CallStatus _status = CallStatus.idle;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  int? _remoteUid;
  bool _isAccepting = false;
  bool _isInCallScreen = false;
  bool _isCaller = false;

  List<CallModel> _callHistory = [];
  bool _isHistoryLoading = false;
  int _historyPage = 1;
  bool _hasMoreHistory = true;

  // Timer fields
  Timer? _callTimer;
  int _durationSeconds = 0;
  
  // Navigation key to show call screens
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  RtcEngine? get engine => _engine;
  CallModel? get currentCall => _currentCall;
  CallStatus get status => _status;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  int? get remoteUid => _remoteUid;
  bool get isAccepting => _isAccepting;
  bool get isInCallScreen => _isInCallScreen;
  bool get isCaller => _isCaller;
  int get durationSeconds => _durationSeconds;

  String get formattedDuration {
    final minutes = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_durationSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  List<CallModel> get callHistory => _callHistory;
  bool get isHistoryLoading => _isHistoryLoading;

  CallProvider() {
    _initSocketListeners();
    _initNotificationListener();
    _initCallKitListener();
  }

  void _startTimer() {
    _durationSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationSeconds++;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    // We keep _durationSeconds for a moment so UI can show final time
  }

  void setInCallScreen(bool value) {
    _isInCallScreen = value;
    notifyListeners();
  }

  void _initCallKitListener() {
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      debugPrint("CallKit Event: ${event.eventName}");
      
      if (event is CallEventActionCallAccept) {
        acceptCall();
      } else if (event is CallEventActionCallDecline) {
        rejectCall();
      } else if (event is CallEventActionCallEnded) {
        endCall();
      }
    });
  }

  void _startRinging() {
    FlutterRingtonePlayer().playRingtone();
    Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
  }

  void _stopRinging() {
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
  }

  void _initNotificationListener() {
    NotificationService.foregroundMessageStream.listen((message) {
      debugPrint("CallProvider: FCM message received: ${message.data}");
      final type = message.data['type'];
      if (type == 'CALL' || type == 'INCOMING_CALL' || message.data['callId'] != null) {
        _handleIncomingCall(message.data);
      }
    });
  }

  void _initSocketListeners() {
    _socketService.messageStream.listen((eventData) {
      final event = eventData['event'];
      final data = eventData['data'];

      debugPrint("Call Socket Event: $event");
      debugPrint("Call Socket Data: $data");

      switch (event) {
        case 'incoming_call':
          _handleIncomingCall(data);
          break;
        case 'call_accepted':
          _handleCallAccepted(data);
          break;
        case 'call_rejected':
        case 'call_ended':
        case 'call_cancelled':
        case 'call_busy':
        case 'call_missed':
          _handleCallEnd(data);
          break;
      }
    });
  }

  String? _extractCallId(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      return (data['_id'] ?? data['id'] ?? data['callId'])?.toString();
    }
    return null;
  }

  Future<void> _handleIncomingCall(dynamic data) async {
    debugPrint("Handling incoming call payload: $data");
    
    final incomingCallId = _extractCallId(data);
    if (incomingCallId == null) {
      debugPrint("Error: Could not extract call ID from incoming call data");
      return;
    }

    // AVOID DUPLICATE EVENTS: If we already have this call active/ringing, ignore the duplicate event
    debugPrint("Duplicate Check: Current ID: ${_currentCall?.sId}, Incoming ID: $incomingCallId");
    if (_currentCall?.sId == incomingCallId) {
      debugPrint("Ignoring duplicate incoming call event for $incomingCallId");
      return;
    }

    if (_status != CallStatus.idle) {
      debugPrint("User is already in another call (Status: $_status), marking incoming call $incomingCallId as busy");
      await _callRepository.busyCall(incomingCallId);
      return;
    }

    _isCaller = false;
    if (data is Map) {
      _currentCall = CallModel.fromJson(Map<String, dynamic>.from(data));
      // Ensure sId is set if it was missing in Map but we extracted it via _extractCallId
      _currentCall!.sId ??= incomingCallId;
    } else {
      debugPrint("Incoming call data is not a Map, attempting to fetch details for $incomingCallId");
      try {
        _currentCall = await _callRepository.getCallDetails(incomingCallId);
        _currentCall!.sId ??= incomingCallId;
      } catch (e) {
        debugPrint("Error fetching incoming call details: $e");
        return;
      }
    }

    debugPrint("Current call set with ID: ${_currentCall?.sId}");
    _status = CallStatus.ringing;
    _startRinging();
    notifyListeners();
    
    debugPrint("Showing IncomingCallScreen");
    _isInCallScreen = true;
    // Show IncomingCallScreen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/call'),
        builder: (context) => const IncomingCallScreen(),
      ),
    );
  }

  void _handleCallAccepted(dynamic data) {
    final acceptedCallId = _extractCallId(data);
    debugPrint("Call accepted event received for ID: $acceptedCallId");
    
    if (_currentCall?.sId == acceptedCallId || acceptedCallId != null) {
      _status = CallStatus.active;
      _stopRinging();
      _startTimer();
      _joinChannel();
      notifyListeners();
    }
  }

  void _handleCallEnd(dynamic data) {
    final endedCallId = _extractCallId(data);
    debugPrint("Call ended/rejected event received for ID: $endedCallId. Current call ID: ${_currentCall?.sId}");

    // If ID matches, or if we are in a call and receive an end event without specific ID (broadcast)
    if (_currentCall?.sId == endedCallId || (_currentCall != null && endedCallId == null)) {
      debugPrint("Ending call locally and popping screens");
      _stopRinging();
      _stopTimer();
      _endCallLocally();
      // Pop call screens if any are currently pushed
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
      _isInCallScreen = false;
      notifyListeners();
    }
  }

  void _endCallLocally() {
    _status = CallStatus.ended;
    notifyListeners();
    
    Future.delayed(const Duration(seconds: 2), () {
      // Only clear if the status is still 'ended' (meaning no new call started)
      if (_status == CallStatus.ended) {
        _status = CallStatus.idle;
        _currentCall = null;
        _remoteUid = null;
        _durationSeconds = 0;
        _disposeEngine();
        notifyListeners();
      }
    });
  }

  Future<void> startCall(String receiverId, String type, {String? partnerName, String? partnerImage}) async {
    try {
      debugPrint("Starting $type call to $receiverId");
      _isCaller = true;
      _status = CallStatus.ringing;
      notifyListeners();

      final call = await _callRepository.startCall(receiverId, type);
      _currentCall = call;
      
      // Enrich receiver data if metadata was provided
      if (_currentCall?.receiver != null && partnerName != null) {
        _currentCall!.receiver!.name = partnerName;
        _currentCall!.receiver!.profileImage = partnerImage;
      }
      
      debugPrint("Call started successfully: ${_currentCall?.sId}");
      
      _isInCallScreen = true;
      // Show ActiveCallScreen (as "Calling...") immediately
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/call'),
          builder: (context) => const ActiveCallScreen(),
        ),
      );

      // Initialize engine in background
      _initEngine().then((_) {
        debugPrint("Agora engine initialized for caller");
      }).catchError((e) {
        debugPrint("Error initializing Agora engine: $e");
      });
      
      notifyListeners();
    } catch (e) {
      _status = CallStatus.idle;
      notifyListeners();
      debugPrint("Error starting call: $e");
      _showError(e.toString());
    }
  }

  Future<void> fetchHistory({bool isRefresh = false}) async {
    if (isRefresh) {
      _historyPage = 1;
      _hasMoreHistory = true;
      _callHistory = [];
    }

    if (!_hasMoreHistory || _isHistoryLoading) return;

    _isHistoryLoading = true;
    notifyListeners();

    try {
      final response = await _callRepository.fetchCallHistory(page: _historyPage);
      if (response['success'] == true) {
        final List<dynamic> callsData = response['calls'];
        final newCalls = callsData.map((e) => CallModel.fromJson(e)).toList();
        
        if (newCalls.isEmpty) {
          _hasMoreHistory = false;
        } else {
          _callHistory.addAll(newCalls);
          _historyPage++;
        }
      }
    } catch (e) {
      debugPrint("Error fetching call history: $e");
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  void _showError(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> acceptCall() async {
    if (_currentCall == null || _isAccepting) {
      debugPrint("AcceptCall aborted: _currentCall is ${_currentCall == null ? 'NULL' : 'NOT NULL'}, _isAccepting is $_isAccepting");
      return;
    }
    
    final String? callId = _currentCall!.sId;
    if (callId == null) {
      debugPrint("Error: Current call has no ID. Data: ${_currentCall!.toJson()}");
      _showError("Cannot accept call: Missing ID");
      return;
    }

    try {
      _isAccepting = true;
      notifyListeners();

      debugPrint("Accepting call via API: $callId");
      final updatedCall = await _callRepository.acceptCall(callId);
      
      // Merge updated call data but preserve sId if missing
      _currentCall = updatedCall;
      _currentCall!.sId ??= callId;
      
      _status = CallStatus.active;
      _stopRinging();
      _startTimer();
      
      debugPrint("Initializing Agora engine for receiver...");
      await _initEngine();
      
      debugPrint("Joining channel: ${_currentCall!.channelName} with token: ${_currentCall!.agoraToken}");
      await _joinChannel();
      
      _isAccepting = false;
      notifyListeners();

      // Replace IncomingCallScreen with ActiveCallScreen
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/call'),
          builder: (context) => const ActiveCallScreen(),
        ),
      );
    } catch (e) {
      _isAccepting = false;
      notifyListeners();
      debugPrint("Error accepting call: $e");
      _showError("Failed to accept call: $e");
    }
  }

  Future<void> rejectCall() async {
    final callId = _currentCall?.sId;
    debugPrint("Rejecting call: $callId");
    
    _stopRinging();
    if (callId == null) {
      debugPrint("Error: No active call to reject");
      _endCallLocally();
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
      return;
    }

    try {
      await _callRepository.rejectCall(callId);
      _endCallLocally();
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
    } catch (e) {
      debugPrint("Error rejecting call: $e");
      _endCallLocally();
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
    }
  }

  Future<void> endCall() async {
    final callId = _currentCall?.sId;
    debugPrint("Ending call: $callId");

    _stopRinging();
    if (callId == null) {
      debugPrint("Error: No active call to end");
      _endCallLocally();
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
      return;
    }

    try {
      await _callRepository.endCall(callId);
      _endCallLocally();
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
    } catch (e) {
      debugPrint("Error ending call: $e");
      _endCallLocally(); // Force end locally if API fails
      navigatorKey.currentState?.popUntil((route) => route.settings.name != '/call');
    }
  }

  Future<void> _initEngine() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          _engine!.setEnableSpeakerphone(_isSpeakerOn).catchError((e) {
            debugPrint("Error setting speakerphone in handler: $e");
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          _remoteUid = remoteUid;
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left");
          _remoteUid = null;
          notifyListeners();
          if (_status == CallStatus.active) {
            endCall();
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("Local user left channel");
        },
      ),
    );

    if (_currentCall?.type == 'video') {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }
  }

  Future<void> _joinChannel() async {
    if (_engine == null || _currentCall == null) return;

    await _engine!.joinChannel(
      token: _currentCall!.agoraToken ?? "",
      channelId: _currentCall!.channelName!,
      uid: _currentCall!.agoraUid ?? (int.tryParse(HiveService.userId ?? "0") ?? 0),
      options: const ChannelMediaOptions(),
    );
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _engine?.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    _engine?.muteLocalVideoStream(_isVideoOff);
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  void switchCamera() {
    _engine?.switchCamera();
  }

  void _disposeEngine() {
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
  }

  @override
  void dispose() {
    _disposeEngine();
    super.dispose();
  }
}
