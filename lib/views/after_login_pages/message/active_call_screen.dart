import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActiveCallScreen extends StatelessWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final call = callProvider.currentCall;

    if (call == null) return const SizedBox.shrink();

    final isCaller = call.caller?.sId == HiveService.userId || call.caller?.id == HiveService.userId;
    final partner = isCaller ? call.receiver : call.caller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background/Remote Video
          if (call.type == 'video')
            Positioned.fill(
              child: (callProvider.remoteUid != null && callProvider.engine != null)
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: callProvider.engine!,
                        canvas: VideoCanvas(uid: callProvider.remoteUid),
                        connection: RtcConnection(channelId: call.channelName),
                      ),
                    )
                  : Container(
                      color: Colors.black87,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: partner?.profileImage != null
                                ? NetworkImage(partner!.profileImage!)
                                : null,
                            child: partner?.profileImage == null
                                ? const Icon(Icons.person, size: 60, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 30),
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 20),
                          Text(
                            "Connecting to ${partner?.name ?? 'Partner'}...",
                            style: text16(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      Colors.black,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundImage: partner?.profileImage != null
                          ? NetworkImage(partner!.profileImage!)
                          : null,
                      child: partner?.profileImage == null
                          ? const Icon(Icons.person, size: 80, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      partner?.name ?? "Unknown",
                      style: text28(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      callProvider.status == CallStatus.active 
                        ? callProvider.formattedDuration 
                        : (callProvider.status == CallStatus.ringing ? "Ringing..." : "Connecting..."),
                      style: text18(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Local Video (Small Overlay)
          if (call.type == 'video' && !callProvider.isVideoOff && callProvider.engine != null)
            Positioned(
              right: 20,
              top: 100,
              width: 110,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: callProvider.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

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
                      if (call.type == 'video')
                        Text(
                          partner?.name ?? "",
                          style: text12(color: Colors.white70),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (call.type == 'video' && callProvider.status == CallStatus.active)
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

          // Bottom Controls with Glassmorphism
          Positioned(
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
                        callProvider.isMuted ? Icons.mic_off : Icons.mic,
                        callProvider.isMuted ? Colors.red.withOpacity(0.8) : Colors.white10,
                        callProvider.toggleMute,
                      ),
                      if (call.type == 'video')
                        _buildControl(
                          callProvider.isVideoOff ? Icons.videocam_off : Icons.videocam,
                          callProvider.isVideoOff ? Colors.red.withOpacity(0.8) : Colors.white10,
                          callProvider.toggleVideo,
                        ),
                      _buildControl(
                        Icons.call_end,
                        Colors.red,
                        callProvider.endCall,
                        isLarge: true,
                      ),
                      if (call.type == 'video')
                        _buildControl(
                          Icons.switch_camera,
                          Colors.white10,
                          callProvider.switchCamera,
                        ),
                      _buildControl(
                        callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        callProvider.isSpeakerOn ? Colors.white10 : Colors.orange.withOpacity(0.8),
                        callProvider.toggleSpeaker,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControl(IconData iconData, Color bgColor, VoidCallback onTap,
      {bool isLarge = false, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 65 : 50,
        width: isLarge ? 65 : 50,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: isLarge ? [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: Icon(
          icon ?? iconData,
          color: Colors.white,
          size: isLarge ? 32 : 24,
        ),
      ),
    );
  }
}
