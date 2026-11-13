import 'package:bgms_mobile_app/features/maps/replay/replay_models.dart';
import 'package:bgms_mobile_app/features/maps/hotdrop_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('리플레이는 30초 초과 기록 간격을 나누고 미래 좌표를 그리지 않는다', () {
    const replay = MatchReplay(
      mapId: 'Erangel',
      focusName: 'me',
      tracks: [
        ReplayTrack(
          name: 'Me',
          teamId: 1,
          isTeam: true,
          points: [
            ReplayPosition(0, 0.1, 0.2),
            ReplayPosition(30000, 0.2, 0.3),
            ReplayPosition(61001, 0.8, 0.9),
          ],
        ),
      ],
      fights: [],
      zones: [],
    );
    expect(replay.pathSegmentsAt(-1), isEmpty);
    expect(replay.pathSegmentsAt(60000).single, hasLength(2));
    final segments = replay.pathSegmentsAt(61001);
    expect(segments.map((segment) => segment.length), [2, 1]);
    expect(segments.last.single.x, 0.8);
  });

  test('기록 사이는 보간하고 공백 구간과 마지막 기록 이후는 위치를 만들지 않는다', () {
    const track = ReplayTrack(
      name: 'Me',
      teamId: 1,
      isTeam: true,
      points: [
        ReplayPosition(0, 0, 0),
        ReplayPosition(10000, 1, 0.5),
        ReplayPosition(100000, 0, 0),
      ],
    );
    expect(track.at(-1), isNull);
    expect(track.at(5000)!.x, 0.5);
    expect(track.at(5000)!.y, 0.25);
    expect(track.at(20000)!.x, 1, reason: '긴 공백 직후엔 마지막 위치에 머문다');
    expect(track.at(50000), isNull);
    expect(track.at(100000)!.x, 0);
    expect(track.at(140000), isNull);
  });

  test('encoding v1 리플레이는 tracks에서 좌표를 읽고 아군 교전만 남긴다', () {
    final replay = MatchReplay.fromJson({
      'mapName': '론도',
      'startTime': '2026-11-13T15:14:31Z',
      'encoding': {'version': 1, 'timeBaseMs': 0},
      'teamNames': ['miaeq_q', 'kangheesung_'],
      'tracks': [
        {
          'name': 'KangHeeSung_',
          'teamId': 3,
          'isTeam': true,
          't': [-5000, 1000, 11000],
          'x': [0, 4096, 8192],
          'y': [0, 4096, 8192],
        },
        {
          'name': 'MiaeQ_Q',
          'teamId': 3,
          'isTeam': true,
          't': [1000],
          'x': [100],
          'y': [100],
        },
        {
          'name': 'Enemy',
          'teamId': 9,
          'isTeam': false,
          't': [1000],
          'x': [200],
          'y': [200],
        },
      ],
      'events': [
        0,
        1,
        {
          'type': 'groggy',
          'relativeTimeMs': 9000,
          'attacker': 'Enemy',
          'victim': 'MiaeQ_Q',
          'victimX': 4096,
          'victimY': 0,
          'weapon': 'WeapAK47_C',
        },
        {
          'type': 'kill',
          'relativeTimeMs': 9500,
          'attacker': 'Enemy',
          'victim': 'Other',
        },
      ],
      'zoneEvents': [],
    }, 'KangHeeSung_');
    expect(replay.mapId, 'Rondo');
    expect(replay.positions.map((p) => p.timeMs), [1000, 11000]);
    expect(replay.squad.map((t) => t.name), ['MiaeQ_Q', 'KangHeeSung_']);
    expect(replay.enemies.single.name, 'Enemy');
    expect(replay.fights.single.type, 'groggy');
    expect(replay.fights.single.x, 0.5);
    expect(replay.durationMs, 11000);
  });

  test('리플레이는 선택 선수의 유효 좌표를 시각순으로 읽고 존재하지 않는 좌표를 만들지 않는다', () {
    final replay = MatchReplay.fromJson({
      'mapName': 'Baltic_Main',
      'startTime': '2026-10-02T00:00:00Z',
      'zoneEvents': [],
      'events': [
        {
          'type': 'position',
          'name': 'TGLTN',
          'relativeTimeMs': 2000,
          'x': 8192,
          'y': 4096,
        },
        {
          'type': 'position',
          'name': 'TGLTN',
          'relativeTimeMs': 1000,
          'x': 0,
          'y': 0,
        },
        {
          'type': 'position',
          'name': 'TGLTN',
          'relativeTimeMs': 3000,
          'x': null,
          'y': 0,
        },
        {
          'type': 'position',
          'name': 'other',
          'relativeTimeMs': 1000,
          'x': 100,
          'y': 100,
        },
        {
          'type': 'kill',
          'relativeTimeMs': 2500,
          'attacker': 'TGLTN',
          'victim': 'other',
        },
      ],
    }, 'tgltn');
    expect(replay.mapId, 'Erangel');
    expect(replay.positions.length, 2);
    expect(replay.positions.last.x, 1);
    expect(replay.positions.last.y, 0.5);
    expect(replay.positions.first.timeMs, 1000);
    expect(replay.durationMs, 2500);
    expect(replay.fights.single.victim, 'other');
  });
  test('핫드랍은 8192 좌표 계약과 유효한 강도만 그린다', () {
    expect(hotdropPoints({'points': 'invalid'}), isEmpty);
    final points = hotdropPoints({
      'points': [
        {'lng': 4096, 'lat': 8192, 'intensity': 0.5},
        {'lng': 2048, 'lat': 0, 'intensity': 1},
        {'lng': 1024, 'lat': 6144, 'intensity': 0.25},
        {'lng': -1, 'lat': 100, 'intensity': 0.8},
        {'lng': 200, 'intensity': 1},
      ],
    });
    expect(points, [
      (x: 0.5, y: 0.0, intensity: 0.5),
      (x: 0.25, y: 1.0, intensity: 1.0),
      (x: 0.125, y: 0.25, intensity: 0.25),
    ]);
  });
}
