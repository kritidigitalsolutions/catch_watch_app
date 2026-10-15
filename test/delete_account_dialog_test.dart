import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/delete_account_dialog.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class MockSubscriptionProvider extends SubscriptionProvider {
  bool mockSuccess = true;
  SubscriptionData? mockSub;
  int? mockRemainingDays;
  String? mockStatusError;
  int fetchCallCount = 0;

  @override
  SubscriptionData? get currentSubscription => mockSub;

  @override
  int? get remainingDays => mockRemainingDays;

  @override
  String? get subscriptionStatusError => mockStatusError;

  @override
  Future<bool> fetchSubscriptionStatus({int? expectedMinLevel}) async {
    fetchCallCount++;
    if (!mockSuccess) {
      mockStatusError = mockStatusError ?? 'Network error connecting to subscription server';
      return false;
    }
    mockStatusError = null;
    return true;
  }
}

class MockProfileProvider extends ProfileProvider {
  bool mockDeleteSuccess = true;
  String? mockDeleteError;
  bool isDeleting = false;
  int deleteCallCount = 0;
  String? lastReason;
  String? lastReasonDetails;

  @override
  bool get isDeletingAccount => isDeleting;

  @override
  String? get deleteAccountError => mockDeleteError;

  @override
  Future<bool> deleteAccount({
    String? reason,
    String? reasonDetails,
    BuildContext? context,
  }) async {
    deleteCallCount++;
    lastReason = reason;
    lastReasonDetails = reasonDetails;

    if (!mockDeleteSuccess) {
      mockDeleteError = mockDeleteError ?? 'Failed to delete account on server';
      return false;
    }
    mockDeleteError = null;
    return true;
  }
}

class MockAuthProvider extends AuthProvider {
  bool resetCalled = false;
  bool clearPhoneCalled = false;

  @override
  void resetAuthState({bool clearPhone = false}) {
    resetCalled = true;
    clearPhoneCalled = clearPhone;
    notifyListeners();
  }
}

// ─── Test Harness Helper ──────────────────────────────────────────────────────

Widget createTestApp({
  required MockSubscriptionProvider subProvider,
  required MockProfileProvider profileProvider,
  required MockAuthProvider authProvider,
  Widget? child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login Screen Mock')),
      },
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1400)),
        child: Scaffold(
          body: child ??
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showDeleteAccountDialog(ctx, entryPoint: 'unit_test'),
                  child: const Text('Open Dialog'),
                ),
              ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    DeleteAccountDialog.debugMockIsIOS = true;
  });

  tearDown(() {
    DeleteAccountDialog.debugMockIsIOS = null;
  });

  group('Entitlement Classification & Model Behavior', () {
    test('1. Distinguishes active entitlement correctly', () {
      final sub = SubscriptionData(
        status: 'active',
        endDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        gateway: 'apple',
      );
      final classification = sub.getEntitlementClassification(remainingDays: 30);
      expect(classification, EntitlementClassification.activeEntitlement);
      expect(sub.isActive, isTrue);
      expect(sub.isCancelled, isFalse);
      expect(sub.isAppleGateway, isTrue);
    });

    test('2. Distinguishes cancelled subscription whose entitlement remains valid', () {
      final futureDate = DateTime.now().add(const Duration(days: 14)).toIso8601String();
      final sub = SubscriptionData(
        status: 'cancelled',
        endDate: futureDate,
        gateway: 'apple_iap',
      );
      final classification = sub.getEntitlementClassification(remainingDays: 14);
      expect(classification, EntitlementClassification.cancelledWithEntitlement);
      expect(sub.isCancelled, isTrue);
      expect(sub.isCancelledWithEntitlement(remainingDays: 14), isTrue);
      expect(sub.isAppleGateway, isTrue);
    });

    test('3. Distinguishes expired subscription correctly', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
      final sub = SubscriptionData(
        status: 'expired',
        endDate: pastDate,
      );
      final classification = sub.getEntitlementClassification(remainingDays: 0);
      expect(classification, EntitlementClassification.expired);
      expect(sub.isExpired(remainingDays: 0), isTrue);
    });

    test('4. Correctly classifies null subscription as none', () {
      SubscriptionData? getSub() => null;
      final sub = getSub();
      final classification = sub?.getEntitlementClassification() ?? EntitlementClassification.none;
      expect(classification, EntitlementClassification.none);
    });
  });

  group('Delete Account Dialog Flow Scenarios', () {
    testWidgets('Scenario A: Active subscription - User sees warning, Manage button, and acknowledgment',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(
          status: 'active',
          endDate: '2026-11-15T00:00:00.000Z',
          gateway: 'apple',
        )
        ..mockRemainingDays = 32;

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Step 1: Why are you leaving?
      expect(find.text('Why are you leaving?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Select a reason and tap Continue
      await tester.tap(find.text('I no longer use Catch & Watch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Apple Subscription Guidance
      expect(find.text('Apple Subscription Notice'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Manage Apple Subscription'), findsOneWidget);
      expect(find.text('Important Apple Billing Guidance'), findsOneWidget);
      expect(
        find.textContaining('Deleting your Catch & Watch account does not cancel your Apple subscription.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Apple will continue to charge your Apple ID on future renewal dates'),
        findsOneWidget,
      );
      expect(find.text('Recently cancelled in Apple Settings?'), findsOneWidget);

      // Verify Continue to Deletion is disabled until acknowledgment
      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue to Deletion'),
      );
      expect(continueButton.onPressed, isNull);

      // Acknowledge warning
      await tester.scrollUntilVisible(find.byType(Checkbox), 50);
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Now Continue to Deletion is enabled
      final enabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue to Deletion'),
      );
      expect(enabledButton.onPressed, isNotNull);

      // Proceed to Step 3
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue to Deletion'));
      await tester.pumpAndSettle();

      // Step 3: Final confirmation
      expect(find.text('Delete Account'), findsNWidgets(2)); // Title and Button
      expect(find.textContaining('Reminder: Deleting your account will NOT cancel your Apple subscription.'), findsOneWidget);
      expect(find.text('What will be permanently erased'), findsOneWidget);
    });

    testWidgets('Scenario B: No subscription or Expired subscription - Advances directly to final confirmation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = null
        ..mockRemainingDays = null;

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Step 1
      expect(find.text('Why are you leaving?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Direct to Step 3 (Skipping Apple guidance because no subscription exists)
      expect(find.text('Apple Subscription Notice'), findsNothing);
      expect(find.text('What will be permanently erased'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Delete Account'), findsOneWidget);
    });

    testWidgets('Scenario C: Subscription status API failure - Explicit error and user can proceed without trap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = false
        ..mockStatusError = 'Failed to reach subscription verification service (503)';

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Step 1 Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 Error State
      expect(find.text('Subscription Check Failed'), findsOneWidget);
      expect(find.text('Failed to reach subscription verification service (503)'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Manage Apple Subscription'), findsOneWidget);

      // Verify user is NOT trapped: Checkbox allows acknowledging unverified status and continuing
      expect(find.widgetWithText(ElevatedButton, 'Continue to Deletion'), findsOneWidget);
      var continueBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue to Deletion'));
      expect(continueBtn.onPressed, isNull);

      // Check acknowledgment
      await tester.scrollUntilVisible(find.byType(Checkbox), 50);
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pumpAndSettle();

      continueBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue to Deletion'));
      expect(continueBtn.onPressed, isNotNull);

      // Tap Continue to Deletion
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue to Deletion'));
      await tester.pumpAndSettle();

      // Step 3 shows explicit warning about unverified status
      expect(find.textContaining('Warning: Subscription status could not be verified with the server.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Delete Account'), findsOneWidget);
    });

    testWidgets('Scenario D: User proceeds with deletion while subscription active -> Deletion succeeds',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(
          status: 'active',
          endDate: '2026-11-15T00:00:00.000Z',
          gateway: 'apple',
        )
        ..mockRemainingDays = 32;

      final profileProvider = MockProfileProvider()..mockDeleteSuccess = true;
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Acknowledge on Step 2
      await tester.scrollUntilVisible(find.byType(Checkbox), 50);
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue to Deletion'));
      await tester.pumpAndSettle();

      // Step 3: Tap final Delete Account
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      // Verify profileProvider.deleteAccount was called
      expect(profileProvider.deleteCallCount, 1);
      // Verify navigated to login
      expect(find.text('Login Screen Mock'), findsOneWidget);
      // Dialog is dismissed
      expect(find.text('What will be permanently erased'), findsNothing);
    });

    testWidgets('Scenario E: Delete API failure -> Dialog remains open with inline error banner',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()..mockSub = null;
      final profileProvider = MockProfileProvider()
        ..mockDeleteSuccess = false
        ..mockDeleteError = 'Server error 500: Database constraint violation';
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // In Step 3: Tap Delete Account
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      // Deletion failed: Dialog must NOT dismiss!
      expect(find.text('Server error 500: Database constraint violation'), findsAtLeastNWidgets(1));
      expect(find.text('What will be permanently erased'), findsOneWidget);
      expect(find.text('Login Screen Mock'), findsNothing);
      expect(authProvider.resetCalled, isFalse);
    });

    testWidgets('Scenario F: App resume re-fetches subscription status',
        (WidgetTester tester) async {
      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(status: 'active', gateway: 'apple');

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final initialFetchCount = subProvider.fetchCallCount;

      // Simulate AppLifecycleState.resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify status was re-fetched
      expect(subProvider.fetchCallCount, greaterThan(initialFetchCount));
    });

    testWidgets('Scenario G: User cancelled in Apple Settings, backend status updates to cancelledWithEntitlement',
        (WidgetTester tester) async {
      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(
          status: 'cancelled',
          endDate: '2026-10-31T00:00:00.000Z',
          gateway: 'apple',
        )
        ..mockRemainingDays = 17;

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 shows "Cancelled" badge and entitled until notice
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('Entitled until:'), findsOneWidget);
      expect(
        find.textContaining('Account deletion does not trigger an Apple refund for remaining paid time.'),
        findsOneWidget,
      );
    });

    testWidgets('Scenario H: Active entitlement with null gateway (/api/subscription/status payload) transitions to Step 2',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(
          status: 'active',
          plan: Plan(
            id: '6acf4c9e1e76a3cd5bf0fabc',
            name: 'CatchWatch Premium Monthly',
            price: 199,
          ),
          gateway: null, // Backend does not return a gateway field
        )
        ..mockRemainingDays = 1;

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Step 1: Why are you leaving? (Without selecting any reason)
      expect(find.text('Why are you leaving?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Apple Subscription Notice rendered
      expect(find.text('Apple Subscription Notice'), findsOneWidget);
      expect(find.text('CatchWatch Premium Monthly'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('1 day remaining'), findsOneWidget);
      expect(find.text('Manage Apple Subscription'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('Scenario I: Reason is optional - Continue proceeds to Step 2 without reason selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final subProvider = MockSubscriptionProvider()
        ..mockSuccess = true
        ..mockSub = SubscriptionData(
          status: 'active',
          plan: Plan(
            id: '6acf4c9e1e76a3cd5bf0fabc',
            name: 'CatchWatch Premium Monthly',
          ),
        )
        ..mockRemainingDays = 1;

      final profileProvider = MockProfileProvider();
      final authProvider = MockAuthProvider();

      await tester.pumpWidget(createTestApp(
        subProvider: subProvider,
        profileProvider: profileProvider,
        authProvider: authProvider,
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Continue immediately with NO reason selected
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Confirms transition succeeded to Step 2
      expect(find.text('Apple Subscription Notice'), findsOneWidget);
    });
  });
}
