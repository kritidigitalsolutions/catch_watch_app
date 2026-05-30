import 'dart:async';

import 'package:catch_watch/main.dart';
import 'package:catch_watch/views/before_login_Pages/categories_screen.dart';
import 'package:catch_watch/views/before_login_Pages/profile_setup_screen.dart';
import 'package:flutter/material.dart';

import '../../views/before_login_Pages/otp_verify_screen.dart';

class OnboardingProvider extends ChangeNotifier {
  final PageController pageController = PageController();
  int currentPage = 0;

  final List<OnboardingItem> onboardingData = [
    OnboardingItem(
      image: "assets/images/1.png",
      title: "Discover Content",
      subtitle:
      "Watch stories that match your vibe\nDiscover short films, premium movies and trending entertainment in one place.",
    ),
    OnboardingItem(
      image: "assets/images/2.png",
      title: "Shorts Experience",
      subtitle:
      "Scroll. Watch. Enjoy.\nWatch unlimited short videos from creators for free.",
    ),
    OnboardingItem(
      image: "assets/images/3.png",
      title: "Premium + Create",
      subtitle:
      "Unlock premium. Create your own.\nStream premium stories or upload your own videos.",
    ),
  ];

  void onPageChanged(int index) {
    currentPage = index;
    notifyListeners();
  }

  void nextPage() {
    if (currentPage < onboardingData.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToPage(int page) {
    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}

class OnboardingItem {
  final String image;
  final String title;
  final String subtitle;

  OnboardingItem({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}



enum AuthStep { login, otp, categories, profile, done }

class AuthProvider extends ChangeNotifier {
  // ─── Navigation State ──────────────────────────────────────
  AuthStep _step = AuthStep.login;
  AuthStep get step => _step;

  // ─── Login State ───────────────────────────────────────────
  String _phoneNumber = '';
  String _countryCode = '+91';
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  String get phoneNumber => _phoneNumber;
  String get countryCode => _countryCode;
  bool get agreedToTerms => _agreedToTerms;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get maskedPhone {
    if (_phoneNumber.length < 6) return _phoneNumber;
    final visible = _phoneNumber.substring(_phoneNumber.length - 2);
    final masked = 'XXXXXX$visible';
    return '$_countryCode $masked';
  }

  void setPhone(String value) {
    _phoneNumber = value.trim();
    _errorMessage = null;
    notifyListeners();
  }

  void setCountryCode(String code) {
    _countryCode = code;
    notifyListeners();
  }

  void toggleTerms(bool? value) {
    _agreedToTerms = value ?? false;
    notifyListeners();
  }

  Future<void> sendOtp(BuildContext context) async {
    if (_phoneNumber.length < 10) {
      _errorMessage = 'Please enter a valid 10-digit mobile number.';
      notifyListeners();
      return;
    }
    if (!_agreedToTerms) {
      _errorMessage = 'Please agree to the Terms of Service and Privacy Policy.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    _isLoading = false;
    _otpSent = true;
    _startResendTimer();
    _step = AuthStep.otp;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OtpScreen(),
      ),
    );
    notifyListeners();
  }

  // ─── OTP State ─────────────────────────────────────────────
  final List<String> _otpDigits = List.filled(6, '');
  bool _otpSent = false;
  bool _otpVerifying = false;
  String? _otpError;
  int _resendSeconds = 30;
  Timer? _resendTimer;
  bool _canResend = false;

  List<String> get otpDigits => List.unmodifiable(_otpDigits);
  bool get otpSent => _otpSent;
  bool get otpVerifying => _otpVerifying;
  String? get otpError => _otpError;
  int get resendSeconds => _resendSeconds;
  bool get canResend => _canResend;
  String get otpCode => _otpDigits.join();

  void setOtpDigit(int index, String value) {
    if (index < 0 || index >= 6) return;
    _otpDigits[index] = value;
    _otpError = null;
    notifyListeners();
  }

  void clearOtp() {
    for (int i = 0; i < 6; i++) {
      _otpDigits[i] = '';
    }
    _otpError = null;
    notifyListeners();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        _resendSeconds--;
        notifyListeners();
      } else {
        _canResend = true;
        timer.cancel();
        notifyListeners();
      }
    });
  }

  Future<void> resendOtp() async {
    if (!_canResend) return;
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    clearOtp();
    _startResendTimer();
    notifyListeners();
  }

  Future<void> verifyOtp(BuildContext context) async {
    final code = otpCode;
    if (code.length < 6) {
      _otpError = 'Please enter all 6 digits.';
      notifyListeners();
      return;
    }

    _otpVerifying = true;
    _otpError = null;
    notifyListeners();

    // Simulate API verification — accept "123456" as valid for demo
    await Future.delayed(const Duration(seconds: 2));

    if (code == '123456') {
      _otpVerifying = false;
      _step = AuthStep.categories;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CategoriesScreen(),
        ),
      );
      notifyListeners();
    } else {
      _otpVerifying = false;
      _otpError = 'Invalid OTP. Use 123456 for demo.';
      notifyListeners();
    }
  }

  void goBackToLogin() {
    _step = AuthStep.login;
    clearOtp();
    notifyListeners();
  }

  // ─── Categories State ───────────────────────────────────────
  final List<String> allGenres = [
    'Action', 'Comedy', 'Romance',
    'Thriller', 'Horror', 'Crime', 'Drama',
    'Adventure', 'Sci-Fi', 'Documentary',
  ];

  final Set<String> _selectedGenres = {};
  String? _categoriesError;

  Set<String> get selectedGenres => Set.unmodifiable(_selectedGenres);
  String? get categoriesError => _categoriesError;

  void toggleGenre(String genre) {
    if (_selectedGenres.contains(genre)) {
      _selectedGenres.remove(genre);
    } else {
      _selectedGenres.add(genre);
    }
    _categoriesError = null;
    notifyListeners();
  }

  void proceedFromCategories(BuildContext context) {
    if (_selectedGenres.isEmpty) {
      _categoriesError = 'Please select at least one genre.';
      notifyListeners();
      return;
    }
    _step = AuthStep.profile;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(),
      ),
    );
    notifyListeners();
  }

  void goBackToOtp() {
    _step = AuthStep.otp;
    notifyListeners();
  }

  // ─── Profile State ─────────────────────────────────────────
  String _name = '';
  String _username = '';
  String? _avatarPath;
  bool _profileSaving = false;
  String? _profileError;
  String? _nameError;
  String? _usernameError;

  String get name => _name;
  String get username => _username;
  String? get avatarPath => _avatarPath;
  bool get profileSaving => _profileSaving;
  String? get profileError => _profileError;
  String? get nameError => _nameError;
  String? get usernameError => _usernameError;

  void setName(String value) {
    _name = value.trim();
    _nameError = null;
    notifyListeners();
  }

  void setUsername(String value) {
    _username = value.trim().replaceAll(' ', '_').toLowerCase();
    _usernameError = null;
    notifyListeners();
  }

  void setAvatarPath(String? path) {
    _avatarPath = path;
    notifyListeners();
  }

  bool _validateProfile() {
    bool valid = true;
    if (_name.isEmpty) {
      _nameError = 'Name is required.';
      valid = false;
    } else if (_name.length < 2) {
      _nameError = 'Name must be at least 2 characters.';
      valid = false;
    }
    if (_username.isEmpty) {
      _usernameError = 'Username is required.';
      valid = false;
    } else if (_username.length < 3) {
      _usernameError = 'Username must be at least 3 characters.';
      valid = false;
    } else if (!RegExp(r'^[a-z0-9_]+$').hasMatch(_username)) {
      _usernameError = 'Only lowercase letters, numbers and underscores.';
      valid = false;
    }
    notifyListeners();
    return valid;
  }

  Future<void> saveProfile(BuildContext context) async {
    if (!_validateProfile()) return;

    _profileSaving = true;
    _profileError = null;
    notifyListeners();

    // Simulate API save
    await Future.delayed(const Duration(seconds: 2));

    _profileSaving = false;
    _step = AuthStep.done;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MyHomePage(),
      ),
    );
    notifyListeners();
  }

  void goBackToCategories() {
    _step = AuthStep.categories;
    notifyListeners();
  }

  // ─── Cleanup ───────────────────────────────────────────────
  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}