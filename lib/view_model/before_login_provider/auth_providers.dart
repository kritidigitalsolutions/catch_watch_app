import 'dart:async';
import 'dart:io';

import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/main.dart';
import 'package:catch_watch/models/auth_models.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/views/before_login_Pages/categories_screen.dart';
import 'package:catch_watch/views/before_login_Pages/profile_setup_screen.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../views/before_login_Pages/otp_verify_screen.dart';
import '../after_login_provider/chat_provider.dart';

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

class AuthProvider extends ChangeNotifier with CodeAutoFill {
  final AuthRepository _authRepository = AuthRepository();

  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      for (int i = 0; i < 6; i++) {
        _otpDigits[i] = code![i];
      }
      notifyListeners();
    }
  }

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
      _errorMessage =
          'Please agree to the Terms of Service and Privacy Policy.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {'phone': _phoneNumber};
      final response = await _authRepository.sendOtp(data);

      _isLoading = false;
      if (response.success == true) {
        _otpSent = true;
        _startResendTimer();
        _step = AuthStep.otp;
        listenForCode();

        if (response.otp != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your OTP is: ${response.otp}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OtpScreen()),
        );
      } else {
        _errorMessage = response.message ?? 'Failed to send OTP';
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
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

  Future<void> resendOtp([BuildContext? context]) async {
    if (!_canResend) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = {'phone': _phoneNumber};
      final response = await _authRepository.sendOtp(data);

      _isLoading = false;
      if (response.success == true) {
        clearOtp();
        _startResendTimer();
        listenForCode();

        if (response.otp != null && context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your OTP is: ${response.otp}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to resend OTP')),
          );
        }
      }
    } catch (e) {
      _isLoading = false;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
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

    try {
      final data = {
        'phone': _phoneNumber,
        'otp': code,
      };
      final response = await _authRepository.verifyOtp(data);

      if (response.success == true) {
        if (response.isNewUser == true) {
          _otpVerifying = false;
          _step = AuthStep.categories;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CategoriesScreen()),
          );
        } else {
          // Existing user, save details and go to Home
          if (response.token != null) {
            final userDetail = UserDetails(
              name: response.user?.name,
              phone: response.user?.phone,
              image: response.user?.profileImage,
              token: response.token,
              sId: response.user?.id,
              isNewUser: false,
            );
            await HiveService.saveUser(userDetail);
            NotificationService.syncTokenToServer(null); // Sync FCM token after login
            
            // Initialize Chat Socket & E2EE
            if (context.mounted) {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              chatProvider.initSocket();
              chatProvider.initE2EE();
            }

          }
          _otpVerifying = false;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MyHomePage()),
            (route) => false,
          );
        }
      } else {
        _otpVerifying = false;
        _otpError = response.message ?? 'Invalid OTP';
      }
    } catch (e) {
      _otpVerifying = false;
      _otpError = e.toString();
    }
    notifyListeners();
  }

  void goBackToLogin() {
    _step = AuthStep.login;
    clearOtp();
    notifyListeners();
  }

  Future<void> verifyFromAutoFill(String code, BuildContext context) async {
    for (int i = 0; i < 6; i++) {
      _otpDigits[i] = code[i];
    }
    notifyListeners();
    await verifyOtp(context);
  }

  // ─── Categories State ───────────────────────────────────────
  final List<String> allGenres = [
    'Action',
    'Comedy',
    'Romance',
    'Thriller',
    'Horror',
    'Crime',
    'Drama',
    'Adventure',
    'Sci-Fi',
    'Documentary',
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
      MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
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

  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      _avatarPath = image.path;
      notifyListeners();
    }
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

    try {
      dio.FormData formData = dio.FormData.fromMap({
        'name': _name,
        'username': _username,
        'phone': _phoneNumber,
        'genres': _selectedGenres.toList(),
        'bio': '',
      });

      if (_avatarPath != null) {
        formData.files.add(MapEntry(
          'profileImage',
          await dio.MultipartFile.fromFile(_avatarPath!,
              filename: 'profile.jpg'),
        ));
      }

      final response = await _authRepository.completeProfile(formData);

      if (response.success == true) {
        // Save to Hive
        final userDetail = UserDetails(
          name: response.user?.name,
          phone: response.user?.phone,
          image: response.user?.profileImage,
          token: response.token,
          sId: response.user?.id,
          isNewUser: false,
        );
        await HiveService.saveUser(userDetail);
        NotificationService.syncTokenToServer(null); // Sync FCM token after profile complete
        
        // Initialize Chat Socket & E2EE
        if (context.mounted) {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          chatProvider.initSocket();
          chatProvider.initE2EE();
        }


        _profileSaving = false;
        _step = AuthStep.done;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      } else {
        _profileSaving = false;
        _profileError = response.message ?? 'Failed to complete profile';
      }
    } catch (e) {
      _profileSaving = false;
      _profileError = e.toString();
    }
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
    unregisterListener();
    super.dispose();
  }
}
