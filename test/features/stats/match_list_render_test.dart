import 'package:bgms_mobile_app/features/stats/player_match_history_models.dart';
import 'package:bgms_mobile_app/features/stats/player_match_history_repository.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:bgms_mobile_app/features/stats/widgets/match_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실제 서버 응답을 재현한다. KangHeeSung_ 계정은 4경기 모두 squad다.
class _SingleModeRepository extends Fake implements PlayerStatsRepository {
  _SingleModeRepository({
    this.modes = const ['squad', 'squad', 'squad', 'squad'],
  });

  /// 각 매치의 게임 모드. 모드가 섞인 경우를 재현할 때 쓴다.
  final List<String> modes;

  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
    bool includeSummaries = true,
    int summaryLimit = 20,
  }) {
    return SynchronousFuture(
      PlayerStatsBundle(
        profile: PlayerStatsProfile(
          nickname: nickname,
          platform: platform,
          seasonId: 'division.bro.official.pc-2018-42',
          kd: 1.2,
          adr: 180,
          winRate: 0,
          averageRank: 17,
          roundsPlayed: modes.length,
          recentMatches: [for (var i = 1; i <= modes.length; i++) 'm$i'],
          matchModes: {
            for (var i = 1; i <= modes.length; i++) 'm$i': modes[i - 1],
          },
          seasonsList: const ['division.bro.official.pc-2018-42'],
          updatedAt: DateTime(2026, 8, 1),
          modeStats: const {},
        ),
        matches: [
          for (var i = 1; i <= modes.length; i++)
            MatchSummary(
              matchId: 'm$i',
              mapName: '태이고',
              mapId: null,
              gameMode: modes[i - 1],
              kills: i,
              damage: 100.0 * i,
              rank: 10 + i,
              isFallback: false,
              tier: null,
              createdAt: DateTime(2026, 8, 1),
              headshotKills: 0,
              timeSurvived: 600,
            ),
        ],
        summaryFallback: false,
      ),
    );
  }
}

class _HistoryRepository extends PlayerMatchHistoryRepository {
  final requestedPages = <int>[];
  final requestedFilters = <String>[];

  @override
  Future<PlayerMatchHistoryPage> fetchPage({
    required String nickname,
    required String platform,
    int page = 1,
    String filter = 'all',
  }) async {
    requestedPages.add(page);
    requestedFilters.add(filter);
    return PlayerMatchHistoryPage.fromJson({
      'page': page,
      'totalPages': 2,
      'totalCount': 3,
      'matches': [
        for (final id in page == 1 ? ['db-1', 'db-2'] : ['db-3'])
          {
            'match_id': id,
            'map_name': 'Baltic_Main',
            'game_mode': 'squad',
            'kills': 2,
            'damage': 150,
            'win_place': 5,
          },
      ],
      'performanceSummaries': {
        'db-1': {'deathPhase': 4},
      },
    });
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester,
    _SingleModeRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'KangHeeSung_',
            platform: 'steam',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('매치'));
    await tester.pumpAndSettle();
  }

  testWidgets('필터 없이 모든 매치 카드를 렌더링한다', (tester) async {
    await pump(tester, _SingleModeRepository());

    expect(find.text('최근 매치'), findsOneWidget);
    expect(find.text('4경기'), findsOneWidget);

    // 매치 리스트에는 모드 필터를 두지 않는다. 항상 전체를 보여준다.
    expect(find.widgetWithText(ChoiceChip, '전체'), findsNothing);

    // 매치 카드가 실제로 트리에 존재해야 한다.
    final cards = find.byType(MatchCard);
    expect(cards, findsNWidgets(4));
  });

  testWidgets('모드가 섞여 있어도 상단 큐/모드 선택과 무관하게 전부 보여준다', (tester) async {
    // 상단 지표 필터 기본값은 경쟁전/스쿼드지만, 리스트는 솔로와 듀오도 남긴다.
    await pump(
      tester,
      _SingleModeRepository(
        modes: const ['squad', 'duo-fpp', 'solo', 'squad-fpp', 'duo'],
      ),
    );

    expect(find.text('5경기'), findsOneWidget);

    final cards = find.byType(MatchCard);
    expect(cards, findsNWidgets(5));

    // 매치 구역에는 시즌 지표용 모드 칩도, 목록을 좁히는 칩도 없다.
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '전체'), findsNothing);
  });

  testWidgets('매치 탭은 DB 저장 경기를 20경기씩 더 불러온다', (tester) async {
    final history = _HistoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'KangHeeSung_',
            platform: 'steam',
            repository: _SingleModeRepository(),
            historyRepository: history,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('전체 매치'), findsOneWidget);
    expect(find.text('총 3경기'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(2));
    final more = find.text('20경기 더 보기 (2/3)');
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(history.requestedPages, [1, 2]);
    expect(find.byType(MatchCard, skipOffstage: false), findsNWidgets(3));
    expect(find.textContaining('더 보기 ('), findsNothing);
  });

  test('DB 경기 이력은 분석 요약의 사망 페이즈를 붙인다', () {
    final page = PlayerMatchHistoryPage.fromJson({
      'matches': [
        {'match_id': 'a', 'win_place': 3},
        {'match_id': 'b', 'win_place': 9},
      ],
      'performanceSummaries': {
        'a': {'deathPhase': 6},
      },
    });
    expect(page.matches.first.deathPhase, 6);
    expect(page.matches.last.deathPhase, isNull);
  });

  testWidgets('매치 탭 상단 필터는 서버에 다시 요청해 첫 페이지부터 보여준다', (tester) async {
    final history = _HistoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'KangHeeSung_',
            platform: 'steam',
            repository: _SingleModeRepository(),
            historyRepository: history,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ranked = find.widgetWithText(ChoiceChip, '경쟁전');
    await tester.ensureVisible(ranked);
    await tester.tap(ranked);
    await tester.pumpAndSettle();

    expect(history.requestedFilters, ['all', 'ranked']);
    expect(history.requestedPages, [1, 1]);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '경쟁전'))
          .selected,
      isTrue,
    );
  });
}
