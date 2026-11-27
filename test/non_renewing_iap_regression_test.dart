import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/services/iap_service.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Non-Renewing IAP Product ID & Helper Validation', () {
    test('all 4 new Product IDs are defined correctly', () {
      expect(orangeTickProductId, 'com.app.catchWatch.creator.orangetick');
      expect(ottWeeklyProductId, 'com.app.catchWatch.premium.weekly');
      expect(ottMonthlyProductId, 'com.app.catchWatch.premium.monthly');
      expect(ottYearlyProductId, 'com.app.catchWatch.premium.yearly');
    });

    test('helpers identify current and legacy Orange Tick products', () {
      expect(isOrangeTickProduct(orangeTickProductId), isTrue);
      expect(isOrangeTickProduct(legacyOrangeTickProductId), isTrue);
      expect(isOrangeTickProduct('com.app.catchWatch.creator.orangetick'), isTrue);
      expect(isOrangeTickProduct('com.app.catchWatch.sub.creator.orangetick'), isTrue);
      expect(isOrangeTickProduct(ottWeeklyProductId), isFalse);
      expect(isOrangeTickProduct(null), isFalse);
    });

    test('helpers identify current and legacy OTT Weekly products', () {
      expect(isOttWeeklyProduct(ottWeeklyProductId), isTrue);
      expect(isOttWeeklyProduct(legacyOttWeeklyProductId), isTrue);
      expect(isOttWeeklyProduct('com.app.catchWatch.premium.weekly'), isTrue);
      expect(isOttWeeklyProduct('com.app.catchWatch.sub.premium.weekly'), isTrue);
      expect(isOttWeeklyProduct(ottMonthlyProductId), isFalse);
      expect(isOttWeeklyProduct(null), isFalse);
    });

    test('helpers identify current and legacy OTT Monthly products', () {
      expect(isOttMonthlyProduct(ottMonthlyProductId), isTrue);
      expect(isOttMonthlyProduct(legacyOttMonthlyProductId), isTrue);
      expect(isOttMonthlyProduct('com.app.catchWatch.premium.monthly'), isTrue);
      expect(isOttMonthlyProduct('com.app.catchWatch.sub.premium.monthly'), isTrue);
      expect(isOttMonthlyProduct(ottYearlyProductId), isFalse);
      expect(isOttMonthlyProduct(null), isFalse);
    });

    test('helpers identify current and legacy OTT Yearly products', () {
      expect(isOttYearlyProduct(ottYearlyProductId), isTrue);
      expect(isOttYearlyProduct(legacyOttYearlyProductId), isTrue);
      expect(isOttYearlyProduct('com.app.catchWatch.premium.yearly'), isTrue);
      expect(isOttYearlyProduct('com.app.catchWatch.sub.premium.yearly'), isTrue);
      expect(isOttYearlyProduct(ottWeeklyProductId), isFalse);
      expect(isOttYearlyProduct(null), isFalse);
    });

    test('isOttProduct helper recognizes all OTT tiers but rejects Orange Tick', () {
      expect(isOttProduct(ottWeeklyProductId), isTrue);
      expect(isOttProduct(ottMonthlyProductId), isTrue);
      expect(isOttProduct(ottYearlyProductId), isTrue);
      expect(isOttProduct(legacyOttWeeklyProductId), isTrue);
      expect(isOttProduct(legacyOttMonthlyProductId), isTrue);
      expect(isOttProduct(legacyOttYearlyProductId), isTrue);
      expect(isOttProduct(orangeTickProductId), isFalse);
      expect(isOttProduct(legacyOrangeTickProductId), isFalse);
      expect(isOttProduct(null), isFalse);
    });
  });

  group('Plan Model Dynamic Mapping with New Product IDs', () {
    test('Plan dynamically resolves effectiveAppleProductId for new product IDs', () {
      final weeklyPlan = Plan(id: 'w1', name: 'Weekly Pass', appleProductId: ottWeeklyProductId);
      final monthlyPlan = Plan(id: 'm1', name: 'Monthly VIP', appleProductId: ottMonthlyProductId);
      final yearlyPlan = Plan(id: 'y1', name: 'Yearly Access', appleProductId: ottYearlyProductId);
      final orangePlan = Plan(id: 'o1', name: 'Orange Tick Verification', appleProductId: orangeTickProductId);

      expect(weeklyPlan.effectiveAppleProductId, ottWeeklyProductId);
      expect(monthlyPlan.effectiveAppleProductId, ottMonthlyProductId);
      expect(yearlyPlan.effectiveAppleProductId, ottYearlyProductId);
      expect(orangePlan.effectiveAppleProductId, orangeTickProductId);
    });

    test('Plan correctly assigns effectiveLevel to new OTT product IDs', () {
      final weeklyPlan = Plan(id: 'w1', appleProductId: ottWeeklyProductId);
      final monthlyPlan = Plan(id: 'm1', appleProductId: ottMonthlyProductId);
      final yearlyPlan = Plan(id: 'y1', appleProductId: ottYearlyProductId);
      final orangePlan = Plan(id: 'o1', appleProductId: orangeTickProductId);

      expect(weeklyPlan.effectiveLevel, 1);
      expect(monthlyPlan.effectiveLevel, 2);
      expect(yearlyPlan.effectiveLevel, 3);
      expect(orangePlan.effectiveLevel, 10);
    });

    test('Legacy product IDs automatically map forward to new IDs in effectiveAppleProductId', () {
      final legacyWeekly = Plan(id: 'lw', appleProductId: legacyOttWeeklyProductId);
      final legacyMonthly = Plan(id: 'lm', appleProductId: legacyOttMonthlyProductId);
      final legacyYearly = Plan(id: 'ly', appleProductId: legacyOttYearlyProductId);
      final legacyOrange = Plan(id: 'lo', appleProductId: legacyOrangeTickProductId);

      expect(legacyWeekly.effectiveAppleProductId, ottWeeklyProductId);
      expect(legacyMonthly.effectiveAppleProductId, ottMonthlyProductId);
      expect(legacyYearly.effectiveAppleProductId, ottYearlyProductId);
      expect(legacyOrange.effectiveAppleProductId, orangeTickProductId);
    });

    test('Plans with matching new product IDs partition correctly into Weekly, Monthly, and Yearly', () {
      final plans = [
        Plan(id: 'p_week', name: 'Catch&Watch Weekly', appleProductId: ottWeeklyProductId),
        Plan(id: 'p_month', name: 'Catch&Watch Monthly', appleProductId: ottMonthlyProductId),
        Plan(id: 'p_year', name: 'Catch&Watch Yearly', appleProductId: ottYearlyProductId),
      ];

      Plan? weeklyPlan;
      Plan? monthlyPlan;
      Plan? yearlyPlan;

      for (final p in plans) {
        final prodId = p.effectiveAppleProductId;
        if (isOttWeeklyProduct(prodId) && weeklyPlan == null) {
          weeklyPlan = p;
        } else if (isOttYearlyProduct(prodId) && yearlyPlan == null) {
          yearlyPlan = p;
        } else if (isOttMonthlyProduct(prodId) && monthlyPlan == null) {
          monthlyPlan = p;
        }
      }

      expect(weeklyPlan, isNotNull);
      expect(weeklyPlan!.id, 'p_week');
      expect(monthlyPlan, isNotNull);
      expect(monthlyPlan!.id, 'p_month');
      expect(yearlyPlan, isNotNull);
      expect(yearlyPlan!.id, 'p_year');
    });

    test('Manual repurchase is permitted when previous subscription is expired', () {
      final allPlans = [
        Plan(id: 'p_week', level: 1, appleProductId: ottWeeklyProductId),
        Plan(id: 'p_month', level: 2, appleProductId: ottMonthlyProductId),
        Plan(id: 'p_year', level: 3, appleProductId: ottYearlyProductId),
      ];

      final expiredSub = SubscriptionData(
        id: 'sub_old',
        plan: 'p_month',
        status: 'expired',
        endDate: '2026-01-01T00:00:00Z',
      );

      final action = determinePlanAction(
        targetPlan: allPlans[1],
        currentSubscription: expiredSub,
        remainingDays: 0,
        allPlans: allPlans,
      );

      expect(action, PlanActionType.purchase);
    });
  });

  group('Dynamic Downgrade Restriction Message', () {
    final availablePlans = [
      Plan(id: 'p_week', name: 'CatchWatch Premium Weekly', level: 1, appleProductId: ottWeeklyProductId),
      Plan(id: 'p_month', name: 'CatchWatch Premium Monthly', level: 2, appleProductId: ottMonthlyProductId),
      Plan(id: 'p_year', name: 'CatchWatch Premium Yearly', level: 3, appleProductId: ottYearlyProductId),
    ];

    test('generates dynamic message with active Monthly plan and formatted dd MMM yyyy endDate', () {
      final sub = SubscriptionData(
        id: 'sub_active_month',
        plan: 'p_month',
        status: 'active',
        endDate: '2026-12-19T12:00:00Z',
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active CatchWatch Premium Monthly plan. You cannot switch to a lower plan until your current plan validity ends on 19 Dec 2026.',
      );
    });

    test('generates dynamic message with active Yearly plan', () {
      final sub = SubscriptionData(
        id: 'sub_active_year',
        plan: 'p_year',
        status: 'active',
        endDate: '2027-11-19T12:00:00Z',
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active CatchWatch Premium Yearly plan. You cannot switch to a lower plan until your current plan validity ends on 19 Nov 2027.',
      );
    });

    test('generates dynamic message with active Weekly plan', () {
      final sub = SubscriptionData(
        id: 'sub_active_week',
        plan: 'p_week',
        status: 'active',
        endDate: '2026-11-26T12:00:00Z',
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active CatchWatch Premium Weekly plan. You cannot switch to a lower plan until your current plan validity ends on 26 Nov 2026.',
      );
    });

    test('shows safe fallback message when endDate is null', () {
      final sub = SubscriptionData(
        id: 'sub_no_date',
        plan: 'p_month',
        status: 'active',
        endDate: null,
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active CatchWatch Premium Monthly plan. You cannot switch to a lower plan until your current plan validity ends.',
      );
    });

    test('shows safe fallback message when endDate is invalid string', () {
      final sub = SubscriptionData(
        id: 'sub_invalid_date',
        plan: 'p_month',
        status: 'active',
        endDate: 'not-a-valid-date',
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active CatchWatch Premium Monthly plan. You cannot switch to a lower plan until your current plan validity ends.',
      );
    });

    test('shows safe fallback message when subscription is null', () {
      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: null,
        availablePlans: availablePlans,
      );

      expect(
        message,
        'You already have an active Premium plan. You cannot switch to a lower plan until your current plan validity ends.',
      );
    });

    test('does not duplicate "plan" word when plan name already ends with "Plan"', () {
      final customPlans = [
        Plan(id: 'cp_1', name: 'VIP Monthly Plan', level: 2),
      ];
      final sub = SubscriptionData(
        id: 'sub_plan_word',
        plan: 'cp_1',
        status: 'active',
        endDate: '2026-12-19T12:00:00Z',
      );

      final message = SubscriptionScreen.formatDowngradeRestrictionMessage(
        subscription: sub,
        availablePlans: customPlans,
      );

      expect(
        message,
        'You already have an active VIP Monthly Plan. You cannot switch to a lower plan until your current plan validity ends on 19 Dec 2026.',
      );
    });
  });

  group('Development Server URL Resolution Tests', () {
    test('AppUrl resolves to local dev server 192.168.1.26:5000', () {
      expect(AppUrl.serverUrl, 'http://192.168.1.26:5000');
      expect(AppUrl.baseUrl, 'http://192.168.1.26:5000/api');
    });

    test('Orange Tick verification endpoints resolve to dev server', () {
      expect(
        AppUrl.updateVerification,
        'http://192.168.1.26:5000/api/verification/update',
      );
      expect(
        AppUrl.applyVerification,
        'http://192.168.1.26:5000/api/verification/apply',
      );
      expect(
        AppUrl.verificationStatus,
        'http://192.168.1.26:5000/api/verification/status',
      );
      expect(
        AppUrl.getOrangetickPlans,
        'http://192.168.1.26:5000/api/plan/orangetick',
      );
    });

    test('isTrustedApiUrl recognizes local dev server URLs', () {
      expect(
        AppUrl.isTrustedApiUrl('http://192.168.1.26:5000/api/verification/update'),
        isTrue,
      );
      expect(
        AppUrl.isTrustedApiUrl('https://api.catchandwatch.com/api/verification/update'),
        isFalse,
      );
    });
  });

  group('Orange Tick Verification Stale-State & Edit Mode Hardening Tests', () {
    test('isPendingStatus identifies eligible pending statuses and rejects non-pending', () {
      expect(VerificationProvider.isPendingStatus('pending'), isTrue);
      expect(VerificationProvider.isPendingStatus('PENDING'), isTrue);
      expect(VerificationProvider.isPendingStatus('under_review'), isTrue);
      expect(VerificationProvider.isPendingStatus('UNDER_REVIEW'), isTrue);
      expect(VerificationProvider.isPendingStatus('in_review'), isTrue);
      expect(VerificationProvider.isPendingStatus('IN_REVIEW'), isTrue);
      expect(VerificationProvider.isPendingStatus('processing'), isTrue);

      expect(VerificationProvider.isPendingStatus('APPROVED'), isFalse);
      expect(VerificationProvider.isPendingStatus('VERIFIED'), isFalse);
      expect(VerificationProvider.isPendingStatus('REJECTED'), isFalse);
      expect(VerificationProvider.isPendingStatus('CANCELLED'), isFalse);
      expect(VerificationProvider.isPendingStatus('CANCELED'), isFalse);
      expect(VerificationProvider.isPendingStatus('CLOSED'), isFalse);
      expect(VerificationProvider.isPendingStatus('NOT_VERIFIED'), isFalse);
      expect(VerificationProvider.isPendingStatus(null), isFalse);
      expect(VerificationProvider.isPendingStatus(''), isFalse);
    });

    test('isEligibleForEdit requires both a valid server-assigned ID and eligible pending status', () {
      // Null application
      expect(VerificationProvider.isEligibleForEdit(null), isFalse);

      // Application with no ID
      final appNoId = VerificationApplication(status: 'PENDING');
      expect(VerificationProvider.isEligibleForEdit(appNoId), isFalse);

      // Application with empty ID
      final appEmptyId = VerificationApplication(id: '', status: 'PENDING');
      expect(VerificationProvider.isEligibleForEdit(appEmptyId), isFalse);

      // Application with valid ID but rejected / cancelled / closed status
      final appRejected = VerificationApplication(id: 'app_1', status: 'REJECTED');
      expect(VerificationProvider.isEligibleForEdit(appRejected), isFalse);

      final appCancelled = VerificationApplication(id: 'app_2', status: 'CANCELLED');
      expect(VerificationProvider.isEligibleForEdit(appCancelled), isFalse);

      final appNotVerified = VerificationApplication(id: 'app_3', status: 'NOT_VERIFIED');
      expect(VerificationProvider.isEligibleForEdit(appNotVerified), isFalse);

      final appApproved = VerificationApplication(id: 'app_4', status: 'APPROVED');
      expect(VerificationProvider.isEligibleForEdit(appApproved), isFalse);

      // Application with valid ID and pending status -> Eligible!
      final appPending = VerificationApplication(id: 'app_valid_1', status: 'PENDING');
      expect(VerificationProvider.isEligibleForEdit(appPending), isTrue);

      final appUnderReview = VerificationApplication(id: 'app_valid_2', status: 'UNDER_REVIEW');
      expect(VerificationProvider.isEligibleForEdit(appUnderReview), isTrue);

      final appInReview = VerificationApplication(id: 'app_valid_3', status: 'in_review');
      expect(VerificationProvider.isEligibleForEdit(appInReview), isTrue);
    });

    test('isNoPendingRequestError recognizes 404 / no pending request messages', () {
      expect(
        VerificationProvider.isNoPendingRequestError('No pending verification request available to update'),
        isTrue,
      );
      expect(
        VerificationProvider.isNoPendingRequestError({'message': 'No pending verification request available to update'}),
        isTrue,
      );
      expect(
        VerificationProvider.isNoPendingRequestError({'error': 'no pending request found'}),
        isTrue,
      );
      expect(
        VerificationProvider.isNoPendingRequestError('Generic connection failure'),
        isFalse,
      );
      expect(
        VerificationProvider.isNoPendingRequestError(null),
        isFalse,
      );
    });

    test('VerificationProvider stale application is cleared and effectiveStatus reflects NOT_VERIFIED', () {
      final provider = VerificationProvider();

      // Simulate a previously populated application in state
      final staleApp = VerificationApplication(
        id: 'stale_id_123',
        status: 'PENDING',
        fullName: 'Stale User',
      );
      provider.setCurrentApplicationForTesting(staleApp);

      expect(provider.currentApplication, isNotNull);
      expect(provider.currentApplication!.id, 'stale_id_123');
      expect(provider.effectiveStatus, 'PENDING');

      // Clear state (e.g. when API returns null application)
      provider.clearApplication();

      expect(provider.currentApplication, isNull);
      expect(provider.effectiveStatus, 'NOT_VERIFIED');
      expect(VerificationProvider.isEligibleForEdit(provider.currentApplication), isFalse);
    });

    test('Reapplication flow is preserved when status is REJECTED or CANCELLED', () {
      final provider = VerificationProvider();

      final rejectedApp = VerificationApplication(
        id: 'rej_123',
        status: 'REJECTED',
      );
      provider.setCurrentApplicationForTesting(rejectedApp);

      expect(provider.effectiveStatus, 'REJECTED');
      expect(provider.isRejected, isTrue);
      expect(provider.canReapply, isTrue);
      // Even with an ID, rejected application must NOT enter Edit Mode
      expect(VerificationProvider.isEligibleForEdit(rejectedApp), isFalse);

      final cancelledApp = VerificationApplication(
        id: 'canc_123',
        status: 'CANCELLED',
      );
      provider.setCurrentApplicationForTesting(cancelledApp);

      expect(provider.effectiveStatus, 'CANCELLED');
      expect(provider.isCancelled, isTrue);
      expect(provider.canReapply, isTrue);
      // Even with an ID, cancelled application must NOT enter Edit Mode
      expect(VerificationProvider.isEligibleForEdit(cancelledApp), isFalse);
    });
  });
}
