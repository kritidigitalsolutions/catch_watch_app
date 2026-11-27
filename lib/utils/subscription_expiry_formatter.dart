String formatSubscriptionExpiry(
  DateTime? expiry, {
  DateTime? now,
  int? fallbackRemainingDays,
}) {
  if (expiry == null) {
    final days = fallbackRemainingDays ?? 0;
    if (days <= 0) return 'Expired';
    return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
  }

  final remaining = expiry.difference(now ?? DateTime.now());
  if (remaining <= Duration.zero) return 'Expired';

  if (remaining < const Duration(hours: 24)) {
    final totalMinutes =
        (remaining.inMicroseconds / Duration.microsecondsPerMinute).ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return 'Expires in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    if (minutes == 0) {
      return 'Expires in $hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return 'Expires in $hours ${hours == 1 ? 'hour' : 'hours'} '
        '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  final days = (remaining.inMicroseconds / Duration.microsecondsPerDay).ceil();
  return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
}
