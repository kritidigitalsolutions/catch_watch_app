import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/vip_support_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/vip_support/create_ticket_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/vip_support/ticket_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class VipSupportScreen extends StatefulWidget {
  const VipSupportScreen({super.key});

  @override
  State<VipSupportScreen> createState() => _VipSupportScreenState();
}

class _VipSupportScreenState extends State<VipSupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VipSupportProvider>().fetchMyTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('VIP Support', style: text18(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<VipSupportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.tickets.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchMyTickets(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.tickets.length,
              itemBuilder: (context, index) {
                final ticket = provider.tickets[index];
                return _TicketCard(ticket: ticket);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Ticket', style: text14(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent_rounded, size: 80, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            'No support tickets yet',
            style: text16(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Need help? Create a new ticket and\nour VIP support team will assist you.',
            textAlign: TextAlign.center,
            style: text14(color: AppColors.grey500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: const Text('Create Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final dynamic ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (ticket.status?.toLowerCase()) {
      case 'open':
        statusColor = AppColors.info;
        break;
      case 'in_progress':
        statusColor = AppColors.warning;
        break;
      case 'resolved':
        statusColor = AppColors.success;
        break;
      case 'closed':
        statusColor = AppColors.grey600;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.grey200),
      ),
      child: InkWell(
        onTap: () {
          context.read<VipSupportProvider>().setSelectedTicket(ticket);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket.id!)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.status?.replaceAll('_', ' ').toUpperCase() ?? 'OPEN',
                      style: text10(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if ((ticket.unreadByUser ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ticket.unreadByUser}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(DateTime.parse(ticket.createdAt ?? DateTime.now().toString())),
                    style: text12(color: AppColors.grey500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.subject ?? 'No Subject',
                style: text16(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Category: ${ticket.category?.replaceAll('_', ' ')}',
                style: text13(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.priority_high_rounded, size: 14, color: _getPriorityColor(ticket.priority)),
                  const SizedBox(width: 4),
                  Text(
                    ticket.priority ?? 'MEDIUM',
                    style: text12(
                      color: _getPriorityColor(ticket.priority),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Text('View Chat', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.grey600;
    }
  }
}
