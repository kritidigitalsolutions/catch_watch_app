import 'dart:async';

import 'package:catch_watch/models/auth_models.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/repository/auth_repository.dart';
import 'package:catch_watch/utils/hive_service/userdetail.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/views/before_login_Pages/categories_screen.dart';
import 'package:catch_watch/views/before_login_Pages/login_screen.dart';
import 'package:catch_watch/views/before_login_Pages/otp_verify_screen.dart';
import 'package:catch_watch/views/before_login_Pages/profile_setup_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeSignupAuthRepository extends AuthRepository {
  int sendOtpCalls = 0;
  int verifyOtpCalls = 0;
  int completeProfileCalls = 0;
  FormData? lastCompleteProfileFormData;
  Completer<VerifyOtpResponse>? verifyOtpCompleter;
  Completer<CompleteProfileResponse>? completeProfileCompleter;

  SendOtpResponse sendOtpResponse = SendOtpResponse(
    success: true,
    message: 'OTP sent',
    isNewUser: true,
    otp: '482917',
  );

  VerifyOtpResponse verifyOtpResponse = VerifyOtpResponse(
    success: true,
    message: 'OTP verified',
    isNewUser: true,
    token: 'signup-jwt-token',
    user: UserModel(id: 'new-user-1', phone: '9876543210'),
  );

  CompleteProfileResponse completeProfileResponse = CompleteProfileResponse(
    success: true,
    message: 'Profile completed',
    token: 'signup-jwt-token',
    user: UserModel(
      id: 'new-user-1',
      phone: '9876543210',
      name: 'Aarav Sharma',
      username: 'aarav_sharma',
    ),
  );

  @override
  Future<SendOtpResponse> sendOtp(dynamic data) async {
    sendOtpCalls++;
    return sendOtpResponse;
  }

  @override
  Future<VerifyOtpResponse> verifyOtp(dynamic data) async {
    verifyOtpCalls++;
    if (verifyOtpCompleter != null) {
      return verifyOtpCompleter!.future;
    }
    return verifyOtpResponse;
  }

  @override
  Future<CompleteProfileResponse> completeProfile(FormData data) async {
    completeProfileCalls++;
    lastCompleteProfileFormData = data;
    if (completeProfileCompleter != null) {
      return completeProfileCompleter!.future;
    }
    return completeProfileResponse;
  }
}

class _DummyHomeScreen extends StatelessWidget {
  const _DummyHomeScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('HOME_SCREEN_REACHED'),
      ),
    );
  }
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

  group('Signup Back Navigation (CategoriesScreen & ProfileSetupScreen)', () {
    testWidgets(
      'AppBar back buttons on ProfileSetupScreen and CategoriesScreen pop routes once and sync AuthStep',
      (tester) async {
        final fakeRepo = FakeSignupAuthRepository();
        final auth = AuthProvider(
          authRepository: fakeRepo,
          isDebugMode: false,
          homeScreenBuilder: (_) => const _DummyHomeScreen(),
          onSessionPersisted: (_) async {},
        );
        addTearDown(auth.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: const MaterialApp(
              home: LoginScreen(),
            ),
          ),
        );

        // 1. LoginScreen -> OtpScreen
        await tester.enterText(find.byType(TextFormField), '9876543210');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(OtpScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.otp));

        // 2. OtpScreen -> CategoriesScreen
        for (int i = 0; i < 6; i++) {
          auth.setOtpDigit(i, '${i + 1}');
        }
        await auth.verifyOtp(tester.element(find.byType(OtpScreen)));
        await tester.pumpAndSettle();

        expect(find.byType(CategoriesScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.categories));

        // 3. Select a genre and proceed CategoriesScreen -> ProfileSetupScreen
        await tester.tap(find.text('Action'));
        await tester.pump();
        expect(auth.selectedGenres, contains('Action'));

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.profile));

        // 4. Tap AppBar Back button on ProfileSetupScreen -> pops back to CategoriesScreen
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(CategoriesScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.categories));
        expect(auth.selectedGenres, contains('Action'));

        // 5. User can proceed to ProfileSetupScreen again after going back
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.profile));

        // 6. Pop back to CategoriesScreen, then tap AppBar Back button on CategoriesScreen -> pops back to OtpScreen
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.byType(CategoriesScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CategoriesScreen), findsNothing);
        expect(find.byType(OtpScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.otp));

        auth.resetOtpState();
        await tester.pump();
      },
    );

    testWidgets(
      'System back navigation (Navigator.maybePop) on ProfileSetupScreen and CategoriesScreen syncs AuthStep without double-popping',
      (tester) async {
        final fakeRepo = FakeSignupAuthRepository();
        final auth = AuthProvider(
          authRepository: fakeRepo,
          isDebugMode: false,
          homeScreenBuilder: (_) => const _DummyHomeScreen(),
          onSessionPersisted: (_) async {},
        );
        addTearDown(auth.dispose);

        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              navigatorKey: navKey,
              home: const OtpScreen(),
            ),
          ),
        );

        for (int i = 0; i < 6; i++) {
          auth.setOtpDigit(i, '${i + 1}');
        }
        await auth.verifyOtp(navKey.currentContext!);
        await tester.pumpAndSettle();
        expect(find.byType(CategoriesScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.categories));

        auth.toggleGenre('Sci-Fi');
        auth.proceedFromCategories(navKey.currentContext!);
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.profile));

        // Trigger system pop from ProfileSetupScreen
        await navKey.currentState!.maybePop();
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(CategoriesScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.categories));

        // Trigger system pop from CategoriesScreen
        await navKey.currentState!.maybePop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CategoriesScreen), findsNothing);
        expect(find.byType(OtpScreen), findsOneWidget);
        expect(auth.step, equals(AuthStep.otp));
      },
    );
  });

  group('Duplicate Route Prevention & Complete Signup Stack Clearing', () {
    testWidgets(
      'prevents duplicate CategoriesScreen and ProfileSetupScreen pushes on concurrent/repeated triggers',
      (tester) async {
        final fakeRepo = FakeSignupAuthRepository()
          ..verifyOtpCompleter = Completer<VerifyOtpResponse>();
        final auth = AuthProvider(
          authRepository: fakeRepo,
          isDebugMode: false,
          homeScreenBuilder: (_) => const _DummyHomeScreen(),
          onSessionPersisted: (_) async {},
        );
        addTearDown(auth.dispose);

        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              navigatorKey: navKey,
              home: const OtpScreen(),
            ),
          ),
        );

        for (int i = 0; i < 6; i++) {
          auth.setOtpDigit(i, '${i + 1}');
        }

        // Trigger verifyOtp twice concurrently (e.g. Pinput.onCompleted + Verify button)
        final f1 = auth.verifyOtp(navKey.currentContext!);
        final f2 = auth.verifyOtp(navKey.currentContext!);

        fakeRepo.verifyOtpCompleter!.complete(fakeRepo.verifyOtpResponse);
        await Future.wait([f1, f2]);
        await tester.pumpAndSettle();

        expect(fakeRepo.verifyOtpCalls, equals(1));
        expect(find.byType(CategoriesScreen), findsOneWidget);

        // Select genre and call proceedFromCategories twice rapidly
        auth.toggleGenre('Drama');
        final categoriesContext = tester.element(find.byType(CategoriesScreen));
        auth.proceedFromCategories(categoriesContext);
        auth.proceedFromCategories(categoriesContext);
        await tester.pumpAndSettle();

        expect(find.byType(ProfileSetupScreen), findsOneWidget);

        // Popping once should return directly to CategoriesScreen (not a duplicate ProfileSetupScreen)
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(find.byType(CategoriesScreen), findsOneWidget);
      },
    );

    testWidgets(
      'successful signup navigates to Home via pushAndRemoveUntil and clears entire signup stack',
      (tester) async {
        final fakeRepo = FakeSignupAuthRepository();
        UserDetails? persistedUser;
        final auth = AuthProvider(
          authRepository: fakeRepo,
          isDebugMode: false,
          homeScreenBuilder: (_) => const _DummyHomeScreen(),
          onSessionPersisted: (user) async {
            persistedUser = user;
          },
        );
        addTearDown(auth.dispose);

        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              navigatorKey: navKey,
              home: const LoginScreen(),
            ),
          ),
        );

        // 1. LoginScreen -> OtpScreen
        await tester.enterText(find.byType(TextFormField), '9876543210');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(OtpScreen), findsOneWidget);

        // 2. OtpScreen -> CategoriesScreen
        for (int i = 0; i < 6; i++) {
          auth.setOtpDigit(i, '${i + 1}');
        }
        await auth.verifyOtp(tester.element(find.byType(OtpScreen)));
        await tester.pumpAndSettle();
        expect(find.byType(CategoriesScreen), findsOneWidget);

        // 3. Verify genre validation before selecting a genre
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(find.text('Please select at least one genre.'), findsOneWidget);
        expect(find.byType(ProfileSetupScreen), findsNothing);

        // Select genres and proceed to ProfileSetupScreen
        await tester.tap(find.text('Action'));
        await tester.tap(find.text('Thriller'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsOneWidget);

        // 4. Verify profile validation before entering name/username
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(find.text('Name is required.'), findsOneWidget);
        expect(find.text('Username is required.'), findsOneWidget);
        expect(fakeRepo.completeProfileCalls, equals(0));

        // 5. Fill valid name and username and complete signup
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'Aarav Sharma');
        await tester.enterText(textFields.at(1), 'aarav_sharma');
        await tester.pump();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(fakeRepo.completeProfileCalls, equals(1));
        expect(persistedUser, isNotNull);
        expect(persistedUser!.token, equals('signup-jwt-token'));
        expect(auth.step, equals(AuthStep.done));

        // Verify Home screen is displayed and all previous auth/signup routes are cleared
        expect(find.text('HOME_SCREEN_REACHED'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(OtpScreen), findsNothing);
        expect(find.byType(CategoriesScreen), findsNothing);
        expect(find.byType(ProfileSetupScreen), findsNothing);
        expect(navKey.currentState!.canPop(), isFalse);
      },
    );

    test('resetAuthState clears all stale signup fields on logout or account deletion', () {
      final auth = AuthProvider(
        authRepository: FakeSignupAuthRepository(),
        isDebugMode: false,
      );
      addTearDown(auth.dispose);

      auth.setCountryCode('+971');
      auth.setPhone('501234567');
      auth.toggleGenre('Action');
      auth.setName('Test Name');
      auth.setUsername('test_user');
      auth.setAvatarPath('/tmp/avatar.jpg');

      auth.resetAuthState(clearPhone: true);

      expect(auth.phoneNumber, isEmpty);
      expect(auth.countryCode, equals('+91'));
      expect(auth.selectedGenres, isEmpty);
      expect(auth.name, isEmpty);
      expect(auth.username, isEmpty);
      expect(auth.avatarPath, isNull);
      expect(auth.step, equals(AuthStep.login));
    });
  });
}
