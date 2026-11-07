import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/models/watchlist_model.dart';
import 'package:catch_watch/utils/entitlement_helper.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_search_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/watchlist_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/wish_list_screen.dart';
import 'package:catch_watch/views/after_login_pages/search_screen.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class MockSubscriptionProvider extends SubscriptionProvider {
  List<Plan> _mockPlans = [];
  SubscriptionData? _mockSub;
  int? _mockDays;
  int fetchStatusCallCount = 0;

  void setSubscription(SubscriptionData? sub, {int? days}) {
    _mockSub = sub;
    _mockDays = days;
    notifyListeners();
  }

  @override
  List<Plan> get plans => _mockPlans;

  @override
  SubscriptionData? get currentSubscription => _mockSub;

  @override
  int? get remainingDays => _mockDays;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchPlans() async {
    _mockPlans = [
      Plan(
        id: 'plan_monthly',
        name: 'Monthly Premium',
        price: 199,
        duration: 30,
        planType: 'monthly',
        isActive: true,
      ),
    ];
    notifyListeners();
  }

  @override
  Future<bool> fetchSubscriptionStatus({int? expectedMinLevel}) async {
    fetchStatusCallCount++;
    return true;
  }
}

class MockProfileProvider extends ProfileProvider {
  @override
  Future<void> fetchProfile({bool forceRefresh = false}) async {}
}

class MockHomeScreenProvider extends HomeScreenProvider {
  List<Content> _content = [];

  @override
  List<Content> get allContent => _content;

  void setAllContent(List<Content> c) {
    _content = c;
    notifyListeners();
  }
}

class MockWatchlistProvider extends WatchlistProvider {
  List<WatchlistItem> _mockItems = [];

  @override
  List<WatchlistItem> get items => _mockItems;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchWatchlist() async {}

  void setItems(List<WatchlistItem> items) {
    _mockItems = items;
    notifyListeners();
  }
}

class FakeReelsProvider extends ReelsProvider {
  @override
  Future<void> searchReels(String query) async {}

  @override
  void clearSearch() {}
}

class FakeUserSearchProvider extends UserSearchProvider {
  @override
  Future<void> searchUsers(String query) async {}

  @override
  void clearSearch() {}
}

class FakeCallProvider extends CallProvider {
  @override
  CallStatus get status => CallStatus.idle;
}

Widget createFullTestApp({
  required MockSubscriptionProvider subscriptionProvider,
  required MockProfileProvider profileProvider,
  MockHomeScreenProvider? homeProvider,
  MockWatchlistProvider? watchlistProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subscriptionProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ChangeNotifierProvider<HomeScreenProvider>.value(
        value: homeProvider ?? MockHomeScreenProvider(),
      ),
      ChangeNotifierProvider<WatchlistProvider>.value(
        value: watchlistProvider ?? MockWatchlistProvider(),
      ),
      ChangeNotifierProvider<ReelsProvider>.value(value: FakeReelsProvider()),
      ChangeNotifierProvider<UserSearchProvider>.value(value: FakeUserSearchProvider()),
      ChangeNotifierProvider<CallProvider>.value(value: FakeCallProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('SubscriptionScreen Navigation Tests', () {
    late MockSubscriptionProvider subProvider;
    late MockProfileProvider profProvider;

    setUp(() {
      subProvider = MockSubscriptionProvider();
      profProvider = MockProfileProvider();
    });

    testWidgets('exiting via back button without purchase returns null (not true)',
        (WidgetTester tester) async {
      bool? purchaseResult;

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  purchaseResult = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  );
                },
                child: const Text('Open Subscription'),
              ),
            ),
          ),
        ),
      );

      // Tap to open subscription screen
      await tester.tap(find.text('Open Subscription'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a Plan'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Verify we returned to root and purchaseResult is null (did not return true)
      expect(find.text('Open Subscription'), findsOneWidget);
      expect(purchaseResult, isNull);
    });

    testWidgets('caller awaiting subscription proceeds only when true is returned',
        (WidgetTester tester) async {
      bool videoOpened = false;

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final content = Content(id: 'c1', isPremium: true);
                  if (!EntitlementHelper.canWatch(context, content)) {
                    final subscribed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                    if (subscribed == true) {
                      videoOpened = true;
                    }
                  }
                },
                child: const Text('Watch Premium Video'),
              ),
            ),
          ),
        ),
      );

      // Tap watch premium video
      await tester.tap(find.text('Watch Premium Video'));
      await tester.pumpAndSettle();

      // Screen is showing SubscriptionScreen
      expect(find.text('Choose a Plan'), findsOneWidget);

      // Simulate back without purchase
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Verify video was not opened
      expect(videoOpened, isFalse);
    });

    testWidgets('successful purchase popup Done button pops screen with true and only pops once',
        (WidgetTester tester) async {
      bool? purchaseResult;

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    purchaseResult = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  child: const Text('Open Subscription'),
                ),
              );
            },
          ),
        ),
      );

      // 1. Open SubscriptionScreen
      await tester.tap(find.text('Open Subscription'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a Plan'), findsOneWidget);

      // 2. Trigger verified success popup via test hook
      final stateFinder = find.byType(SubscriptionScreen);
      expect(stateFinder, findsOneWidget);
      final dynamic state = tester.state(stateFinder);
      state.showSuccessPopupForTesting();
      await tester.pumpAndSettle();

      // 3. Verify success dialog is shown
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('Your Premium subscription is now active.'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // 4. Tap 'Done' button
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 5. Verify the dialog is dismissed and SubscriptionScreen is popped
      expect(find.text('Payment Successful!'), findsNothing);
      expect(find.text('Choose a Plan'), findsNothing);
      expect(find.text('Open Subscription'), findsOneWidget);

      // 6. Verify SubscriptionScreen returned true
      expect(purchaseResult, isTrue);

      // 7. Verify screen popped only once (root scaffold is still displayed and not popped)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('EntitlementHelper.openContent Unified Navigation Tests', () {
    late MockSubscriptionProvider subProvider;
    late MockProfileProvider profProvider;

    setUp(() {
      subProvider = MockSubscriptionProvider();
      profProvider = MockProfileProvider();
    });

    testWidgets('free content directly opens MovieDetailScreen without SubscriptionScreen',
        (WidgetTester tester) async {
      final freeMovie = Content(id: 'free_1', title: 'Free Movie', isPremium: false);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EntitlementHelper.openContent(context, freeMovie),
                child: const Text('Open Free Movie'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Free Movie'));
      await tester.pumpAndSettle();

      // Directly opened MovieDetailScreen without SubscriptionScreen
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
    });

    testWidgets('entitled premium content directly opens MovieDetailScreen without SubscriptionScreen',
        (WidgetTester tester) async {
      subProvider.setSubscription(
        SubscriptionData(status: 'active', endDate: DateTime.now().add(const Duration(days: 30)).toIso8601String()),
        days: 30,
      );
      final premiumMovie = Content(id: 'prem_1', title: 'Premium Movie', isPremium: true);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EntitlementHelper.openContent(context, premiumMovie),
                child: const Text('Open Premium Movie'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Premium Movie'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
    });

    testWidgets('free short film directly opens ShortVideoPlayerScreen',
        (WidgetTester tester) async {
      final shortFilm = Content(
        id: 'short_1',
        title: 'Short Film',
        type: 'shortFilm',
        isPremium: false,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EntitlementHelper.openContent(context, shortFilm),
                child: const Text('Open Short'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Short'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(ShortVideoPlayerScreen), findsOneWidget);
    });

    testWidgets('locked movie intercepts navigation and pushes SubscriptionScreen',
        (WidgetTester tester) async {
      final lockedMovie = Content(id: 'locked_1', title: 'Locked Movie', isPremium: true);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EntitlementHelper.openContent(context, lockedMovie),
                child: const Text('Open Locked Movie'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Locked Movie'));
      await tester.pumpAndSettle();

      // Intercepted and pushed SubscriptionScreen
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);

      // Dismiss subscription screen without purchase
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Returned to root, MovieDetailScreen was NOT opened
      expect(find.text('Open Locked Movie'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
    });

    testWidgets('locked movie opens MovieDetailScreen after successful subscription purchase',
        (WidgetTester tester) async {
      final lockedMovie = Content(id: 'locked_1', title: 'Locked Movie', isPremium: true);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EntitlementHelper.openContent(context, lockedMovie),
                child: const Text('Open Locked Movie'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Locked Movie'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionScreen), findsOneWidget);

      // Simulate purchase success in SubscriptionProvider
      subProvider.setSubscription(
        SubscriptionData(status: 'active', endDate: DateTime.now().add(const Duration(days: 30)).toIso8601String()),
        days: 30,
      );

      // Trigger verified success popup in SubscriptionScreen
      final dynamic subState = tester.state(find.byType(SubscriptionScreen));
      subState.showSuccessPopupForTesting();
      await tester.pumpAndSettle();

      // Tap 'Done'
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // After purchase, fetchSubscriptionStatus was called and user navigated to MovieDetailScreen!
      expect(subProvider.fetchStatusCallCount, greaterThan(0));
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
    });
  });

  group('MovieDetailScreen Centralized Entitlement Gate Tests', () {
    late MockSubscriptionProvider subProvider;
    late MockProfileProvider profProvider;

    setUp(() {
      subProvider = MockSubscriptionProvider();
      profProvider = MockProfileProvider();
    });

    testWidgets('directly opening MovieDetailScreen with locked content displays locked paywall view, NOT embedded SubscriptionScreen',
        (WidgetTester tester) async {
      final lockedMovie = Content(id: 'direct_locked', title: 'Direct Locked Movie', isPremium: true);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: MovieDetailScreen(content: lockedMovie),
        ),
      );

      await tester.pumpAndSettle();

      // Verifies that SubscriptionScreen is NOT embedded inside MovieDetailScreen
      expect(find.byType(SubscriptionScreen), findsNothing);

      // Verifies that the locked paywall view is displayed
      expect(find.text('Direct Locked Movie'), findsAtLeastNWidgets(1));
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('Premium Subscription Required'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Subscribe to Watch'), findsOneWidget);
    });

    testWidgets('tapping Subscribe to Watch in locked view pushes SubscriptionScreen as modal route',
        (WidgetTester tester) async {
      final lockedMovie = Content(id: 'direct_locked', title: 'Direct Locked Movie', isPremium: true);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          child: MovieDetailScreen(content: lockedMovie),
        ),
      );

      await tester.pumpAndSettle();

      final subscribeBtn = find.widgetWithText(ElevatedButton, 'Subscribe to Watch');
      expect(subscribeBtn, findsOneWidget);

      // Ensure button is visible before tap
      await tester.ensureVisible(subscribeBtn);
      await tester.pumpAndSettle();

      // Tap Subscribe to Watch
      await tester.tap(subscribeBtn);
      await tester.pumpAndSettle();

      // Pushed SubscriptionScreen
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.text('Choose a Plan'), findsOneWidget);

      // Back button on SubscriptionScreen returns to the locked MovieDetailScreen
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.text('Subscribe to Watch'), findsOneWidget);
    });
  });

  group('SearchScreen Premium Entitlement Navigation Tests', () {
    late MockSubscriptionProvider subProvider;
    late MockProfileProvider profProvider;
    late MockHomeScreenProvider homeProvider;

    setUp(() {
      subProvider = MockSubscriptionProvider();
      profProvider = MockProfileProvider();
      homeProvider = MockHomeScreenProvider();
    });

    testWidgets('tapping free movie result opens MovieDetailScreen',
        (WidgetTester tester) async {
      homeProvider.setAllContent([
        Content(id: 's_free', title: 'Search Free Movie', isPremium: false),
      ]);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          homeProvider: homeProvider,
          child: const SearchScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final movieItem = find.text('Search Free Movie');
      expect(movieItem, findsOneWidget);

      await tester.tap(movieItem);
      await tester.pumpAndSettle();

      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.byType(SubscriptionScreen), findsNothing);
    });

    testWidgets('tapping locked movie result intercepts and pushes SubscriptionScreen',
        (WidgetTester tester) async {
      homeProvider.setAllContent([
        Content(id: 's_locked', title: 'Search Locked Movie', isPremium: true),
      ]);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          homeProvider: homeProvider,
          child: const SearchScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final movieItem = find.text('Search Locked Movie');
      expect(movieItem, findsOneWidget);

      await tester.tap(movieItem);
      await tester.pumpAndSettle();

      // Intercepted by SubscriptionScreen
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);

      // Cancel subscription
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Stays on SearchScreen
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
    });
  });

  group('WishListScreen Premium Entitlement Navigation Tests', () {
    late MockSubscriptionProvider subProvider;
    late MockProfileProvider profProvider;
    late MockWatchlistProvider watchlistProvider;

    setUp(() {
      subProvider = MockSubscriptionProvider();
      profProvider = MockProfileProvider();
      watchlistProvider = MockWatchlistProvider();
    });

    testWidgets('tapping card for free movie in wishlist opens MovieDetailScreen',
        (WidgetTester tester) async {
      watchlistProvider.setItems([
        WatchlistItem(
          id: 'w_1',
          item: Content(id: 'w_free', title: 'Wishlist Free Movie', isPremium: false),
        ),
      ]);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          watchlistProvider: watchlistProvider,
          child: const WishListScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final itemFinder = find.text('Wishlist Free Movie');
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.byType(SubscriptionScreen), findsNothing);
    });

    testWidgets('tapping card for locked movie in wishlist pushes SubscriptionScreen',
        (WidgetTester tester) async {
      watchlistProvider.setItems([
        WatchlistItem(
          id: 'w_2',
          item: Content(id: 'w_locked', title: 'Wishlist Locked Movie', isPremium: true),
        ),
      ]);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          watchlistProvider: watchlistProvider,
          child: const WishListScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final itemFinder = find.text('Wishlist Locked Movie');
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pumpAndSettle();

      // Intercepted and pushed SubscriptionScreen
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);

      // Back button returns to Wishlist
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(WishListScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
    });

    testWidgets('tapping play button for locked movie in wishlist pushes SubscriptionScreen',
        (WidgetTester tester) async {
      watchlistProvider.setItems([
        WatchlistItem(
          id: 'w_3',
          item: Content(id: 'w_locked_play', title: 'Wishlist Play Movie', isPremium: true),
        ),
      ]);

      await tester.pumpWidget(
        createFullTestApp(
          subscriptionProvider: subProvider,
          profileProvider: profProvider,
          watchlistProvider: watchlistProvider,
          child: const WishListScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final playIconFinder = find.byIcon(Icons.play_arrow_rounded);
      expect(playIconFinder, findsOneWidget);

      await tester.tap(playIconFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
    });
  });
}
