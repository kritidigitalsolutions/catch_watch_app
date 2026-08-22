import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/views/after_login_pages/message/active_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CallOverlay extends StatelessWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Consumer<CallProvider>(
          builder: (context, provider, _) {
            final call = provider.currentCall;
            final isVisible = provider.status == CallStatus.active && 
                              !provider.isInCallScreen;

            if (!isVisible || call == null) return const SizedBox.shrink();

            return Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    provider.setInCallScreen(true);
                    Navigator.push(
                      provider.navigatorKey.currentContext!,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/call'),
                        builder: (context) => const ActiveCallScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.call, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    provider.status == CallStatus.ringing ? "Incoming Call" : "Active Call",
                                    style: text10(color: Colors.white70),
                                  ),
                                  if (provider.status == CallStatus.active) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      "• ${provider.formattedDuration}",
                                      style: text10(color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                (call.caller?.sId == HiveService.userId || call.caller?.id == HiveService.userId)
                                    ? (call.receiver?.name ?? "User")
                                    : (call.caller?.name ?? "User"),
                                style: text14(color: Colors.white, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            provider.isMuted ? Icons.mic_off : Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: provider.toggleMute,
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.red, size: 24),
                          onPressed: () {
                            if (provider.status == CallStatus.ringing) {
                              provider.rejectCall();
                            } else {
                              provider.endCall();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
