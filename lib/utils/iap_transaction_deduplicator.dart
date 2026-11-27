/// Identifies one Apple transaction event. Renewals share an original
/// transaction ID, so the current transaction ID must remain part of the key.
String? iapTransactionEventKey({
  required String productId,
  required String? transactionId,
  required String? originalTransactionId,
  String? fallbackFingerprint,
}) {
  final transaction = transactionId?.trim();
  final fallback = fallbackFingerprint?.trim();
  if ((transaction == null || transaction.isEmpty) &&
      (fallback == null || fallback.isEmpty)) {
    return null;
  }
  return '$productId|${originalTransactionId?.trim() ?? ''}|${transaction?.isNotEmpty == true ? transaction : fallback}';
}

/// Process-local duplicate suppression for StoreKit's at-least-once stream.
/// Failed verifications can be retried after a short cooldown or explicitly
/// by Restore; successful and terminal transaction events stay suppressed.
class IapTransactionDeduplicator {
  IapTransactionDeduplicator({
    this.retryCooldown = const Duration(seconds: 30),
  });

  final Duration retryCooldown;
  final Set<String> _inFlight = {};
  final Set<String> _settled = {};
  final Map<String, DateTime> _retryAfter = {};

  bool tryStart(String key, {DateTime? now}) {
    if (_settled.contains(key) || !_inFlight.add(key)) return false;
    final currentTime = now ?? DateTime.now();
    final retryAt = _retryAfter[key];
    if (retryAt != null && currentTime.isBefore(retryAt)) {
      _inFlight.remove(key);
      return false;
    }
    _retryAfter.remove(key);
    return true;
  }

  void markVerified(String key) {
    _inFlight.remove(key);
    _retryAfter.remove(key);
    _settled.add(key);
  }

  void markTerminal(String key) => markVerified(key);

  void markFailed(String key, {DateTime? now}) {
    _inFlight.remove(key);
    _retryAfter[key] = (now ?? DateTime.now()).add(retryCooldown);
  }

  void abandon(String key) => _inFlight.remove(key);

  /// Lets a user initiated Restore retry previously failed transactions.
  void allowRetries() => _retryAfter.clear();

  void clear() {
    _inFlight.clear();
    _settled.clear();
    _retryAfter.clear();
  }
}
