import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/theme/bgms_theme.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/widgets/match_card.dart';

void main() {
  group('MatchCard Tests', () {
    final sampleProfile = PlayerStatsProfile(
      nickname: 'TestPlayer',
      platform: 'steam',
      seasonId: 'division.bro.official.pc-2018-01',
      kd: 2.5,
      adr: 300.0,
      winRate: 15.0,
      averageRank: 8.5,
      roundsPlayed: 100,
      recentMatches: const ['match-1', 'match-2'],
      matchModes: const {'match-1': 'squad', 'match-2': 'squad'},
      seasonsList: const ['division.bro.official.pc-2018-01'],
      updatedAt: DateTime.now(),
      modeStats: const {},
    );

    testWidgets('치킨(#1) 매치는 승리 엠블럼과 골드 하이라이트를 표시한다', (tester) async {
      final chickenMatch = MatchSummary(
        matchId: 'match-1',
        mapName: 'Baltic_Main',
        gameMode: 'squad',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        rank: 1,
        kills: 7,
        damage: 850,
        timeSurvived: 1800,
        isFallback: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: Scaffold(
            body: MatchCard(match: chickenMatch, profile: sampleProfile),
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('에란겔'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.text('WIN'), findsOneWidget);
    });

    testWidgets('일반 순위 매치를 올바른 정보로 렌더링한다', (tester) async {
      final normalMatch = MatchSummary(
        matchId: 'match-2',
        mapName: 'Desert_Main',
        gameMode: 'squad',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        rank: 12,
        kills: 3,
        damage: 420,
        timeSurvived: 900,
        isFallback: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: Scaffold(
            body: MatchCard(match: normalMatch, profile: sampleProfile),
          ),
        ),
      );

      expect(find.text('#12'), findsOneWidget);
      expect(find.text('미라마'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('경기 정보 fallback은 분석 대기 대신 조회 불가와 시간 미확인을 표시한다', (tester) async {
      final missingMatch = MatchSummary.fallback(
        matchId: 'missing-match',
        gameMode: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: Scaffold(
            body: MatchCard(match: missingMatch, profile: sampleProfile),
          ),
        ),
      );

      expect(find.text('경기 정보 없음'), findsOneWidget);
      expect(find.text('경기 시간 확인 전'), findsOneWidget);
      expect(find.text('분석 대기'), findsNothing);
      expect(find.text('-'), findsNWidgets(3));
    });

    testWidgets('좁은 화면과 큰 글꼴에서 매치 카드가 넘치지 않는다', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 800);
        for (final rank in [1, 12]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: BgmsTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MatchCard(
                    profile: sampleProfile,
                    match: MatchSummary(
                      matchId: 'narrow-match',
                      mapName: 'Erangel',
                      gameMode: 'squad-fpp',
                      createdAt: DateTime.now().subtract(
                        const Duration(hours: 4),
                      ),
                      rank: rank,
                      kills: 12,
                      damage: 1234,
                      timeSurvived: 1800,
                      isFallback: false,
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('1234'), findsOneWidget);
        }
      }
    });
  });
}
