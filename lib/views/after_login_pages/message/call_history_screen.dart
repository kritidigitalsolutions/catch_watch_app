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
                final bool isOutgoing = call.caller?.id == currentUserId || call.caller?.sId == currentUserId;
                final partner = isOutgoing ? call.receiver : call.caller;

                IconData statusIcon;
                Color statusColor;

                switch (call.status?.toLowerCase()) {
                  case 'missed':
                    statusIcon = Icons.call_missed;
                    statusColor = Colors.red;
                    break;
                  case 'rejected':
                  case 'busy':
                    statusIcon = Icons.block;
                    statusColor = Colors.grey;
                    break;
                  default:
                    statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
                    statusColor = call.status == 'ended' ? Colors.green : Colors.grey;
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
                        "${call.type == 'video' ? 'Video' : 'Audio'} • ${_formatDateTime(call.createdAt)}",
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
                        provider.startCall(partner?.sId ?? partner?.id ?? "", call.type ?? 'audio');
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
