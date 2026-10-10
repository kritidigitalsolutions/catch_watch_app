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
    isActive = json['isActive'];
    planType = json['planType']?.toString();
    isRecommended = json['isRecommended'];
    appleProductId = json['appleProductId'] ?? json['productId'];
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
}

class SubscriptionStatusResponse {
  bool? success;
  SubscriptionData? subscription;
  int? remainingDays;

  SubscriptionStatusResponse({
    this.success,
    this.subscription,
    this.remainingDays,
  });

  SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    subscription = json['subscription'] != null
        ? SubscriptionData.fromJson(json['subscription'])
        : null;
    remainingDays = json['remainingDays'];
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

  SubscriptionData({
    this.id,
    this.user,
    this.plan,
    this.status,
    this.amount,
    this.currency,
    this.startDate,
    this.endDate,
  });

  SubscriptionData.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    user = json['user'];
    if (json['plan'] is Map<String, dynamic>) {
      plan = Plan.fromJson(json['plan']);
    } else {
      plan = json['plan'];
    }
    status = json['status'];
    amount = json['amount'];
    currency = json['currency'];
    startDate = json['startDate'];
    endDate = json['endDate'];
  }
}
