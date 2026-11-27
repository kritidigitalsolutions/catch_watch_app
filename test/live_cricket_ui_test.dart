import 'package:catch_watch/models/live_match_model.dart';
import 'package:catch_watch/repository/live_cricket_repository.dart';
import 'package:catch_watch/utils/entitlement_helper.dart';
import 'package:catch_watch/view_model/after_login_provider/live_cricket_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/views/after_login_pages/cricket/live_match_list_screen.dart';
import 'package:catch_watch/views/after_login_pages/cricket/match_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/cricket/widgets/featured_match_card.dart';
import 'package:catch_watch/views/after_login_pages/cricket/widgets/live_match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeCricketRepo extends LiveCricketRepository {
  List<LiveMatchModel> fakeMatches = [];
  LiveMatchModel? fakeFeatured;

  @override
  Future<List<LiveMatchModel>> getLiveMatches({
    String? status,
    String? tournament,
    String? format,
    int? limit,
  }) async {
    if (status != null && status.isNotEmpty) {
      return fakeMatches.where((m) => m.rawStatus.toUpperCase() == status.toUpperCase()).toList();
    }
    return fakeMatches;
  }

  @override
  Future<LiveMatchModel?> getFeaturedLiveMatch() async => fakeFeatured;

  @override
  Future<LiveMatchModel?> getLiveMatchDetails(String matchId) async {
    return fakeMatches.firstWhere(
      (m) => m.id == matchId,
      orElse: () => fakeFeatured ?? fakeMatches.first,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleLiveMatch = LiveMatchModel.fromJson({
    'id': 'match-ui-1',
    'title': 'India vs Australia Super 8s',
    'series': 'ICC T20 World Cup 2026',
    'matchType': 'T20',
    'venue': 'Wankhede Stadium, Mumbai',
    'status': 'LIVE',
    'statusNote': 'India won the toss and elected to bat',
    'team1': {
      'name': 'India',
      'shortName': 'IND',
      'score': '186/4',
      'overs': '18.2',
    },
    'team2': {
      'name': 'Australia',
      'shortName': 'AUS',
      'score': 'Yet to bat',
    },
    'isFeatured': true,
    'isPremium': false,
    'viewerCount': 1400,
  });

  final sampleUpcomingMatch = LiveMatchModel.fromJson({
    'id': 'match-ui-2',
    'title': 'England vs South Africa',
    'series': 'T20 Series 2026',
    'matchType': 'T20',
    'status': 'UPCOMING',
    'team1': {'name': 'England', 'shortName': 'ENG'},
    'team2': {'name': 'South Africa', 'shortName': 'SA'},
    'startTime': '2026-11-20T19:30:00.000Z',
  });

  final sampleCompletedMatch = LiveMatchModel.fromJson({
    'id': 'match-ui-3',
    'title': 'Sri Lanka vs Bangladesh',
    'series': 'T20 Series 2026',
    'status': 'COMPLETED',
    'statusNote': 'Bangladesh won by 6 wickets',
    'team1': {'name': 'Sri Lanka', 'shortName': 'SL', 'score': '168/7'},
    'team2': {'name': 'Bangladesh', 'shortName': 'BAN', 'score': '172/4'},
  });

  group('FeaturedMatchCard Widget Tests', () {
    testWidgets('Renders featured match tournament, teams, score and LIVE badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeaturedMatchCard(match: sampleLiveMatch),
          ),
        ),
      );

      expect(find.text('ICC T20 World Cup 2026'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('IND'), findsOneWidget);
      expect(find.text('AUS'), findsOneWidget);
      expect(find.text('Watch Live'), findsOneWidget);
      expect(find.text('India won the toss and elected to bat'), findsOneWidget);
    });
  });

  group('LiveMatchCard Widget Tests', () {
    testWidgets('Renders live card with LIVE badge and scores', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMatchCard(match: sampleLiveMatch),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('IND'), findsOneWidget);
      expect(find.text('AUS'), findsOneWidget);
      expect(find.text('186/4'), findsOneWidget);
    });

    testWidgets('Renders upcoming card with Upcoming badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMatchCard(match: sampleUpcomingMatch),
          ),
        ),
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('ENG'), findsOneWidget);
      expect(find.text('SA'), findsOneWidget);
    });

    testWidgets('Renders completed card with Completed badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMatchCard(match: sampleCompletedMatch),
          ),
        ),
      );

      expect(find.text('✔ Completed'), findsOneWidget);
      expect(find.text('SL'), findsOneWidget);
      expect(find.text('BAN'), findsOneWidget);
      expect(find.text('Bangladesh won by 6 wickets'), findsOneWidget);
    });
  });

  group('LiveMatchListScreen Tests', () {
    testWidgets('Renders hero banner, segmented pill tabs, and match cards', (tester) async {
      final fakeRepo = FakeCricketRepo();
      fakeRepo.fakeMatches = [sampleLiveMatch, sampleUpcomingMatch, sampleCompletedMatch];
      final provider = LiveCricketProvider(repository: fakeRepo);

      await tester.pumpWidget(
        ChangeNotifierProvider<LiveCricketProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: LiveMatchListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Cricket')),
        findsWidgets,
      );
      expect(find.text('Watch Live Matches, Scores & Updates'), findsOneWidget);
      expect(find.textContaining('Live ('), findsOneWidget);
      expect(find.textContaining('Upcoming ('), findsOneWidget);
      expect(find.textContaining('Completed ('), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  });

  group('MatchDetailsScreen Tests', () {
    testWidgets('Renders match details, info pills and starts polling', (tester) async {
      final fakeRepo = FakeCricketRepo();
      fakeRepo.fakeMatches = [sampleLiveMatch];
      final provider = LiveCricketProvider(repository: fakeRepo);

      await tester.pumpWidget(
        ChangeNotifierProvider<LiveCricketProvider>.value(
          value: provider,
          child: MaterialApp(
            home: MatchDetailsScreen(
              matchId: sampleLiveMatch.id,
              initialMatch: sampleLiveMatch,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Match Summary'), findsOneWidget);
      expect(find.text('India won the toss and elected to bat'), findsWidgets);
      expect(find.text('Scorecard Overview'), findsOneWidget);
      expect(find.text('Watch Live'), findsOneWidget);
      expect(provider.isPollingActive, isTrue);

      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  });

  group('EntitlementHelper.canWatchLiveMatch Isolation Tests', () {
    testWidgets('Allows free live matches unconditionally', (tester) async {
      final freeMatch = sampleLiveMatch.copyWith(isPremium: false);
      final subProvider = SubscriptionProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: subProvider,
          child: Builder(
            builder: (context) {
              final allowed = EntitlementHelper.canWatchLiveMatch(context, freeMatch);
              expect(allowed, isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Blocks premium live match when subscription is null', (tester) async {
      final premiumMatch = sampleLiveMatch.copyWith(isPremium: true);
      final subProvider = SubscriptionProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: subProvider,
          child: Builder(
            builder: (context) {
              final allowed = EntitlementHelper.canWatchLiveMatch(context, premiumMatch);
              expect(allowed, isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
