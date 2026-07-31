import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실제 서버 응답을 재현한다. KangHeeSung_ 계정은 4경기 모두 squad다.
class _SingleModeRepository extends Fake implements PlayerStatsRepository {
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
          roundsPlayed: 4,
          recentMatches: const ['m1', 'm2', 'm3', 'm4'],
          matchModes: const {
            'm1': 'squad',
            'm2': 'squad',
            'm3': 'squad',
            'm4': 'squad',
          },
          seasonsList: const ['division.bro.official.pc-2018-42'],
          updatedAt: DateTime(2026, 8, 1),
          modeStats: const {},
        ),
        matches: [
          for (var i = 1; i <= 4; i++)
            MatchSummary(
              matchId: 'm$i',
              mapName: '태이고',
              mapId: null,
              gameMode: 'squad',
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

  testWidgets('모드가 한 종류여도 매치 카드가 모두 렌더링된다', (tester) async {
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

    // 모드가 하나뿐이면 필터 칩을 노출하지 않는다.
    expect(find.widgetWithText(ChoiceChip, '전체'), findsNothing);

    // 매치 카드가 실제로 트리에 존재해야 한다.
    final cards = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_MatchCard',
    );
    expect(cards, findsNWidgets(4));
  });
}
