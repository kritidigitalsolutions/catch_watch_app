import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/error_state_widget.dart';
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
  // Local guard to block rapid duplicate redeem submissions.
  bool _submitting = false;

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

  // --- Redeem form validation -------------------------------------------------
  // Format rules only. Minimum redeem amount / redemption increments are NOT
  // enforced here because the backend does not currently expose such a config
  // (reported as a dependency).
  static final RegExp _upiRegex = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$');
  static final RegExp _ifscRegex = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');
  static final RegExp _accountNumberRegex = RegExp(r'^\d{9,18}$');
  static final RegExp _holderNameRegex = RegExp(r"^[A-Za-z][A-Za-z .']*$");

  bool _isValidUpiId(String value) => _upiRegex.hasMatch(value.trim());

  bool _isValidIfsc(String value) => _ifscRegex.hasMatch(value.trim().toUpperCase());

  bool _isValidAccountNumber(String value) => _accountNumberRegex.hasMatch(value.trim());

  bool _isValidHolderName(String value) {
    final v = value.trim();
    return v.length >= 3 && _holderNameRegex.hasMatch(v);
  }

  void _showRedeemDialog() {
    String paymentMethod = "UPI";
    _submitting = false;
    final TextEditingController accountHolderController = TextEditingController();
    final TextEditingController upiIdController = TextEditingController();
    final TextEditingController accountNumberController = TextEditingController();
    final TextEditingController ifscController = TextEditingController();
    final TextEditingController bankNameController = TextEditingController();

    // Inline validation messages (reset each time the sheet opens / re-validates).
    String? pointsError;
    String? holderError;
    String? upiError;
    String? accountError;
    String? ifscError;
    String? bankNameError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Consumer<WalletProvider>(
        builder: (context, provider, _) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                _buildTextField(_redeemController, "Enter points", Icons.stars_rounded, isNumber: true, errorText: pointsError),
                Text("Available: ${provider.walletSummary?.availablePoints ?? 0} Points", style: text10(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _buildPayoutRegionNotice(isSheet: true),
                const SizedBox(height: 16),
                Text("Select Payment Method", style: text14(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMethodTab("UPI", paymentMethod == "UPI", () => setSheetState(() => paymentMethod = "UPI")),
                    const SizedBox(width: 12),
                    _buildMethodTab("Bank Account", paymentMethod == "BANK", () => setSheetState(() => paymentMethod = "BANK")),
                  ],
                ),
                const SizedBox(height: 20),
                if (paymentMethod == "UPI") ...[
                  _buildTextField(accountHolderController, "Account Holder Name", Icons.person, errorText: holderError),
                  const SizedBox(height: 12),
                  _buildTextField(upiIdController, "UPI ID", Icons.account_balance_wallet_rounded, errorText: upiError),
                ] else ...[
                  _buildTextField(accountHolderController, "Account Holder Name", Icons.person, errorText: holderError),
                  const SizedBox(height: 12),
                  _buildTextField(accountNumberController, "Account Number", Icons.numbers_rounded, isNumber: true, errorText: accountError),
                  const SizedBox(height: 12),
                  _buildTextField(ifscController, "IFSC Code", Icons.code_rounded, errorText: ifscError),
                  const SizedBox(height: 12),
                  _buildTextField(bankNameController, "Bank Name", Icons.account_balance_rounded, errorText: bankNameError),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (provider.isRedeeming || _submitting)
                        ? null
                        : () async {
                      // Second guard: block a duplicate tap that may have queued
                      // before the button rebuilds into its disabled state.
                      if (_submitting) return;
                      setSheetState(() => _submitting = true);
                      bool didPop = false;

                      // Capture the sheet's Navigator BEFORE the async gap so the
                      // success path never resolves a navigator from a context that
                      // may be invalid/unmounted afterwards. This pops only the
                      // redeem bottom sheet route — never the wallet screen.
                      final NavigatorState sheetNavigator = Navigator.of(sheetContext);

                      try {
                        // Clear any previous inline errors before re-validating.
                        pointsError = null;
                        holderError = null;
                        upiError = null;
                        accountError = null;
                        ifscError = null;
                        bankNameError = null;

                        final points = int.tryParse(_redeemController.text.trim());
                        final availablePoints = provider.walletSummary?.availablePoints ?? 0;

                        // Points: must be a positive number and not exceed the
                        // available balance. No minimum / increment rule is enforced
                        // here because the backend does not expose such a config.
                        if (points == null || points <= 0) {
                          pointsError = "Enter a valid number of points";
                        } else if (points > availablePoints) {
                          pointsError = "Insufficient points. Available: $availablePoints";
                        }

                        // Account holder name.
                        if (!_isValidHolderName(accountHolderController.text)) {
                          holderError = "Enter a valid account holder name";
                        }

                        if (paymentMethod == "UPI") {
                          if (!_isValidUpiId(upiIdController.text)) {
                            upiError = "Enter a valid UPI ID (e.g. name@bank)";
                          }
                        } else {
                          if (!_isValidAccountNumber(accountNumberController.text)) {
                            accountError = "Enter a valid account number (9-18 digits)";
                          }
                          if (!_isValidIfsc(ifscController.text)) {
                            ifscError = "Enter a valid IFSC (e.g. ABCD0123456)";
                          }
                          if (bankNameController.text.trim().isEmpty) {
                            bankNameError = "Enter bank name";
                          }
                        }

                        // Never call the API when validation fails.
                        final hasValidationError = pointsError != null ||
                            holderError != null ||
                            upiError != null ||
                            accountError != null ||
                            ifscError != null ||
                            bankNameError != null;
                        if (hasValidationError) {
                          setSheetState(() {});
                          return;
                        }

                        final success = await provider.redeemPoints(
                          points: points!,
                          paymentMethod: paymentMethod == "UPI" ? "UPI" : "BANK_ACCOUNT",
                          accountHolderName: accountHolderController.text,
                          upiId: upiIdController.text,
                          accountNumber: accountNumberController.text,
                          ifscCode: ifscController.text,
                          bankName: bankNameController.text,
                        );

                        if (!mounted) return;

                        if (success) {
                          _redeemController.clear();
                          // Close ONLY the redeem sheet, and only while it is still
                          // mounted (the user may have swiped it away mid-request).
                          // Guarding on the sheet's own context guarantees the pop
                          // targets the sheet route rather than the screen beneath.
                          if (sheetContext.mounted) {
                            sheetNavigator.pop();
                          }
                          didPop = true;
                          _showSnack("$points Points redeemed successfully!", isError: false);
                        } else {
                          _showSnack(provider.redeemError ?? "Redeem failed");
                        }
                      } finally {
                        // Always release the guard so the button can be re-enabled.
                        _submitting = false;
                        if (!didPop && sheetContext.mounted) {
                          setSheetState(() {});
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: (provider.isRedeeming || _submitting)
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
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, String? errorText}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: text14(color: AppColors.grey400),
        errorText: errorText,
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
      body: _buildBody(provider),
    );
  }

  Future<void> _refreshWallet() async {
    final provider = context.read<WalletProvider>();
    await provider.fetchWalletSummary();
    await provider.fetchPointsSummary();
    await provider.fetchPointHistory();
  }

  Widget _buildBody(WalletProvider provider) {
    // The balance is only rendered once a valid wallet summary exists, so a
    // failed request can never be shown as a real ₹0 balance.
    if (provider.walletSummary == null) {
      if (provider.walletSummaryError != null) {
        return RefreshIndicator(
          onRefresh: _refreshWallet,
          child: ErrorStateWidget(
            title: 'Unable to load wallet',
            message: 'Please check your internet connection and try again.',
            isLoading: provider.isWalletSummaryLoading,
            onRetry: () {
              if (!provider.isWalletSummaryLoading) {
                _refreshWallet();
              }
            },
          ),
        );
      }
      // Initial load (or the brief pre-fetch frame) — existing loader.
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshWallet,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(provider),
              const SizedBox(height: 16),
              _buildPayoutRegionNotice(),
              const SizedBox(height: 24),
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
                  onPressed: () => _showRedeemDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: provider.isRedeeming ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Redeem Points", style: TextStyle(fontWeight: FontWeight.bold)),
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
      // Only claim the history is empty when the request actually succeeded;
      // a failed request must not be misreported as "No transactions yet".
      if (provider.pointHistoryError != null) {
        return ErrorStateWidget(
          title: 'Unable to load transactions',
          message: 'Please check your internet connection and try again.',
          isLoading: provider.isPointHistoryLoading,
          isScrollable: false,
          onRetry: () {
            if (!provider.isPointHistoryLoading) {
              context.read<WalletProvider>().fetchPointHistory();
            }
          },
        );
      }
      return const EmptyStateWidget(
        title: "No transactions yet",
        message: "Your points activity will appear here once you start earning.",
        icon: Icons.receipt_long_outlined,
        isScrollable: false,
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

  Widget _buildPayoutRegionNotice({bool isSheet = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isSheet ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(isSheet ? 12 : 14),
        border: Border.all(color: const Color(0xFFB9DBFF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF0066CC),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Payout Region Availability",
                  style: text12(fontWeight: FontWeight.w700, color: const Color(0xFF004080)),
                ),
                const SizedBox(height: 3),
                Text(
                  "Withdrawals currently support Indian UPI IDs and Indian bank accounts with valid IFSC codes. International payouts are currently not supported.",
                  style: text11(color: const Color(0xFF004080)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
