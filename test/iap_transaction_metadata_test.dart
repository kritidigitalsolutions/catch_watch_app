import 'dart:convert';

import 'package:catch_watch/utils/iap_transaction_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IAP transaction event metadata', () {
    const purchaseId = 'sandbox-tx-new';
    const originalId = 'sandbox-tx-original';
    final purchaseDate = DateTime.utc(2026, 11, 18, 9, 42, 49);
    final expiryDate = DateTime.utc(2026, 11, 18, 9, 47, 49);
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'transactionId': purchaseId,
          'originalTransactionId': originalId,
          'purchaseDate': purchaseDate.millisecondsSinceEpoch,
          'expiresDate': expiryDate.millisecondsSinceEpoch,
        }),
      ),
    );
    final metadata = IapTransactionMetadata.fromStoreKit(
      purchaseId: purchaseId,
      transactionDate: null,
      serverVerificationData: 'header.$payload.signature',
    );

    test('extracts current and original transaction IDs separately', () {
      expect(metadata.transactionId, purchaseId);
      expect(metadata.originalTransactionId, originalId);
    });

    test('extracts Sandbox purchase and expiry timestamps in UTC', () {
      expect(metadata.purchaseDate, purchaseDate);
      expect(metadata.expiryDate, expiryDate);
    });

    test('parses transactionDate milliseconds if the JWS date is absent', () {
      final fromStoreKitDate = IapTransactionMetadata.fromStoreKit(
        purchaseId: purchaseId,
        transactionDate: purchaseDate.millisecondsSinceEpoch.toString(),
        serverVerificationData: '',
      );
      expect(fromStoreKitDate.purchaseDate, purchaseDate);
      expect(fromStoreKitDate.expiryDate, isNull);
    });
  });
}
