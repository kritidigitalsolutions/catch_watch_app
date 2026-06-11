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
  int? price;
  int? duration;
  List<String>? features;
  bool? isActive;
  String? planType;
  bool? isRecommended;

  Plan({
    this.id,
    this.name,
    this.price,
    this.duration,
    this.features,
    this.isActive,
    this.planType,
    this.isRecommended,
  });

  Plan.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    name = json['name'];
    price = json['price'];
    duration = json['duration'];
    features = json['features'] != null ? List<String>.from(json['features']) : null;
    isActive = json['isActive'];
    planType = json['planType'];
    isRecommended = json['isRecommended'];
  }
}

class SubscriptionStatusResponse {
  bool? success;
  SubscriptionData? subscription;
  int? remainingDays;

  SubscriptionStatusResponse({this.success, this.subscription, this.remainingDays});

  SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    subscription = json['subscription'] != null ? SubscriptionData.fromJson(json['subscription']) : null;
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
