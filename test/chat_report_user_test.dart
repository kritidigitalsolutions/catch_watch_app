import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:catch_watch/data/network/base_api_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/repository/report_repository.dart';
import 'package:catch_watch/res/appUrl.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/report_provider.dart';
import 'package:catch_watch/views/after_login_pages/message/chat_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/message/chat_screen.dart';
import 'package:catch_watch/views/after_login_pages/report/report_bottom_sheet.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class MockApiService implements BaseApiService {
  dynamic responseData;
  Exception? exceptionToThrow;
  String? lastUrl;
  dynamic lastData;
  int callCount = 0;
  Completer<dynamic>? hangCompleter;

  @override
  Future<dynamic> postApi(String url, dynamic data) async {
    callCount++;
    lastUrl = url;
    lastData = data;
    if (hangCompleter != null) {
      return hangCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseData;
  }

  @override
  Future<dynamic> getApi(String url) async => responseData;

  @override
  Future<dynamic> patchApi(String url, dynamic data) async => responseData;

  @override
  Future<dynamic> putApi(String url, dynamic data) async => responseData;

  @override
  Future<dynamic> deleteApi(String url, dynamic data) async => responseData;
}

class FakeChatProvider extends ChatProvider {
  FakeChatProvider() : super(autoInit: false);

  final List<MessageModel> _mockMessages = [];

  void setMockMessages(List<MessageModel> msgs) {
    _mockMessages.clear();
    _mockMessages.addAll(msgs);
  }

  @override
  List<MessageModel> get messages => _mockMessages;

  @override
  bool isBlockedByMe(String userId) => false;

  @override
  bool isMuted(String conversationId) => false;

  @override
  Future<void> fetchMessages(String conversationId, {bool refresh = false, int page = 1}) async {}

  @override
  Future<void> fetchPinnedMessages(String conversationId) async {}

  @override
  Future<void> fetchUserStatus(String partnerId) async {}

  @override
  Future<void> fetchBlockedUsers() async {}

  @override
  void setActiveConversation(String? conversationId, [String? partnerId]) {}

  @override
  void clearReplyingMessage() {}
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HiveService.debugMockIsLogin = true;
    HiveService.debugMockUserId = 'reporter_user_id_100';
  });

  tearDown(() {
    HiveService.debugMockIsLogin = null;
    HiveService.debugMockUserId = null;
  });

  group('ReportRepository Unit Tests', () {
    test('submitReport sends correct URL and JSON payload', () async {
      final mockApi = MockApiService();
      mockApi.responseData = {
        'success': true,
        'message': 'Report submitted successfully.',
        'report': {
          '_id': 'rep_123',
          'reporter': 'reporter_user_id_100',
          'reportedUser': 'partner_user_456',
          'targetType': 'user',
          'targetId': 'partner_user_456',
          'reason': 'HARASSMENT',
          'description': 'Target sent inappropriate messages',
          'status': 'pending',
        }
      };

      final repository = ReportRepository(apiService: mockApi);
      final response = await repository.submitReport(
        targetType: 'user',
        targetId: '  partner_user_456  ',
        reason: '  HARASSMENT  ',
        description: '  Target sent inappropriate messages  ',
      );

      expect(mockApi.callCount, 1);
      expect(mockApi.lastUrl, AppUrl.reports);
      expect(mockApi.lastData, {
        'targetType': 'user',
        'targetId': 'partner_user_456',
        'reason': 'HARASSMENT',
        'description': 'Target sent inappropriate messages',
      });
      expect(response.success, isTrue);
      expect(response.message, 'Report submitted successfully.');
      expect(response.report?.targetId, 'partner_user_456');
    });

    test('submitReport omits description key when null or empty', () async {
      final mockApi = MockApiService();
      mockApi.responseData = {'success': true, 'message': 'OK'};

      final repository = ReportRepository(apiService: mockApi);
      await repository.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'SPAM',
        description: '   ',
      );

      expect(mockApi.lastData, {
        'targetType': 'user',
        'targetId': 'partner_user_456',
        'reason': 'SPAM',
      });
      expect(mockApi.lastData.containsKey('description'), isFalse);
    });

    test('submitReport throws ArgumentError when targetId is empty', () async {
      final mockApi = MockApiService();
      final repository = ReportRepository(apiService: mockApi);

      expect(
        () => repository.submitReport(
          targetType: 'user',
          targetId: '   ',
          reason: 'SPAM',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(mockApi.callCount, 0);
    });
  });

  group('ReportProvider Unit Tests', () {
    test('submitReport succeeds and updates provider state', () async {
      final mockApi = MockApiService();
      mockApi.responseData = {
        'success': true,
        'message': 'Report received.',
      };
      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      expect(provider.isSubmitting, isFalse);
      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'HARASSMENT',
        description: 'Inappropriate chat behavior',
      );

      expect(response, isNotNull);
      expect(response!.success, isTrue);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.lastResponse, isNotNull);
    });

    test('submitReport rejects unauthenticated user', () async {
      HiveService.debugMockIsLogin = false;
      final mockApi = MockApiService();
      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'HARASSMENT',
      );

      expect(response, isNull);
      expect(provider.errorMessage, 'You need to be logged in to submit a report.');
      expect(mockApi.callCount, 0);
    });

    test('submitReport prevents user from reporting their own profile', () async {
      HiveService.debugMockUserId = 'self_user_789';
      final mockApi = MockApiService();
      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'self_user_789',
        reason: 'HARASSMENT',
      );

      expect(response, isNull);
      expect(provider.errorMessage, 'You cannot report your own profile.');
      expect(mockApi.callCount, 0);
    });

    test('submitReport rejects empty reason', () async {
      final mockApi = MockApiService();
      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: '   ',
      );

      expect(response, isNull);
      expect(provider.errorMessage, 'Please select a reason for reporting.');
      expect(mockApi.callCount, 0);
    });

    test('submitReport rejects empty targetId', () async {
      final mockApi = MockApiService();
      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: '   ',
        reason: 'SPAM',
      );

      expect(response, isNull);
      expect(provider.errorMessage, 'Invalid target item identifier.');
      expect(mockApi.callCount, 0);
    });

    test('submitReport prevents duplicate in-flight submissions', () async {
      final mockApi = MockApiService();
      final completer = Completer<dynamic>();
      mockApi.hangCompleter = completer;

      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      // Start first call (will pause in completer)
      final future1 = provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'SPAM',
      );

      expect(provider.isSubmitting, isTrue);

      // Attempt duplicate call while first is in-flight
      final future2 = provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'SPAM',
      );

      final result2 = await future2;
      expect(result2, isNull);
      expect(mockApi.callCount, 1, reason: 'Duplicate call should be ignored while in-flight');

      // Finish first call
      completer.complete({'success': true, 'message': 'Report received.'});
      final result1 = await future1;
      expect(result1?.success, isTrue);
      expect(provider.isSubmitting, isFalse);
    });

    test('submitReport handles AppException gracefully', () async {
      final mockApi = MockApiService();
      mockApi.exceptionToThrow = BadRequestException('You have already reported this user.');

      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'HARASSMENT',
      );

      expect(response, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, 'You have already reported this user.');
    });

    test('submitReport handles generic Network failure', () async {
      final mockApi = MockApiService();
      mockApi.exceptionToThrow = Exception('Network connection timed out');

      final repository = ReportRepository(apiService: mockApi);
      final provider = ReportProvider(repository: repository);

      final response = await provider.submitReport(
        targetType: 'user',
        targetId: 'partner_user_456',
        reason: 'HARASSMENT',
      );

      expect(response, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, contains('Network connection timed out'));
    });
  });

  group('ChatDetailsScreen Report User Widget Tests', () {
    testWidgets('renders Report User tile and triggers ReportBottomSheet', (tester) async {
      final mockApi = MockApiService();
      mockApi.responseData = {'success': true, 'message': 'Reported'};
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));
      final fakeChatProvider = FakeChatProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: fakeChatProvider),
          ],
          child: const MaterialApp(
            home: ChatDetailsScreen(
              partnerId: 'partner_123',
              name: 'Alice Wonder',
              username: 'alice',
              image: '',
              conversationId: 'conv_123',
            ),
          ),
        ),
      );

      // Verify "Report User" ListTile is displayed
      final reportTileFinder = find.widgetWithText(ListTile, 'Report User');
      expect(reportTileFinder, findsOneWidget);
      expect(find.text('Report @alice for inappropriate content, abuse, or spam'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      // Tap "Report User" tile
      await tester.tap(reportTileFinder);
      await tester.pumpAndSettle();

      // Verify ReportBottomSheet has opened
      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('Report Alice Wonder'), findsOneWidget);
      expect(find.text('Reason for reporting'), findsOneWidget);
      expect(find.text('Harassment'), findsOneWidget);
      expect(find.text('Spam'), findsOneWidget);
    });

    testWidgets('PopupMenuButton includes Report User action', (tester) async {
      final mockApi = MockApiService();
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));
      final fakeChatProvider = FakeChatProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: fakeChatProvider),
          ],
          child: const MaterialApp(
            home: ChatDetailsScreen(
              partnerId: 'partner_123',
              name: 'Alice Wonder',
              username: 'alice',
              image: '',
              conversationId: 'conv_123',
            ),
          ),
        ),
      );

      // Tap the top-right more_vert icon to open PopupMenu
      final menuButtonFinder = find.byIcon(Icons.more_vert);
      expect(menuButtonFinder, findsOneWidget);
      await tester.tap(menuButtonFinder);
      await tester.pumpAndSettle();

      // Verify "Report User" menu item is present
      final reportMenuItem = find.widgetWithText(PopupMenuItem<String>, 'Report User');
      expect(reportMenuItem, findsOneWidget);

      // Tap "Report User" menu item
      await tester.tap(reportMenuItem);
      await tester.pumpAndSettle();

      // Verify ReportBottomSheet opens
      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('Report Alice Wonder'), findsOneWidget);
    });
  });

  group('ChatScreen Report User and Message Widget Tests', () {
    testWidgets('ChatScreen options menu includes Report User action', (tester) async {
      final mockApi = MockApiService();
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));
      final fakeChatProvider = FakeChatProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: fakeChatProvider),
          ],
          child: const MaterialApp(
            home: ChatScreen(
              partnerId: 'partner_123',
              conversationId: 'conv_123',
              name: 'Alice Wonder',
              username: 'alice',
              image: '',
            ),
          ),
        ),
      );

      await tester.pump();

      // In ChatScreen AppBar, find the options/more/info button
      final infoIconFinder = find.byIcon(Icons.info_outline);
      expect(infoIconFinder, findsOneWidget);

      // Tap info icon to show chat options bottom sheet
      await tester.tap(infoIconFinder);
      await tester.pumpAndSettle();

      // Verify options contain Delete Chat, Block User, and Report User
      expect(find.text('Delete Chat'), findsOneWidget);
      expect(find.text('Block User'), findsOneWidget);
      final reportOption = find.text('Report User');
      expect(reportOption, findsOneWidget);

      // Tap Report User
      await tester.tap(reportOption);
      await tester.pumpAndSettle();

      // Verify ReportBottomSheet opens with partner details
      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('Report Alice Wonder'), findsOneWidget);
    });

    testWidgets('Long-pressing incoming message includes Report Message action', (tester) async {
      final mockApi = MockApiService();
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));
      final fakeChatProvider = FakeChatProvider();

      final incomingMessage = MessageModel(
        sId: 'msg_999',
        sender: Sender(sId: 'partner_123', name: 'Alice Wonder'),
        text: 'Suspicious incoming chat message',
        messageType: 'text',
        createdAt: DateTime.now().toIso8601String(),
      );

      fakeChatProvider.setMockMessages([incomingMessage]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
            ChangeNotifierProvider<ChatProvider>.value(value: fakeChatProvider),
          ],
          child: const MaterialApp(
            home: ChatScreen(
              partnerId: 'partner_123',
              conversationId: 'conv_123',
              name: 'Alice Wonder',
              username: 'alice',
              image: '',
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the message text
      final messageFinder = find.text('Suspicious incoming chat message');
      expect(messageFinder, findsOneWidget);

      // Long press the message to open message actions
      await tester.longPress(messageFinder);
      await tester.pumpAndSettle();

      // Verify "Report Message" action is present
      final reportMsgAction = find.text('Report Message');
      expect(reportMsgAction, findsOneWidget);

      // Tap Report Message
      await tester.tap(reportMsgAction);
      await tester.pumpAndSettle();

      // Verify ReportBottomSheet opens
      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('Report Alice Wonder'), findsOneWidget);
    });
  });

  group('ReportBottomSheet Submission Flow & Error Handling', () {
    testWidgets('Selecting reason and submitting shows success and closes bottom sheet', (tester) async {
      final mockApi = MockApiService();
      mockApi.responseData = {
        'success': true,
        'message': 'Report submitted successfully.',
      };
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));

      await tester.pumpWidget(
        ChangeNotifierProvider<ReportProvider>.value(
          value: reportProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showReportBottomSheet(
                        ctx,
                        targetType: 'user',
                        targetId: 'partner_123',
                        targetTitle: 'Report Alice Wonder',
                      );
                    },
                    child: const Text('Open Report'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportBottomSheet), findsOneWidget);

      // Verify submit button is disabled before selecting a reason
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);
      expect(mockApi.callCount, 0);

      // Select 'Harassment'
      final harassmentOption = find.text('Harassment');
      await tester.ensureVisible(harassmentOption);
      await tester.tap(harassmentOption);
      await tester.pumpAndSettle();

      // Submit button is now enabled
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNotNull);

      // Enter optional description
      final descField = find.byType(TextField);
      await tester.ensureVisible(descField);
      await tester.enterText(descField, 'User sent insulting messages');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify API was called with expected arguments
      expect(mockApi.callCount, 1);
      expect(mockApi.lastData['targetType'], 'user');
      expect(mockApi.lastData['targetId'], 'partner_123');
      expect(mockApi.lastData['reason'], 'HARASSMENT');
      expect(mockApi.lastData['description'], 'User sent insulting messages');

      // Verify bottom sheet dismissed
      expect(find.byType(ReportBottomSheet), findsNothing);
    });

    testWidgets('API error displays inline error message and keeps sheet open for retry', (tester) async {
      final mockApi = MockApiService();
      mockApi.exceptionToThrow = BadRequestException('User has already been reported.');
      final reportProvider = ReportProvider(repository: ReportRepository(apiService: mockApi));

      await tester.pumpWidget(
        ChangeNotifierProvider<ReportProvider>.value(
          value: reportProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showReportBottomSheet(
                        ctx,
                        targetType: 'user',
                        targetId: 'partner_123',
                        targetTitle: 'Report Alice Wonder',
                      );
                    },
                    child: const Text('Open Report'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      // Select 'Spam'
      final spamOption = find.text('Spam');
      await tester.ensureVisible(spamOption);
      await tester.tap(spamOption);
      await tester.pumpAndSettle();

      // Tap submit
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Bottom sheet stays open and shows error message
      expect(find.byType(ReportBottomSheet), findsOneWidget);
      expect(find.text('User has already been reported.'), findsOneWidget);
    });
  });
}
