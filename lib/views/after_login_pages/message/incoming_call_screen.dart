import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final call = callProvider.currentCall;

    if (call == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundImage: call.caller?.profileImage != null
                  ? NetworkImage(call.caller!.profileImage!)
                  : null,
              child: call.caller?.profileImage == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              call.caller?.name ?? "Unknown Caller",
              style: text24(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Incoming ${call.type} call...",
              style: text16(color: Colors.white70),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallAction(
                  Icons.close,
                  "Reject",
                  Colors.red,
                  () => callProvider.rejectCall(),
                ),
                _buildCallAction(
                  Icons.check,
                  "Accept",
                  Colors.green,
                  callProvider.isAccepting 
                    ? null 
                    : () => callProvider.acceptCall(),
                  isLoading: callProvider.isAccepting,
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
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
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
              : Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: text14(color: Colors.white)),
      ],
    );
  }
}
