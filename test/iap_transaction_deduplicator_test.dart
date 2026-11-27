import 'package:catch_watch/utils/iap_transaction_deduplicator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IAP transaction event deduplication', () {
    const productId = 'com.app.catchWatch.premium.monthly';
    const originalId = 'sandbox-original-100';
    const firstRenewal = 'sandbox-renewal-100-1';
    const secondRenewal = 'sandbox-renewal-100-2';

    String key(String transactionId) => iapTransactionEventKey(
      productId: productId,
      transactionId: transactionId,
      originalTransactionId: originalId,
    )!;

    test('fresh monthly transaction can be verified once', () {
      final deduper = IapTransactionDeduplicator();
      expect(deduper.tryStart(key(firstRenewal)), isTrue);
      deduper.markVerified(key(firstRenewal));
      expect(deduper.tryStart(key(firstRenewal)), isFalse);
    });

    test('concurrent copies of the same transaction cannot both verify', () {
      final deduper = IapTransactionDeduplicator();
      final eventKey = key(firstRenewal);
      expect(deduper.tryStart(eventKey), isTrue);
      expect(deduper.tryStart(eventKey), isFalse);
    });

    test(
      'six deliveries of one transaction produce one verification attempt',
      () {
        final deduper = IapTransactionDeduplicator();
        final eventKey = key(firstRenewal);
        final now = DateTime.utc(2026, 11, 18, 9);
        var attempts = 0;
        for (var i = 0; i < 6; i++) {
          if (deduper.tryStart(eventKey, now: now)) {
            attempts++;
            deduper.markFailed(eventKey, now: now);
          }
        }
        expect(attempts, 1);
      },
    );

    test('first renewal shares original ID but is a distinct transaction', () {
      final deduper = IapTransactionDeduplicator();
      final firstKey = key(firstRenewal);
      deduper.tryStart(firstKey);
      deduper.markVerified(firstKey);
      expect(deduper.tryStart(key(secondRenewal)), isTrue);
    });

    test(
      'multiple renewals are accepted while duplicate renewal events are not',
      () {
        final deduper = IapTransactionDeduplicator();
        for (final transactionId in [
          firstRenewal,
          secondRenewal,
          'sandbox-renewal-100-3',
        ]) {
          final eventKey = key(transactionId);
          expect(deduper.tryStart(eventKey), isTrue);
          deduper.markVerified(eventKey);
          expect(deduper.tryStart(eventKey), isFalse);
        }
      },
    );

    test('a new process can re-verify an unfinished event after restart', () {
      final previousProcess = IapTransactionDeduplicator();
      final eventKey = key(firstRenewal);
      previousProcess.tryStart(eventKey);
      previousProcess.markFailed(eventKey);

      final restartedProcess = IapTransactionDeduplicator();
      expect(restartedProcess.tryStart(eventKey), isTrue);
    });

    test('Restore explicitly permits retry before the cooldown ends', () {
      final deduper = IapTransactionDeduplicator();
      final eventKey = key(firstRenewal);
      final now = DateTime.utc(2026, 11, 18, 9);
      expect(deduper.tryStart(eventKey, now: now), isTrue);
      deduper.markFailed(eventKey, now: now);
      expect(
        deduper.tryStart(eventKey, now: now.add(const Duration(seconds: 1))),
        isFalse,
      );
      deduper.allowRetries();
      expect(
        deduper.tryStart(eventKey, now: now.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('backend outage failure becomes retryable after cooldown', () {
      final deduper = IapTransactionDeduplicator();
      final eventKey = key(firstRenewal);
      final now = DateTime.utc(2026, 11, 18, 9);
      expect(deduper.tryStart(eventKey, now: now), isTrue);
      deduper.markFailed(eventKey, now: now);
      expect(
        deduper.tryStart(eventKey, now: now.add(const Duration(seconds: 29))),
        isFalse,
      );
      expect(
        deduper.tryStart(eventKey, now: now.add(const Duration(seconds: 30))),
        isTrue,
      );
    });

    test('events without a stable transaction or fingerprint are rejected', () {
      expect(
        iapTransactionEventKey(
          productId: productId,
          transactionId: null,
          originalTransactionId: originalId,
        ),
        isNull,
      );
    });
  });
}
