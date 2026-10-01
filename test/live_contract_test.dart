import 'dart:convert';
import 'dart:io';

import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/rankings/ranking_models.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// bgms.kr 운영 API에서 실제로 받아 저장한 응답으로 파서 계약을 검증한다.
///
/// 픽스처는 `test/fixtures/`에 있으며, 서버 응답 구조가 바뀌면 이 테스트가 먼저 깨진다.
Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('운영 GET /api/pubg/player 응답', () {
    late Map<String, dynamic> raw;
    late PlayerStatsProfile profile;

    setUp(() {
      raw = _fixture('player_response.json');
      profile = PlayerStatsProfile.fromJson(raw);
    });

    test('프로필 기본 정보를 읽는다', () {
      expect(profile.nickname, isNotEmpty);
      expect(profile.platform, 'steam');
      expect(profile.seasonId, startsWith('division.bro.official.pc'));
      expect(profile.recentMatches, isNotEmpty);
      expect(profile.matchModes, isNotEmpty);
      expect(profile.updatedAt, isNotNull);
      expect(profile.hasSeasonStats, isTrue);
    });

    test('서버가 내려주는 seasons 배열을 시즌 목록으로 읽는다', () {
      final serverSeasons = (raw['seasons'] as List)
          .map((season) => (season as Map)['id'].toString())
          .toList();

      expect(serverSeasons, isNotEmpty, reason: '시즌 목록이 담긴 픽스처여야 한다');
      expect(profile.seasonsList, serverSeasons);
      expect(profile.seasonsList, contains(profile.seasonId));
    });

    test('경쟁전 통계는 deaths를 사용해 K/D가 부풀지 않는다', () {
      final ranked = (profile.modeStats['ranked'] ?? const {}).values
          .where((stats) => stats.roundsPlayed > 0)
          .toList();

      expect(ranked, isNotEmpty, reason: '경쟁전 기록이 있는 픽스처여야 한다');
      for (final stats in ranked) {
        expect(stats.losses, greaterThan(0), reason: 'ranked는 deaths로 채워야 한다');
        expect(stats.kd, lessThan(stats.kills));
        expect(stats.adr, greaterThan(0));
        expect(stats.currentTier, isNotNull);
      }
    });

    test('경쟁전 top10Ratio와 avgSurvivalTime을 지표로 환산한다', () {
      final rankedRaw = (raw['stats'] as Map)['ranked'] as Map;
      final rankedModes = profile.modeStats['ranked'] ?? const {};

      for (final entry in rankedModes.entries) {
        final source = rankedRaw[entry.key];
        if (source is! Map) continue;
        final stats = entry.value;
        if (stats.roundsPlayed <= 0) continue;

        final top10Ratio = (source['top10Ratio'] as num).toDouble();
        expect(
          stats.top10Rate,
          closeTo(top10Ratio * 100, 1.0),
          reason: 'ranked는 top10s 대신 top10Ratio를 사용해야 한다',
        );

        final avgSurvival = (source['avgSurvivalTime'] as num).toDouble();
        expect(
          stats.timeSurvived / stats.roundsPlayed,
          closeTo(avgSurvival, 1.0),
          reason: 'ranked는 timeSurvived 대신 avgSurvivalTime을 사용해야 한다',
        );
      }
    });

    test('일반전 통계는 losses와 top10s를 그대로 읽는다', () {
      final normal = (profile.modeStats['normal'] ?? const {}).values
          .where((stats) => stats.roundsPlayed > 0)
          .toList();

      expect(normal, isNotEmpty, reason: '일반전 기록이 있는 픽스처여야 한다');
      for (final stats in normal) {
        expect(stats.losses, greaterThan(0));
        expect(stats.top10Rate, greaterThanOrEqualTo(0));
        expect(stats.top10Rate, lessThanOrEqualTo(100));
      }
    });
  });

  group('운영 GET /api/rankings 응답', () {
    test('entries를 순위 순서대로 파싱한다', () {
      final board = RankingBoard.fromJson(
        _fixture('rankings_response.json'),
        query: const RankingQuery(tab: 'damage'),
      );

      expect(board.source, RankingSource.api);
      expect(board.entries, isNotEmpty);
      expect(board.entries.first.rank, 1);
      for (final entry in board.entries) {
        expect(entry.nickname, isNotEmpty);
        expect(entry.nickname, isNot('Unknown'));
        expect(entry.rank, greaterThan(0));
        expect(entry.value, greaterThan(0));
        expect(entry.platform, isNotEmpty);
      }
    });
  });

  group('운영 POST /api/pubg/matches-summary 응답', () {
    test('summaries의 stats.winPlace를 순위로 읽는다', () {
      final json = _fixture('matches_summary_response.json');
      final summaries = json['summaries'] as Map;

      expect(summaries, isNotEmpty, reason: '요약이 담긴 픽스처여야 한다');

      for (final entry in summaries.entries) {
        final summary = MatchSummary.fromJson(
          entry.key.toString(),
          Map<String, dynamic>.from(entry.value as Map),
        );

        expect(summary.isFallback, isFalse);
        expect(summary.mapName, isNot('맵 정보 없음'));
        expect(summary.gameMode, isNot('모드 정보 없음'));
        expect(summary.rank, isNotNull, reason: 'stats.winPlace를 읽어야 한다');
        expect(summary.rank, greaterThan(0));
        expect(summary.kills, greaterThan(0));
        expect(summary.damage, greaterThan(0));
        expect(summary.timeSurvived, greaterThan(0));
        expect(
          summary.createdAt.isAfter(DateTime.utc(2024)),
          isTrue,
          reason: 'createdAt을 서버 값에서 읽어야 한다',
        );
      }
    });

    test('missingMatchIds는 fallback 매치로 표시할 대상이다', () {
      final json = _fixture('matches_summary_response.json');
      expect(json['missingMatchIds'], isA<List<dynamic>>());
    });
  });

  group('운영 GET /api/maps/{mapId}/markers 응답', () {
    test('마커 좌표를 0~1 정규화 값으로 읽는다', () {
      final layer = MapMarkerLayer.fromJson(
        _fixture('markers_response.json'),
        mapId: 'Erangel',
      );

      expect(layer.mapId, 'Erangel');
      expect(layer.source, MapMarkerSource.api);
      expect(layer.markers, isNotEmpty);
      for (final marker in layer.markers) {
        expect(marker.x, inInclusiveRange(0, 1));
        expect(marker.y, inInclusiveRange(0, 1));
        expect(marker.layer, isNotEmpty);
        expect(marker.layer, isNot('default'));
        expect(marker.label, isNotEmpty);
      }
    });
  });

  group('운영 GET /api/pubg/match 응답', () {
    late Map<String, dynamic> raw;
    late MatchDetail detail;

    setUp(() {
      raw = _fixture('match_response.json');
      detail = MatchDetail.fromJson(raw['matchId'].toString(), raw);
    });

    test('매치 상세 기본 지표를 파싱한다', () {
      expect(detail.isFallback, isFalse);
      expect(detail.mapName, isNot('맵 정보 없음'));
      expect(detail.gameMode, isNot('모드 정보 없음'));
      expect(detail.nickname, isNotEmpty);
      expect(detail.rank, isNotNull);
      expect(detail.rank, greaterThan(0));
      expect(detail.kills, greaterThan(0));
      expect(detail.damage, greaterThan(0));
      expect(detail.survivalSeconds, greaterThan(0));
      expect(detail.survivalText, matches(RegExp(r'^\d+:\d{2}$')));
    });

    test('team 배열에서 팀 전체 킬을 합산한다', () {
      final team = raw['team'] as List;
      final expectedTeamKills = team.fold<int>(
        0,
        (sum, member) => sum + ((member as Map)['kills'] as num).round(),
      );

      expect(team, isNotEmpty, reason: '팀 정보가 담긴 픽스처여야 한다');
      expect(detail.teamKills, expectedTeamKills);
      expect(detail.teamKills, greaterThanOrEqualTo(detail.kills));
    });

    test('전술 분석 블록을 파싱한다', () {
      expect(detail.tradeStats.tradeKills, greaterThanOrEqualTo(0));
      expect(detail.isolationData.teammateCount, greaterThanOrEqualTo(0));
      expect(detail.benchmark.combat, greaterThanOrEqualTo(0));
      expect(detail.vehicleCombat.roadKills, greaterThanOrEqualTo(0));
    });
  });
}
