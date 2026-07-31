import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:catch_watch/repository/verification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class VerificationProvider extends ChangeNotifier {
  final VerificationRepository _repository = VerificationRepository();

  List<Plan> _bluetickPlans = [];
  VerificationApplication? _currentApplication;
  bool _isLoading = false;
  bool _isInitialStatusLoaded = false;
  String? _error;

  List<Plan> get bluetickPlans => _bluetickPlans;
  VerificationApplication? get currentApplication => _currentApplication;
  bool get isLoading => _isLoading;
  bool get isInitialStatusLoaded => _isInitialStatusLoaded;
  String? get error => _error;

  Future<void> fetchBluetickPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getBluetickPlans();
      if (response.success == true) {
        _bluetickPlans = response.plans ?? [];
      } else {
        _error = 'Failed to fetch verification plans';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchVerificationStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.getVerificationStatus();
      if (response.success == true) {
        _currentApplication = response.application;
      } else {
        _currentApplication = null;
      }
    } catch (e) {
      debugPrint("Verification Status Error: $e");
      _currentApplication = null;
    } finally {
      _isLoading = false;
      _isInitialStatusLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> applyVerification(FormData data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.applyVerification(data);
      if (response['success'] == true) {
        await fetchVerificationStatus();
        return true;
      } else {
        _error = response['message'] ?? 'Application failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateVerification(FormData data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.updateVerification(data);
      if (response['success'] == true) {
        await fetchVerificationStatus();
        return true;
      } else {
        _error = response['message'] ?? 'Update failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelVerification() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.cancelVerification();
      if (response['success'] == true) {
        await fetchVerificationStatus();
        return true;
      } else {
        _error = response['message'] ?? 'Cancellation failed';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
