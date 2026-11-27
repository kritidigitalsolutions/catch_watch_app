import 'package:catch_watch/utils/restore_purchase_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasVerifiedRestoreTransaction', () {
    test('does not treat cached entitlement as a successful restore', () {
      expect(hasVerifiedRestoreTransaction(0), isFalse);
    });

    test('accepts a restore after backend verification succeeds', () {
      expect(hasVerifiedRestoreTransaction(1), isTrue);
    });
  });
}
