import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CallProvider>(context, listen: false).fetchHistory(isRefresh: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        Provider.of<CallProvider>(context, listen: false).fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return "";
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        return DateFormat('hh:mm a').format(dateTime);
      }
      return DateFormat('dd MMM, hh:mm a').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = HiveService.userId;
    final currentUserName = HiveService.getUser()?.name;

    bool isMe(dynamic person) {
      if (person == null) return false;
      String? pid;
      String? pName;
      
      // In CallModel, caller/receiver are Sender objects
      if (person is String) {
        pid = person;
      } else {
        pid = person.sId ?? person.id;
        pName = person.name;
      }

      if (pid != null && currentUserId != null && pid == currentUserId) return true;
      if (pName != null && currentUserName != null && 
          pName.toLowerCase().trim() == currentUserName.toLowerCase().trim()) return true;
      return false;
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text("Call History", style: text18(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<CallProvider>(
        builder: (context, provider, child) {
          if (provider.isHistoryLoading && provider.callHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.callHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call_end_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("No call history yet", style: text16(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchHistory(isRefresh: true),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: provider.callHistory.length + (provider.isHistoryLoading ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                if (index == provider.callHistory.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final call = provider.callHistory[index];

                // Robust check if current user is caller or receiver
                final bool isCurrentUserCaller = isMe(call.caller);
                final bool isCurrentUserReceiver = isMe(call.receiver);

                // The partner is the participant who is NOT me
                dynamic partner;
                if (isCurrentUserCaller) {
                  partner = call.receiver;
                } else if (isCurrentUserReceiver) {
                  partner = call.caller;
                } else {
                  // Fallback: If caller looks like me, partner is receiver. Otherwise caller.
                  partner = isMe(call.caller) ? call.receiver : call.caller;
                }

                // If partner resolved to me (e.g. calling yourself), or is still null, 
                // try to find the one that is definitely NOT me
                if (isMe(partner)) {
                  if (!isMe(call.caller)) {
                    partner = call.caller;
                  } else if (!isMe(call.receiver)) {
                    partner = call.receiver;
                  }
                }

                IconData statusIcon;
                Color statusColor;
                String statusText = "";

                final status = call.status?.toLowerCase() ?? "";
                final bool isOutgoing = isCurrentUserCaller;

                if (status == 'missed') {
                  statusIcon = Icons.call_missed;
                  statusColor = Colors.red;
                  statusText = "Missed";
                } else if (status == 'rejected' || status == 'busy') {
                  statusIcon = Icons.block;
                  statusColor = Colors.grey;
                  statusText = status == 'busy' ? "Busy" : "Rejected";
                } else if (status == 'cancelled') {
                  if (isOutgoing) {
                    statusIcon = Icons.call_made;
                    statusColor = Colors.grey;
                    statusText = "Cancelled";
                  } else {
                    statusIcon = Icons.call_missed;
                    statusColor = Colors.red;
                    statusText = "Missed";
                  }
                } else if (status == 'ended') {
                  statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
                  statusColor = Colors.green;
                  statusText = isOutgoing ? "Outgoing" : "Incoming";
                } else {
                  statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
                  statusColor = Colors.grey;
                  statusText = isOutgoing ? "Outgoing" : "Incoming";
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: partner?.profileImage != null && partner!.profileImage!.isNotEmpty
                        ? NetworkImage(partner.profileImage!)
                        : null,
                    child: partner?.profileImage == null || partner!.profileImage!.isEmpty
                        ? const Icon(Icons.person, size: 25)
                        : null,
                  ),
                  title: Text(
                    partner?.name ?? "Unknown",
                    style: text16(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        "$statusText • ${call.type == 'video' ? 'Video' : 'Audio'} • ${_formatDateTime(call.createdAt)}",
                        style: text12(color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      call.type == 'video' ? Icons.videocam_outlined : Icons.call_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      if (partner?.sId != null || partner?.id != null) {
                        provider.startCall(
                          partner?.sId ?? partner?.id ?? "", 
                          call.type ?? 'audio',
                          partnerName: partner?.name,
                          partnerImage: partner?.profileImage,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
