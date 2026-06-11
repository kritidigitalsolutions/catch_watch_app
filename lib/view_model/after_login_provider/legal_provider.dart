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
    try {
      return _documents.firstWhere((doc) => doc.type == type);
    } catch (e) {
      return null;
    }
  }
}
