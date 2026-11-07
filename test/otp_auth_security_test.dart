import 'package:catch_watch/data/network/api_network_service.dart';
import 'package:catch_watch/models/auth_models.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/views/before_login_Pages/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAuthRepository extends AuthRepository {
  Map<String, dynamic>? lastSendOtpPayload;
  Map<String, dynamic>? lastVerifyOtpPayload;
  FormData? lastCompleteProfileFormData;
  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;

  SendOtpResponse sendOtpResponse = SendOtpResponse(
    success: true,
    message: 'OTP sent successfully',
    isNewUser: true,
    otp: '482917',
  );

  VerifyOtpResponse verifyOtpResponse = VerifyOtpResponse(
    success: true,
    message: 'OTP verified',
    isNewUser: true,
    token: 'test-jwt-token',
    user: UserModel(id: 'u1', phone: '501234567', name: 'Test User'),
  );

  CompleteProfileResponse completeProfileResponse = CompleteProfileResponse(
    success: true,
    message: 'Profile completed',
    token: 'test-jwt-token',
    user: UserModel(id: 'u1', phone: '501234567', name: 'Test User'),
  );

  @override
  Future<SendOtpResponse> sendOtp(dynamic data) async {
    sendOtpCallCount++;
    if (data is Map) {
      lastSendOtpPayload = Map<String, dynamic>.from(data);
    }
    return sendOtpResponse;
  }

  @override
  Future<VerifyOtpResponse> verifyOtp(dynamic data) async {
    verifyOtpCallCount++;
    if (data is Map) {
      lastVerifyOtpPayload = Map<String, dynamic>.from(data);
    }
    return verifyOtpResponse;
  }

  @override
  Future<CompleteProfileResponse> completeProfile(FormData data) async {
    lastCompleteProfileFormData = data;
    return completeProfileResponse;
  }
}

Widget _buildTestLoginApp(AuthProvider authProvider) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: const MaterialApp(
      home: LoginScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel smsAutofillChannel = MethodChannel('sms_autofill');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsAutofillChannel, (MethodCall call) async {
      if (call.method == 'getAppSignature') {
        return 'test-signature';
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsAutofillChannel, null);
  });

  group('Country Code Selection & Normalization', () {
    test('defaults to +91 and normalizes country codes consistently', () {
      final auth = AuthProvider(
        authRepository: FakeAuthRepository(),
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      expect(auth.countryCode, equals('+91'));

      auth.setCountryCode('+1');
      expect(auth.countryCode, equals('+1'));

      auth.setCountryCode('971');
      expect(auth.countryCode, equals('+971'));

      auth.setCountryCode(' +44 ');
      expect(auth.countryCode, equals('+44'));

      auth.setCountryCode('');
      expect(auth.countryCode, equals('+91'));
    });

    test('includes selected countryCode and phone in sendOtp and verifyOtp payloads', () {
      final fakeRepo = FakeAuthRepository();
      final auth = AuthProvider(
        authRepository: fakeRepo,
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      auth.setCountryCode('+971');
      auth.setPhone('501234567');
      auth.toggleTerms(true);

      expect(
        auth.buildSendOtpPayload(),
        equals(<String, dynamic>{
          'phone': '501234567',
          'countryCode': '+971',
        }),
      );

      expect(
        auth.buildVerifyOtpPayload('654321'),
        equals(<String, dynamic>{
          'phone': '501234567',
          'countryCode': '+971',
          'otp': '654321',
        }),
      );
    });
  });

  group('International Phone Number Validation (9-10 Digits & Country Rules)', () {
    test('enforces 10-digit numbers for India (+91) and USA (+1)', () {
      for (final code in ['+91', '+1']) {
        expect(AuthProvider.isValidPhoneForCountry('987654321', code), isFalse,
            reason: '9-digit number should be rejected for $code');
        expect(AuthProvider.isValidPhoneForCountry('9876543210', code), isTrue,
            reason: '10-digit number should be accepted for $code');
        expect(AuthProvider.isValidPhoneForCountry('98765432101', code), isFalse,
            reason: '11-digit number should be rejected for $code');
      }
    });

    test('supports 9-digit and 10-digit local mobile numbers for UAE (+971), Australia (+61), and UK (+44)', () {
      // UAE 9-digit (501234567) & 10-digit with trunk 0 (0501234567)
      expect(AuthProvider.isValidPhoneForCountry('501234567', '+971'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('0501234567', '+971'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('50123456', '+971'), isFalse);

      // Australia 9-digit (412345678) & 10-digit with trunk 0 (0412345678)
      expect(AuthProvider.isValidPhoneForCountry('412345678', '+61'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('0412345678', '+61'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('41234567', '+61'), isFalse);

      // UK 9-digit & 10-digit
      expect(AuthProvider.isValidPhoneForCountry('791112345', '+44'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('7911123456', '+44'), isTrue);
      expect(AuthProvider.isValidPhoneForCountry('79111234', '+44'), isFalse);
    });

    test('rejects non-numeric characters and empty phone numbers across all country codes', () {
      expect(AuthProvider.isValidPhoneForCountry('', '+91'), isFalse);
      expect(AuthProvider.isValidPhoneForCountry('98765abcde', '+91'), isFalse);
      expect(AuthProvider.isValidPhoneForCountry('501-234-567', '+971'), isFalse);
    });

    testWidgets('LoginScreen allows selecting +971 (UAE) and submitting a valid 9-digit phone number', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final auth = AuthProvider(
        authRepository: fakeRepo,
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(_buildTestLoginApp(auth));

      // Initially +91 is selected; a 9-digit number should fail validation
      await tester.enterText(find.byType(TextFormField), '501234567');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(fakeRepo.sendOtpCallCount, equals(0));
      expect(find.text('Please enter a valid 10-digit mobile number.'), findsOneWidget);

      // Open country code picker and select UAE (+971)
      await tester.tap(find.text('+91'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+971'));
      await tester.pumpAndSettle();

      expect(auth.countryCode, equals('+971'));
      expect(auth.errorMessage, isNull);

      // Tap Continue with the 9-digit UAE number
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeRepo.sendOtpCallCount, equals(1));
      expect(
        fakeRepo.lastSendOtpPayload,
        equals(<String, dynamic>{
          'phone': '501234567',
          'countryCode': '+971',
        }),
      );

      auth.resetOtpState();
      await tester.pump();
    });

    testWidgets('verifyOtp sends matching countryCode, phone, and 6-digit OTP to backend', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final auth = AuthProvider(
        authRepository: fakeRepo,
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      auth.setCountryCode('+61');
      auth.setPhone('412345678');
      for (int i = 0; i < 6; i++) {
        auth.setOtpDigit(i, '${i + 1}');
      }

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );

      await auth.verifyOtp(capturedContext);
      await tester.pump();

      expect(fakeRepo.verifyOtpCallCount, equals(1));
      expect(
        fakeRepo.lastVerifyOtpPayload,
        equals(<String, dynamic>{
          'phone': '412345678',
          'countryCode': '+61',
          'otp': '123456',
        }),
      );
    });
  });

  group('OTP Security: SnackBar Visibility & Log Redaction', () {
    test('shouldShowOtpInUi suppresses OTP in production mode and when OTP is null/empty', () {
      expect(
        AuthProvider.shouldShowOtpInUi('654321', isDebugMode: false),
        isFalse,
      );
      expect(
        AuthProvider.shouldShowOtpInUi(null, isDebugMode: true),
        isFalse,
      );
      expect(
        AuthProvider.shouldShowOtpInUi('   ', isDebugMode: true),
        isFalse,
      );
      expect(
        AuthProvider.shouldShowOtpInUi('654321', isDebugMode: true),
        isTrue,
      );
    });

    testWidgets('does NOT expose OTP in SnackBar when isDebugMode is false (production)', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final auth = AuthProvider(
        authRepository: fakeRepo,
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(_buildTestLoginApp(auth));

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeRepo.sendOtpCallCount, equals(1));
      expect(find.textContaining('Your OTP is:'), findsNothing);
      expect(find.textContaining('482917'), findsNothing);

      auth.resetOtpState();
      await tester.pump();
    });

    testWidgets('shows debug OTP SnackBar ONLY when isDebugMode is true', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final auth = AuthProvider(
        authRepository: fakeRepo,
        isDebugMode: true,
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(_buildTestLoginApp(auth));

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeRepo.sendOtpCallCount, equals(1));
      expect(find.text('Your OTP is: 482917'), findsOneWidget);

      auth.resetOtpState();
      await tester.pump();
    });

    test('NetworkApiService.sanitizeDataForLogs redacts OTP fields from request and response logs', () {
      final rawPayload = <String, dynamic>{
        'phone': '9876543210',
        'countryCode': '+91',
        'otp': '654321',
        'nested': <String, dynamic>{
          'OTP': '999999',
          'token': 'secret-jwt',
        },
      };

      final sanitized =
          NetworkApiService.sanitizeDataForLogs(rawPayload) as Map<String, dynamic>;

      expect(sanitized['phone'], equals('9876543210'));
      expect(sanitized['countryCode'], equals('+91'));
      expect(sanitized['otp'], equals('[REDACTED]'));
      final nested = sanitized['nested'] as Map<String, dynamic>;
      expect(nested['OTP'], equals('[REDACTED]'));
      expect(nested['token'], equals('[REDACTED]'));
    });
  });
}
