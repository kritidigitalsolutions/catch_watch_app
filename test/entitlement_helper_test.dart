import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/utils/entitlement_helper.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class TestSubscriptionProvider extends SubscriptionProvider {
  SubscriptionData? _mockSub;
  int? _mockRemainingDays;

  @override
  SubscriptionData? get currentSubscription => _mockSub;

  @override
  int? get remainingDays => _mockRemainingDays;

  void setMockSubscription(SubscriptionData? sub, {int? remainingDays}) {
    _mockSub = sub;
    _mockRemainingDays = remainingDays;
  }
}

Widget buildTestWidget({
  required TestSubscriptionProvider provider,
  required Widget Function(BuildContext) childBuilder,
}) {
  return ChangeNotifierProvider<SubscriptionProvider>.value(
    value: provider,
    child: Builder(builder: childBuilder),
  );
}

void main() {
  group('EntitlementHelper.canWatch', () {
    late TestSubscriptionProvider provider;

    setUp(() {
      provider = TestSubscriptionProvider();
    });

    testWidgets('grants access for non-premium content when subscription is null',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'free_1', isPremium: false);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isTrue);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('grants access for content when isPremium is null',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'free_2', isPremium: null);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isTrue);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access for premium content when subscription is null',
        (tester) async {
      provider.setMockSubscription(null);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_1', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('grants access for premium content with active non-expired subscription',
        (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 30)).toIso8601String();
      final sub = SubscriptionData(
        id: 'sub_1',
        status: 'active',
        endDate: futureDate,
      );
      provider.setMockSubscription(sub, remainingDays: 30);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_2', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isTrue);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access for premium content with expired status',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
      final sub = SubscriptionData(
        id: 'sub_2',
        status: 'expired',
        endDate: pastDate,
      );
      provider.setMockSubscription(sub, remainingDays: 0);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_3', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access when subscription status is pending',
        (tester) async {
      final sub = SubscriptionData(
        id: 'sub_pending',
        status: 'pending',
      );
      provider.setMockSubscription(sub, remainingDays: 10);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_4', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access when subscription status is inactive',
        (tester) async {
      final sub = SubscriptionData(
        id: 'sub_inactive',
        status: 'inactive',
      );
      provider.setMockSubscription(sub, remainingDays: 10);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_5', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access when subscription status is failed',
        (tester) async {
      final sub = SubscriptionData(
        id: 'sub_failed',
        status: 'failed',
      );
      provider.setMockSubscription(sub, remainingDays: 10);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_6', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access when subscription status is created',
        (tester) async {
      final sub = SubscriptionData(
        id: 'sub_created',
        status: 'created',
      );
      provider.setMockSubscription(sub, remainingDays: 10);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_7', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('grants access when status is cancelled but still within valid period',
        (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 15)).toIso8601String();
      final sub = SubscriptionData(
        id: 'sub_cancelled_valid',
        status: 'cancelled',
        endDate: futureDate,
      );
      provider.setMockSubscription(sub, remainingDays: 15);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_8', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isTrue);
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('denies access when status is cancelled and period has expired',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      final sub = SubscriptionData(
        id: 'sub_cancelled_expired',
        status: 'cancelled',
        endDate: pastDate,
      );
      provider.setMockSubscription(sub, remainingDays: 0);

      await tester.pumpWidget(
        buildTestWidget(
          provider: provider,
          childBuilder: (context) {
            final content = Content(id: 'prem_9', isPremium: true);
            final result = EntitlementHelper.canWatch(context, content);
            expect(result, isFalse);
            return const SizedBox();
          },
        ),
      );
    });
  });
}

