import 'package:catch_watch/models/legal_model.dart';
import 'package:catch_watch/repository/legal_repository.dart';
import 'package:flutter/material.dart';

class LegalProvider extends ChangeNotifier {
  final LegalRepository _legalRepository = LegalRepository();

  List<LegalDocument> _documents = [];
  bool _isLoading = false;
  String? _error;

  List<LegalDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchLegalDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _legalRepository.getLegalDocuments();
      if (response.success == true) {
        _documents = response.documents ?? [];
      } else {
        _error = 'Failed to fetch legal documents';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  LegalDocument? getDocumentByType(String type) {
    if (_documents.isEmpty) return null;
    final query = type.trim().toLowerCase().replaceAll('_', '-');

    // 1. Direct exact or normalized match
    try {
      return _documents.firstWhere(
        (doc) => (doc.type?.trim().toLowerCase().replaceAll('_', '-') ?? '') == query,
      );
    } catch (_) {}

    // 2. Keyword/Alias matching (e.g. 'terms', 'terms-conditions', 'terms_of_service')
    if (query.contains('term')) {
      try {
        return _documents.firstWhere(
          (doc) => (doc.type?.toLowerCase().contains('term') ?? false) ||
                   (doc.title?.toLowerCase().contains('term') ?? false),
        );
      } catch (_) {}
    }

    if (query.contains('privacy')) {
      try {
        return _documents.firstWhere(
          (doc) => (doc.type?.toLowerCase().contains('privacy') ?? false) ||
                   (doc.title?.toLowerCase().contains('privacy') ?? false),
        );
      } catch (_) {}
    }

    if (query.contains('refund')) {
      try {
        return _documents.firstWhere(
          (doc) => (doc.type?.toLowerCase().contains('refund') ?? false) ||
                   (doc.title?.toLowerCase().contains('refund') ?? false),
        );
      } catch (_) {}
    }

    return null;
  }
}
