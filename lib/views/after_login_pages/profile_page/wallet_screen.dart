import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _redeemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _redeemController.dispose();
    super.dispose();
  }

  void _showRedeemDialog(ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Redeem Points", style: text18(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter the number of points you want to redeem.", style: text12(color: AppColors.grey600)),
            const SizedBox(height: 16),
            TextField(
              controller: _redeemController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter points",
                hintStyle: text14(color: AppColors.grey400),
                filled: true,
                fillColor: AppColors.grey50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(Icons.stars_rounded, color: AppColors.yellow),
              ),
            ),
            const SizedBox(height: 8),
            Text("Available: ${provider.totalPoints} Points", style: text10(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: text14(color: AppColors.grey600)),
          ),
          ElevatedButton(
            onPressed: () {
              final points = int.tryParse(_redeemController.text);
              if (points != null && points > 0 && points <= provider.totalPoints) {
                provider.redeemPoints(points);
                _redeemController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$points Points redeemed successfully!"),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid points entered"), backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Redeem", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("My Points Wallet", style: text20(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(provider),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Points History", style: text18(fontWeight: FontWeight.w800)),
                  Text("All Transactions", style: text12(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTransactionList(provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ProfileProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black, Color(0xFF2C2C2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Available Points", style: text14(color: Colors.white70)),
              const Icon(Icons.stars_rounded, color: AppColors.yellow, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.totalPoints.toString(),
            style: text30(color: Colors.white, fontWeight: FontWeight.w900).copyWith(fontSize: 40),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showRedeemDialog(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Redeem Points", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ProfileProvider provider) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.transactionHistory.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.grey100),
      itemBuilder: (context, index) {
        final tx = provider.transactionHistory[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tx['isCredit'] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx['isCredit'] ? Icons.add_rounded : Icons.remove_rounded,
              color: tx['isCredit'] ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text(tx['title'], style: text14(fontWeight: FontWeight.w600)),
          subtitle: Text(tx['date'], style: text12(color: AppColors.grey500)),
          trailing: Text(
            "${tx['amount']} Pts",
            style: text14(
              fontWeight: FontWeight.w900,
              color: tx['isCredit'] ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }
}
