import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/wallet_provider.dart';
import '../../../models/wallet_model.dart';

class RedeemHistoryScreen extends StatefulWidget {
  const RedeemHistoryScreen({super.key});

  @override
  State<RedeemHistoryScreen> createState() => _RedeemHistoryScreenState();
}

class _RedeemHistoryScreenState extends State<RedeemHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchRedeemHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Redeem History", style: text18(fontWeight: FontWeight.w800)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: text14(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Active Requests"),
            Tab(text: "Processed History"),
          ],
        ),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.redeemHistory.isEmpty && provider.redeemRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(provider.redeemRequests),
              _buildList(provider.redeemHistory),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<RedeemHistory> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppColors.grey200),
            const SizedBox(height: 16),
            Text("No records found", style: text14(color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RedeemCard(item: item);
      },
    );
  }
}

class _RedeemCard extends StatelessWidget {
  final RedeemHistory item;
  const _RedeemCard({required this.item});

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING': return Colors.orange;
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return AppColors.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpi = item.paymentDetails?.paymentMethod == "UPI";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item.points} Points",
                    style: text16(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  Text(
                    "₹${item.amount}",
                    style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status ?? 'UNKNOWN',
                  style: text10(color: _getStatusColor(item.status), fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.grey100),
          ),
          Row(
            children: [
              Icon(isUpi ? Icons.account_balance_wallet_rounded : Icons.account_balance_rounded, size: 16, color: AppColors.grey600),
              const SizedBox(width: 8),
              Text(
                isUpi ? "UPI: ${item.paymentDetails?.upiId}" : "Bank: ${item.paymentDetails?.accountNumber}",
                style: text12(color: AppColors.grey700, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.grey400),
              const SizedBox(width: 8),
              Text(
                item.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt!) : '',
                style: text11(color: AppColors.grey500),
              ),
            ],
          ),
          if (item.status == 'REJECTED' && item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Text(
                "Reason: ${item.rejectionReason}",
                style: text11(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          if (item.adminRemark != null && item.adminRemark!.isNotEmpty) ...[
             const SizedBox(height: 12),
            Text(
              "Note: ${item.adminRemark}",
              style: text11(color: AppColors.grey600).copyWith(fontStyle: FontStyle.italic),
            ),
          ]
        ],
      ),
    );
  }
}
