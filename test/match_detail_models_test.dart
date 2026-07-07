import 'package:bgms_mobile_app/features/stats/match_detail_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MatchDetail parses nested match payload', () {
    final detail = MatchDetail.fromJson('match-1', {
      'matchInfo': {
        'map': 'Erangel',
        'mapId': 'erangel',
        'gameMode': 'squad-fpp',
      },
      'stats': {
        'name': 'KangHeeSung_',
        'kills': 7,
        'damageDealt': 645.5,
        'winPlace': 3,
        'timeSurvived': 1540,
      },
      'team': {'rank': 3, 'kills': 12},
    });

    expect(detail.matchId, 'match-1');
    expect(detail.mapName, 'Erangel');
    expect(detail.mapId, 'erangel');
    expect(detail.gameMode, 'squad-fpp');
    expect(detail.nickname, 'KangHeeSung_');
    expect(detail.kills, 7);
    expect(detail.damage, 645.5);
    expect(detail.rank, 3);
    expect(detail.survivalSeconds, 1540);
    expect(detail.teamKills, 12);
    expect(detail.survivalText, '25:40');
    expect(detail.isFallback, isFalse);
  });

  test('MatchDetail creates fallback from summary', () {
    final summary = MatchSummary(
      matchId: 'match-2',
      mapName: 'Taego',
      mapId: 'taego',
      gameMode: 'duo',
      kills: 2,
      damage: 210,
      rank: 8,
      isFallback: true,
      createdAt: DateTime(2026, 7, 7, 12, 0, 0),
    );

    final detail = MatchDetail.fromSummary(summary, nickname: 'Player');

    expect(detail.matchId, 'match-2');
    expect(detail.mapName, 'Taego');
    expect(detail.mapId, 'taego');
    expect(detail.nickname, 'Player');
    expect(detail.kills, 2);
    expect(detail.isFallback, isTrue);
  });
}
