import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:catch_watch/repository/verification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class VerificationProvider extends ChangeNotifier {
  final VerificationRepository _repository = VerificationRepository();

  List<Plan> _bluetickPlans = [];
  List<Plan> _orangetickPlans = [];
  VerificationApplication? _currentApplication;
  bool _isLoading = false;
  bool _isInitialStatusLoaded = false;
  bool _isBluetickPlansLoaded = false;
  bool _isOrangetickPlansLoaded = false;
  bool _isFetchingPlans = false;
  bool _isFetchingStatus = false;
  bool _isApplyingVerification = false;
  bool _isUpdatingVerification = false;
  String? _error;
  String? _statusError;
  String? _plansError;
  String? _rawStatus;
  bool? _isVerified;
  String? _badgeType;
  bool _isAlreadyPending = false;
  dynamic _lastErrorData;

  List<Plan> get orangetickPlans => _orangetickPlans;
  bool get isOrangetickPlansLoaded => _isOrangetickPlansLoaded;
  List<Plan> get bluetickPlans => _bluetickPlans;
  VerificationApplication? get currentApplication => _currentApplication;
  bool get isLoading => _isLoading;
  bool get isInitialStatusLoaded => _isInitialStatusLoaded;
  bool get isBluetickPlansLoaded => _isBluetickPlansLoaded;
  bool get isFetchingPlans => _isFetchingPlans;
  bool get isFetchingStatus => _isFetchingStatus;
  bool get isApplyingVerification => _isApplyingVerification;
  bool get isUpdatingVerification => _isUpdatingVerification;
  String? get error => _error;
  String? get statusError => _statusError;
  String? get plansError => _plansError;
  String? get rawStatus => _rawStatus;
  bool? get isVerified => _isVerified;
  String? get badgeType => _badgeType;
  bool get isAlreadyPending => _isAlreadyPending;
  dynamic get lastErrorData => _lastErrorData;

  String get effectiveStatus {
    // 1. If backend explicitly reports isVerified == true
    if (_isVerified == true) return 'VERIFIED';

    // 2. Check rawStatus from response
    if (_rawStatus != null && _rawStatus!.isNotEmpty) {
      final upper = _rawStatus!.trim().toUpperCase();
      if (upper == 'PENDING' || upper == 'UNDER_REVIEW' || upper == 'IN_REVIEW' || upper == 'PROCESSING') {
        return 'PENDING';
      }
      if (upper == 'APPROVED' || upper == 'ACTIVE' || upper == 'VERIFIED') {
        return 'VERIFIED';
      }
      if (upper == 'REJECTED') {
        return 'REJECTED';
      }
      if (upper == 'CANCELLED' ||
          upper == 'CANCELED' ||
          upper == 'ADMIN_CANCELLED' ||
          upper == 'ADMIN_CANCELED' ||
          upper == 'CLOSED') {
        return 'CANCELLED';
      }
      if (upper == 'NOT_VERIFIED') {
        return 'NOT_VERIFIED';
      }
    }

    // 3. Check currentApplication status
    if (_currentApplication != null) {
      final appStatus = (_currentApplication?.status ?? '').trim().toUpperCase();
      if (appStatus == 'PENDING' || appStatus == 'UNDER_REVIEW' || appStatus == 'IN_REVIEW' || appStatus == 'PROCESSING') {
        return 'PENDING';
      }
      if (appStatus == 'APPROVED' || appStatus == 'ACTIVE' || appStatus == 'VERIFIED') {
        return 'VERIFIED';
      }
      if (appStatus == 'REJECTED') {
        return 'REJECTED';
      }
      if (appStatus == 'CANCELLED' ||
          appStatus == 'CANCELED' ||
          appStatus == 'ADMIN_CANCELLED' ||
          appStatus == 'ADMIN_CANCELED' ||
          appStatus == 'CLOSED') {
        return 'CANCELLED';
      }
      if (appStatus == 'NOT_VERIFIED') {
        return 'NOT_VERIFIED';
      }
      if (appStatus.isNotEmpty) {
        return appStatus;
      }
    }

    // 4. Missing or unknown status with an existing application is safely treated as PENDING
    if (_currentApplication != null) {
      return 'PENDING';
    }

    return 'NOT_VERIFIED';
  }

  bool get isRejected => effectiveStatus == 'REJECTED';
  bool get isCancelled => effectiveStatus == 'CANCELLED';
  bool get canReapply => isRejected || isCancelled;

  bool get isNotVerified {
    if (_statusError != null) return false;
    if (!_isInitialStatusLoaded) return false;
    return effectiveStatus == 'NOT_VERIFIED';
  }

  bool get hasActiveOrPendingApplication {
    if (effectiveStatus == 'PENDING') return true;
    if (_currentApplication == null) return false;
    final status = (_currentApplication?.status ?? '').trim().toUpperCase();
    return status == 'PENDING' ||
        status == 'UNDER_REVIEW' ||
        status == 'IN_REVIEW' ||
        status == 'PROCESSING' ||
        (status != 'APPROVED' &&
            status != 'ACTIVE' &&
            status != 'VERIFIED' &&
            status != 'REJECTED' &&
            status != 'CANCELLED' &&
            status != 'CANCELED' &&
            status != 'ADMIN_CANCELLED' &&
            status != 'ADMIN_CANCELED' &&
            status != 'CLOSED' &&
            status != 'NOT_VERIFIED');
  }

  bool get isVerifiedActive {
    if (_isVerified == true) return true;
    if (effectiveStatus == 'VERIFIED') return true;
    final status = (_currentApplication?.status ?? '').trim().toUpperCase();
    return status == 'APPROVED' || status == 'ACTIVE' || status == 'VERIFIED';
  }

  bool get canApplyForVerification {
    return isNotVerified || canReapply;
  }

  Future<void> fetchOrangetickPlans({bool forceRefresh = false}) async {
    if (_isFetchingPlans) {
      debugPrint('[ORANGE_TICK_DEBUG] fetchOrangetickPlans() SKIPPED: already in-flight');
      return;
    }
    if (!forceRefresh && _isOrangetickPlansLoaded && _orangetickPlans.isNotEmpty) {
      debugPrint('[ORANGE_TICK_DEBUG] fetchOrangetickPlans() SKIPPED: already loaded');
      return;
    }
    _isFetchingPlans = true;
    _isLoading = true;
    _error = null;
    _plansError = null;
    debugPrint('[ORANGE_TICK_DEBUG] fetchOrangetickPlans() START');
    debugPrint('[ORANGE_TICK_FLOW] planFetch START');
    notifyListeners();

    try {
      final response = await _repository.getOrangetickPlans();
      if (response.success == true) {
        _orangetickPlans = response.plans ?? [];
      } else {
        _plansError = 'Failed to fetch verification plans';
        _error = _plansError;
      }
    } catch (e) {
      _plansError = e.toString();
      _error = _plansError;
    } finally {
      _isFetchingPlans = false;
      _isOrangetickPlansLoaded = true;
      _isLoading = false;
      notifyListeners();
      debugPrint('[ORANGE_TICK_DEBUG] fetchOrangetickPlans() END');
      debugPrint('[ORANGE_TICK_FLOW] planFetch END');
      debugPrint('[ORANGE_TICK_FLOW] planCount=${_orangetickPlans.length}');
    }
  }

  Future<void> fetchBluetickPlans({bool forceRefresh = false}) async {
    if (_isFetchingPlans) {
      debugPrint('[BLUE_TICK_DEBUG] getBluetickPlans() SKIPPED: already in-flight');
      return;
    }
    if (!forceRefresh && _isBluetickPlansLoaded && _bluetickPlans.isNotEmpty) {
      debugPrint('[BLUE_TICK_DEBUG] getBluetickPlans() SKIPPED: already loaded');
      return;
    }
    _isFetchingPlans = true;
    _isLoading = true;
    _error = null;
    _plansError = null;
    debugPrint('[BLUE_TICK_DEBUG] getBluetickPlans() START');
    notifyListeners();

    try {
      final response = await _repository.getBluetickPlans();
      if (response.success == true) {
        _bluetickPlans = response.plans ?? [];
      } else {
        _plansError = 'Failed to fetch verification plans';
        _error = _plansError;
      }
    } catch (e) {
      _plansError = e.toString();
      _error = _plansError;
    } finally {
      _isFetchingPlans = false;
      _isBluetickPlansLoaded = true;
      _isLoading = false;
      notifyListeners();
      debugPrint('[BLUE_TICK_DEBUG] getBluetickPlans() END');
    }
  }

  Future<void> fetchVerificationStatus({bool forceRefresh = false}) async {
    if (_isFetchingStatus) {
      debugPrint('[ORANGE_TICK_DEBUG] fetchVerificationStatus() SKIPPED: already in-flight');
      return;
    }
    _isFetchingStatus = true;
    _isLoading = true;
    _error = null;
    _statusError = null;
    debugPrint('[ORANGE_TICK_DEBUG] fetchVerificationStatus() START');
    notifyListeners();

    try {
      final response = await _repository.getVerificationStatus();
      if (response.application != null) {
        if (_currentApplication != null) {
          // If the application IDs match, or one of them is null, merge carefully
          // so submitted fields are never overwritten with null/empty values
          if (_currentApplication!.id == null ||
              response.application!.id == null ||
              _currentApplication!.id == response.application!.id) {
            _currentApplication = _currentApplication!.mergeWith(response.application!);
          } else {
            _currentApplication = response.application;
          }
        } else {
          _currentApplication = response.application;
        }
      } else if (_currentApplication != null && response.status != null) {
        // Status endpoint omitted application details: update status on existing application
        _currentApplication = _currentApplication!.copyWith(status: response.status);
      }

      _rawStatus = response.status ?? _currentApplication?.status;
      _isVerified = response.isVerified ?? (_rawStatus?.toUpperCase() == 'VERIFIED');
      _badgeType = response.badgeType ?? _badgeType;
      if (response.success != true && response.status == null && response.application == null) {
        _statusError = response.message ?? 'Failed to fetch verification status';
        _error = _statusError;
      }
    } catch (e) {
      debugPrint("Verification Status Error: $e");
      // Do NOT nullify _currentApplication if we already have it from submission
      _statusError = e.toString();
      _error = _statusError;
    } finally {
      _isFetchingStatus = false;
      _isLoading = false;
      _isInitialStatusLoaded = true;
      notifyListeners();
      debugPrint('[ORANGE_TICK_DEBUG] fetchVerificationStatus() END (effectiveStatus=$effectiveStatus, isVerified=$_isVerified, error=$_statusError)');
    }
  }

  VerificationApplication _buildApplicationFromSubmission(
    dynamic response,
    FormData? formData, {
    Plan? plan,
  }) {
    Map<String, dynamic>? appMap;
    if (response is Map) {
      if (response['application'] is Map) {
        appMap = Map<String, dynamic>.from(response['application'] as Map);
      } else if (response['data'] is Map) {
        final d = response['data'] as Map;
        if (d['application'] is Map) {
          appMap = Map<String, dynamic>.from(d['application'] as Map);
        } else if (d['verification'] is Map) {
          appMap = Map<String, dynamic>.from(d['verification'] as Map);
        } else {
          appMap = Map<String, dynamic>.from(d);
        }
      } else if (response['verification'] is Map) {
        appMap = Map<String, dynamic>.from(response['verification'] as Map);
      }
    }

    VerificationApplication? parsedApp;
    if (appMap != null) {
      try {
        parsedApp = VerificationApplication.fromJson(appMap);
      } catch (e) {
        debugPrint('[ORANGE_TICK_DEBUG] Error parsing application from submission response: $e');
      }
    }

    String? formFullName;
    String? formIdType;
    String? formIdNumber;
    String? formPlanId;
    String? formPaymentId;
    String? formTransactionId;
    String? formOrderId;
    if (formData != null) {
      for (final field in formData.fields) {
        final key = field.key.toLowerCase();
        if (key == 'fullname' || key == 'full_name' || key == 'name') {
          formFullName = field.value;
        } else if (key == 'governmentidtype' ||
            key == 'idtype' ||
            key == 'documenttype' ||
            key == 'id_type') {
          formIdType = field.value;
        } else if (key == 'governmentidnumber' ||
            key == 'idnumber' ||
            key == 'id_number') {
          formIdNumber = field.value;
        } else if (key == 'planid' || key == 'plan_id' || key == 'plan') {
          formPlanId = field.value;
        } else if (key == 'paymentid' || key == 'payment_id') {
          formPaymentId = field.value;
        } else if (key == 'transactionid' || key == 'transaction_id') {
          formTransactionId = field.value;
        } else if (key == 'orderid' || key == 'order_id') {
          formOrderId = field.value;
        }
      }
    }

    final localApp = VerificationApplication(
      id: _currentApplication?.id,
      user: _currentApplication?.user,
      fullName: formFullName ?? _currentApplication?.fullName,
      governmentIdType: formIdType ?? _currentApplication?.governmentIdType,
      governmentIdNumber: formIdNumber ?? _currentApplication?.governmentIdNumber,
      planId: formPlanId ?? plan?.id ?? _currentApplication?.planId,
      plan: plan ?? _currentApplication?.plan,
      paymentId: formPaymentId ?? _currentApplication?.paymentId,
      transactionId: formTransactionId ?? _currentApplication?.transactionId,
      orderId: formOrderId ?? _currentApplication?.orderId,
      isPaid: _currentApplication?.isPaid,
      status: 'PENDING',
      createdAt: _currentApplication?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (parsedApp != null) {
      return localApp.mergeWith(parsedApp);
    }
    return localApp;
  }

  Future<bool> applyVerification(FormData data, {Plan? plan}) async {
    if (_isApplyingVerification) {
      debugPrint('[ORANGE_TICK_FLOW] applyVerification IGNORED: already in-flight');
      return false;
    }
    _isApplyingVerification = true;
    _isLoading = true;
    _error = null;
    _isAlreadyPending = false;
    _lastErrorData = null;
    notifyListeners();

    try {
      final response = await _repository.applyVerification(data);
      if (response != null && response['success'] == true) {
        final submittedApp = _buildApplicationFromSubmission(response, data, plan: plan);
        _currentApplication = _currentApplication == null
            ? submittedApp
            : _currentApplication!.mergeWith(submittedApp);
        _rawStatus = _currentApplication?.status ?? 'PENDING';

        await fetchVerificationStatus(forceRefresh: true);
        return true;
      } else {
        _lastErrorData = response;
        _isAlreadyPending = _detectIfPending(response);
        _error = response?['message'] ?? response?['error'] ?? 'Application failed';
        return false;
      }
    } catch (e) {
      dynamic errorData;
      String errorMessage = e.toString();

      if (e is AppException) {
        errorData = e.data;
        errorMessage = e.message;
      } else if (e is DioException) {
        errorData = e.response?.data;
        errorMessage = e.message ?? e.toString();
      }

      _lastErrorData = errorData;
      _isAlreadyPending = _detectIfPending(errorData) || _isPendingMessage(errorMessage);
      _error = errorMessage;
      return false;
    } finally {
      _isApplyingVerification = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _detectIfPending(dynamic data) {
    if (data == null) return false;
    if (data is Map) {
      final code = (data['code'] ?? data['errorCode'] ?? data['statusCode'])?.toString().toLowerCase() ?? '';
      if (code == 'already_pending' ||
          code == 'verification_pending' ||
          code == 'pending' ||
          code == 'active_request' ||
          code == 'already_applied') {
        return true;
      }

      final status = (data['status'])?.toString().toLowerCase() ?? '';
      if (status == 'pending' ||
          status == 'already_pending' ||
          status == 'verification_pending' ||
          status == 'under_review' ||
          status == 'active_request') {
        return true;
      }

      if (data['application'] is Map) {
        final appStatus = data['application']['status']?.toString().toLowerCase() ?? '';
        if (appStatus == 'pending' || appStatus == 'under_review') {
          return true;
        }
      }

      final msg = (data['message'] ?? data['error'])?.toString() ?? '';
      if (_isPendingMessage(msg)) {
        return true;
      }
    } else if (data is String) {
      return _isPendingMessage(data);
    }
    return false;
  }

  bool _isPendingMessage(String msg) {
    if (msg.isEmpty) return false;
    final lower = msg.toLowerCase();
    return lower.contains('active verification request') ||
        lower.contains('verification request under review') ||
        lower.contains('already have an active verification') ||
        lower.contains('already have a verification request') ||
        lower.contains('already pending') ||
        lower.contains('verification pending') ||
        (lower.contains('verification') && lower.contains('under review')) ||
        (lower.contains('request') && lower.contains('under review')) ||
        (lower.contains('already') && lower.contains('review'));
  }

  Future<bool> updateVerification(FormData data, {Plan? plan}) async {
    if (_isUpdatingVerification) {
      debugPrint('[ORANGE_TICK_FLOW] updateVerification IGNORED: already in-flight');
      return false;
    }
    _isUpdatingVerification = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.updateVerification(data);
      final bool isSuccess = response != null &&
          (response['success'] == true ||
              response['status'] == true ||
              response['status'] == 200 ||
              response['statusCode'] == 200 ||
              (response['message'] != null &&
                  response['message'].toString().toLowerCase().contains('success')));

      if (isSuccess) {
        final submittedApp = _buildApplicationFromSubmission(response, data, plan: plan);
        _currentApplication = _currentApplication == null
            ? submittedApp
            : _currentApplication!.mergeWith(submittedApp);
        _rawStatus = _currentApplication?.status ?? 'PENDING';

        await fetchVerificationStatus(forceRefresh: true);
        return true;
      } else {
        _error = response?['message'] ?? 'Update failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdatingVerification = false;
      _isLoading = false;
      notifyListeners();
    }
  }
}
