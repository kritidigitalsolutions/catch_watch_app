import 'dart:async';

import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/main.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/views/before_login_Pages/categories_screen.dart';
import 'package:catch_watch/views/before_login_Pages/profile_setup_screen.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
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
  final AuthRepository _authRepository;
  final bool _isDebugMode;
  final WidgetBuilder _homeScreenBuilder;
  final Future<void> Function(UserDetails user)? _onSessionPersisted;

  AuthProvider({
    AuthRepository? authRepository,
    bool isDebugMode = kDebugMode,
    WidgetBuilder? homeScreenBuilder,
    Future<void> Function(UserDetails user)? onSessionPersisted,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _isDebugMode = kDebugMode && isDebugMode,
        _homeScreenBuilder =
            homeScreenBuilder ?? ((_) => const MyHomePage()),
        _onSessionPersisted = onSessionPersisted;

  /// Supported country dial codes displayed in the LoginScreen country picker.
  static const Map<String, String> supportedCountries = <String, String>{
    '🇮🇳 India': '+91',
    '🇺🇸 USA': '+1',
    '🇬🇧 UK': '+44',
    '🇦🇪 UAE': '+971',
    '🇦🇺 Australia': '+61',
  };

  /// Normalizes a country dial code to `+<digits>` format (defaults to `+91`).
  static String normalizeCountryCode(String code) {
    final String trimmed = code.trim();
    if (trimmed.isEmpty) return '+91';
    final String digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '+91';
    return '+$digits';
  }

  /// Minimum valid local subscriber number length for [countryCode].
  ///
  /// - India (`+91`) and USA/NANP (`+1`): 10 digits.
  /// - UAE (`+971`), Australia (`+61`), UK (`+44`), and other international
  ///   country codes: 9 digits (supporting 9-digit local mobile numbers).
  static int minPhoneDigitsForCountry(String countryCode) {
    final String normalized = normalizeCountryCode(countryCode);
    switch (normalized) {
      case '+91':
      case '+1':
        return 10;
      case '+971':
      case '+61':
      case '+44':
      default:
        return 9;
    }
  }

  /// Maximum valid local subscriber number length for [countryCode].
  ///
  /// - India (`+91`), USA (`+1`), UAE (`+971`), Australia (`+61`), UK (`+44`):
  ///   10 digits (accommodating 10-digit numbers or 9-digit numbers with a
  ///   leading trunk `0`).
  /// - Other international country codes: up to 15 digits per ITU-T E.164.
  static int maxPhoneDigitsForCountry(String countryCode) {
    final String normalized = normalizeCountryCode(countryCode);
    switch (normalized) {
      case '+91':
      case '+1':
      case '+971':
      case '+61':
      case '+44':
        return 10;
      default:
        return 15;
    }
  }

  /// Validates that [phone] contains only digits and satisfies the valid digit
  /// length range for [countryCode].
  static bool isValidPhoneForCountry(String phone, String countryCode) {
    final String trimmed = phone.trim();
    if (trimmed.isEmpty || !RegExp(r'^\d+$').hasMatch(trimmed)) {
      return false;
    }
    final int minLen = minPhoneDigitsForCountry(countryCode);
    final int maxLen = maxPhoneDigitsForCountry(countryCode);
    return trimmed.length >= minLen && trimmed.length <= maxLen;
  }

  /// Determines whether a debug-only OTP preview may be shown in the UI.
  ///
  /// Strictly returns `false` in production/release builds (`!kDebugMode`) or
  /// when [isDebugMode] is `false`, or when [otp] is null/blank.
  static bool shouldShowOtpInUi(
    String? otp, {
    bool isDebugMode = kDebugMode,
  }) {
    if (!kDebugMode || !isDebugMode) return false;
    final String? cleanOtp = otp?.trim();
    return cleanOtp != null && cleanOtp.isNotEmpty;
  }

  /// Whether this provider instance is running in debug mode.
  bool get isDebugMode => _isDebugMode;

  /// Whether this provider instance is permitted to display a debug OTP SnackBar.
  bool shouldShowOtpSnackBar(String? otp) {
    return shouldShowOtpInUi(otp, isDebugMode: _isDebugMode);
  }

  void _safeListenForCode() {
    try {
      listenForCode();
    } catch (e) {
      if (_isDebugMode) {
        debugPrint('Error starting SMS code listener: $e');
      }
    }
  }

  void _safeUnregisterListener() {
    try {
      unregisterListener().catchError((Object e) {
        if (_isDebugMode) {
          debugPrint('Error unregistering listener: $e');
        }
      });
    } catch (e) {
      if (_isDebugMode) {
        debugPrint('Error unregistering listener: $e');
      }
    }
  }

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
  String get fullPhoneNumber => '$_countryCode$_phoneNumber';
  int get minPhoneLength => minPhoneDigitsForCountry(_countryCode);
  int get maxPhoneLength => maxPhoneDigitsForCountry(_countryCode);
  bool get isPhoneValid => isValidPhoneForCountry(_phoneNumber, _countryCode);
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
    _countryCode = normalizeCountryCode(code);
    _errorMessage = null;
    notifyListeners();
  }

  void toggleTerms(bool? value) {
    _agreedToTerms = value ?? false;
    if (_agreedToTerms &&
        _errorMessage ==
            'Please agree to the Terms of Service and Privacy Policy.') {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Builds the request payload for `/api/auth/send-otp`.
  /// Includes both `'phone'` (local subscriber digits) and `'countryCode'`
  /// (`+<dialCode>`) for backend compatibility.
  Map<String, dynamic> buildSendOtpPayload() {
    return <String, dynamic>{
      'phone': _phoneNumber,
      'countryCode': _countryCode,
    };
  }

  /// Builds the request payload for `/api/auth/verify-otp`.
  /// Includes `'phone'`, `'countryCode'`, and `'otp'`.
  Map<String, dynamic> buildVerifyOtpPayload(String otp) {
    return <String, dynamic>{
      'phone': _phoneNumber,
      'countryCode': _countryCode,
      'otp': otp,
    };
  }

  Future<void> sendOtp(BuildContext context) async {
    if (_isLoading) return;
    if (!isPhoneValid) {
      final int minLen = minPhoneLength;
      final int maxLen = maxPhoneLength;
      if (minLen == 10 && maxLen == 10) {
        _errorMessage = 'Please enter a valid 10-digit mobile number.';
      } else if (minLen == 9 && maxLen == 10) {
        _errorMessage = 'Please enter a valid 9 to 10-digit mobile number.';
      } else {
        _errorMessage =
            'Please enter a valid mobile number ($minLen-$maxLen digits).';
      }
      notifyListeners();
      return;
    }
    if (!_agreedToTerms) {
      _errorMessage =
          'Please agree to the Terms of Service and Privacy Policy.';
      notifyListeners();
      return;
    }

    final bool wasAlreadyOnOtpStep = _step == AuthStep.otp;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = buildSendOtpPayload();
      final response = await _authRepository.sendOtp(data);

      _isLoading = false;
      if (response.success == true) {
        clearOtp();
        _otpSent = true;
        _startResendTimer();
        _step = AuthStep.otp;
        _safeListenForCode();

        if (shouldShowOtpSnackBar(response.otp) && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your OTP is: ${response.otp!.trim()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (context.mounted && !wasAlreadyOnOtpStep) {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/auth/otp'),
              builder: (context) => const OtpScreen(),
            ),
          ).then((_) {
            if (_step == AuthStep.otp) {
              _step = AuthStep.login;
              notifyListeners();
            }
          });
        }
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
    if (_otpDigits[index] == value && _otpError == null) return;
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
      final data = buildSendOtpPayload();
      final response = await _authRepository.sendOtp(data);

      _isLoading = false;
      if (response.success == true) {
        clearOtp();
        _startResendTimer();
        _safeListenForCode();

        if (shouldShowOtpSnackBar(response.otp) &&
            context != null &&
            context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your OTP is: ${response.otp!.trim()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 10),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to resend OTP')),
          );
        }
      }
    } catch (e) {
      _isLoading = false;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    notifyListeners();
  }

  Future<void> _persistAuthenticatedSession(
    UserDetails userDetail,
    ChatProvider? chatProvider,
  ) async {
    if (_onSessionPersisted != null) {
      await _onSessionPersisted(userDetail);
      return;
    }
    await HiveService.saveUser(userDetail);
    await HiveService.setOnboardingCompleted(true);
    await NotificationService.syncTokenToServer(); // Sync FCM token

    // Initialize Chat Socket & E2EE
    if (chatProvider != null) {
      chatProvider.initSocket();
      chatProvider.ensureReady();
    }
  }

  ChatProvider? _tryReadChatProvider(BuildContext context) {
    if (!context.mounted) return null;
    try {
      return Provider.of<ChatProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> verifyOtp(BuildContext context) async {
    if (_otpVerifying) return;
    if (_step == AuthStep.categories ||
        _step == AuthStep.profile ||
        _step == AuthStep.done) {
      return;
    }
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
      final data = buildVerifyOtpPayload(code);
      final response = await _authRepository.verifyOtp(data);

      if (response.success == true) {
        if (response.isNewUser == true) {
          _otpVerifying = false;
          resetOtpState();
          _step = AuthStep.categories;
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/signup/categories'),
                builder: (context) => const CategoriesScreen(),
              ),
            ).then((_) {
              if (_step == AuthStep.categories) {
                _step = AuthStep.otp;
                notifyListeners();
              }
            });
          }
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
            ChatProvider? chatProvider;
            if (context.mounted) {
              chatProvider = _tryReadChatProvider(context);
            }
            await _persistAuthenticatedSession(userDetail, chatProvider);
          }
          _otpVerifying = false;
          _step = AuthStep.done;
          resetOtpState();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/home'),
                builder: _homeScreenBuilder,
              ),
              (route) => false,
            );
          }
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

  /// Resets all temporary OTP state and stops active timers/listeners
  void resetOtpState() {
    clearOtp();
    _resendTimer?.cancel();
    _resendTimer = null;
    _canResend = false;
    _resendSeconds = 30;
    _otpError = null;
    _otpSent = false;
    _otpVerifying = false;
    _safeUnregisterListener();
    notifyListeners();
  }

  /// Cancels OTP verification and returns to login step
  /// Note: Keeps [_phoneNumber] intact so the user can edit their number
  void goBackToLogin() {
    _step = AuthStep.login;
    resetOtpState();
  }

  /// Completely resets all authentication provider state (phone, OTP, terms, errors, signup fields)
  /// Used upon logout and account deletion
  void resetAuthState({bool clearPhone = true}) {
    if (clearPhone) {
      _phoneNumber = '';
      _countryCode = '+91';
    }
    _errorMessage = null;
    _agreedToTerms = false;
    _isLoading = false;
    _selectedGenres.clear();
    _categoriesError = null;
    _name = '';
    _username = '';
    _avatarPath = null;
    _profileSaving = false;
    _profileError = null;
    _nameError = null;
    _usernameError = null;
    _step = AuthStep.login;
    resetOtpState();
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
    if (_step == AuthStep.profile || _profileSaving) {
      return;
    }
    _categoriesError = null;
    _step = AuthStep.profile;
    notifyListeners();
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/signup/profile'),
          builder: (context) => const ProfileSetupScreen(),
        ),
      ).then((_) {
        if (_step == AuthStep.profile) {
          _step = AuthStep.categories;
          notifyListeners();
        }
      });
    }
  }

  void goBackToOtp([BuildContext? context]) {
    _step = AuthStep.otp;
    _categoriesError = null;
    notifyListeners();
    if (context != null &&
        context.mounted &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
    if (_profileSaving) return;
    if (!_validateProfile()) return;

    _profileSaving = true;
    _profileError = null;
    notifyListeners();

    try {
      dio.FormData formData = dio.FormData.fromMap({
        'name': _name,
        'username': _username,
        'phone': _phoneNumber,
        'countryCode': _countryCode,
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
        ChatProvider? chatProvider;
        if (context.mounted) {
          chatProvider = _tryReadChatProvider(context);
        }
        await _persistAuthenticatedSession(userDetail, chatProvider);

        _profileSaving = false;
        _step = AuthStep.done;
        resetOtpState();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/home'),
              builder: _homeScreenBuilder,
            ),
            (route) => false,
          );
        }
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

  void goBackToCategories([BuildContext? context]) {
    _step = AuthStep.categories;
    _profileError = null;
    notifyListeners();
    if (context != null &&
        context.mounted &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ─── Cleanup ───────────────────────────────────────────────
  @override
  void dispose() {
    _resendTimer?.cancel();
    _safeUnregisterListener();
    super.dispose();
  }
}
