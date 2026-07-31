import 'package:bgms_mobile_app/features/stats/all_matches_screen.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MatchSummary _match({
  required String matchId,
  required String gameMode,
  String mapName = '태이고',
}) {
  return MatchSummary(
    matchId: matchId,
    mapName: mapName,
    mapId: null,
    gameMode: gameMode,
    kills: 2,
    damage: 180,
    rank: 12,
    isFallback: false,
    tier: null,
    createdAt: DateTime(2026, 8, 1),
    headshotKills: 0,
    timeSurvived: 700,
  );
}

PlayerStatsProfile _profile() {
  return PlayerStatsProfile(
    nickname: 'KangHeeSung_',
    platform: 'steam',
    seasonId: 'division.bro.official.pc-2018-42',
    kd: 1.2,
    adr: 200,
    winRate: 5,
    averageRank: 14,
    roundsPlayed: 6,
    recentMatches: const [],
    matchModes: const {},
    seasonsList: const ['division.bro.official.pc-2018-42'],
    updatedAt: DateTime(2026, 8, 1),
    modeStats: const {},
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<MatchSummary> matches, {
    bool summaryFallback = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AllMatchesScreen(
          matches: matches,
          profile: _profile(),
          summaryFallback: summaryFallback,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('전체 매치를 기본으로 모두 보여준다', (tester) async {
    await pump(tester, [
      _match(matchId: 'm1', gameMode: 'squad'),
      _match(matchId: 'm2', gameMode: 'duo-fpp'),
      _match(matchId: 'm3', gameMode: 'solo'),
    ]);

    expect(find.text('전체 매치'), findsOneWidget);
    expect(find.text('KangHeeSung_'), findsOneWidget);
    expect(find.text('3경기'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(3));
    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
  });

  testWidgets('모드 필터를 고르면 해당 모드만 남는다', (tester) async {
    await pump(tester, [
      _match(matchId: 'm1', gameMode: 'squad'),
      _match(matchId: 'm2', gameMode: 'duo-fpp'),
      _match(matchId: 'm3', gameMode: 'solo'),
      _match(matchId: 'm4', gameMode: 'squad-fpp'),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, '스쿼드'));
    await tester.pumpAndSettle();

    // squad와 squad-fpp가 같은 그룹으로 묶인다.
    expect(find.byType(MatchCard), findsNWidgets(2));
    expect(find.text('2경기 / 전체 4경기'), findsOneWidget);
  });

  testWidgets('모드가 한 종류면 필터를 노출하지 않는다', (tester) async {
    await pump(tester, [
      _match(matchId: 'm1', gameMode: 'squad'),
      _match(matchId: 'm2', gameMode: 'squad-fpp'),
    ]);

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(MatchCard), findsNWidgets(2));
  });

  testWidgets('매치가 없으면 빈 상태를 보여준다', (tester) async {
    await pump(tester, const []);

    expect(find.textContaining('최근 매치가 없거나'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('일부 미분석 상태를 알린다', (tester) async {
    await pump(tester, [
      _match(matchId: 'm1', gameMode: 'squad'),
    ], summaryFallback: true);

    expect(find.textContaining('서버 분석이 끝나지 않아'), findsOneWidget);
  });
}
