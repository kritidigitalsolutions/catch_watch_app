import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:catch_watch/models/wallet_model.dart';
import 'package:catch_watch/view_model/after_login_provider/wallet_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/wallet_screen.dart';

// ─── Test Double ──────────────────────────────────────────────────────────────

class MockWalletProvider extends WalletProvider {
  WalletSummary? _mockSummary = WalletSummary(
    availablePoints: 500,
    totalPoints: 1200,
  );
  List<PointHistoryLog> _mockHistory = [];
  bool _mockIsRedeeming = false;
  String? _mockRedeemError;
  int redeemCallCount = 0;
  int? lastRedeemPoints;
  String? lastPaymentMethod;
  Map<String, dynamic>? lastPaymentDetails;

  void setMockIsRedeeming(bool isRedeeming) {
    _mockIsRedeeming = isRedeeming;
    notifyListeners();
  }

  void setMockSummary(WalletSummary? summary) {
    _mockSummary = summary;
    notifyListeners();
  }

  void setMockHistory(List<PointHistoryLog> history) {
    _mockHistory = history;
    notifyListeners();
  }

  @override
  WalletSummary? get walletSummary => _mockSummary;

  @override
  String? get walletSummaryError => null;

  @override
  bool get isWalletSummaryLoading => false;

  @override
  List<PointHistoryLog> get pointHistory => _mockHistory;

  @override
  bool get isPointHistoryLoading => false;

  @override
  bool get isRedeeming => _mockIsRedeeming;

  @override
  String? get redeemError => _mockRedeemError;

  @override
  Future<void> fetchWalletSummary() async {}

  @override
  Future<void> fetchPointsSummary() async {}

  @override
  Future<void> fetchPointHistory() async {}

  @override
  Future<bool> redeemPoints({
    required int points,
    required String paymentMethod,
    String? upiId,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
  }) async {
    redeemCallCount++;
    lastRedeemPoints = points;
    lastPaymentMethod = paymentMethod;
    if (paymentMethod == 'UPI') {
      lastPaymentDetails = {
        'accountHolderName': accountHolderName,
        'upiId': upiId,
      };
    } else {
      lastPaymentDetails = {
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'bankName': bankName,
      };
    }
    return true;
  }
}

Widget createWalletTestApp({
  required MockWalletProvider walletProvider,
}) {
  return ChangeNotifierProvider<WalletProvider>.value(
    value: walletProvider,
    child: const MaterialApp(
      home: WalletScreen(),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Wallet Screen Region-Availability Notice & Validation Tests', () {
    late MockWalletProvider walletProvider;

    setUp(() {
      walletProvider = MockWalletProvider();
    });

    testWidgets('WalletScreen renders Payout Region Availability notice below balance card',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWalletTestApp(walletProvider: walletProvider));
      await tester.pumpAndSettle();

      // Verify Available Points card is rendered
      expect(find.text('Available Points'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);

      // Verify the region notice is visible on the main wallet dashboard before entering payout details
      expect(find.text('Payout Region Availability'), findsOneWidget);
      expect(
        find.text(
          'Withdrawals currently support Indian UPI IDs and Indian bank accounts with valid IFSC codes. International payouts are currently not supported.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Verify Redeem Points button is present
      expect(find.widgetWithText(ElevatedButton, 'Redeem Points'), findsOneWidget);
    });

    testWidgets('Redeem bottom sheet displays region availability notice before payout inputs',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWalletTestApp(walletProvider: walletProvider));
      await tester.pumpAndSettle();

      // Tap "Redeem Points" button to open modal bottom sheet
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redeem Points'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and notice are visible
      expect(find.text('Redeem Points'), findsAtLeastNWidgets(1));
      expect(find.text('Payout Region Availability'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Withdrawals currently support Indian UPI IDs and Indian bank accounts with valid IFSC codes. International payouts are currently not supported.',
        ),
        findsAtLeastNWidgets(1),
      );

      // Verify method tabs and input fields are rendered below the notice
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);
      expect(find.text('Account Holder Name'), findsOneWidget);
      expect(find.text('UPI ID'), findsOneWidget);
    });

    testWidgets('UPI redemption enforces valid UPI ID format and submits successfully',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWalletTestApp(walletProvider: walletProvider));
      await tester.pumpAndSettle();

      // Open redeem bottom sheet
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redeem Points'));
      await tester.pumpAndSettle();

      final redeemNowBtn = find.widgetWithText(ElevatedButton, 'Redeem Now');
      await tester.ensureVisible(redeemNowBtn);

      // 1. Enter invalid points (> available)
      final textFields = find.byType(TextField);
      // TextField 0: Enter points
      // TextField 1: Account Holder Name
      // TextField 2: UPI ID
      await tester.enterText(textFields.at(0), '9999');
      await tester.enterText(textFields.at(1), 'Rajesh Kumar');
      await tester.enterText(textFields.at(2), 'invalid-upi-id');

      await tester.tap(redeemNowBtn);
      await tester.pumpAndSettle();

      expect(find.text('Insufficient points. Available: 500'), findsOneWidget);
      expect(find.text('Enter a valid UPI ID (e.g. name@bank)'), findsOneWidget);
      expect(walletProvider.redeemCallCount, 0);

      // 2. Fix points and UPI ID
      await tester.enterText(textFields.at(0), '100');
      await tester.enterText(textFields.at(2), 'rajesh@okaxis');

      await tester.tap(redeemNowBtn);
      await tester.pumpAndSettle();

      expect(walletProvider.redeemCallCount, 1);
      expect(walletProvider.lastRedeemPoints, 100);
      expect(walletProvider.lastPaymentMethod, 'UPI');
      expect(walletProvider.lastPaymentDetails, {
        'accountHolderName': 'Rajesh Kumar',
        'upiId': 'rajesh@okaxis',
      });
    });

    testWidgets('Bank Account redemption enforces Indian IFSC and account number rules',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWalletTestApp(walletProvider: walletProvider));
      await tester.pumpAndSettle();

      // Open redeem sheet
      await tester.tap(find.widgetWithText(ElevatedButton, 'Redeem Points'));
      await tester.pumpAndSettle();

      // Switch to Bank Account tab
      final bankTab = find.text('Bank Account');
      await tester.tap(bankTab);
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      // TextField 0: Enter points
      // TextField 1: Account Holder Name
      // TextField 2: Account Number
      // TextField 3: IFSC Code
      // TextField 4: Bank Name

      await tester.enterText(textFields.at(0), '200');
      await tester.enterText(textFields.at(1), 'Rajesh Kumar');
      await tester.enterText(textFields.at(2), '12345'); // invalid (< 9 digits)
      await tester.enterText(textFields.at(3), 'INVALID_IFSC'); // invalid format
      await tester.enterText(textFields.at(4), 'HDFC Bank');

      final redeemNowBtn = find.widgetWithText(ElevatedButton, 'Redeem Now');
      await tester.ensureVisible(redeemNowBtn);
      await tester.tap(redeemNowBtn);
      await tester.pumpAndSettle();

      // Assert validation errors
      expect(find.text('Enter a valid account number (9-18 digits)'), findsOneWidget);
      expect(find.text('Enter a valid IFSC (e.g. ABCD0123456)'), findsOneWidget);
      expect(walletProvider.redeemCallCount, 0);

      // Fix account number and IFSC to valid Indian bank format
      await tester.enterText(textFields.at(2), '123456789012');
      await tester.enterText(textFields.at(3), 'HDFC0001234');

      await tester.tap(redeemNowBtn);
      await tester.pumpAndSettle();

      expect(walletProvider.redeemCallCount, 1);
      expect(walletProvider.lastRedeemPoints, 200);
      expect(walletProvider.lastPaymentMethod, 'BANK_ACCOUNT');
      expect(walletProvider.lastPaymentDetails, {
        'accountHolderName': 'Rajesh Kumar',
        'accountNumber': '123456789012',
        'ifscCode': 'HDFC0001234',
        'bankName': 'HDFC Bank',
      });
    });
  });
}
