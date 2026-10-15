import '../services/iap_service.dart';

class PlanResponse {
  bool? success;
  int? count;
  List<Plan>? plans;

  PlanResponse({this.success, this.count, this.plans});

  PlanResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    count = json['count'];
    if (json['plans'] != null) {
      plans = <Plan>[];
      json['plans'].forEach((v) {
        plans!.add(Plan.fromJson(v));
      });
    }
  }
}

class Plan {
  String? id;
  String? name;
  String? category;
  String? planCategory;
  int? price;
  int? duration;
  List<String>? features;
  bool? isActive;
  String? planType;
  bool? isRecommended;
  String? appleProductId;
  int? level;

  Plan({
    this.id,
    this.name,
    this.category,
    this.planCategory,
    this.price,
    this.duration,
    this.features,
    this.isActive,
    this.planType,
    this.isRecommended,
    this.appleProductId,
    this.level,
  });

  Plan.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    name = json['name'];
    category = json['category']?.toString();
    planCategory = json['planCategory']?.toString();
    price = json['price'];
    duration = json['duration'];
    features = json['features'] != null
        ? (json['features'] as List)
            .map(
              (f) => f.toString().replaceAll(
                RegExp(r'profashional', caseSensitive: false),
                'Professional',
              ),
            )
            .toList()
        : null;
    planType = json['planType']?.toString();
    isRecommended = json['isRecommended'];
    appleProductId = json['appleProductId'] ?? json['productId'];

    // Normalize misconfigured planType (e.g. backend returning 'monthly' for a 365-day Yearly plan)
    final lowerPlanName = (name ?? '').toLowerCase();
    final isYearlyIdentity = duration == 365 ||
        appleProductId == 'com.app.catchWatch.sub.premium.yearly' ||
        lowerPlanName.contains('yearly') ||
        lowerPlanName.contains('annual');
    if (isYearlyIdentity && (planType == null || planType == 'monthly')) {
      planType = 'yearly';
    }

    int? parseLevel(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
      return null;
    }
    level = parseLevel(json['level'] ?? json['rank'] ?? json['tier']);
  }

  /// Canonical plan type: 'weekly', 'monthly', or 'yearly' (or 'creator_verification')
  String get effectivePlanType {
    if (isOrangeTickPlan || isBlueTickPlan) return 'creator_verification';

    final prodId = effectiveAppleProductId;
    if (prodId == ottWeeklyProductId) return 'weekly';
    if (prodId == ottYearlyProductId) return 'yearly';
    if (prodId == ottMonthlyProductId) return 'monthly';

    if (duration == 365 || (name?.toLowerCase().contains('year') ?? false)) {
      return 'yearly';
    }
    if (duration == 7 || (name?.toLowerCase().contains('week') ?? false)) {
      return 'weekly';
    }
    if (duration == 30 || (name?.toLowerCase().contains('month') ?? false)) {
      return 'monthly';
    }

    final raw = (planType ?? '').toLowerCase().trim();
    if (raw.isNotEmpty) return raw;
    return 'monthly';
  }

  /// Returns true if this plan is classified as a Blue Tick plan
  bool get isBlueTickPlan {
    final cat = (category ?? planCategory ?? '').toLowerCase().trim();
    if (cat == 'bluetick' || cat == 'blue_tick' || cat == 'blue') return true;

    final type = (planType ?? '').toLowerCase().trim();
    if (type == 'bluetick' || type == 'blue_tick' || type == 'blue') {
      return true;
    }

    final lowerName = (name ?? '').toLowerCase().trim();
    if (lowerName.contains('blue tick') ||
        lowerName.contains('bluetick') ||
        lowerName.contains('blue badge')) {
      return true;
    }
    return false;
  }

  /// Returns true if this plan is classified as an Orange Tick / Creator Verification plan
  bool get isOrangeTickPlan {
    if (isBlueTickPlan) return false;

    final cat = (category ?? planCategory ?? '').toLowerCase().trim();
    if (cat.contains('orange') ||
        cat.contains('creator') ||
        cat == 'verification') {
      return true;
    }

    final type = (planType ?? '').toLowerCase().trim();
    if (type.contains('orange') ||
        type.contains('creator') ||
        type == 'verification') {
      return true;
    }

    final lowerName = (name ?? '').toLowerCase().trim();
    if (lowerName.contains('orange') || lowerName.contains('creator')) {
      return true;
    }

    return false;
  }

  /// Returns true if this plan is eligible to be presented or used in the Orange Tick flow
  bool get isEligibleForOrangeTick => !isBlueTickPlan;

  /// App Store Connect Product ID.
  /// Resolves to weekly, monthly, or yearly based on backend appleProductId,
  /// plan name, duration, or planType. Defaults to monthly.
  /// Price is strictly excluded to prevent misclassification under promotions/discounts.
  String get effectiveAppleProductId {
    // 1. If appleProductId explicitly matches a registered official StoreKit ID, return it
    if (appleProductId == orangeTickProductId ||
        appleProductId == ottWeeklyProductId ||
        appleProductId == ottMonthlyProductId ||
        appleProductId == ottYearlyProductId) {
      return appleProductId!;
    }

    final lowerName = name?.toLowerCase() ?? '';
    final lowerType = planType?.toLowerCase() ?? '';
    final lowerCat = (category ?? planCategory ?? '').toLowerCase();

    // 2. Creator verification subscription:
    // Any creator verification / tick / orange / bluetick plan maps strictly to orangeTickProductId
    if (isOrangeTickPlan ||
        lowerName.contains('orange') ||
        lowerType.contains('orange') ||
        lowerCat.contains('orange') ||
        lowerName.contains('creator') ||
        lowerType.contains('creator') ||
        lowerCat.contains('creator') ||
        lowerName.contains('tick') ||
        lowerType.contains('verification') ||
        lowerCat.contains('verification') ||
        lowerName.contains('bluetick') ||
        lowerType.contains('bluetick') ||
        lowerCat.contains('bluetick')) {
      return orangeTickProductId;
    }

    // 3. Fallback to backend-provided Apple Product ID if non-empty
    if (appleProductId != null && appleProductId!.isNotEmpty) {
      return appleProductId!;
    }

    // 4. OTT Structural / identity fallback
    // Weekly: name/type contains "week" or duration is 7 days
    if (lowerName.contains('week') ||
        lowerType.contains('week') ||
        duration == 7) {
      return ottWeeklyProductId;
    }

    // Yearly: name contains "year" or "annual", type contains "year", or duration is 365 days / 12 months
    if (lowerName.contains('year') ||
        lowerName.contains('annual') ||
        lowerType.contains('year') ||
        duration == 365 ||
        duration == 12) {
      return ottYearlyProductId;
    }

    // Monthly: default core recurring plan
    return ottMonthlyProductId;
  }

  /// Effective plan hierarchy level (1: Weekly, 2: Monthly, 3: Yearly).
  /// Higher integer represents a higher tier subscription.
  int get effectiveLevel {
    if (level != null && level! > 0) return level!;

    if (isOrangeTickPlan || isBlueTickPlan) return 10;

    final prodId = effectiveAppleProductId;
    if (prodId == ottWeeklyProductId) return 1;
    if (prodId == ottMonthlyProductId) return 2;
    if (prodId == ottYearlyProductId) return 3;

    final lowerName = (name ?? '').toLowerCase();
    final lowerType = (planType ?? '').toLowerCase();

    if (lowerName.contains('week') ||
        lowerType.contains('week') ||
        duration == 7) {
      return 1;
    }
    if (lowerName.contains('year') ||
        lowerName.contains('annual') ||
        lowerType.contains('year') ||
        duration == 365 ||
        duration == 12) {
      return 3;
    }
    if (lowerName.contains('month') ||
        lowerType.contains('month') ||
        duration == 30 ||
        duration == 1) {
      return 2;
    }

    if (price != null) {
      if (price! <= 99) return 1;
      if (price! <= 399) return 2;
      return 3;
    }

    return 1;
  }
}

class SubscriptionStatusResponse {
  bool? success;
  String? message;
  SubscriptionData? subscription;
  int? remainingDays;

  SubscriptionStatusResponse({
    this.success,
    this.message,
    this.subscription,
    this.remainingDays,
  });

  SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] == true ||
        json['status'] == true ||
        json['status'] == 'success') {
      success = true;
    } else if (json['success'] == false ||
        json['status'] == false ||
        json['status'] == 'error' ||
        json['status'] == 'fail') {
      success = false;
    } else {
      success = json['success'];
    }

    message = json['message']?.toString() ?? json['error']?.toString();

    final dynamic subData = json['subscription'] ??
        (json['data'] is Map<String, dynamic>
            ? (json['data']['subscription'] ??
                (((json['data'] as Map<String, dynamic>).containsKey('plan') ||
                  (json['data'] as Map<String, dynamic>).containsKey('planId') ||
                  (json['data'] as Map<String, dynamic>).containsKey('status') ||
                  (json['data'] as Map<String, dynamic>).containsKey('endDate') ||
                  (json['data'] as Map<String, dynamic>).containsKey('_id'))
                    ? json['data']
                    : null))
            : null);

    subscription = subData is Map<String, dynamic>
        ? SubscriptionData.fromJson(subData)
        : null;

    final dynamic remDays = json['remainingDays'] ??
        json['data']?['remainingDays'] ??
        json['remaining_days'];
    remainingDays = remDays is int
        ? remDays
        : int.tryParse(remDays?.toString() ?? '');
  }
}

class SubscriptionData {
  String? id;
  String? user;
  dynamic plan; // Can be ID string or Plan object
  String? status;
  int? amount;
  String? currency;
  String? startDate;
  String? endDate;
  int? level;

  String? gateway;
  String? originalTransactionId;

  SubscriptionData({
    this.id,
    this.user,
    this.plan,
    this.status,
    this.amount,
    this.currency,
    this.startDate,
    this.endDate,
    this.level,
    this.gateway,
    this.originalTransactionId,
  });

  SubscriptionData.fromJson(Map<String, dynamic> json) {
    id = json['_id'] ?? json['id'];
    user = json['user'];
    if (json['plan'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['plan']);
    } else {
      plan = json['plan'] ?? json['planId'];
    }
    status = json['status'];
    amount = json['amount'] is int
        ? json['amount']
        : int.tryParse(json['amount']?.toString() ?? '');
    currency = json['currency'];
    startDate = json['startDate'];
    endDate = json['endDate'];
    gateway = json['gateway'] ??
        json['paymentGateway'] ??
        json['paymentMethod'] ??
        json['provider'] ??
        json['source'] ??
        json['platform'];
    originalTransactionId =
        json['originalTransactionId'] ?? json['original_transaction_id'];

    int? parseLevel(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
      return null;
    }

    level = parseLevel(json['level'] ?? json['rank'] ?? json['tier']);
    if (level == null && plan is Plan) {
      level = (plan as Plan).effectiveLevel;
    }
  }

  /// Whether the payment gateway or provider is Apple / StoreKit
  bool get isAppleGateway {
    final g = (gateway ?? '').toLowerCase().trim();
    return g.contains('apple') || g.contains('storekit') || g.contains('ios');
  }

  /// Returns the subscription's plan ID regardless of whether plan is a String or Plan object
  String? get planId {
    if (plan is Plan) {
      return (plan as Plan).id;
    } else if (plan is String) {
      return plan as String;
    }
    return null;
  }

  /// Returns the subscription's plan name if available
  String? get planName {
    if (plan is Plan) {
      return (plan as Plan).name;
    }
    return null;
  }

  /// Returns the typed Plan object if available
  Plan? get planObject {
    if (plan is Plan) {
      return plan as Plan;
    }
    return null;
  }

  /// Checks whether subscription status is officially active
  bool get isActive {
    final s = (status ?? '').toLowerCase().trim();
    return s == 'active';
  }

  /// Checks whether subscription has been cancelled but may still have remaining time
  bool get isCancelled {
    final s = (status ?? '').toLowerCase().trim();
    return s == 'cancelled' || s == 'canceled';
  }

  /// Checks whether the subscription end date is in the past
  bool get isDateExpired {
    if (endDate != null && endDate!.isNotEmpty) {
      try {
        final end = DateTime.parse(endDate!);
        final now = end.isUtc ? DateTime.now().toUtc() : DateTime.now();
        return end.isBefore(now);
      } catch (_) {}
    }
    return false;
  }

  /// Checks whether subscription is expired by status, date, or remaining days
  bool isExpired({int? remainingDays}) {
    final s = (status ?? '').toLowerCase().trim();
    if (s == 'expired') return true;
    if (isDateExpired) return true;
    if (remainingDays != null && remainingDays < 0) return true;
    if (remainingDays != null && remainingDays == 0 && isDateExpired) return true;
    return false;
  }

  /// Checks whether the subscription is cancelled but the paid entitlement remains valid
  bool isCancelledWithEntitlement({int? remainingDays}) {
    if (!isCancelled) return false;
    return !isExpired(remainingDays: remainingDays);
  }

  /// Resolves the comprehensive entitlement status of this subscription
  EntitlementClassification getEntitlementClassification({int? remainingDays}) {
    if (isExpired(remainingDays: remainingDays)) {
      return EntitlementClassification.expired;
    }
    if (isCancelledWithEntitlement(remainingDays: remainingDays)) {
      return EntitlementClassification.cancelledWithEntitlement;
    }
    if (isActive) {
      return EntitlementClassification.activeEntitlement;
    }
    if (remainingDays != null && remainingDays > 0 && !isDateExpired) {
      return EntitlementClassification.activeEntitlement;
    }
    return EntitlementClassification.expired;
  }

  /// Formatted end date string (e.g. "24 Oct 2026")
  String? get formattedEndDate {
    if (endDate == null || endDate!.isEmpty) return null;
    try {
      final dt = DateTime.parse(endDate!).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return endDate;
    }
  }

  /// Returns friendly plan display name
  String getEffectivePlanName(List<Plan> availablePlans) {
    if (plan is Plan) {
      final n = (plan as Plan).name;
      if (n != null && n.isNotEmpty) return n;
    }
    final id = planId;
    if (id != null) {
      for (final p in availablePlans) {
        if (p.id == id && p.name != null && p.name!.isNotEmpty) {
          return p.name!;
        }
      }
    }
    return 'Catch & Watch Premium';
  }

  /// Validates whether the subscription is currently active/entitled and within valid period
  bool isCurrentlyValid({int? remainingDays}) {
    if (isExpired(remainingDays: remainingDays)) return false;
    final s = (status ?? '').toLowerCase().trim();
    if (s == 'active') return true;
    if (isCancelledWithEntitlement(remainingDays: remainingDays)) return true;
    if (remainingDays != null && remainingDays > 0 && !isDateExpired) return true;
    return false;
  }

  /// Resolves effective level comparing against all known plans
  int getEffectiveLevel(List<Plan> availablePlans) {
    if (level != null && level! > 0) return level!;
    if (plan is Plan) return (plan as Plan).effectiveLevel;

    final id = planId;
    if (id != null && id.isNotEmpty) {
      for (final p in availablePlans) {
        if (p.id == id) return p.effectiveLevel;
      }
    }

    if (amount != null) {
      if (amount! <= 99) return 1;
      if (amount! <= 399) return 2;
      return 3;
    }
    return 1;
  }
}

/// Classification of a user's subscription entitlement
enum EntitlementClassification {
  /// Active, auto-renewing or ongoing paid subscription
  activeEntitlement,

  /// Cancelled at store/provider level, but remaining paid period is still valid
  cancelledWithEntitlement,

  /// Period ended or subscription explicitly terminated/expired
  expired,

  /// No record of any subscription
  none,
}

/// Action classification for a plan relative to user's currently active subscription
enum PlanActionType {
  /// No active subscription or current subscription expired. Any plan can be purchased.
  purchase,

  /// Target plan matches the active subscription. Duplicate purchase blocked.
  current,

  /// Target plan is higher level than active subscription. Upgrade permitted.
  upgrade,

  /// Target plan is lower level than active subscription. Downgrade blocked until expiry.
  downgrade,
}

/// Determines the valid action for a target plan based on current verified subscription
PlanActionType determinePlanAction({
  required Plan targetPlan,
  required SubscriptionData? currentSubscription,
  required int? remainingDays,
  required List<Plan> allPlans,
}) {
  if (currentSubscription == null ||
      !currentSubscription.isCurrentlyValid(remainingDays: remainingDays)) {
    return PlanActionType.purchase;
  }

  final String? activePlanId = currentSubscription.planId;
  final Plan? activePlanObj = currentSubscription.planObject;

  // Check if target is the same active plan (duplicate purchase prevention)
  final bool isSameId = activePlanId != null &&
      activePlanId.isNotEmpty &&
      targetPlan.id != null &&
      targetPlan.id == activePlanId;
  final bool isSameAppleProduct = activePlanObj != null &&
      activePlanObj.effectiveAppleProductId == targetPlan.effectiveAppleProductId;

  if (isSameId || isSameAppleProduct) {
    return PlanActionType.current;
  }

  final int currentLevel = currentSubscription.getEffectiveLevel(allPlans);
  final int targetLevel = targetPlan.effectiveLevel;

  if (targetLevel > currentLevel) {
    return PlanActionType.upgrade;
  } else if (targetLevel < currentLevel) {
    return PlanActionType.downgrade;
  } else {
    // Same level tier (e.g. promotional variation of same duration)
    return PlanActionType.current;
  }
}

/// Upgrade pricing quote breakdown
class UpgradeQuote {
  final Plan currentPlan;
  final Plan targetPlan;
  final int originalPrice;
  final int creditAmount;
  final int payableAmount;
  final String currency;
  final int? remainingDays;
  final bool isCreditExceeding;

  UpgradeQuote({
    required this.currentPlan,
    required this.targetPlan,
    required this.originalPrice,
    required this.creditAmount,
    required this.payableAmount,
    this.currency = '₹',
    this.remainingDays,
    this.isCreditExceeding = false,
  });

  /// Factory from backend response if backend provides an upgrade quote endpoint
  factory UpgradeQuote.fromJson(
    Map<String, dynamic> json, {
    required Plan currentPlan,
    required Plan targetPlan,
  }) {
    final orig = json['originalPrice'] ?? json['newPlanPrice'] ?? targetPlan.price ?? 0;
    final credit = json['creditAmount'] ?? json['unusedCredit'] ?? json['eligibleCredit'] ?? 0;
    final payable = json['payableAmount'] ?? json['finalAmount'] ?? json['amount'] ?? 0;

    final origInt = orig is int ? orig : int.tryParse(orig.toString()) ?? 0;
    final creditInt = credit is int ? credit : int.tryParse(credit.toString()) ?? 0;
    final payableInt = payable is int ? payable : int.tryParse(payable.toString()) ?? 0;

    return UpgradeQuote(
      currentPlan: currentPlan,
      targetPlan: targetPlan,
      originalPrice: origInt,
      creditAmount: creditInt,
      payableAmount: payableInt < 0 ? 0 : payableInt,
      currency: json['currency']?.toString() ?? '₹',
      remainingDays: json['remainingDays'] is int
          ? json['remainingDays']
          : int.tryParse(json['remainingDays']?.toString() ?? ''),
      isCreditExceeding: creditInt >= origInt,
    );
  }

  /// Calculates an estimated prorated upgrade quote using approved daily rate proration
  factory UpgradeQuote.calculateEstimate({
    required Plan currentPlan,
    required Plan targetPlan,
    required int remainingDays,
  }) {
    final targetPrice = targetPlan.price ?? 0;
    final currentPrice = currentPlan.price ?? 0;
    final currentDuration = currentPlan.duration ??
        (currentPlan.effectiveLevel == 1
            ? 7
            : (currentPlan.effectiveLevel == 2 ? 30 : 365));

    int credit = 0;
    if (currentDuration > 0 && remainingDays > 0) {
      final double dailyRate = currentPrice / currentDuration;
      credit = (dailyRate * remainingDays).floor();
      // Cap credit at current plan price
      if (credit > currentPrice) credit = currentPrice;
    }

    final payable = (targetPrice - credit) > 0 ? (targetPrice - credit) : 0;

    return UpgradeQuote(
      currentPlan: currentPlan,
      targetPlan: targetPlan,
      originalPrice: targetPrice,
      creditAmount: credit,
      payableAmount: payable,
      remainingDays: remainingDays,
      isCreditExceeding: credit >= targetPrice,
    );
  }
}
