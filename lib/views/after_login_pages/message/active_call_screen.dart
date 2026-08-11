import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:catch_watch/res/app_colors.dart';
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          if (call.type == 'video')
            Center(
              child: (callProvider.remoteUid != null && callProvider.engine != null)
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: callProvider.engine!,
                        canvas: VideoCanvas(uid: callProvider.remoteUid),
                        connection: RtcConnection(channelId: call.channelName),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          "Connecting...",
                          style: text16(color: Colors.white),
                        ),
                      ],
                    ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: call.receiver?.profileImage != null
                        ? NetworkImage(call.receiver!.profileImage!)
                        : null,
                    child: call.receiver?.profileImage == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    callProvider.remoteUid != null ? "Connected" : "Calling...",
                    style: text18(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Local Video (Small Overlay)
          if (call.type == 'video' && !callProvider.isVideoOff && callProvider.engine != null)
            Positioned(
              right: 20,
              top: 50,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: callProvider.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),

          // Top Info
          Positioned(
            top: 50,
            left: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  onPressed: () {
                    callProvider.setInCallScreen(false);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  call.type == 'video' ? "Video Call" : "Audio Call",
                  style: text16(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControl(
                  callProvider.isMuted ? Icons.mic_off : Icons.mic,
                  callProvider.isMuted ? Colors.red : Colors.white24,
                  callProvider.toggleMute,
                ),
                if (call.type == 'video')
                  _buildControl(
                    callProvider.isVideoOff ? Icons.videocam_off : Icons.videocam,
                    callProvider.isVideoOff ? Colors.red : Colors.white24,
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
                    Colors.white24,
                    callProvider.switchCamera,
                  ),
                _buildControl(
                  callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  callProvider.isSpeakerOn ? Colors.white24 : Colors.red,
                  callProvider.toggleSpeaker,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControl(IconData icon, Color bgColor, VoidCallback onTap,
      {bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 16 : 12),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isLarge ? 32 : 24,
        ),
      ),
    );
  }
}
