import 'dart:io';
import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/services/iap_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:catch_watch/repository/plan_repository.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'verification_main_screen.dart';
import 'verification_status_screen.dart';
import 'verified_status_screen.dart';

class VerificationFormScreen extends StatefulWidget {
  final Plan plan;
  final VerificationApplication? existingApplication;
  final bool isReapplication;
  const VerificationFormScreen({
    super.key,
    required this.plan,
    this.existingApplication,
    this.isReapplication = false,
  });

  @override
  State<VerificationFormScreen> createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Android Razorpay instance (never initialized or used on iOS)
  Razorpay? _razorpay;

  // iOS Apple IAP state
  bool _isPurchasing = false;
  bool _isPurchaseInitiatedByButton = false;
  final Set<String> _inFlightTransactionIds = {};
  final Set<String> _verifiedTransactionIds = {};
  String? _backendOrderId;
  PurchaseDetails? _verifiedPurchaseDetails;
  String? _lastAppleVerificationError;
  bool _isLastTransactionExpired = false;
  bool _isLastTransactionConflict = false;

  // In-flight submission guards
  bool _isSubmitting = false;
  bool _isSubmittingKyc = false;
  bool _hasSubmittedApplication = false;

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _twitterController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedIdType = 'Aadhaar';
  File? _idFront;
  File? _idBack;
  File? _selfie;
  bool _confirmed = false;
  bool _submitted = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  bool get _hasFront =>
      _idFront != null ||
      (widget.existingApplication?.idFront != null &&
          widget.existingApplication!.idFront!.isNotEmpty);

  bool get _hasSelfie =>
      _selfie != null ||
      (widget.existingApplication?.selfie != null &&
          widget.existingApplication!.selfie!.isNotEmpty);

  bool get _isReapplication {
    if (widget.isReapplication) return true;
    final appStatus = widget.existingApplication?.status?.trim().toUpperCase();
    if (appStatus == 'REJECTED' ||
        appStatus == 'CANCELLED' ||
        appStatus == 'CANCELED' ||
        appStatus == 'ADMIN_CANCELLED' ||
        appStatus == 'ADMIN_CANCELED' ||
        appStatus == 'CLOSED') {
      return true;
    }
    try {
      final provider = context.read<VerificationProvider>();
      if (provider.canReapply || provider.isRejected || provider.isCancelled) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool get _isUpdate => widget.existingApplication != null && !_isReapplication;

  @override
  void initState() {
    super.initState();
    final appStatus = widget.existingApplication?.status?.trim().toUpperCase();
    final bool isClosedStatus = appStatus == 'REJECTED' ||
        appStatus == 'CANCELLED' ||
        appStatus == 'CANCELED' ||
        appStatus == 'ADMIN_CANCELLED' ||
        appStatus == 'ADMIN_CANCELED' ||
        appStatus == 'CLOSED';
    final bool isUpdate = widget.existingApplication != null &&
        !widget.isReapplication &&
        !isClosedStatus;
    if (!isUpdate) {
      if (!Platform.isIOS) {
        _razorpay = Razorpay();
        _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
        _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
        _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      } else {
        // Form opens completely idle: do NOT initialize purchase listeners or register transaction handlers here.
        _preloadIapProduct();
      }
    }

    final user = context.read<ProfileProvider>().user;
    if (widget.existingApplication != null) {
      final app = widget.existingApplication!;
      _fullNameController.text =
          (app.fullName != null && app.fullName!.isNotEmpty)
          ? app.fullName!
          : (user?.name ?? '');
      _usernameController.text =
          (app.username != null && app.username!.isNotEmpty)
          ? app.username!
          : (user?.username ?? '');
      _idNumberController.text = app.governmentIdNumber ?? '';
      _websiteController.text = app.website ?? '';
      _instagramController.text = app.instagram ?? '';
      _facebookController.text = app.facebook ?? '';
      _youtubeController.text = app.youtube ?? '';
      _twitterController.text = app.twitter ?? '';
      _linkedinController.text = app.linkedin ?? '';
      _reasonController.text = app.reason ?? '';
      _selectedIdType =
          (app.governmentIdType != null && app.governmentIdType!.isNotEmpty)
          ? app.governmentIdType!
          : 'Aadhaar';
      _confirmed = true;
    } else if (user != null) {
      _fullNameController.text = user.name ?? '';
      _usernameController.text = user.username ?? '';
    }
  }

  void _preloadIapProduct() {
    Future.microtask(() async {
      final pid = widget.plan.effectiveAppleProductId;
      if (!IapService.instance.isProductLoaded(pid)) {
        await IapService.instance.loadProducts({pid, orangeTickProductId});
        if (mounted) setState(() {});
      }
      // Ensure the singleton purchase stream listener is initialized on iOS so StoreKit
      // queue delivers any pending transactions while the form remains idle
      IapService.instance.ensurePurchaseStreamInitialized();
    });
  }

  void _setupIapHandlersForPurchase() {
    if (IapService.instance.orangeTickPurchaseHandler != null) {
      debugPrint(
        '[ORANGE_TICK_FLOW] Orange Tick purchase handler already set up for this attempt. Skipping duplicate setup.',
      );
      return;
    }
    IapService.instance.registerOrangeTickHandler(
      onVerify: _verifyApplePurchase,
      planId: widget.plan.id,
      orderId: _backendOrderId,
    );
    IapService.instance.onPurchaseSuccess = _onApplePurchaseSuccess;
    IapService.instance.onError = (message) {
      IapService.instance.unregisterOrangeTickHandler();
      if (!mounted) return;
      _lastAppleVerificationError = message;
      setState(() {
        _isPurchasing = false;
        _isSubmitting = false;
        _isPurchaseInitiatedByButton = false;
      });
      if (!context.mounted) return;
      try {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        debugPrint('[ORANGE_TICK_DEBUG] Ignored SnackBar error: $e');
      }
    };
    IapService.instance.onPending = (isPending) {
      if (mounted && _isPurchasing != isPending) {
        setState(() {
          _isPurchasing = isPending;
        });
      }
    };
    IapService.instance.onCanceled = () {
      IapService.instance.unregisterOrangeTickHandler();
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isSubmitting = false;
          _isPurchaseInitiatedByButton = false;
        });
      }
    };
    IapService.instance.ensurePurchaseStreamInitialized();
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _backendOrderId = null;
    if (Platform.isIOS) {
      _isPurchaseInitiatedByButton = false;
      IapService.instance.unregisterOrangeTickHandler();
      if (IapService.instance.onPurchaseSuccess == _onApplePurchaseSuccess) {
        IapService.instance.onPurchaseSuccess = null;
      }
      if (IapService.instance.onVerifyPurchase == _verifyApplePurchase) {
        IapService.instance.onVerifyPurchase = null;
      }
      IapService.instance.onError = null;
      IapService.instance.onPending = null;
      IapService.instance.onCanceled = null;
    }
    _fullNameController.dispose();
    _usernameController.dispose();
    _idNumberController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    _twitterController.dispose();
    _linkedinController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // --- Apple IAP Handlers (iOS Only) ---

  Future<bool> _verifyApplePurchase(PurchaseDetails purchaseDetails) async {
    // 0. Boundary guard: Must be explicitly initiated by user tapping Submit & Subscribe
    if (!_isPurchaseInitiatedByButton) {
      debugPrint(
        '[ORANGE_TICK_IAP] _verifyApplePurchase rejected: Purchase was not initiated by user button tap',
      );
      return false;
    }

    // 1. Audit purchase update
    debugPrint('[ORANGE_TICK_IAP] Purchase received');
    debugPrint(
      '[ORANGE_TICK_IAP] Status: ${purchaseDetails.status == PurchaseStatus.purchased ? "purchased" : purchaseDetails.status.name}',
    );
    debugPrint('[ORANGE_TICK_IAP] Product ID: ${purchaseDetails.productID}');
    debugPrint(
      '[ORANGE_TICK_IAP] Transaction ID: ${purchaseDetails.purchaseID}',
    );

    // 2. CRITICAL: Strictly verify PurchaseStatus is PURCHASED or RESTORED
    // Backend verification must NEVER be triggered for pending, canceled, or error states
    if (purchaseDetails.status != PurchaseStatus.purchased &&
        purchaseDetails.status != PurchaseStatus.restored) {
      debugPrint(
        '[ORANGE_TICK_IAP] Verification skipped: purchase status is ${purchaseDetails.status}, expected purchased or restored',
      );
      return false;
    }
    debugPrint(
      '[ORANGE_TICK_IAP] ${purchaseDetails.status == PurchaseStatus.restored ? "Restored" : "Purchased"} transaction verification started',
    );

    // 3. CRITICAL: Verify product belongs to Orange Tick plan
    final expectedProductId = widget.plan.effectiveAppleProductId;
    final isOrangeTickProduct =
        purchaseDetails.productID == orangeTickProductId ||
        purchaseDetails.productID == expectedProductId;
    if (!isOrangeTickProduct) {
      debugPrint(
        '[ORANGE_TICK_IAP] Verification skipped: product ${purchaseDetails.productID} does not match Orange Tick ($expectedProductId)',
      );
      return false;
    }

    // 4. CRITICAL: Verify valid transaction data exists
    final String txId = purchaseDetails.purchaseID ?? '';
    final String serverData =
        purchaseDetails.verificationData.serverVerificationData;
    if (txId.isEmpty || serverData.isEmpty) {
      debugPrint(
        '[ORANGE_TICK_IAP] Verification aborted: empty transactionId or serverVerificationData',
      );
      return false;
    }

    // 5. CRITICAL: Prevent duplicate / concurrent verification for the same transaction
    if (_verifiedTransactionIds.contains(txId) ||
        IapService.instance.isTransactionVerified(txId) ||
        _inFlightTransactionIds.contains(txId)) {
      debugPrint(
        '[ORANGE_TICK_IAP] Transaction $txId already verified or currently in-flight. Skipping duplicate verification.',
      );
      return _verifiedTransactionIds.contains(txId) ||
          IapService.instance.isTransactionVerified(txId);
    }
    _inFlightTransactionIds.add(txId);

    try {
      final String? originalTxId = IapService.instance
          .extractOriginalTransactionId(purchaseDetails);
      final String orderId =
          _backendOrderId ??
          IapService.instance.activeOrangeTickOrderId ??
          '';

      debugPrint('[ORANGE_TICK_IAP]');
      debugPrint('[ORANGE_TICK_IAP] Payment successful');
      debugPrint('[ORANGE_TICK_IAP] Product ID: ${purchaseDetails.productID}');
      debugPrint('[ORANGE_TICK_IAP] Transaction ID: $txId');
      debugPrint(
        '[ORANGE_TICK_IAP] Original Transaction ID: ${originalTxId ?? txId}',
      );
      debugPrint('[ORANGE_TICK_IAP] Backend Order ID: $orderId');

      final payload = {
        "orderId": orderId,
        "serverVerificationData": serverData,
        "productId": purchaseDetails.productID,
        "transactionId": txId,
        "originalTransactionId": originalTxId ?? txId,
      };

      debugPrint('[ORANGE_TICK_IAP] POST verify-apple');

      // Call PlanRepository directly to avoid triggering fetchSubscriptionStatus() (OTT) from SubscriptionProvider
      final planRepo = PlanRepository();
      final response = await planRepo.verifyApplePayment(payload);
      final bool success = response != null && response['success'] == true;

      if (success) {
        _verifiedTransactionIds.add(txId);
        IapService.instance.markTransactionVerified(txId);
        _verifiedPurchaseDetails = purchaseDetails;
        _lastAppleVerificationError = null;
        debugPrint('[ORANGE_TICK_IAP] Backend verification success');
        return true;
      } else {
        final serverMsg =
            response?['message']?.toString() ??
            'Apple subscription verification rejected by server.';
        _lastAppleVerificationError = serverMsg;
        debugPrint(
          '[ORANGE_TICK_IAP] Backend verification failed: $_lastAppleVerificationError',
        );
        await _checkAndHandleTerminalResponse(purchaseDetails, serverMsg);
        return false;
      }
    } catch (e) {
      debugPrint(
        '[ORANGE_TICK_IAP] Apple transaction verification exception: $e',
      );
      String errorMsg = e.toString();
      if (e is AppException) {
        errorMsg = e.message;
      }
      _lastAppleVerificationError = errorMsg;
      await _checkAndHandleTerminalResponse(purchaseDetails, errorMsg);
      return false;
    } finally {
      _inFlightTransactionIds.remove(txId);
    }
  }

  Future<void> _checkAndHandleTerminalResponse(
    PurchaseDetails purchaseDetails,
    String message,
  ) async {
    final lower = message.toLowerCase();
    final bool isExpired =
        lower.contains('expired') ||
        IapService.instance.isTransactionExpired(purchaseDetails);

    if (isExpired) {
      debugPrint(
        '[ORANGE_TICK_IAP] Transaction ${purchaseDetails.purchaseID} confirmed EXPIRED by backend ($message). Marking terminal and completing in StoreKit.',
      );
      _isLastTransactionExpired = true;
      await IapService.instance.resolveAndCompleteTerminalTransaction(
        purchaseDetails,
        reason: 'expired',
      );
      return;
    }

    final bool isConflict =
        lower.contains('already linked') ||
        lower.contains('another user') ||
        lower.contains('another account');

    if (isConflict) {
      debugPrint(
        '[ORANGE_TICK_IAP] Transaction ${purchaseDetails.purchaseID} belongs to another account ($message).',
      );
      _isLastTransactionConflict = true;
      return;
    }
  }

  void _onApplePurchaseSuccess(PurchaseDetails purchaseDetails) {
    debugPrint(
      '[ORANGE_TICK_IAP] _onApplePurchaseSuccess: Apple purchase verified & completed',
    );
    IapService.instance.endOrangeTickPurchaseAttempt();
    IapService.instance.unregisterOrangeTickHandler();
    if (!mounted) return;
    setState(() {
      _isPurchasing = false;
      _isSubmitting = false;
    });

    // Step 4: Submit KYC application after successful Apple verification
    _submitKycAfterPayment(purchaseDetails);
  }

  Future<void> _submitKycAfterPayment(PurchaseDetails purchaseDetails) async {
    if (!mounted) {
      debugPrint(
        '[ORANGE_TICK_FLOW] _submitKycAfterPayment: widget unmounted, skipping UI submission',
      );
      return;
    }

    if (_isSubmittingKyc) {
      debugPrint('[ORANGE_TICK_FLOW] _submitKycAfterPayment already in-flight');
      return;
    }

    setState(() {
      _isSubmittingKyc = true;
    });

    final String txId = purchaseDetails.purchaseID ?? '';
    final provider = context.read<VerificationProvider>();
    final bool isUpdate = _isUpdate;

    try {
      debugPrint('[ORANGE_TICK_FLOW] Submitting KYC after Apple verification');
      final formData = await _buildFormData(
        paymentId: txId,
        transactionId: txId,
        orderId: _backendOrderId ?? IapService.instance.activeOrangeTickOrderId,
      );

      bool success = false;
      if (!isUpdate) {
        debugPrint('[ORANGE_TICK_FLOW] POST /api/verification/apply started');
        success = await provider.applyVerification(formData, plan: widget.plan);
        debugPrint(
          '[ORANGE_TICK_FLOW] POST /api/verification/apply completed: success=$success',
        );
      } else {
        debugPrint('[ORANGE_TICK_FLOW] PUT /api/verification/update started');
        success = await provider.updateVerification(
          formData,
          plan: widget.plan,
        );
        debugPrint(
          '[ORANGE_TICK_FLOW] PUT /api/verification/update completed: success=$success',
        );
      }

      if (!mounted) return;

      if (success) {
        _hasSubmittedApplication = true;
        _verifiedPurchaseDetails =
            null; // Clean up stored purchase state on successful KYC submission
        _isPurchaseInitiatedByButton = false;
        _backendOrderId = null;
        IapService.instance.unregisterOrangeTickHandler();

        // Step 7: Verification status is already fetched once by applyVerification/updateVerification
        debugPrint(
          '[ORANGE_TICK_FLOW] KYC application succeeded. Profile refresh.',
        );
        try {
          context.read<ProfileProvider>().fetchProfile();
        } catch (_) {}

        final status = provider.effectiveStatus;
        debugPrint('[ORANGE_TICK_FLOW] Resulting verification status: $status');

        if (status == 'PENDING' || provider.hasActiveOrPendingApplication) {
          // Display the pending/review UI consistent with the Catch & Watch app
          _navigateToStatusScreen(const VerificationStatusScreen());
        } else if (status == 'VERIFIED' || provider.isVerifiedActive) {
          // Display the verified UI
          _navigateToStatusScreen(const VerifiedStatusScreen());
        } else if (status == 'NOT_VERIFIED') {
          // If status is NOT_VERIFIED, do not falsely display pending or verified state
          _showSubmissionErrorDialog(
            provider.error ??
                'Application submitted but status is not verified. Please check back later.',
          );
        } else {
          if (provider.currentApplication != null) {
            _navigateToStatusScreen(const VerificationStatusScreen());
          } else {
            _showSuccessPopup();
          }
        }
      } else {
        // KYC application submission failed after payment verification succeeded!
        // Preserve transaction state to retry application submission safely without repurchasing
        _verifiedPurchaseDetails = purchaseDetails;
        debugPrint(
          '[ORANGE_TICK_FLOW] KYC application failed. Preserved purchaseDetails for safe retry.',
        );
        if (provider.isAlreadyPending) {
          _showPendingVerificationDialog();
        } else {
          _showKycRetryDialog(
            provider.error ??
                'Failed to submit KYC application. Your payment was verified.',
          );
        }
      }
    } catch (e) {
      debugPrint('[ORANGE_TICK_FLOW] Exception during KYC submission: $e');
      _verifiedPurchaseDetails = purchaseDetails;
      if (mounted) {
        _showKycRetryDialog(
          'An error occurred while submitting your KYC details: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingKyc = false;
        });
      }
    }
  }

  void _navigateToStatusScreen(Widget screen) {
    if (!mounted || !context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  void _showKycRetryDialog(String errorMessage) {
    if (!mounted || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Submission Issue',
                  style: text16(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '$errorMessage\n\nYour Apple subscription was successfully completed and verified. You do NOT need to pay again.',
            style: text14(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Close', style: text14(color: AppColors.grey500)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (_verifiedPurchaseDetails != null) {
                  _submitKycAfterPayment(_verifiedPurchaseDetails!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Retry Submission',
                style: text14(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Ensures a backend payment order exists before opening StoreKit or registering handlers.
  /// Reuses existing _backendOrderId if retrying the same attempt.
  Future<bool> _ensureBackendOrderCreated() async {
    if (_backendOrderId != null && _backendOrderId!.isNotEmpty) {
      return true;
    }

    debugPrint('[ORANGE_TICK_IAP] Creating backend order');
    try {
      final planRepo = PlanRepository();
      final orderResponse = await planRepo.createOrder(widget.plan.id!);
      final orderData =
          orderResponse != null && orderResponse['order'] is Map
              ? orderResponse['order']
              : null;
      final createdOrderId =
          orderData?['id']?.toString() ?? orderResponse?['orderId']?.toString();

      if (createdOrderId == null || createdOrderId.isEmpty) {
        final msg =
            orderResponse?['message']?.toString() ??
            'Failed to create order on the server. Please try again.';
        debugPrint('[ORANGE_TICK_IAP] Order creation failed: $msg');
        IapService.instance.unregisterOrangeTickHandler();
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _isPurchasing = false;
            _isPurchaseInitiatedByButton = false;
          });
          _showSubmissionErrorDialog(msg);
        }
        return false;
      }

      _backendOrderId = createdOrderId;
      debugPrint('[ORANGE_TICK_IAP] Backend order created: $_backendOrderId');
      return true;
    } catch (e) {
      debugPrint('[ORANGE_TICK_IAP] Exception creating order: $e');
      IapService.instance.unregisterOrangeTickHandler();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isPurchasing = false;
          _isPurchaseInitiatedByButton = false;
        });
        final errorMsg = e is AppException ? e.message : e.toString();
        _showSubmissionErrorDialog('Failed to create order: $errorMsg');
      }
      return false;
    }
  }

  Future<bool> _startApplePurchase() async {
    final productId = widget.plan.effectiveAppleProductId;
    var product =
        IapService.instance.getProduct(productId) ??
        IapService.instance.getProduct(orangeTickProductId);
    if (product == null) {
      if (!mounted || !context.mounted) return false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await IapService.instance.loadProducts({productId, orangeTickProductId});
      if (mounted && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // safely close loader
      }
      product =
          IapService.instance.getProduct(productId) ??
          IapService.instance.getProduct(orangeTickProductId);
    }

    if (product == null) {
      IapService.instance.unregisterOrangeTickHandler();
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isSubmitting = false;
          _isPurchaseInitiatedByButton = false;
        });
        if (context.mounted) {
          _showSubmissionErrorDialog(
            'Orange Tick subscription product is currently unavailable in the App Store. Please try again later.',
          );
        }
      }
      return false;
    }

    setState(() {
      _isPurchasing = true;
      _isPurchaseInitiatedByButton = true;
    });

    final orderReady = await _ensureBackendOrderCreated();
    if (!orderReady) {
      return false;
    }

    IapService.instance.beginOrangeTickPurchaseAttempt(
      orderId: _backendOrderId ?? '',
      planId: widget.plan.id ?? '',
    );

    try {
      final launched = await IapService.instance.buyProduct(product);
      if (!launched) {
        IapService.instance.endOrangeTickPurchaseAttempt();
        IapService.instance.unregisterOrangeTickHandler();
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isSubmitting = false;
            _isPurchaseInitiatedByButton = false;
          });
        }
        return false;
      }
      return true;
    } on PlatformException catch (e) {
      debugPrint(
        '[ORANGE_TICK_IAP] buyProduct PlatformException: ${e.code} - ${e.message}',
      );
      IapService.instance.endOrangeTickPurchaseAttempt();
      IapService.instance.unregisterOrangeTickHandler();
      if (e.code == 'storekit_duplicate_product_object' ||
          (e.message?.contains('pending transaction') ?? false)) {
        // StoreKit has an unfinished transaction blocking the new purchase
        final pendingPurchase =
            IapService.instance.unresolvedOrangeTickPurchase;
        if (pendingPurchase != null) {
          await _recoverOldTransaction(pendingPurchase);
        } else {
          if (mounted) {
            setState(() {
              _isPurchasing = false;
              _isSubmitting = false;
              _isPurchaseInitiatedByButton = false;
            });
            _showSubmissionErrorDialog(
              'A transaction is already pending with the App Store for this subscription. Please wait a moment and tap Submit & Subscribe again, or check your App Store subscriptions.',
            );
          }
        }
        return false;
      } else {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isSubmitting = false;
            _isPurchaseInitiatedByButton = false;
          });
          _showSubmissionErrorDialog(
            'Unable to initiate purchase: ${e.message ?? e.toString()}',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('[ORANGE_TICK_IAP] buyProduct unexpected exception: $e');
      IapService.instance.endOrangeTickPurchaseAttempt();
      IapService.instance.unregisterOrangeTickHandler();
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isSubmitting = false;
          _isPurchaseInitiatedByButton = false;
        });
        _showSubmissionErrorDialog('Unable to initiate purchase: $e');
      }
      return false;
    }
  }

  Future<void> _recoverOldTransaction(PurchaseDetails oldPurchase) async {
    if (!mounted) return;
    setState(() {
      _isPurchasing = true;
      _isSubmitting = true;
      _isPurchaseInitiatedByButton = true;
    });

    try {
      debugPrint(
        '[ORANGE_TICK_FLOW] Recovering existing transaction: ${oldPurchase.purchaseID}',
      );
      _setupIapHandlersForPurchase();

      final expDate = IapService.instance.extractExpirationDate(oldPurchase);
      final bool isExpired =
          IapService.instance.isTransactionExpired(oldPurchase) ||
          (expDate != null && expDate.isBefore(DateTime.now()));

      if (isExpired) {
        debugPrint(
          '[ORANGE_TICK_FLOW] Recovered transaction ${oldPurchase.purchaseID} is expired locally. Completing in StoreKit and retrying fresh purchase.',
        );
        if (oldPurchase.pendingCompletePurchase) {
          await IapService.instance.completePurchase(oldPurchase);
        }
        IapService.instance.clearUnresolvedOrangeTickPurchase();
        await _startApplePurchase();
        return;
      }

      final oldTxId = oldPurchase.purchaseID ?? '';
      final originalTxId =
          IapService.instance.extractOriginalTransactionId(oldPurchase) ??
          oldTxId;
      debugPrint(
        '[ORANGE_TICK_IAP] Reusing active subscription transaction $oldTxId (original $originalTxId) for re-application',
      );

      final verified = await _verifyApplePurchase(oldPurchase);
      if (verified) {
        debugPrint(
          '[ORANGE_TICK_FLOW] Existing transaction verified successfully.',
        );
        if (oldPurchase.pendingCompletePurchase) {
          await IapService.instance.completePurchase(oldPurchase);
        }
        IapService.instance.clearUnresolvedOrangeTickPurchase();
        IapService.instance.unregisterOrangeTickHandler();
        _verifiedPurchaseDetails = oldPurchase;
        if (mounted) {
          try {
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              const SnackBar(
                content: Text(
                  "Your existing active subscription will be used. You won't be charged again.",
                ),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          } catch (_) {}
          setState(() {
            _isPurchasing = false;
          });
          await _submitKycAfterPayment(oldPurchase);
        }
      } else {
        debugPrint(
          '[ORANGE_TICK_FLOW] Existing transaction verification failed.',
        );
        IapService.instance.unregisterOrangeTickHandler();
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isSubmitting = false;
            _isPurchaseInitiatedByButton = false;
          });
          if (_isLastTransactionExpired) {
            _isLastTransactionExpired = false;
            _showExpiredSubscriptionDialog(
              txId: oldPurchase.purchaseID ?? '',
              errorMessage:
                  _lastAppleVerificationError ??
                  'Your previous Apple subscription has expired.',
            );
          } else {
            _showSubmissionErrorDialog(
              _lastAppleVerificationError ??
                  'Unable to verify the existing App Store transaction with the server. Please check your App Store subscriptions or contact support.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[ORANGE_TICK_FLOW] Exception recovering existing transaction: $e',
      );
      IapService.instance.unregisterOrangeTickHandler();
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isSubmitting = false;
          _isPurchaseInitiatedByButton = false;
        });
        _showSubmissionErrorDialog('Error recovering existing transaction: $e');
      }
    }
  }

  // --- Razorpay Handlers (Android Only) ---

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final subProvider = context.read<SubscriptionProvider>();

    if (mounted && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final success = await subProvider.verifyPayment({
      "razorpay_order_id": response.orderId,
      "razorpay_payment_id": response.paymentId,
      "razorpay_signature": response.signature,
      "planId": widget.plan.id,
      "type": "verification",
    });

    if (mounted && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading
    }

    if (success && mounted && context.mounted) {
      try {
        context.read<ProfileProvider>().fetchProfile();
        context.read<VerificationProvider>().fetchVerificationStatus(
          forceRefresh: true,
        );
      } catch (_) {}
      _showSuccessPopup();
    } else if (mounted && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(subProvider.error ?? 'Verification payment failed'),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _showSuccessPopup() {
    if (!mounted || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Application Submitted!',
              style: text18(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Orange Tick verification request is being processed. We will notify you once it\'s reviewed.',
              textAlign: TextAlign.center,
              style: text14(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: text14(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Image Source',
              style: text16(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceItem(
                  Icons.camera_alt_rounded,
                  'Camera',
                  () => Navigator.pop(context, ImageSource.camera),
                ),
                _sourceItem(
                  Icons.photo_library_rounded,
                  'Gallery',
                  () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == 'front') _idFront = File(pickedFile.path);
          if (type == 'back') _idBack = File(pickedFile.path);
          if (type == 'selfie') _selfie = File(pickedFile.path);
        });
      }
    }
  }

  Widget _sourceItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: text12(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isPurchasing || _isSubmittingKyc) {
      debugPrint('[ORANGE_TICK_FLOW] _submit ignored: already in-flight');
      return;
    }

    // If Apple purchase was already verified, retry KYC submission directly without repurchasing
    if (_verifiedPurchaseDetails != null) {
      debugPrint(
        '[ORANGE_TICK_FLOW] Retrying KYC submission with previously verified Apple transaction',
      );
      await _submitKycAfterPayment(_verifiedPurchaseDetails!);
      return;
    }

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final bool hasFront = _hasFront;
    final bool hasSelfie = _hasSelfie;

    if (!isFormValid || !hasFront || !hasSelfie || !_confirmed) {
      setState(() {
        _submitted = true;
        _autoValidateMode = AutovalidateMode.onUserInteraction;
      });
      if (mounted && context.mounted) {
        String? message;
        if (!isFormValid) {
          message = 'Please fill in all required fields';
        } else if (!hasFront || !hasSelfie) {
          message = 'Please upload all required documents';
        } else if (!_confirmed) {
          message = 'Please confirm that all provided information is accurate';
        }
        if (message != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    final bool isUpdate = _isUpdate;

    // --- ZERO PAYMENT EDIT MODE (Issue 2) ---
    if (isUpdate) {
      setState(() {
        _isSubmitting = true;
      });
      try {
        debugPrint(
          '[ORANGE_TICK_FLOW] Edit Mode - Updating verification details without payment',
        );
        final provider = context.read<VerificationProvider>();
        final formData = await _buildFormData(
          paymentId: widget.existingApplication?.paymentId,
          transactionId: widget.existingApplication?.transactionId,
          orderId: widget.existingApplication?.orderId,
        );
        final success = await provider.updateVerification(
          formData,
          plan: widget.plan,
        );
        debugPrint('[ORANGE_TICK_FLOW] updateVerification result: $success');
        if (success) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('Verification details updated successfully'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
              ),
            );
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            }
          }
          return;
        } else {
          if (mounted && context.mounted) {
            _showSubmissionErrorDialog(
              provider.error ??
                  'Failed to update verification details. Please try again.',
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('[ORANGE_TICK_FLOW] updateVerification exception: $e');
        if (mounted && context.mounted) {
          _showSubmissionErrorDialog(
            'Failed to update verification details: $e',
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        } else {
          _isSubmitting = false;
        }
      }
    }

    if (widget.plan.id == null || widget.plan.id!.isEmpty) {
      _showSubmissionErrorDialog(
        'Invalid plan selected. Please go back and select a valid Orange Tick plan.',
      );
      return;
    }

    if (widget.plan.isBlueTickPlan || !widget.plan.isEligibleForOrangeTick) {
      _showSubmissionErrorDialog(
        'The selected plan is not an Orange Tick plan. Please select a valid Orange Tick plan.',
      );
      return;
    }

    if (_verifiedPurchaseDetails != null) {
      debugPrint(
        '[ORANGE_TICK_FLOW] Retrying KYC submission with verified purchase: ${_verifiedPurchaseDetails!.purchaseID}',
      );
      await _submitKycAfterPayment(_verifiedPurchaseDetails!);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      debugPrint('[ORANGE_TICK_FLOW] Submit & Subscribe tapped');
      final provider = context.read<VerificationProvider>();

      if (Platform.isIOS) {
        _isPurchaseInitiatedByButton = true;

        // Step 1: Ensure backend order is created before registering handlers & opening StoreKit
        final orderReady = await _ensureBackendOrderCreated();
        if (!orderReady) {
          return;
        }

        _setupIapHandlersForPurchase();

        // Step 2: Handle previous unresolved transaction conflicts BEFORE fresh purchase
        final unresolved = IapService.instance.unresolvedOrangeTickPurchase;
        if (unresolved != null) {
          final unresolvedTxId = unresolved.purchaseID ?? '';
          final appTxId =
              provider.currentApplication?.transactionId ??
              provider.currentApplication?.paymentId;

          // 2a. Check if this transaction was already processed in backend application
          if (unresolvedTxId.isNotEmpty &&
              (appTxId == unresolvedTxId ||
                  provider.hasActiveOrPendingApplication)) {
            debugPrint(
              '[ORANGE_TICK_FLOW] Unresolved transaction $unresolvedTxId already processed in backend application. Completing StoreKit transaction.',
            );
            if (unresolved.pendingCompletePurchase) {
              await IapService.instance.completePurchase(unresolved);
            }
            IapService.instance.clearUnresolvedOrangeTickPurchase();
            IapService.instance.unregisterOrangeTickHandler();
            setState(() {
              _isSubmitting = false;
            });
            if (mounted && context.mounted) {
              _showPendingVerificationDialog();
            }
            return;
          }

          // 2b. Check if transaction is error, canceled, or already confirmed terminal
          if (unresolved.status == PurchaseStatus.error ||
              unresolved.status == PurchaseStatus.canceled ||
              IapService.instance.isTransactionTerminal(unresolvedTxId)) {
            debugPrint(
              '[ORANGE_TICK_FLOW] Unresolved transaction $unresolvedTxId is ${unresolved.status.name} / terminal. Completing in StoreKit.',
            );
            if (unresolved.pendingCompletePurchase) {
              await IapService.instance.completePurchase(unresolved);
            }
            IapService.instance.clearUnresolvedOrangeTickPurchase();
            // Transaction queue is now cleared, proceed to fresh purchase below
          } else if (unresolved.status == PurchaseStatus.purchased ||
              unresolved.status == PurchaseStatus.restored) {
            // 2c. Unresolved purchased/restored transaction exists!
            // Reconcile and verify with backend now that user has submitted the form
            debugPrint(
              '[ORANGE_TICK_FLOW] Reconciling unresolved StoreKit transaction $unresolvedTxId with backend.',
            );

            // Re-check cached transaction is still active (expiresDate in the future)
            final expDate =
                IapService.instance.extractExpirationDate(unresolved);
            final bool isExpired =
                IapService.instance.isTransactionExpired(unresolved) ||
                (expDate != null && expDate.isBefore(DateTime.now()));

            if (isExpired) {
              debugPrint(
                '[ORANGE_TICK_FLOW] Cached unresolved transaction $unresolvedTxId is expired locally (expiresDate: $expDate). Completing in StoreKit and falling through to fresh purchase.',
              );
              if (unresolved.pendingCompletePurchase) {
                await IapService.instance.completePurchase(unresolved);
              }
              IapService.instance.clearUnresolvedOrangeTickPurchase();
              // Queue is now clear; do not return so execution falls through to fresh buyProduct purchase below
            } else {
              final originalTxId =
                  IapService.instance.extractOriginalTransactionId(unresolved) ??
                  unresolvedTxId;
              debugPrint(
                '[ORANGE_TICK_IAP] Reusing active subscription transaction $unresolvedTxId (original $originalTxId) for re-application',
              );

              setState(() {
                _isPurchasing = true;
              });

              final verified = await _verifyApplePurchase(unresolved);
              if (verified) {
                debugPrint(
                  '[ORANGE_TICK_FLOW] Unresolved transaction $unresolvedTxId verified successfully.',
                );
                if (unresolved.pendingCompletePurchase) {
                  await IapService.instance.completePurchase(unresolved);
                }
                IapService.instance.clearUnresolvedOrangeTickPurchase();
                IapService.instance.unregisterOrangeTickHandler();
                _verifiedPurchaseDetails = unresolved;
                if (mounted) {
                  try {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.hideCurrentSnackBar();
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Your existing active subscription will be used. You won't be charged again.",
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } catch (_) {}
                  setState(() {
                    _isPurchasing = false;
                  });
                  await _submitKycAfterPayment(unresolved);
                }
                return;
              } else {
                debugPrint(
                  '[ORANGE_TICK_FLOW] Unresolved transaction $unresolvedTxId verification failed: $_lastAppleVerificationError',
                );
                IapService.instance.unregisterOrangeTickHandler();
                if (mounted) {
                  setState(() {
                    _isPurchasing = false;
                    _isSubmitting = false;
                    _isPurchaseInitiatedByButton = false;
                  });
                  if (_isLastTransactionExpired) {
                    _isLastTransactionExpired = false;
                    _showExpiredSubscriptionDialog(
                      txId: unresolvedTxId,
                      errorMessage:
                          _lastAppleVerificationError ??
                          'Your previous Apple subscription has expired.',
                    );
                  } else if (_isLastTransactionConflict) {
                    _isLastTransactionConflict = false;
                    _showSubmissionErrorDialog(
                      _lastAppleVerificationError ??
                          'This Apple subscription is already associated with another account.',
                    );
                  } else {
                    _showSubmissionErrorDialog(
                      _lastAppleVerificationError ??
                          'Unable to verify your App Store subscription with the server. Please check your internet connection and try again.',
                    );
                  }
                }
                return;
              }
            }
          }
        }

        // Step 2.5: Pricing mismatch guard (Requirement 9)
        // If the backend price and actual Apple StoreKit price differ, block purchase with clear message
        final product =
            IapService.instance.getProduct(
              widget.plan.effectiveAppleProductId,
            ) ??
            IapService.instance.getProduct(orangeTickProductId);
        if (product != null) {
          final backendPrice = widget.plan.price ?? 0;
          final storeKitRawPrice = product.rawPrice;
          if ((storeKitRawPrice - backendPrice).abs() > 0.01) {
            debugPrint(
              '[ORANGE_TICK_FLOW] Price mismatch blocked purchase: backend=₹$backendPrice, storeKit=${product.price} ($storeKitRawPrice)',
            );
            IapService.instance.endOrangeTickPurchaseAttempt();
            IapService.instance.unregisterOrangeTickHandler();
            if (mounted) {
              setState(() {
                _isSubmitting = false;
                _isPurchasing = false;
                _isPurchaseInitiatedByButton = false;
              });
              _showPriceMismatchDialog(
                backendPrice: backendPrice,
                storeKitPrice: product.price,
              );
            }
            return;
          }
        }

        // Step 3: Trigger fresh Apple StoreKit purchase (no Razorpay order needed for Apple IAP)
        debugPrint(
          '[ORANGE_TICK_FLOW] Triggering fresh Apple StoreKit purchase',
        );
        await _startApplePurchase();
      } else {
        // --- Android Existing Razorpay Flow (Untouched) ---
        final subProvider = context.read<SubscriptionProvider>();
        bool success = true;
        if (!isUpdate && !_hasSubmittedApplication) {
          final formData = await _buildFormData();
          debugPrint('[ORANGE_TICK_FLOW] verification/apply started');
          success = await provider.applyVerification(
            formData,
            plan: widget.plan,
          );
          debugPrint(
            '[ORANGE_TICK_FLOW] verification/apply completed: success=$success',
          );
          if (success) {
            _hasSubmittedApplication = true;
          }
        } else if (isUpdate) {
          final formData = await _buildFormData();
          debugPrint('[ORANGE_TICK_FLOW] verification/update started');
          success = await provider.updateVerification(
            formData,
            plan: widget.plan,
          );
          debugPrint(
            '[ORANGE_TICK_FLOW] verification/update completed: success=$success',
          );
        }

        if (success && mounted) {
          if (isUpdate && provider.currentApplication?.isPaid == true) {
            _showSuccessPopup();
            return;
          }

          final response = await subProvider.createOrder(widget.plan.id!);
          if (!mounted) return;
          if (response != null && response['order'] != null) {
            final order = response['order'];
            final razorpayKey = response['key'];
            final user = context.read<ProfileProvider>().user;

            var options = {
              'key': razorpayKey ?? 'rzp_test_SztpB3DjlEhcKW',
              'amount': order['amount'],
              'name': 'Catch Watch Verification',
              'order_id': order['id'],
              'description': widget.plan.name,
              'prefill': {'contact': user?.phone ?? '', 'email': ''},
            };
            _razorpay?.open(options);
          }
        } else if (mounted) {
          if (provider.isAlreadyPending) {
            _showPendingVerificationDialog();
          } else {
            _showSubmissionErrorDialog(
              provider.error ?? 'Failed to submit application',
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<dio.FormData> _buildFormData({
    String? paymentId,
    String? transactionId,
    String? orderId,
  }) async {
    final Map<String, dynamic> dataMap = {
      'fullName': _fullNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'governmentIdType': _selectedIdType,
      'governmentIdNumber': _idNumberController.text.trim(),
      'planId': widget.plan.id,
      'website': _websiteController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'youtube': _youtubeController.text.trim(),
      'twitter': _twitterController.text.trim(),
      'linkedin': _linkedinController.text.trim(),
      'reason': _reasonController.text.trim(),
      'confirmation': 'true',
    };

    final bool isUpdate = _isUpdate;

    final effectivePaymentId =
        paymentId ?? (isUpdate ? widget.existingApplication?.paymentId : null);
    final effectiveTransactionId =
        transactionId ??
        (isUpdate ? widget.existingApplication?.transactionId : null);
    final effectiveOrderId =
        orderId ?? (isUpdate ? widget.existingApplication?.orderId : null);
    final effectiveAppId = isUpdate ? widget.existingApplication?.id : null;

    if (effectivePaymentId != null && effectivePaymentId.isNotEmpty) {
      dataMap['paymentId'] = effectivePaymentId;
    }
    if (effectiveTransactionId != null && effectiveTransactionId.isNotEmpty) {
      dataMap['transactionId'] = effectiveTransactionId;
    }
    if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
      dataMap['orderId'] = effectiveOrderId;
    }
    if (effectiveAppId != null && effectiveAppId.isNotEmpty) {
      dataMap['applicationId'] = effectiveAppId;
      dataMap['id'] = effectiveAppId;
    }

    if (_idFront == null &&
        widget.existingApplication?.idFront != null &&
        widget.existingApplication!.idFront!.isNotEmpty) {
      dataMap['idFront'] = widget.existingApplication!.idFront;
    }
    if (_idBack == null &&
        widget.existingApplication?.idBack != null &&
        widget.existingApplication!.idBack!.isNotEmpty) {
      dataMap['idBack'] = widget.existingApplication!.idBack;
    }
    if (_selfie == null &&
        widget.existingApplication?.selfie != null &&
        widget.existingApplication!.selfie!.isNotEmpty) {
      dataMap['selfie'] = widget.existingApplication!.selfie;
    }

    final dio.FormData formData = dio.FormData.fromMap(dataMap);

    if (_idFront != null) {
      formData.files.add(
        MapEntry(
          'idFront',
          await dio.MultipartFile.fromFile(
            _idFront!.path,
            filename: 'id_front.jpg',
          ),
        ),
      );
    }

    if (_idBack != null) {
      formData.files.add(
        MapEntry(
          'idBack',
          await dio.MultipartFile.fromFile(
            _idBack!.path,
            filename: 'id_back.jpg',
          ),
        ),
      );
    }

    if (_selfie != null) {
      formData.files.add(
        MapEntry(
          'selfie',
          await dio.MultipartFile.fromFile(
            _selfie!.path,
            filename: 'selfie.jpg',
          ),
        ),
      );
    }

    return formData;
  }

  void _showPendingVerificationDialog() {
    if (!mounted || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Verification Pending',
                  style: text20(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'You already have a verification request under review.\n\nOur team is currently reviewing your submitted information.\n\nYou don\'t need to submit another request at this time.',
                  textAlign: TextAlign.center,
                  style: appTextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final provider = context.read<VerificationProvider>();
                      await provider.fetchVerificationStatus(
                        forceRefresh: true,
                      );
                      if (!mounted || !context.mounted) return;
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => provider.currentApplication != null
                                ? const VerificationStatusScreen()
                                : const VerificationMainScreen(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'View Status',
                      style: text15(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: text14(
                        color: AppColors.grey700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSubmissionErrorDialog(String message) {
    if (!mounted || !context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Unable to submit verification',
            style: text16(fontWeight: FontWeight.bold),
          ),
          content: Text(message, style: text14(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: text14(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPriceMismatchDialog({
    required int backendPrice,
    required String storeKitPrice,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Price Mismatch',
                style: text16(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'The selected plan price is ₹$backendPrice, but Apple App Store is configured for $storeKitPrice.\n\nTo prevent incorrect charges, this purchase has been blocked. Please contact support or update the plan pricing.',
          style: text14(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: text14(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiredSubscriptionDialog({
    required String txId,
    required String errorMessage,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Subscription Expired',
                style: text16(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Your previous Apple subscription (Transaction ID: $txId) has expired.\n\n$errorMessage\n\nYou can continue to purchase a new subscription to get your Orange Tick.',
          style: text14(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Close', style: text14(color: AppColors.grey500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (mounted) {
                _submit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Subscribe Now',
              style: text14(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubmitButtonText() {
    if (_isUpdate) {
      return 'Save Changes';
    }
    if (_verifiedPurchaseDetails != null) {
      return 'Retry KYC Submission';
    }
    final priceStr = widget.plan.price != null
        ? ' (₹${widget.plan.price})'
        : '';
    if (Platform.isIOS) {
      if (IapService.instance.isProductNotFound(
            widget.plan.effectiveAppleProductId,
          ) &&
          IapService.instance.isProductNotFound(orangeTickProductId)) {
        return 'Subscription Unavailable';
      }
      return 'Submit & Subscribe$priceStr';
    }
    return 'Submit & Pay$priceStr';
  }

  String _getBusyButtonText() {
    if (_isPurchasing) {
      return 'Processing Payment...';
    }
    if (_isSubmittingKyc || _isSubmitting) {
      return _isUpdate ? 'Saving Changes...' : 'Submitting Application...';
    }
    return 'Please wait...';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final isBusy =
        _isSubmitting ||
        _isSubmittingKyc ||
        _isPurchasing ||
        (_isUpdate
            ? provider.isUpdatingVerification
            : provider.isApplyingVerification);
    final bool requiresPayment = !_isUpdate;
    final bool isIapUnavailable =
        requiresPayment &&
        Platform.isIOS &&
        (IapService.instance.isProductNotFound(
              widget.plan.effectiveAppleProductId,
            ) &&
            IapService.instance.isProductNotFound(orangeTickProductId));
    final bool isIapLoading =
        requiresPayment &&
        Platform.isIOS &&
        !isIapUnavailable &&
        IapService.instance.getProduct(widget.plan.effectiveAppleProductId) ==
            null &&
        IapService.instance.getProduct(orangeTickProductId) == null &&
        (IapService.instance.isLoadingProducts ||
            !IapService.instance.isProductQueried(
              widget.plan.effectiveAppleProductId,
            ));

    final bool canPressSubmit =
        !isBusy && (!requiresPayment || (!isIapUnavailable && !isIapLoading));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isReapplication
              ? 'Reapply for Orange Tick'
              : _isUpdate
                  ? 'Update Verification Details'
                  : 'Orange Tick Request',
          style: text18(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Personal Information'),
                  _buildTextField(
                    _fullNameController,
                    'Full Name *',
                    'Enter your full name',
                    true,
                  ),
                  _buildTextField(
                    _usernameController,
                    'Username (Optional)',
                    '@username',
                    false,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Identity Verification'),
                  _buildDropdown(),
                  _buildTextField(
                    _idNumberController,
                    'ID Number (Optional)',
                    'Enter ID number',
                    false,
                  ),

                  const SizedBox(height: 20),
                  _buildImageUpload(
                    'ID Front *',
                    _idFront,
                    widget.existingApplication?.idFront,
                    () => _pickImage('front'),
                    errorMessage: _submitted && !_hasFront
                        ? 'ID Front document is required'
                        : null,
                  ),
                  _buildImageUpload(
                    'ID Back (Optional)',
                    _idBack,
                    widget.existingApplication?.idBack,
                    () => _pickImage('back'),
                  ),
                  _buildImageUpload(
                    'Selfie *',
                    _selfie,
                    widget.existingApplication?.selfie,
                    () => _pickImage('selfie'),
                    errorMessage: _submitted && !_hasSelfie
                        ? 'Selfie is required'
                        : null,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Social Links (Optional)'),
                  _buildTextField(
                    _websiteController,
                    'Website',
                    'https://example.com',
                    false,
                  ),
                  _buildTextField(
                    _instagramController,
                    'Instagram',
                    'Instagram URL',
                    false,
                  ),
                  _buildTextField(
                    _facebookController,
                    'Facebook',
                    'Facebook URL',
                    false,
                  ),
                  _buildTextField(
                    _youtubeController,
                    'YouTube',
                    'YouTube URL',
                    false,
                  ),
                  _buildTextField(
                    _twitterController,
                    'Twitter/X',
                    'Twitter URL',
                    false,
                  ),
                  _buildTextField(
                    _linkedinController,
                    'LinkedIn',
                    'LinkedIn URL',
                    false,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Additional Details'),
                  _buildTextField(
                    _reasonController,
                    'Reason for Verification',
                    'Why should you be verified?',
                    false,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _confirmed,
                        activeColor: AppColors.primary,
                        onChanged: (val) =>
                            setState(() => _confirmed = val ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'I confirm that all provided information is accurate.',
                          style: text12(color: AppColors.grey700),
                        ),
                      ),
                    ],
                  ),
                  if (_submitted && !_confirmed)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Please confirm that all provided information is accurate',
                            style: text12(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canPressSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isBusy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _getBusyButtonText(),
                                  style: text16(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _getSubmitButtonText(),
                              style: text16(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (isBusy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: text16(fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    bool required, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text12(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: text14(color: AppColors.grey400),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            validator: (val) {
              if (required && (val == null || val.trim().isEmpty)) {
                return 'Full name is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Government ID Type *',
            style: text12(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedIdType,
                isExpanded: true,
                items: ['Aadhaar', 'Passport', 'Driving License', 'PAN']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: text14()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedIdType = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload(
    String label,
    File? image,
    String? existingUrl,
    VoidCallback onTap, {
    String? errorMessage,
  }) {
    final bool hasExisting = existingUrl != null && existingUrl.isNotEmpty;
    final bool hasNew = image != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: text12(fontWeight: FontWeight.w600)),
              if (hasNew)
                Text(
                  'New selected',
                  style: text10(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (hasExisting)
                Text(
                  'Previously uploaded',
                  style: text10(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: errorMessage != null
                      ? AppColors.error
                      : (hasNew || hasExisting)
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.grey200,
                  style: BorderStyle.solid,
                ),
              ),
              child: hasNew
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(image, fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tap to change',
                              style: text10(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : hasExisting
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            existingUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.grey400,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Uploaded document on file',
                                    style: text12(color: AppColors.grey600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tap to change',
                              style: text10(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.grey400,
                          size: 30,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to upload',
                          style: text12(color: AppColors.grey400),
                        ),
                      ],
                    ),
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    errorMessage,
                    style: text12(color: AppColors.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
