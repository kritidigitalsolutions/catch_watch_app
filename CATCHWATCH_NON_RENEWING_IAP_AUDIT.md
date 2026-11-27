# Catch&Watch – Apple Non-Renewing IAP Implementation & Fix Verification Report

**Date of Audit & Fix:** November 19, 2026  
**Implementation Target:** iOS Non-Renewing In-App Purchase Migration (Catch&Watch Flutter Application)  
**Target New Product IDs:**
- **Orange Tick:** `com.app.catchWatch.creator.orangetick`
- **Premium OTT Weekly:** `com.app.catchWatch.premium.weekly`
- **Premium OTT Monthly:** `com.app.catchWatch.premium.monthly`
- **Premium OTT Yearly:** `com.app.catchWatch.premium.yearly`

---

## 1. Executive Summary

All Critical, High, and Medium priority issues identified during the comprehensive Non-Renewing IAP audit have been successfully resolved with minimal, targeted modifications. 

### Status: **ALL CODE-LEVEL ISSUES RESOLVED (PASS)**

1. **Premium OTT Plan Partitioning Fixed (PASS):**
   - Replaced legacy hardcoded ID checks in `lib/views/after_login_pages/profile_page/subsrciption_screen.dart` with `isOttWeeklyProduct()`, `isOttMonthlyProduct()`, and `isOttYearlyProduct()`. Weekly, Monthly, and Yearly plans now correctly render and display on iOS.
2. **Orange Tick Legacy Restore Support Restored (PASS):**
   - Replaced the strict equality check in `lib/views/after_login_pages/profile_page/verification/verification_plans_screen.dart` with `isOrangeTickProduct()`. Both fresh (`com.app.catchWatch.creator.orangetick`) and legacy (`com.app.catchWatch.sub.creator.orangetick`) transactions are now accepted for server-side verification.
3. **App Store Review Guidance Fixed (PASS):**
   - Removed misleading *"check your App Store subscriptions"* instructions from `lib/views/after_login_pages/profile_page/verification/verification_form_screen.dart`. Replaced with accurate transaction verification and support guidance appropriate for Non-Renewing purchases.
   - Changed button text from `'Subscription Unavailable'` to `'Verification Unavailable'`.
4. **Production Server URL Restored (PASS):**
   - Restored `serverUrl = 'https://api.catchandwatch.com'` in `lib/res/appUrl.dart`. Local development URL is retained in comments for developer switching.
5. **Model & Verification Robustness (PASS):**
   - Updated `Plan.isOrangeTickPlan` and `Plan.effectiveLevel` in `lib/models/plan_model.dart` to validate against `isOrangeTickProduct()`.
6. **Automated Testing & Build Verification (PASS):**
   - Added comprehensive regression tests in `test/non_renewing_iap_regression_test.dart`.
   - **All 61 IAP, deduplication, metadata, policy, and account deletion tests passed (100%).**
   - **Flutter analyze:** Zero errors, zero warnings.
   - **iOS build:** `flutter build ios --no-codesign --config-only` succeeded with exit code 0.

---

## 2. Files Modified

| File Path | Nature of Fix |
| :--- | :--- |
| `lib/views/after_login_pages/profile_page/subsrciption_screen.dart` | Fixed `_getEffectivePlans()`, `_getPlanSubtitle()`, and `_getPlanDescription()` to use `isOttWeeklyProduct()`, `isOttMonthlyProduct()`, and `isOttYearlyProduct()`. |
| `lib/views/after_login_pages/profile_page/verification/verification_plans_screen.dart` | Updated line 94 to check `!isOrangeTickProduct(purchaseDetails.productID)`. |
| `lib/views/after_login_pages/profile_page/verification/verification_form_screen.dart` | Fixed product validation to use `isOrangeTickProduct()`, removed misleading "App Store subscriptions" text from error dialogs, and replaced `'Subscription Unavailable'` with `'Verification Unavailable'`. |
| `lib/res/appUrl.dart` | Restored production server URL `https://api.catchandwatch.com`. |
| `lib/models/plan_model.dart` | Added `isOrangeTickProduct()` check to `isOrangeTickPlan` and `effectiveLevel`. |
| `test/iap_transaction_deduplicator_test.dart` | Updated test fixture product ID from legacy to `com.app.catchWatch.premium.monthly`. |
| `test/non_renewing_iap_regression_test.dart` | New comprehensive regression test suite verifying all 4 product IDs, legacy compatibility, model mapping, hierarchy levels, and repurchase behavior. |

---

## 3. Detailed Fixes Implemented

### 3.1 Critical Fix: Premium OTT Plan Rendering (`subsrciption_screen.dart`)
- **Lines 1140–1151:**
  ```dart
  for (final p in recognizedPlans) {
    final prodId = p.effectiveAppleProductId;
    if (isOttWeeklyProduct(prodId) && weeklyPlan == null) {
      weeklyPlan = p;
    } else if (isOttYearlyProduct(prodId) && yearlyPlan == null) {
      yearlyPlan = p;
    } else if (isOttMonthlyProduct(prodId) && monthlyPlan == null) {
      monthlyPlan = p;
    }
  }
  ```
- **Lines 1173–1178 (`_getPlanSubtitle`):**
  ```dart
  if (isOttWeeklyProduct(prodId)) {
    return '7-day fixed access';
  }
  if (isOttYearlyProduct(prodId)) {
    return '12-month fixed access';
  }
  ```
- **Lines 1184–1189 (`_getPlanDescription`):**
  ```dart
  if (isOttWeeklyProduct(prodId)) {
    return 'Entry plan for users who want short-term access.';
  }
  if (isOttYearlyProduct(prodId)) {
    return 'Highest-value plan for long-term members.';
  }
  ```

### 3.2 High-Priority Fix: Orange Tick Legacy Restore (`verification_plans_screen.dart`)
- **Line 94:**
  ```dart
  Future<bool> _verifyApplePurchase(PurchaseDetails purchaseDetails) async {
    if (!isOrangeTickProduct(purchaseDetails.productID)) return false;
    // ...
  ```

### 3.3 High-Priority Fix: Misleading Subscriptions Text (`verification_form_screen.dart`)
- **Lines 298–306:**
  ```dart
  final isMatchingProduct =
      isOrangeTickProduct(purchaseDetails.productID) ||
      purchaseDetails.productID == expectedProductId;
  if (!isMatchingProduct) return false;
  ```
- **Line 768:**
  `'A transaction is already pending with the App Store for this verification. Please wait a moment and tap Submit & Purchase again, or contact support if amount was deducted.'`
- **Line 870:**
  `'Unable to verify the existing App Store transaction with the server. Please check your internet connection or contact support.'`
- **Line 1314:**
  `'Unable to verify your App Store verification purchase with the server. Please check your internet connection and try again.'`
- **Line 1745:**
  Replaced `'Subscription Unavailable'` with `'Verification Unavailable'`.

### 3.4 High-Priority Fix: Production URL Restored (`appUrl.dart`)
- **Lines 4–5:**
  ```dart
  // static const String serverUrl = 'http://192.168.1.26:5000';
  static const String serverUrl = 'https://api.catchandwatch.com';
  ```

---

## 4. Test Results

Command:
```bash
flutter test test/non_renewing_iap_regression_test.dart test/iap_transaction_deduplicator_test.dart test/iap_transaction_metadata_test.dart test/restore_purchase_policy_test.dart test/shared_purchase_stream_listener_test.dart test/subscription_expiry_formatter_test.dart test/subscription_loading_state_test.dart test/delete_account_dialog_test.dart
```

**Output:**
```
00:03 +61: All tests passed!
```
- Total test cases executed: **61**
- Passed: **61**
- Failed: **0**

---

## 5. Flutter Analyze Results

Command:
```bash
flutter analyze lib/views/after_login_pages/profile_page/subsrciption_screen.dart lib/views/after_login_pages/profile_page/verification/verification_plans_screen.dart lib/views/after_login_pages/profile_page/verification/verification_form_screen.dart lib/res/appUrl.dart lib/models/plan_model.dart lib/services/iap_service.dart test/non_renewing_iap_regression_test.dart test/iap_transaction_deduplicator_test.dart
```

**Output:**
```
Analyzing 8 items...
0 errors, 0 warnings.
```

---

## 6. iOS Build Results

Command:
```bash
flutter build ios --no-codesign --config-only
```

**Output:**
```
Building com.app.catchWatch for device (ios-release)...
Exit code: 0
```

---

## 7. Remaining Issues

- **Code-level issues:** **NONE.** All identified Critical, High, and Medium priority issues have been resolved.
- **Backend dependencies:** Verification of purchases depends on `/api/payment/verify-apple` correctly decoding StoreKit 2 JWS tokens and validating expiry dates on the backend server.

---

## 8. Manual Sandbox Testing Still Required

1. **Physical iOS Sandbox Purchase:** Perform test purchases for Weekly, Monthly, Yearly, and Orange Tick with a Sandbox Apple ID on a physical device.
2. **Backend Server Verification:** Verify that `/api/payment/verify-apple` successfully parses StoreKit 2 JWS payloads and marks user accounts active.
3. **Manual Repurchase Test:** Wait for Sandbox subscription expiry (~5 minutes), verify the app switches to Expired, and tap to manually repurchase.
4. **Clean Install Restore:** Verify backend profile recovers verification badge upon login on a fresh install.
