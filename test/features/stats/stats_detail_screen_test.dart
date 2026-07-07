import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/widgets/radar_chart_widget.dart';

class MockPlayerStatsRepository extends Fake implements PlayerStatsRepository {
  bool lastRefresh = false;

  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
    lastRefresh = refresh;
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

    return SynchronousFuture(PlayerStatsBundle(
      profile: profile,
      matches: [
        MatchSummary(
          matchId: 'match-1',
          mapName: 'Erangel',
          gameMode: 'squad',
          kills: 3,
          damage: 450.0,
          rank: 1,
          isFallback: false,
          tier: const {'tier': 'Diamond', 'subTier': 'I'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        MatchSummary(
          matchId: 'match-2',
          mapName: 'Miramar',
          gameMode: 'squad',
          kills: 1,
          damage: 150.0,
          rank: 4,
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ],
      summaryFallback: false,
    ));
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

  testWidgets('StatsDetailScreen - 매치 리스트 아이템 UI 고도화 검증 (우승 하이라이트 및 티어 뱃지)', (WidgetTester tester) async {
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

    // 1. 우승(치킨) 카드 하이라이트 검증
    // rank == 1 일 때 'WINNER WINNER CHICKEN DINNER' 리본/텍스트가 표시되어야 함
    expect(find.text('WINNER WINNER CHICKEN DINNER'), findsOneWidget);

    // 2. 매치 티어 뱃지 검증
    // match-1 에는 Diamond I 이 부여되었으므로, Diamond I 텍스트가 화면에 존재해야 함
    expect(find.text('Diamond I'), findsOneWidget);

    // 3. 맵 배경 및 맵 종류 정보 노출 검증
    expect(find.textContaining('Erangel'), findsWidgets);
    expect(find.textContaining('Miramar'), findsWidgets);
  });

  testWidgets('StatsDetailScreen - 플레이어 변경 시 내부 필터 탭 초기화 검증 (ValueKey 테스트)', (WidgetTester tester) async {
    final mockRepo = MockPlayerStatsRepository();

    // 1. 처음 TestUser로 빌드
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
    await tester.pumpAndSettle();

    // 기본적으로 '스쿼드'가 선택되어 있으므로 Gold III 티어 노출됨
    expect(find.text('Gold III'), findsOneWidget);

    // 2. 모드를 '듀오'로 변경
    await tester.tap(find.text('듀오'));
    await tester.pumpAndSettle();

    // 듀오는 기록이 없으므로 '해당 모드 플레이 기록 없음'이 노출됨
    expect(find.text('해당 모드 플레이 기록 없음'), findsOneWidget);
    expect(find.text('Gold III'), findsNothing);

    // 3. 닉네임을 'TestUser2'로 변경하여 다시 pumpWidget 실행
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'TestUser2',
            platform: 'steam',
            repository: mockRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 닉네임이 변경되었을 때 key가 바르게 작동한다면,
    // _StatsContent의 State가 새로 생성되어 다시 기본 모드인 '스쿼드'가 선택되어야 함.
    // 따라서 다시 'Gold III' 티어가 노출되어야 하고, '해당 모드 플레이 기록 없음'은 사라져야 함.
    expect(find.text('Gold III'), findsOneWidget);
    expect(find.text('해당 모드 플레이 기록 없음'), findsNothing);
  });

  testWidgets('StatsDetailScreen - 매치 리스트 아이템 UI 경과 시간 표시 검증', (WidgetTester tester) async {
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

    // match-1의 경과 시간(5분 전) 표시 검증
    expect(find.text('5분 전'), findsOneWidget);

    // match-2의 경과 시간(3시간 전) 표시 검증
    expect(find.text('3시간 전'), findsOneWidget);
  });

  testWidgets('경쟁전 탭 진입 시 최근 매치 데이터 기반 생존시간, 탑텐율, 헤드샷이 합산 평균으로 보완 렌더링된다', (WidgetTester tester) async {
    final mockRepo = MockRankedStatsSupplementRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'SupplementUser',
            platform: 'steam',
            repository: mockRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 경쟁전 탭(기본선택)일 때: 최근 매치 기반 실시간 보완 통계 검증
    // 예상 평균 생존 시간: (1200 + 600) / 2 = 900초 -> 15분 0초
    // 예상 Top 10 진입률: 1 / 2 = 50.0%
    // 예상 헤드샷 비율: (1 + 0) / (3 + 1) = 25.0%
    expect(find.text('15분 0초'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);

    // 2. 일반전 탭으로 전환
    await tester.tap(find.text('일반전'));
    await tester.pumpAndSettle();

    // 일반전일 때는 PUBG API 제공 값을 그대로 사용
    // normal squad stats: roundsPlayed: 5, top10s: 2 (40.0%), kills: 8, headshotKills: 2 (25.0%), timeSurvived: 4500.0 (평균 900초 -> 15분 0초)
    // top10Rate: stats.top10Rate -> 2 / 5 = 40.0%
    expect(find.text('40.0%'), findsOneWidget);
  });

  testWidgets('StatsDetailScreen 새로고침 탭 시 refresh: true 인자로 레포지토리 호출 검증', (WidgetTester tester) async {
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

    await tester.pumpAndSettle();

    // 1. 처음엔 refresh = false 로 호출됨
    expect(mockRepo.lastRefresh, isFalse);

    // 2. 새로고침 아이콘 탭
    final refreshButton = find.byTooltip('새로고침');
    expect(refreshButton, findsOneWidget);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    // 3. refresh = true 로 다시 호출됨
    expect(mockRepo.lastRefresh, isTrue);
  });

  testWidgets('StatsDetailScreen - Miramar 맵코드 대소문자 믹스 매칭 및 그라데이션 검증', (WidgetTester tester) async {
    final mockRepo = MockMiramarMapNameStatsRepository();

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

    await tester.pumpAndSettle();

    final matchCards = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MatchCard');
    expect(matchCards, findsNWidgets(3));

    for (int i = 0; i < 3; i++) {
      final inkWellFinder = find.descendant(
        of: matchCards.at(i),
        matching: find.byType(InkWell),
      );
      final containerFinder = find.descendant(
        of: inkWellFinder,
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration?;
      final gradient = decoration?.gradient as LinearGradient?;
      expect(gradient, isNotNull);
      expect(gradient!.colors.first, equals(const Color(0xFF5A442E).withValues(alpha: 0.8)));
    }
  });
}

class MockMiramarMapNameStatsRepository extends Fake implements PlayerStatsRepository {
  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
    final modeStats = {
      'ranked': {
        'squad': const GameModeStats(
          roundsPlayed: 10,
          wins: 0,
          top10s: 5,
          losses: 8,
          kills: 15,
          assists: 5,
          damageDealt: 2500.0,
          timeSurvived: 9000.0,
          currentTier: {'tier': 'Gold', 'subTier': 'III'},
          currentRankPoint: 2200,
          bestTier: {'tier': 'Gold', 'subTier': 'I'},
          bestRankPoint: 2400,
          headshotKills: 3,
          longestKill: 350.0,
        ),
      },
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
      recentMatches: const ['match-1', 'match-2', 'match-3'],
      matchModes: const {'match-1': 'squad', 'match-2': 'squad', 'match-3': 'squad'},
      seasonsList: const ['division.bro.official.pc-2024-01'],
      updatedAt: DateTime(2026, 7, 7, 12, 0, 0),
      modeStats: modeStats,
    );

    return SynchronousFuture(PlayerStatsBundle(
      profile: profile,
      matches: [
        MatchSummary(
          matchId: 'match-1',
          mapName: 'Desert_Main',
          gameMode: 'squad',
          kills: 3,
          damage: 450.0,
          rank: 5,
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        MatchSummary(
          matchId: 'match-2',
          mapName: 'desert_main',
          gameMode: 'squad',
          kills: 1,
          damage: 150.0,
          rank: 15,
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        MatchSummary(
          matchId: 'match-3',
          mapName: 'Miramar',
          gameMode: 'squad',
          kills: 5,
          damage: 500.0,
          rank: 2,
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ],
      summaryFallback: false,
    ));
  }
}

class MockRankedStatsSupplementRepository extends Fake implements PlayerStatsRepository {
  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
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
          timeSurvived: 9000.0,
          currentTier: {'tier': 'Gold', 'subTier': 'III'},
          currentRankPoint: 2200,
          bestTier: {'tier': 'Gold', 'subTier': 'I'},
          bestRankPoint: 2400,
          headshotKills: 3,
          longestKill: 350.0,
        ),
      },
      'normal': {
        'squad': const GameModeStats(
          roundsPlayed: 5,
          wins: 1,
          top10s: 2, // 2 / 5 -> 40.0%
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
      recentMatches: const ['match-1', 'match-2', 'match-3'],
      matchModes: const {'match-1': 'squad', 'match-2': 'squad', 'match-3': 'squad'},
      seasonsList: const ['division.bro.official.pc-2024-01'],
      updatedAt: DateTime(2026, 7, 7, 12, 0, 0),
      modeStats: modeStats,
    );

    return SynchronousFuture(PlayerStatsBundle(
      profile: profile,
      matches: [
        MatchSummary(
          matchId: 'match-1',
          mapName: 'Erangel',
          gameMode: 'squad',
          kills: 3,
          damage: 450.0,
          rank: 5, // Top 10
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          headshotKills: 1,
          timeSurvived: 1200.0, // 20 min
        ),
        MatchSummary(
          matchId: 'match-2',
          mapName: 'Miramar',
          gameMode: 'squad',
          kills: 1,
          damage: 150.0,
          rank: 15, // Not Top 10
          isFallback: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          headshotKills: 0,
          timeSurvived: 600.0, // 10 min
        ),
        MatchSummary(
          matchId: 'match-3',
          mapName: 'Sanhok',
          gameMode: 'squad',
          kills: 5,
          damage: 500.0,
          rank: 2,
          isFallback: true, // fallback -> 제외됨
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          headshotKills: 2,
          timeSurvived: 900.0,
        ),
      ],
      summaryFallback: false,
    ));
  }
}
