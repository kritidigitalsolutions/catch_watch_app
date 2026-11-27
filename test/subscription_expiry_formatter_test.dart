import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/utils/subscription_expiry_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSubscriptionExpiry', () {
    final now = DateTime.utc(2026, 11, 18, 8, 10, 36);

    test('uses expiry timestamp for Sandbox subscriptions under 24 hours', () {
      final expiry = DateTime.utc(2026, 11, 18, 8, 15, 36);
      expect(
        formatSubscriptionExpiry(expiry, now: now, fallbackRemainingDays: 1),
        'Expires in 5 minutes',
      );
    });

    test('formats hour and minute singular/plural correctly', () {
      expect(
        formatSubscriptionExpiry(
          now.add(const Duration(hours: 1, minutes: 1)),
          now: now,
        ),
        'Expires in 1 hour 1 minute',
      );
    });

    test('uses singular and plural day grammar', () {
      expect(
        formatSubscriptionExpiry(now.add(const Duration(days: 1)), now: now),
        'Expires in 1 day',
      );
      expect(
        formatSubscriptionExpiry(now.add(const Duration(days: 2)), now: now),
        'Expires in 2 days',
      );
    });

    test('marks timestamps at or before now expired', () {
      expect(formatSubscriptionExpiry(now, now: now), 'Expired');
      expect(
        formatSubscriptionExpiry(
          now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        'Expired',
      );
    });

    test('falls back to backend days only when timestamp is unavailable', () {
      expect(
        formatSubscriptionExpiry(null, now: now, fallbackRemainingDays: 1),
        'Expires in 1 day',
      );
      expect(
        formatSubscriptionExpiry(null, now: now, fallbackRemainingDays: 0),
        'Expired',
      );
    });
  });

  test(
    'active backend status is still expired after its exact end timestamp',
    () {
      final subscription = SubscriptionData(
        status: 'active',
        endDate: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      );
      expect(subscription.isExpired(remainingDays: 1), isFalse);
      expect(
        SubscriptionData(
          status: 'active',
          endDate: DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        ).isExpired(remainingDays: 1),
        isTrue,
      );
    },
  );
}
