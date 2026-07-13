import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/rankings/ranking_models.dart';
import 'package:bgms_mobile_app/features/stats/ai_coaching_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlayerStatsProfile calculates core metrics from player API shape', () {
    final profile = PlayerStatsProfile.fromJson({
      'nickname': 'KangHeeSung_',
      'platform': 'steam',
      'seasonId': 'division.bro.official.pc-2018-31',
      'updatedAt': '2026-07-05T12:00:00.000Z',
      'stats': {
        'ranked': {
          'squad': {
            'roundsPlayed': 10,
            'wins': 2,
            'losses': 8,
            'kills': 24,
            'damageDealt': 3000,
            'rankPoints': 45,
          },
        },
        'normal': {
          'squad': {
            'roundsPlayed': 5,
            'wins': 1,
            'losses': 4,
            'kills': 6,
            'damageDealt': 900,
            'rankPoints': 30,
          },
        },
      },
      'recentMatches': ['match-1', 'match-2'],
      'matchModes': {'match-1': 'squad-fpp'},
    });

    expect(profile.nickname, 'KangHeeSung_');
    expect(profile.kd, closeTo(2.5, 0.01));
    expect(profile.adr, 260);
    expect(profile.winRate, 20);
    expect(profile.averageRank, 5);
    expect(profile.recentMatches, ['match-1', 'match-2']);
  });

  test('MatchSummary parses common summary fields with fallback values', () {
    final summary = MatchSummary.fromJson('match-1', {
      'matchInfo': {
        'mapName': '에란겔',
        'mode': 'squad-fpp',
        'date': '2026-07-06T15:30:00.000Z',
      },
      'player': {'kills': 3, 'damageDealt': 450.5, 'winPlace': 4},
      'timeSurvived': 1234.5,
    });

    expect(summary.mapName, '에란겔');
    expect(summary.gameMode, 'squad-fpp');
    expect(summary.kills, 3);
    expect(summary.damage, 450.5);
    expect(summary.rank, 4);
    expect(summary.isFallback, isFalse);
    expect(summary.createdAt, DateTime.parse('2026-07-06T15:30:00.000Z'));
    expect(summary.timeSurvived, 1234.5);
  });

  test('AiCoachingSummary parses normal NDJSON final response', () {
    final summary = AiCoachingSummary.fromNdjson(
      '{"type":"delta","data":"draft"}\n'
      '{"type":"final","data":"최종 요약"}',
    );

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, '최종 요약');
  });

  test('AiCoachingSummary ignores broken NDJSON lines before final', () {
    final summary = AiCoachingSummary.fromNdjson(
      'not-json\n{"type":"final","data":"복구된 요약"}',
    );

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, '복구된 요약');
  });

  test('AiCoachingSummary accepts plain text response safely', () {
    final summary = AiCoachingSummary.fromNdjson('plain text summary');

    expect(summary.status, AiCoachingStatus.available);
    expect(summary.summary, 'plain text summary');
  });

  test('AiCoachingSummary marks empty response unavailable', () {
    final summary = AiCoachingSummary.fromNdjson('   ');

    expect(summary.status, AiCoachingStatus.unavailable);
  });

  test('AiCoachingSummary parses restricted statuses from json', () {
    final login = AiCoachingSummary.fromJson({
      'status': 'loginRequired',
      'summary': '로그인이 필요합니다',
    });
    final cost = AiCoachingSummary.fromJson({
      'status': 'costRestricted',
      'summary': '사용량 제한',
    });

    expect(login.status, AiCoachingStatus.loginRequired);
    expect(cost.status, AiCoachingStatus.costRestricted);
  });

  test(
    'RankingBoard parses api entries and marks empty response unavailable',
    () {
      const query = RankingQuery(tab: 'damage');
      final board = RankingBoard.fromJson({
        'entries': [
          {
            'rank': 1,
            'nickname': 'Player',
            'platform': 'steam',
            'damage': 312.4,
          },
        ],
      }, query: query);
      final unavailable = RankingBoard.fromJson({'entries': []}, query: query);

      expect(board.source, RankingSource.api);
      expect(board.entries.single.nickname, 'Player');
      expect(board.entries.single.value, 312.4);
      expect(board.displaySourceLabel, '최신 랭킹');
      expect(board.displayMessage, contains('최근 경기'));
      expect(unavailable.source, RankingSource.unavailable);
      expect(unavailable.entries, isEmpty);
      expect(unavailable.displaySourceLabel, '준비 중');
      expect(unavailable.displayMessage, contains('필터'));
    },
  );

  test('MapMarkerLayer parses markers and exposes empty error state', () {
    final layer = MapMarkerLayer.fromJson({
      'markers': [
        {
          'id': 'garage-1',
          'label': '차량',
          'layer': 'Garage',
          'x': 0.25,
          'y': 0.75,
        },
      ],
    }, mapId: 'Erangel');
    final unavailable = MapMarkerLayer.fromJson({
      'markers': [],
    }, mapId: 'Erangel');

    expect(layer.source, MapMarkerSource.api);
    expect(layer.displaySourceLabel, '마커 연동');
    expect(layer.displayMessage, contains('전술 마커'));
    expect(layer.markers.single.layer, 'Garage');
    expect(layer.markers.single.source, MapMarkerSource.api);
    expect(layer.markers.single.x, 0.25);
    expect(layer.markers.single.y, 0.75);
    expect(unavailable.source, MapMarkerSource.fallback);
    expect(unavailable.markers, isEmpty);
    expect(unavailable.displaySourceLabel, '마커 준비 중');
    expect(unavailable.displayMessage, contains('다른 맵'));
  });

  test(
    'PlayerStatsProfile parses separate ranked and normal stats for each mode',
    () {
      final mockJson = {
        'nickname': 'TestPlayer',
        'platform': 'steam',
        'seasonId': 'pc-2026-01',
        'seasonsList': ['pc-2026-01'],
        'stats': {
          'ranked': {
            'squad': {
              'roundsPlayed': 10,
              'kills': 20,
              'deaths': 5,
              'damageDealt': 2500.0,
              'currentTier': {'tier': 'Gold', 'subTier': 'III'},
              'currentRankPoint': 2350,
            },
          },
          'normal': {
            'squad': {
              'roundsPlayed': 5,
              'wins': 1,
              'top10s': 3,
              'kills': 15,
              'losses': 4,
              'damageDealt': 1200.0,
            },
          },
        },
      };
      final profile = PlayerStatsProfile.fromJson(mockJson);
      expect(profile.modeStats['ranked']?['squad']?.roundsPlayed, 10);
      expect(profile.modeStats['ranked']?['squad']?.kills, 20);
      expect(
        profile.modeStats['ranked']?['squad']?.currentTierName,
        'Gold III',
      );
      expect(profile.modeStats['normal']?['squad']?.roundsPlayed, 5);
    },
  );
}
