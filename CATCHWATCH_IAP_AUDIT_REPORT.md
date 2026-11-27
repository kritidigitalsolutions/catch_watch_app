# Catch&Watch iOS In-App Purchase Technical Audit

**Scope:** Read-only source and configuration audit of the Flutter repository. No source files were modified. App Store Connect settings and actual review-device behavior were not accessible for independent verification; their reported state is treated as user-supplied context.

## A. Executive summary

The Flutter product ID constants exactly match the four IDs supplied for App Store Connect, and the iOS bundle identifier is `com.app.catchWatch`. I found no spelling/case/whitespace mismatch in those constants.

The strongest code-level explanation for the three OTT plans showing **Unavailable** is the current UI's interpretation of product-query state. `IapService.loadProducts()` marks IDs queried before it has established that every ID was returned, and on a query exception it marks the IDs queried while returning an empty list. The subscription UI then renders **Unavailable** whenever the ID is queried but no `ProductDetails` is cached. Thus a thrown query, empty/partial response, or unavailable StoreKit state can produce the same user-visible state as an explicit not-found result. This is a confirmed behavior; whether that occurred during App Review is not provable from source alone.

An additional confirmed concern is sequencing: `_loadPlansAndStatus()` waits for two backend calls before starting StoreKit loading. During those calls, plan rows can render from existing/provider state while product query has not yet run. This tends to show `Loading...` / disabled buttons initially, rather than explain a stable `Unavailable` on its own. No code evidence proves a backend race caused the rejection.

The available evidence cannot distinguish an Apple-side product availability/configuration problem from a transient StoreKit query failure or a product response omission. The actual `ProductDetailsResponse` and device logs from review are needed to make that final distinction.

## B. Findings

### High — Query failures are collapsed into “queried, no product” and displayed as unavailable

- **Files:** `lib/services/iap_service.dart:205-245`; `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:1700-1721,1741-1761,1862-1875`
- **Behavior:** The service awaits `isAvailable()`. When unavailable, it adds every requested ID to both `_queriedProductIds` and `_notFoundProductIds`. For a successful query response, it caches returned details and adds explicit `notFoundIDs`; it then also adds any requested ID absent from cache to `_notFoundProductIds`. On exception, it adds requested IDs to `_queriedProductIds`, returns an empty list, but does not preserve an error state or mark them not-found.
- **Impact:** The price widget checks `isProductQueried(id) && product == null`, and the card checks queried plus missing product; each then renders `Unavailable` and disables purchase. A thrown query or empty response therefore becomes indistinguishable in the UI from a confirmed missing product. `response.error` is printed but processing continues and the UI still classifies missing IDs as unavailable.
- **Assessment:** Confirmed UI/error-state defect; not proof that StoreKit itself was healthy during review.

### Medium — Backend plan/status calls delay product lookup

- **File:** `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:136-165`
- **Behavior:** `_loadPlansAndStatus()` awaits `provider.fetchPlans()` and then `provider.fetchSubscriptionStatus()` before calling `loadProducts()`. Product IDs start with the three hardcoded OTT IDs and then add every backend plan's `effectiveAppleProductId`.
- **Impact:** StoreKit loading waits on network/backend latency. If the app is offline or either API stalls, the query never begins at that point. On screen, unqueried products should be represented as loading, but purchase is disabled during that period. If a backend call fails quickly, the code still proceeds because `fetchPlans()` catches errors rather than rethrowing; it queries hardcoded IDs plus whatever plans remain available.
- **Assessment:** Confirmed sequencing dependency, plausible contributor to review UX. It does not itself explain persistent `Unavailable` if query later succeeds.

### Medium — Dynamic backend IDs can expand query set and plan mapping

- **Files:** `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:142-151,1048-1094`; `lib/models/plan_model.dart:51-70,163-214`
- **Behavior:** The OTT query always includes the three known IDs and also all backend plan product IDs. `Plan.fromJson` accepts `appleProductId` or `productId`; `effectiveAppleProductId` returns a recognized ID if exact, otherwise can return arbitrary backend IDs or infer an ID from plan descriptors. `_getEffectivePlans` filters known tiers if any recognized tier exists; if none exists it returns all valid backend plans.
- **Impact:** A malformed/duplicate backend plan can introduce extra query IDs, duplicate plan mappings, or show a plan whose product ID was never among the three expected Apple plans. This does not override the hardcoded IDs, so it cannot alone explain all three known products being absent. Runtime API payloads were unavailable and the actual mappings cannot be confirmed.
- **Assessment:** Confirmed dynamic behavior; runtime configuration risk, not confirmed mismatch.

### Low — StoreKit query diagnostics do not retain enough structured evidence

- **File:** `lib/services/iap_service.dart:160-167,204-245`
- **Behavior:** Availability logs only exceptions / a generic unavailable message. Query logs `response.error` as text and catches exceptions as text, but does not log requested IDs, returned IDs, not-found IDs, completion duration, or a durable state that the UI can distinguish from not-found.
- **Impact:** A diagnostic build cannot reliably establish whether Apple returned no products, a subset, or an error from the existing logs.

### Low — Orange Tick and OTT share one global purchase listener and callbacks

- **Files:** `lib/services/iap_service.dart:170-201,713-725`; `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:83-133,168-176`; `lib/views/after_login_pages/profile_page/verification/verification_plans_screen.dart:43-70,168-177`
- **Behavior:** `IapService` has a single listener guarded by `_subscription != null`. Initialization replaces global callbacks. The OTT screen disposes the singleton listener/callbacks when leaving. Verification flows call initialize or ensure listener separately.
- **Impact:** This is lifecycle-sensitive and can affect purchase/restore event handling across screen transitions. It does not affect the StoreKit product query that most directly determines the OTT plan button label.
- **Assessment:** Confirmed architecture; secondary to the reported unavailable product display.

### Tax information

The user reports Missing Tax Info. This repository cannot establish App Store Connect consequences. Based on the supplied facts, tax information is not a demonstrated cause of StoreKit returning no product details. It may be relevant to sales proceeds, payments, or account compliance depending on Apple’s account state, but should be checked in App Store Connect and Apple documentation/support rather than treated as the root cause. Paid Apps Agreement and bank status were reported Active.

## C. Product ID mapping

| Product | Supplied App Store Connect ID | Flutter constant | Flutter screen query / mapping | Result |
|---|---|---|---|---|
| Premium yearly | `com.app.catchWatch.sub.premium.yearly` | `ottYearlyProductId` (`iap_service.dart:12`) | Hardcoded query (`subsrciption_screen.dart:142-147`); `Plan.effectiveAppleProductId` recognizes exact constant (`plan_model.dart:167-174`) | Exact match |
| Premium monthly | `com.app.catchWatch.sub.premium.monthly` | `ottMonthlyProductId` (`iap_service.dart:11`) | Hardcoded query (`subsrciption_screen.dart:142-147`); exact model mapping | Exact match |
| Premium weekly | `com.app.catchWatch.sub.premium.weekly` | `ottWeeklyProductId` (`iap_service.dart:10`) | Hardcoded query (`subsrciption_screen.dart:142-147`); exact model mapping | Exact match |
| Orange Tick monthly | `com.app.catchWatch.sub.creator.orangetick` | `orangeTickProductId` (`iap_service.dart:9`) | Verification plan query starts with constant (`verification_plans_screen.dart:81-86`); model recognizes exact constant | Exact match |

No extra spaces, capitalization differences, or bundle-ID prefix assumptions are present in these constants. The bundle ID is `com.app.catchWatch` in `ios/Runner.xcodeproj/project.pbxproj:517,709,741`; the product IDs intentionally extend it. Backend mappings are runtime data; the code accepts `appleProductId` / `productId`, but the actual API values were not available to compare.

## D. Current StoreKit loading flow

1. `SubscriptionScreen.initState()` initializes the shared purchase stream on iOS and schedules `_loadPlansAndStatus()` after the first frame (`subsrciption_screen.dart:56-73`).
2. `_loadPlansAndStatus()` fetches backend plans, then subscription status, then constructs a set containing the weekly/monthly/yearly IDs plus each backend plan's effective ID (`:136-151`).
3. `IapService.loadProducts()` marks loading, awaits `isAvailable()`, and if false marks every requested ID queried/not-found and returns an empty list (`iap_service.dart:205-216`).
4. If available, it awaits `queryProductDetails(productIds)`. It logs a non-null response error, caches returned products by exact `product.id`, records explicit not-found IDs, then treats every requested-but-uncached ID as not found (`:218-239`).
5. If query throws, it logs the exception, marks every request queried, returns an empty list, and clears loading (`:240-246`).
6. On completion, the screen calls `setState` (`subsrciption_screen.dart:151-164`). `_buildPriceText` displays `Unavailable` for a queried ID with no product; `_buildPlanBody` also disables the button and labels it `Unavailable` (`:1686-1721,1741-1761,1841-1875`).
7. Purchase requires a mapped `Plan`, looks up the exact effective product ID, and calls `buyNonConsumable` only with the `ProductDetails` object (`:233-306`; `iap_service.dart:263-285`). Thus a product not cached by query cannot be purchased through the normal button.

The loading state is not shown as unavailable before a query has run: `isProductQueried` is false, so the UI shows Loading. However, unavailable StoreKit, response omissions, and exceptions eventually all create the same visible unavailable state (via not-found or queried-with-null).

## E. Purchase and restore flow

- The purchase stream has one active `StreamSubscription` per singleton service instance (`iap_service.dart:187-201`). Repeated `initialize()` calls replace handlers but do not attach a second stream listener. Screen disposal can cancel that listener and clear handlers (`:713-725`).
- Pending calls `onPending(true)`. Purchased/restored events are dispatched to verification (`:415-465,627-677`). Error and canceled events clear pending state and complete the transaction if StoreKit says completion is pending (`:430-459`). Successful verification completes pending transactions and invokes success callback; failed verification intentionally leaves purchased/restored transactions incomplete for retry (`:663-699`).
- OTT purchase maps purchase `productID` to a backend plan by exact `effectiveAppleProductId`, preferring the pending selected plan (`subsrciption_screen.dart:349-405`). It posts `planId`, `productId`, transaction ID, original transaction ID and server verification data to `provider.verifyApplePayment` (`:408-445`). Repository posts to `AppUrl.verifyApplePayment` (`plan_repository.dart:105-108`, URL in `appUrl.dart:176`). This code evidence confirms the client request construction, not backend validation correctness.
- OTT restore calls `restorePurchases()`, waits up to 30 seconds for in-flight verification, refreshes backend status, and reports success if verification or a subscription status is present (`subsrciption_screen.dart:506-555`). The stream ignores restored OTT transactions unless the IAP service's restore state is active (`iap_service.dart:612-624`).
- `buyNonConsumable()` is the Flutter API used for these auto-renewable subscriptions (`iap_service.dart:263-267`); the API name is not itself evidence that the selected `ProductDetails` is wrong. Product type is configured in App Store Connect, not inspectable here.
- Orange Tick is queried separately by its plans screen. Its form preloads product details and sets its purchase handler when the user submits (`verification_plans_screen.dart:73-89`; `verification_form_screen.dart:168-220`). The Orange Tick purchase flow is separate from the three OTT plan buttons.

## F. Native configuration and dependencies

- `pubspec.yaml:62-63`: `in_app_purchase: ^3.2.0`, `in_app_purchase_storekit: ^0.4.13`.
- `pubspec.lock:891-922`: resolved versions `in_app_purchase 3.3.1`, `in_app_purchase_storekit 0.4.13`, platform interface `1.4.1`.
- `ios/Podfile:1`: iOS platform 15.0; `project.pbxproj:491,630,681` also declares deployment target 15.0.
- `ios/Podfile.lock:140,222,294-295,356`: StoreKit plugin pod is present via plugin symlink. No conflicting `SwiftyStoreKit` or `purchases_flutter` dependency was found in `pubspec.yaml`/lock or Podfile.lock search.
- `ios/Runner/Runner.entitlements`: contains only `aps-environment`; no IAP entitlement is normally required for StoreKit purchases.
- `ios/Runner/Info.plist`: no custom StoreKit configuration keys found.
- No project-owned native StoreKit implementation was identified in the audited search. These facts show no obvious native configuration conflict; they do not verify App Store Connect agreements, product territory availability, review storefront, product metadata/localization, bundle association, or signed build entitlements.

## G. Root cause assessment

### Confirmed

1. The UI maps a query-completed/missing-product state to the visible `Unavailable` label and disabled purchase button.
2. The service sets queried state on query exceptions and marks missing cache entries as not-found after any non-throwing response. It does not preserve a distinct query error state for UI rendering.
3. StoreKit query starts only after sequential backend plans and status calls.
4. The four hardcoded IDs match the supplied IDs exactly.

### Not confirmed

- That Apple returned `notFoundIDs` for these products during review.
- That the reviewer had network/StoreKit connectivity, used the expected storefront, or ran the expected build.
- That all product metadata, availability territories, subscription group configuration, agreements, and bundle associations are valid in App Store Connect. The reported `Ready for Review` and successful sandbox test are user-supplied and do not reproduce the review environment.
- That the backend returned incorrect IDs or plan mappings.
- That Missing Tax Info caused the products to be unavailable.

**Most likely code-side cause:** conflation of StoreKit query failure/empty results with genuine product absence. **Most likely system-level possibilities:** App Store Connect product availability/configuration or environment-specific StoreKit query behavior, but neither can be selected as the exact cause without logs from the failed review session or an equivalent reproduction.

## H. Recommended changes (not implemented)

1. Model product loading as separate states: not started/loading/available/not found/query error/StoreKit unavailable. Only show “Unavailable” for an explicit not-found result or a deliberate policy decision; show retry/error messaging for query failures.
2. Log query request IDs, response product IDs, `notFoundIDs`, error code/message, availability, and elapsed time. Do not convert errors into not-found IDs.
3. Consider starting StoreKit availability and product query independently of the backend subscription-status request. Keep backend plans for display/plan selection, but do not let status latency prevent loading known StoreKit IDs.
4. Validate runtime backend Apple IDs against the expected four IDs, deduplicate them, and report mismatches. Avoid presenting arbitrary backend product IDs as purchasable Apple products.
5. Ensure the shared singleton listener lifecycle and callback ownership are stable across both OTT and Orange Tick screens; avoid clearing callbacks needed by another active flow.
6. Verify App Store Connect product availability for all reviewer storefronts, subscription group/product metadata/localizations, bundle ID, agreements, and review submission state. Check Missing Tax Info separately with App Store Connect account support; do not infer it as the product-query root cause.

## I. Temporary diagnostic logging locations

Add temporary, privacy-safe logs at these existing code locations:

1. `lib/services/iap_service.dart:161-167` — log `isAvailable()` result, duration, and exception code/message.
2. `lib/services/iap_service.dart:205-246` — log requested IDs before query; query start/end and duration; returned IDs; explicit `notFoundIDs`; `response.error.code/message`; caught exception code/message. Keep unavailable/error distinct from not found.
3. `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:136-165` — log plans API success/count and the deduplicated StoreKit ID set; log each plan ID to effective Apple product ID mapping (avoid user data).
4. `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:1686-1721,1738-1761` — log product lookup result and computed UI state (`loading`, `available`, `not found`, `query error`) per product ID.
5. `lib/services/iap_service.dart:187-201,415-465` — log listener subscribe/cancel lifecycle and purchase status/product ID/error code. Do not log receipt/JWS/server verification data, credentials, JWTs, or user identifiers.
6. `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:429-445` — log verification request field presence and product/plan IDs only; never log `serverVerificationData` or transaction secrets.
7. `lib/views/after_login_pages/profile_page/subsrciption_screen.dart:506-555` — log restore start/end, event count, verification count, and backend refresh outcome.

## J. Testing checklist

Run with a diagnostic build and record device OS, app build, storefront/region, and timestamps (without personal identifiers or secrets).

- [ ] Physical iPhone; fresh install; launch Choose a Plan and confirm all three known IDs are requested, returned/not-found/error outcomes, price display, and button state.
- [ ] Physical iPad; repeat the same query and purchase UI checks.
- [ ] Sandbox Apple account on each device; verify one successful test purchase for weekly, monthly, yearly, and Orange Tick, each mapped to the expected product.
- [ ] Existing installation with previous subscription data; confirm plan loading, active-plan behavior, and purchase availability for eligible plans.
- [ ] Restore OTT subscription; verify restored stream event, backend verification, transaction completion, and refreshed subscription status.
- [ ] Restore Orange Tick subscription independently; verify it does not interfere with OTT callbacks.
- [ ] Simulate backend plan API failure/slow response; confirm StoreKit query still has a defined outcome and the UI does not remain falsely unavailable.
- [ ] Simulate network failure during Apple verification; confirm transaction is not falsely reported as verified and retry behavior is visible.
- [ ] Simulate StoreKit product-query failure, empty response, partial response, and explicit not-found response; confirm each renders a distinct, accurate UI state.
- [ ] Repeat query after recovery and confirm stale failure/not-found state is cleared for products now returned.

## Verification limits

This report is based on the checked-in source/configuration and the supplied App Store Connect facts. It cannot inspect live App Store Connect product metadata, Apple server responses during review, the exact submitted binary, reviewer device logs, or backend API response payloads. No tests or code changes were made as part of this audit.
