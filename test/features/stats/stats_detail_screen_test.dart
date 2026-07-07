import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/widgets/radar_chart_widget.dart';

class MockPlayerStatsRepository extends Fake implements PlayerStatsRepository {
  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
  }) async {
    final modeStats = {
      'ranked': {
        'squad': const GameModeStats(
          roundsPlayed: 10,
          wins: 2,
          top10s: 5,
          losses: 8,
          kills: 15,
          assists: 5,
          damageDealt: 2500.0,
          timeSurvived: 9000.0, // 9000s total -> 900s avg
          currentTier: {'tier': 'Gold', 'subTier': 'III'},
          currentRankPoint: 2200,
          bestTier: {'tier': 'Gold', 'subTier': 'I'},
          bestRankPoint: 2400,
          headshotKills: 3,
          longestKill: 350.0,
        ),
        'duo': const GameModeStats(
          roundsPlayed: 0,
          wins: 0,
          top10s: 0,
          losses: 0,
          kills: 0,
          assists: 0,
          damageDealt: 0,
          timeSurvived: 0,
          currentTier: null,
          currentRankPoint: 0,
          bestTier: null,
          bestRankPoint: 0,
          headshotKills: 0,
          longestKill: 0,
        ),
      },
      'normal': {
        'squad': const GameModeStats(
          roundsPlayed: 5,
          wins: 1,
          top10s: 2,
          losses: 4,
          kills: 8,
          assists: 2,
          damageDealt: 1200.0,
          timeSurvived: 4500.0,
          currentTier: null,
          currentRankPoint: 0,
          bestTier: null,
          bestRankPoint: 0,
          headshotKills: 2,
          longestKill: 200.0,
        ),
      }
    };

    final profile = PlayerStatsProfile(
      nickname: nickname,
      platform: platform,
      seasonId: 'division.bro.official.pc-2024-01',
      kd: 1.5,
      adr: 250.0,
      winRate: 20.0,
      averageRank: 5.0,
      roundsPlayed: 15,
      recentMatches: const ['match-1', 'match-2'],
      matchModes: const {'match-1': 'squad', 'match-2': 'squad'},
      seasonsList: const ['division.bro.official.pc-2024-01'],
      updatedAt: DateTime(2026, 7, 7, 12, 0, 0),
      modeStats: modeStats,
    );

    return PlayerStatsBundle(
      profile: profile,
      matches: const [
        MatchSummary(
          matchId: 'match-1',
          mapName: 'Erangel',
          gameMode: 'squad',
          kills: 3,
          damage: 450.0,
          rank: 1,
          isFallback: false,
        ),
        MatchSummary(
          matchId: 'match-2',
          mapName: 'Miramar',
          gameMode: 'squad',
          kills: 1,
          damage: 150.0,
          rank: 4,
          isFallback: false,
        ),
      ],
      summaryFallback: false,
    );
  }
}

void main() {
  testWidgets('StatsDetailScreen UI 개편 검증 - 탭 필터링, 레이더 차트, 티어 및 그리드', (WidgetTester tester) async {
    final mockRepo = MockPlayerStatsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'TestUser',
            platform: 'steam',
            repository: mockRepo,
          ),
        ),
      ),
    );

    // 로딩 대기
    await tester.pumpAndSettle();

    // 1. 큐 세그먼트 필터 및 모드 칩 렌더링 확인
    expect(find.text('경쟁전'), findsOneWidget);
    expect(find.text('일반전'), findsOneWidget);
    expect(find.text('스쿼드'), findsOneWidget);
    expect(find.text('듀오'), findsOneWidget);
    expect(find.text('솔로'), findsOneWidget);

    // 2. 경쟁전 기본 선택 상태에서 티어 정보 (Gold III) 및 랭크포인트 진척도 바 노출 확인
    expect(find.text('Gold III'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // 3. 레이더 차트 렌더링 확인
    expect(find.byType(RadarChartWidget), findsOneWidget);

    // 4. 확장된 6개 메트릭 그리드 항목 노출 확인 (KDA, ADR, 승률, 평균 생존 시간, Top 10, 헤드샷 비율)
    expect(find.text('KDA'), findsOneWidget);
    expect(find.text('평균 생존 시간'), findsOneWidget);
    expect(find.text('Top 10'), findsOneWidget);
    expect(find.text('헤드샷 비율'), findsOneWidget);

    // 5. 기록이 없는 '듀오' 모드 선택 시 Empty State 확인
    await tester.tap(find.text('듀오'));
    await tester.pumpAndSettle();

    expect(find.text('해당 모드 플레이 기록 없음'), findsOneWidget);
  });
}
