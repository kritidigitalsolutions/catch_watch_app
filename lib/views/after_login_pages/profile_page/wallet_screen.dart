import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/wallet_provider.dart';
import 'package:intl/intl.dart';
import 'redeem_history_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchWalletSummary();
      context.read<WalletProvider>().fetchPointsSummary();
      context.read<WalletProvider>().fetchPointHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _redeemController.dispose();
    super.dispose();
  }

  void _showRedeemDialog(WalletProvider provider) {
    String paymentMethod = "UPI";
    final TextEditingController accountHolderController = TextEditingController();
    final TextEditingController upiIdController = TextEditingController();
    final TextEditingController accountNumberController = TextEditingController();
    final TextEditingController ifscController = TextEditingController();
    final TextEditingController bankNameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Redeem Points", style: text18(fontWeight: FontWeight.w800)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Enter the number of points you want to redeem.", style: text12(color: AppColors.grey600)),
                const SizedBox(height: 8),
                _buildTextField(_redeemController, "Enter points", Icons.stars_rounded, isNumber: true),
                Text("Available: ${provider.walletSummary?.availablePoints ?? 0} Points", style: text10(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text("Select Payment Method", style: text14(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMethodTab("UPI", paymentMethod == "UPI", () => setState(() => paymentMethod = "UPI")),
                    const SizedBox(width: 12),
                    _buildMethodTab("Bank Account", paymentMethod == "BANK", () => setState(() => paymentMethod = "BANK")),
                  ],
                ),
                const SizedBox(height: 20),
                if (paymentMethod == "UPI") ...[
                  _buildTextField(accountHolderController, "Account Holder Name", Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(upiIdController, "UPI ID", Icons.account_balance_wallet_rounded),
                ] else ...[
                  _buildTextField(accountHolderController, "Account Holder Name", Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(accountNumberController, "Account Number", Icons.numbers_rounded, isNumber: true),
                  const SizedBox(height: 12),
                  _buildTextField(ifscController, "IFSC Code", Icons.code_rounded),
                  const SizedBox(height: 12),
                  _buildTextField(bankNameController, "Bank Name", Icons.account_balance_rounded),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final points = int.tryParse(_redeemController.text);
                      if (points == null || points <= 0 || points > (provider.walletSummary?.availablePoints ?? 0)) {
                        _showSnack("Invalid points entered");
                        return;
                      }

                      if (accountHolderController.text.isEmpty) {
                         _showSnack("Enter Account Holder Name");
                         return;
                      }

                      if (paymentMethod == "UPI" && upiIdController.text.isEmpty) {
                        _showSnack("Enter UPI ID");
                        return;
                      }

                      if (paymentMethod == "BANK") {
                        if (accountNumberController.text.isEmpty || ifscController.text.isEmpty || bankNameController.text.isEmpty) {
                          _showSnack("Fill all bank details");
                          return;
                        }
                      }

                      final success = await provider.redeemPoints(
                        points: points,
                        paymentMethod: paymentMethod == "UPI" ? "UPI" : "BANK_ACCOUNT",
                        accountHolderName: accountHolderController.text,
                        upiId: upiIdController.text,
                        accountNumber: accountNumberController.text,
                        ifscCode: ifscController.text,
                        bankName: bankNameController.text,
                      );

                      if (success) {
                        _redeemController.clear();
                        if (!mounted) return;
                        Navigator.pop(context);
                        _showSnack("$points Points redeemed successfully!", isError: false);
                      } else {
                        if (!mounted) return;
                        _showSnack(provider.error ?? "Redeem failed");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: provider.isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("Redeem Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: text14(color: AppColors.grey400),
        filled: true,
        fillColor: AppColors.grey50,
        prefixIcon: Icon(icon, color: AppColors.grey400, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildMethodTab(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.grey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: text12(color: isSelected ? AppColors.primary : AppColors.grey600, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("My Points Wallet", style: text20(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: provider.isLoading && provider.walletSummary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.fetchWalletSummary();
                await provider.fetchPointsSummary();
                await provider.fetchPointHistory();
              },
              child: FadeTransition(
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
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemHistoryScreen()));
                            },
                            child: Text("Redeem History", style: text12(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTransactionList(provider),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(WalletProvider provider) {
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
            (provider.walletSummary?.availablePoints ?? 0).toString(),
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
                  child: provider.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Redeem Points", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(WalletProvider provider) {
    if (provider.pointHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text("No transactions yet", style: text14(color: AppColors.grey400)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.pointHistory.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.grey100),
      itemBuilder: (context, index) {
        final tx = provider.pointHistory[index];
        final isCredit = tx.points != null && tx.points! >= 0; // Usually points in log are positive increments
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: isCredit ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text(tx.action?.replaceAll('_', ' ') ?? 'Transaction', style: text14(fontWeight: FontWeight.w600)),
          subtitle: Text(
            tx.createdAt != null ? DateFormat('dd MMM, hh:mm a').format(tx.createdAt!) : '',
            style: text12(color: AppColors.grey500),
          ),
          trailing: Text(
            "${isCredit ? '+' : ''}${tx.points} Pts",
            style: text14(
              fontWeight: FontWeight.w900,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }
}
