import 'dart:ui';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with TickerProviderStateMixin {
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

    return Scaffold(
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

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Text(
                  callProvider.status == CallStatus.ended ? "CALL ENDED" : "INCOMING CALL",
                  style: text14(
                    color: callProvider.status == CallStatus.ended ? Colors.redAccent : Colors.white70, 
                    fontWeight: FontWeight.bold
                  ).copyWith(letterSpacing: 4),
                ),
                const Spacer(),
                
                // Pulsing Avatar
                AnimatedBuilder(
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
                          backgroundImage: call.caller?.profileImage != null
                              ? NetworkImage(call.caller!.profileImage!)
                              : null,
                          child: call.caller?.profileImage == null
                              ? const Icon(Icons.person, size: 70, color: Colors.white)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                Text(
                  call.caller?.name ?? "Unknown Caller",
                  style: text32(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        call.type == 'video' ? Icons.videocam : Icons.call,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${call.type?.toUpperCase()} CALL",
                        style: text12(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCallAction(
                        Icons.close,
                        "Decline",
                        Colors.redAccent,
                        () => callProvider.rejectCall(),
                      ),
                      _buildCallAction(
                        Icons.check,
                        "Accept",
                        Colors.greenAccent,
                        callProvider.isAccepting 
                          ? null 
                          : () => callProvider.acceptCall(),
                        isLoading: callProvider.isAccepting,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallAction(
      IconData icon, String label, Color color, VoidCallback? onTap, {bool isLoading = false}) {
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
}
