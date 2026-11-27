import 'dart:async';

import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/repository/plan_repository.dart';
import 'package:catch_watch/utils/apple_purchase_button_policy.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlanRepository extends PlanRepository {
  Future<PlanResponse> Function()? plansRequest;
  Future<SubscriptionStatusResponse> Function()? statusRequest;
  Future<dynamic> Function(Map<String, dynamic>)? appleVerificationRequest;

  @override
  Future<PlanResponse> getPlans() =>
      plansRequest?.call() ??
      Future.value(PlanResponse(success: true, plans: []));

  @override
  Future<SubscriptionStatusResponse> getSubscriptionStatus() =>
      statusRequest?.call() ??
      Future.value(SubscriptionStatusResponse(success: true));

  @override
  Future<dynamic> verifyApplePayment(Map<String, dynamic> data) =>
      appleVerificationRequest?.call(data) ??
      Future.value(<String, dynamic>{'success': true});
}

void main() {
  group('Subscription loading state isolation', () {
    late _FakePlanRepository repository;
    late SubscriptionProvider provider;

    setUp(() {
      repository = _FakePlanRepository();
      provider = SubscriptionProvider(planRepository: repository);
    });

    test('plan loading disables purchase until plan data is ready', () async {
      final response = Completer<PlanResponse>();
      repository.plansRequest = () => response.future;
      final future = provider.fetchPlans();

      expect(provider.isPlanLoading, isTrue);
      expect(
        canStartApplePlanPurchase(
          hasLoadedProduct: false,
          isPlanValid: true,
          isPlanLoading: provider.isPlanLoading,
          isPurchaseLoading: false,
          isProductLoading: false,
          isProductUnavailable: false,
          isCurrentPlan: false,
          isDowngrade: false,
        ),
        isFalse,
      );

      response.complete(
        PlanResponse(success: true, plans: [Plan(id: 'plan-1')]),
      );
      await future;
      expect(provider.isPlanLoading, isFalse);
    });

    test('loaded product remains purchasable during a plans refresh', () {
      expect(
        canStartApplePlanPurchase(
          hasLoadedProduct: true,
          isPlanValid: true,
          isPlanLoading: true,
          isPurchaseLoading: false,
          isProductLoading: false,
          isProductUnavailable: false,
          isCurrentPlan: false,
          isDowngrade: false,
        ),
        isTrue,
      );
    });

    test(
      'loaded StoreKit product is purchasable while status is pending',
      () async {
        final response = Completer<SubscriptionStatusResponse>();
        repository.statusRequest = () => response.future;
        final future = provider.fetchSubscriptionStatus();

        expect(provider.isStatusLoading, isTrue);
        expect(provider.isPlanLoading, isFalse);
        expect(provider.isPurchaseLoading, isFalse);
        expect(
          canStartApplePlanPurchase(
            hasLoadedProduct: true,
            isPlanValid: true,
            isPlanLoading: provider.isPlanLoading,
            isPurchaseLoading: provider.isPurchaseLoading,
            isProductLoading: false,
            isProductUnavailable: false,
            isCurrentPlan: false,
            isDowngrade: false,
          ),
          isTrue,
        );

        response.complete(SubscriptionStatusResponse(success: true));
        await future;
        expect(provider.isStatusLoading, isFalse);
      },
    );

    test('a stalled status request does not disable a loaded product', () async {
      final response = Completer<SubscriptionStatusResponse>();
      repository.statusRequest = () => response.future;
      final future = provider.fetchSubscriptionStatus();

      // A completer models the full backend timeout without making the test wait.
      expect(provider.isStatusLoading, isTrue);
      expect(
        canStartApplePlanPurchase(
          hasLoadedProduct: true,
          isPlanValid: true,
          isPlanLoading: provider.isPlanLoading,
          isPurchaseLoading: provider.isPurchaseLoading,
          isProductLoading: false,
          isProductUnavailable: false,
          isCurrentPlan: false,
          isDowngrade: false,
        ),
        isTrue,
      );

      response.complete(SubscriptionStatusResponse(success: true));
      await future;
    });

    test(
      'status failure leaves purchase enabled and clears only status state',
      () async {
        repository.statusRequest = () async =>
            SubscriptionStatusResponse(success: false, message: 'Server error');

        expect(await provider.fetchSubscriptionStatus(), isFalse);
        expect(provider.isStatusLoading, isFalse);
        expect(provider.isPlanLoading, isFalse);
        expect(provider.isPurchaseLoading, isFalse);
        expect(provider.subscriptionStatusError, 'Server error');
        expect(
          canStartApplePlanPurchase(
            hasLoadedProduct: true,
            isPlanValid: true,
            isPlanLoading: provider.isPlanLoading,
            isPurchaseLoading: provider.isPurchaseLoading,
            isProductLoading: false,
            isProductUnavailable: false,
            isCurrentPlan: false,
            isDowngrade: false,
          ),
          isTrue,
        );
      },
    );

    test(
      'plan API failure exposes plan error without resetting status loading',
      () async {
        final statusResponse = Completer<SubscriptionStatusResponse>();
        repository.statusRequest = () => statusResponse.future;
        final statusFuture = provider.fetchSubscriptionStatus();
        repository.plansRequest = () async =>
            throw StateError('Plan API failed');

        await provider.fetchPlans();

        expect(provider.isPlanLoading, isFalse);
        expect(provider.isStatusLoading, isTrue);
        expect(provider.error, contains('Plan API failed'));

        statusResponse.complete(SubscriptionStatusResponse(success: true));
        await statusFuture;
        expect(provider.isStatusLoading, isFalse);
      },
    );

    test(
      'purchase state disables purchase and resets after initiation failure',
      () {
        provider.setPurchaseInitiating(true);
        expect(provider.isPurchaseLoading, isTrue);
        expect(
          canStartApplePlanPurchase(
            hasLoadedProduct: true,
            isPlanValid: true,
            isPlanLoading: false,
            isPurchaseLoading: provider.isPurchaseLoading,
            isProductLoading: false,
            isProductUnavailable: false,
            isCurrentPlan: false,
            isDowngrade: false,
          ),
          isFalse,
        );

        provider.setPurchaseInitiating(false);
        expect(provider.isPurchaseLoading, isFalse);
      },
    );

    test(
      'invalid plan, unavailable product, current plan, and downgrade block',
      () {
        bool canPurchase({
          bool isPlanValid = true,
          bool productUnavailable = false,
          bool isCurrent = false,
          bool isDowngrade = false,
        }) => canStartApplePlanPurchase(
          hasLoadedProduct: true,
          isPlanValid: isPlanValid,
          isPlanLoading: false,
          isPurchaseLoading: false,
          isProductLoading: false,
          isProductUnavailable: productUnavailable,
          isCurrentPlan: isCurrent,
          isDowngrade: isDowngrade,
        );

        expect(canPurchase(isPlanValid: false), isFalse);
        expect(canPurchase(productUnavailable: true), isFalse);
        expect(canPurchase(isCurrent: true), isFalse);
        expect(canPurchase(isDowngrade: true), isFalse);
      },
    );

    test(
      'status and purchase verification states remain independent',
      () async {
        final statusResponse = Completer<SubscriptionStatusResponse>();
        final verifyResponse = Completer<dynamic>();
        repository.statusRequest = () => statusResponse.future;
        repository.appleVerificationRequest = (_) => verifyResponse.future;

        final statusFuture = provider.fetchSubscriptionStatus();
        final verifyFuture = provider.verifyApplePayment({
          'type': 'verification',
        });
        expect(provider.isStatusLoading, isTrue);
        expect(provider.isPurchaseLoading, isTrue);

        verifyResponse.complete(<String, dynamic>{'success': true});
        await verifyFuture;
        expect(provider.isPurchaseLoading, isFalse);
        expect(provider.isStatusLoading, isTrue);

        statusResponse.complete(SubscriptionStatusResponse(success: true));
        await statusFuture;
        expect(provider.isStatusLoading, isFalse);
      },
    );

    test('status failure does not reset an in-flight plan request', () async {
      final planResponse = Completer<PlanResponse>();
      repository.plansRequest = () => planResponse.future;
      repository.statusRequest = () async =>
          SubscriptionStatusResponse(success: false, message: 'Server error');

      final planFuture = provider.fetchPlans();
      await provider.fetchSubscriptionStatus();

      expect(provider.isStatusLoading, isFalse);
      expect(provider.isPlanLoading, isTrue);

      planResponse.complete(PlanResponse(success: true, plans: []));
      await planFuture;
      expect(provider.isPlanLoading, isFalse);
    });

    test('failed Apple verification clears purchase loading state', () async {
      repository.appleVerificationRequest = (_) async => <String, dynamic>{
        'success': false,
        'message': 'Verification failed',
      };

      expect(
        await provider.verifyApplePayment({'type': 'verification'}),
        isFalse,
      );
      expect(provider.isPurchaseLoading, isFalse);
    });
  });
}
