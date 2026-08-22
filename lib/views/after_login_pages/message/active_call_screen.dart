import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final call = callProvider.currentCall;

    if (call == null) return const SizedBox.shrink();

    final myId = HiveService.userId;
    final isCaller = callProvider.isCaller || 
                     (call.caller?.sId != null && call.caller?.sId == myId) || 
                     (call.caller?.id != null && call.caller?.id == myId);
                     
    final partner = isCaller ? call.receiver : call.caller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          // Glassmorphism layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

          // Main Content
          if (callProvider.status == CallStatus.active && call.type == 'video')
            _buildVideoUI(context, callProvider, call, partner)
          else
            _buildAudioOrRingingUI(context, callProvider, call, partner),

          // Top Info bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                    onPressed: () {
                      callProvider.setInCallScreen(false);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        call.type == 'video' ? "Video Call" : "Audio Call",
                        style: text16(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        callProvider.status == CallStatus.ringing ? "Incoming..." : (partner?.name ?? ""),
                        style: text12(color: Colors.white70),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (callProvider.status == CallStatus.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        callProvider.formattedDuration,
                        style: text14(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Controls
          if (callProvider.status == CallStatus.ringing && !isCaller)
            _buildIncomingControls(context, callProvider)
          else
            _buildActiveControls(context, callProvider, call),
        ],
      ),
    );
  }

  Widget _buildVideoUI(BuildContext context, CallProvider provider, dynamic call, dynamic partner) {
    return Positioned.fill(
      child: (provider.remoteUid != null && provider.engine != null)
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: provider.engine!,
                canvas: VideoCanvas(uid: provider.remoteUid),
                connection: RtcConnection(channelId: call.channelName),
              ),
            )
          : _buildConnectingUI(partner),
    );
  }

  Widget _buildConnectingUI(dynamic partner) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingAvatar(partner),
          const SizedBox(height: 30),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            "Connecting to ${partner?.name ?? 'Partner'}...",
            style: text16(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOrRingingUI(BuildContext context, CallProvider provider, dynamic call, dynamic partner) {
    return Positioned.fill(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingAvatar(partner),
          const SizedBox(height: 24),
          Text(
            partner?.name ?? "Unknown",
            style: text28(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            provider.status == CallStatus.active 
              ? provider.formattedDuration 
              : (provider.status == CallStatus.ringing ? "Ringing..." : "Connecting..."),
            style: text18(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingAvatar(dynamic partner) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140 + (20 * _pulseController.value),
              height: 140 + (20 * _pulseController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15 * (1 - _pulseController.value)),
              ),
            ),
            Container(
              width: 170 + (30 * _pulseController.value),
              height: 170 + (30 * _pulseController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08 * (1 - _pulseController.value)),
              ),
            ),
            CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white24,
              backgroundImage: partner?.profileImage != null
                  ? NetworkImage(partner!.profileImage!)
                  : null,
              child: partner?.profileImage == null
                  ? const Icon(Icons.person, size: 70, color: Colors.white)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncomingControls(BuildContext context, CallProvider provider) {
    return Positioned(
      bottom: 60,
      left: 40,
      right: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionItem(Icons.close, "Decline", Colors.redAccent, provider.rejectCall),
          _buildActionItem(
            Icons.check, 
            "Accept", 
            Colors.greenAccent, 
            provider.acceptCall,
            isLoading: provider.isAccepting
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap, {bool isLoading = false}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 75,
            width: 75,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(22.0),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
              : Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label, 
          style: text14(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActiveControls(BuildContext context, CallProvider provider, dynamic call) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControl(
                  provider.isMuted ? Icons.mic_off : Icons.mic,
                  provider.isMuted ? Colors.red.withOpacity(0.8) : Colors.white10,
                  provider.toggleMute,
                ),
                if (call.type == 'video')
                  _buildControl(
                    provider.isVideoOff ? Icons.videocam_off : Icons.videocam,
                    provider.isVideoOff ? Colors.red.withOpacity(0.8) : Colors.white10,
                    provider.toggleVideo,
                  ),
                _buildControl(
                  Icons.call_end,
                  Colors.red,
                  provider.endCall,
                  isLarge: true,
                ),
                if (call.type == 'video')
                  _buildControl(
                    Icons.switch_camera,
                    Colors.white10,
                    provider.switchCamera,
                  ),
                _buildControl(
                  provider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  provider.isSpeakerOn ? Colors.white10 : Colors.orange.withOpacity(0.8),
                  provider.toggleSpeaker,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControl(IconData iconData, Color bgColor, VoidCallback onTap, {bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 65 : 50,
        width: isLarge ? 65 : 50,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: isLarge ? 32 : 24,
        ),
      ),
    );
  }
}
