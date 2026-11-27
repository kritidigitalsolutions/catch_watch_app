import 'dart:convert';

/// Non-secret identifiers and dates decoded from a StoreKit event.
/// Signed transaction data itself is deliberately not retained or logged here.
class IapTransactionMetadata {
  const IapTransactionMetadata({
    required this.transactionId,
    required this.originalTransactionId,
    required this.purchaseDate,
    required this.expiryDate,
  });

  final String? transactionId;
  final String? originalTransactionId;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;

  factory IapTransactionMetadata.fromStoreKit({
    required String? purchaseId,
    required String? transactionDate,
    required String serverVerificationData,
  }) {
    final payload = _decodeJwsPayload(serverVerificationData);
    final transactionId = _firstValue([
      purchaseId,
      payload?['transactionId'],
      payload?['transaction_id'],
    ]);
    return IapTransactionMetadata(
      transactionId: transactionId,
      originalTransactionId: _firstValue([
        payload?['originalTransactionId'],
        payload?['original_transaction_id'],
      ]),
      purchaseDate: parseStoreKitDate(
        payload?['purchaseDate'] ??
            payload?['purchaseDateMs'] ??
            payload?['purchase_date'] ??
            payload?['purchase_date_ms'] ??
            transactionDate,
      ),
      expiryDate: parseStoreKitDate(
        payload?['expiresDate'] ??
            payload?['expiresDateMs'] ??
            payload?['expires_date'] ??
            payload?['expires_date_ms'],
      ),
    );
  }

  static String? _firstValue(List<dynamic> values) {
    for (final value in values) {
      final normalized = value?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static DateTime? parseStoreKitDate(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      final isMilliseconds = value.abs() >= 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(
        isMilliseconds ? value : value * 1000,
        isUtc: true,
      );
    }
    if (value is! String || value.trim().isEmpty) return null;
    final parsedNumber = int.tryParse(value.trim());
    if (parsedNumber != null) return parseStoreKitDate(parsedNumber);
    return DateTime.tryParse(value)?.toUtc();
  }

  static Map<String, dynamic>? _decodeJwsPayload(String value) {
    if (!value.contains('.')) return null;
    try {
      final parts = value.split('.');
      if (parts.length < 2) return null;
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payload = jsonDecode(decoded);
      return payload is Map<String, dynamic> ? payload : null;
    } catch (_) {
      return null;
    }
  }
}
