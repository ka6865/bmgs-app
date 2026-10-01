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
  }

  testWidgets('필터 없이 모든 매치 카드를 렌더링한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'KangHeeSung_',
            platform: 'steam',
            repository: _SingleModeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

    // 상단 지표용 모드 칩(솔로/듀오/스쿼드) 3개만 있고,
    // 매치 리스트를 좁히는 '전체' 칩은 없다.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.widgetWithText(ChoiceChip, '전체'), findsNothing);
  });

  testWidgets('전체 보기 버튼으로 전체 매치 화면을 연다', (tester) async {
    await pump(
      tester,
      _SingleModeRepository(
        modes: const ['squad', 'duo-fpp', 'solo', 'squad-fpp', 'duo', 'solo'],
      ),
    );

    // 미리보기는 5건까지만 노출하고 나머지는 전체 보기로 넘긴다.
    expect(find.byType(MatchCard), findsNWidgets(5));

    final button = find.textContaining('전체 보기');
    expect(button, findsOneWidget);
    // 버튼이 화면 아래에 있어 스크롤로 노출한 뒤 누른다.
    await tester.scrollUntilVisible(
      button,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // 전체 매치 화면으로 이동해 6건과 모드 필터가 보인다.
    expect(find.text('전체 매치'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(6));
    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
  });
}
