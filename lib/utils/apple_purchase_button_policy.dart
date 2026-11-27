/// Returns whether an OTT Apple plan can be purchased from the current UI state.
/// Subscription-status loading is deliberately not an input: entitlement refresh
/// must not block a product that StoreKit has already made available.
bool canStartApplePlanPurchase({
  required bool hasLoadedProduct,
  required bool isPlanValid,
  required bool isPlanLoading,
  required bool isPurchaseLoading,
  required bool isProductLoading,
  required bool isProductUnavailable,
  required bool isCurrentPlan,
  required bool isDowngrade,
}) {
  return hasLoadedProduct &&
      isPlanValid &&
      (!isPlanLoading || hasLoadedProduct) &&
      !isPurchaseLoading &&
      !isProductLoading &&
      !isProductUnavailable &&
      !isCurrentPlan &&
      !isDowngrade;
}
