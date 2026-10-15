import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:catch_watch/models/report_model.dart';
import 'package:catch_watch/repository/report_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';

class ReportProvider extends ChangeNotifier {
  final ReportRepository _repository = ReportRepository();

  bool _isSubmitting = false;
  String? _errorMessage;
  ReportResponse? _lastResponse;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  ReportResponse? get lastResponse => _lastResponse;

  void clearState() {
    _isSubmitting = false;
    _errorMessage = null;
    _lastResponse = null;
    notifyListeners();
  }

  /// Submits a UGC report and returns the [ReportResponse] on success, or null on failure.
  Future<ReportResponse?> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    if (!HiveService.isLogin()) {
      _errorMessage = 'You need to be logged in to submit a report.';
      notifyListeners();
      return null;
    }

    if (targetId.trim().isEmpty) {
      _errorMessage = 'Invalid target item identifier.';
      notifyListeners();
      return null;
    }

    if (targetType.trim().toLowerCase() == 'user' && targetId.trim() == HiveService.userId) {
      _errorMessage = 'You cannot report your own profile.';
      notifyListeners();
      return null;
    }

    if (reason.trim().isEmpty) {
      _errorMessage = 'Please select a reason for reporting.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _lastResponse = null;
    notifyListeners();

    try {
      final response = await _repository.submitReport(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        description: description,
      );

      _lastResponse = response;
      _isSubmitting = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isSubmitting = false;
      if (e is AppException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      notifyListeners();
      return null;
    }
  }
}
