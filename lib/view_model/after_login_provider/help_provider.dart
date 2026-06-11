import 'package:catch_watch/models/help_model.dart';
import 'package:catch_watch/repository/legal_repository.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpProvider extends ChangeNotifier {
  final LegalRepository _legalRepository = LegalRepository();

  List<HelpItem> _faqItems = [];
  List<HelpItem> _supportItems = [];
  bool _isLoading = false;
  String? _error;

  List<HelpItem> get faqItems => _faqItems;
  List<HelpItem> get supportItems => _supportItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchHelpData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _legalRepository.getHelpData();
      if (response.success == true) {
        _faqItems = response.helpData?.where((item) => item.category == 'faq').toList() ?? [];
        _supportItems = response.helpData?.where((item) => item.category == 'contact-support').toList() ?? [];
      } else {
        _error = 'Failed to fetch help data';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> launchEmail(String email) async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      if (await canLaunchUrl(params)) {
        await launchUrl(params);
      } else {
        // Fallback for some devices
        final String url = 'mailto:$email?subject=Support Request';
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  Future<void> launchPhone(String phone) async {
    // Remove any non-numeric characters for tel: scheme
    final String cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri params = Uri(
      scheme: 'tel',
      path: cleanPhone,
    );
    try {
      if (await canLaunchUrl(params)) {
        await launchUrl(params);
      } else {
        final String url = 'tel:$cleanPhone';
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      debugPrint('Could not launch phone: $e');
    }
  }
}
