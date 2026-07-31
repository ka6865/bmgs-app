import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MatchSummary _match({
  required String matchId,
  required String gameMode,
  required String mapName,
  int kills = 1,
  int? rank = 12,
}) {
  return MatchSummary(
    matchId: matchId,
    mapName: mapName,
    mapId: null,
    gameMode: gameMode,
    kills: kills,
    damage: 120,
    rank: rank,
    isFallback: false,
    tier: null,
    createdAt: DateTime.now(),
    headshotKills: 0,
    timeSurvived: 600,
  );
}

/// 여러 모드가 섞인 매치 목록을 주는 Fake.
class _MixedModeRepository extends Fake implements PlayerStatsRepository {
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
          seasonId: 'division.bro.official.pc-2024-01',
          kd: 1.5,
          adr: 250,
          winRate: 10,
          averageRank: 12,
          roundsPlayed: 3,
          recentMatches: const ['m1', 'm2', 'm3'],
          matchModes: const {},
          seasonsList: const ['division.bro.official.pc-2024-01'],
          updatedAt: DateTime(2026, 8, 1),
          modeStats: const {},
        ),
        matches: [
          _match(matchId: 'm1', gameMode: 'squad', mapName: '에란겔'),
          _match(matchId: 'm2', gameMode: 'duo-fpp', mapName: '태이고'),
          _match(matchId: 'm3', gameMode: 'solo', mapName: '사녹'),
        ],
        summaryFallback: false,
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'TestUser',
            platform: 'steam',
            repository: _MixedModeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('매치 리스트는 기본으로 모든 모드를 보여준다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('3경기'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
  });

  group('MatchModeFilters', () {
    final matches = [
      _match(matchId: 'm1', gameMode: 'squad', mapName: '에란겔'),
      _match(matchId: 'm2', gameMode: 'duo-fpp', mapName: '태이고'),
      _match(matchId: 'm3', gameMode: 'solo', mapName: '사녹'),
      _match(matchId: 'm4', gameMode: 'squad-fpp', mapName: '론도'),
    ];

    test('fpp가 붙은 모드도 같은 그룹으로 묶는다', () {
      expect(MatchModeFilters.normalize('squad-fpp'), 'squad');
      expect(MatchModeFilters.normalize('duo-fpp'), 'duo');
      expect(MatchModeFilters.normalize('SOLO-FPP'), 'solo');
    });

    test('알 수 없는 모드는 null이다', () {
      expect(MatchModeFilters.normalize('분석 대기'), isNull);
      expect(MatchModeFilters.normalize(''), isNull);
    });

    test('존재하는 모드만 정해진 순서로 노출한다', () {
      expect(MatchModeFilters.availableModes(matches), [
        'solo',
        'duo',
        'squad',
      ]);
      expect(MatchModeFilters.availableModes([matches.first]), ['squad']);
    });

    test('all은 전체를, 특정 모드는 해당 매치만 남긴다', () {
      expect(MatchModeFilters.apply(matches, 'all').length, 4);
      expect(MatchModeFilters.apply(matches, 'squad').length, 2);
      expect(MatchModeFilters.apply(matches, 'duo').single.matchId, 'm2');
      expect(MatchModeFilters.apply(matches, 'solo').single.matchId, 'm3');
    });
  });
}
