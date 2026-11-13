import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/maps/replay/match_replay_screen.dart';
import 'package:bgms_mobile_app/features/maps/map_view_helpers.dart';
import 'package:bgms_mobile_app/features/maps/replay/replay_models.dart';
import 'package:bgms_mobile_app/features/stats/weapon_mastery_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_adapter.dart';

const _identity = {
  'matchId': 'm',
  'platform': 'steam',
  'mode': 'lite',
  'playerKey': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'telemetryVersion': 63,
};

Map<String, Object?> _payload() => {
  'identity': _identity,
  'mapName': '론도',
  'startTime': '2026-11-13T15:14:31Z',
  'encoding': {'version': 1, 'timeBaseMs': 0},
  'teamNames': ['me'],
  'tracks': [
    {
      'name': 'Me',
      'teamId': 1,
      'isTeam': true,
      't': [1000, 11000, 21000],
      'x': [1000, 2000, 3000],
      'y': [1000, 2000, 3000],
      'veh': ['DummyTransportAircraft_C', 'BP_Blanc_C', null],
    },
  ],
  'events': [
    0,
    {
      'type': 'kill',
      'relativeTimeMs': 20000,
      'attacker': 'Me',
      'victim': 'Enemy',
      'weapon': 'WeapBerylM762_C',
      'victimX': 3000,
      'victimY': 3000,
    },
    {
      'type': 'groggy',
      'relativeTimeMs': 21000,
      'attacker': 'Stranger',
      'victim': 'Other',
      'weapon': 'WeapHK416_C',
    },
  ],
  'zoneEvents': [
    for (final (t, blue) in [
      (0, 4000),
      (10000, 4000),
      (20000, 3000),
      (30000, 2000),
      (40000, 2000),
    ])
      {
        'relativeTimeMs': t,
        'phase': 1,
        'blueX': 4096,
        'blueY': 4096,
        'blueRadius': blue,
        'whiteX': 4096,
        'whiteY': 4096,
        'whiteRadius': 2000,
      },
  ],
};

void main() {
  test('탈것 이름을 종류로 나누고 텔레메트리 무기 이름을 표시 이름으로 바꾼다', () {
    expect(replayVehicleKind(null), isNull);
    expect(
      replayVehicleKind('DummyTransportAircraft_C'),
      ReplayVehicleKind.plane,
    );
    expect(
      replayVehicleKind('BP_Motorglider_Green_C'),
      ReplayVehicleKind.glider,
    );
    expect(replayVehicleKind('Boat_PG117_C'), ReplayVehicleKind.boat);
    expect(replayVehicleKind('BP_Blanc_C'), ReplayVehicleKind.car);
    expect(pubgWeaponName('WeapBerylM762_C'), '베릴 M762');
    expect(pubgWeaponName('WeapHK416_C'), 'M416');
    expect(pubgWeaponName('WeapNewGun_C'), 'NewGun');
    expect(pubgWeaponName('PlayerFemale_A_C'), '주먹');
  });

  test('킬로그는 모든 처치·기절을, 교전 목록은 아군 교전만 담고 탈것을 기록한다', () {
    final replay = MatchReplay.fromJson(_payload(), 'Me');
    expect(replay.feed.map((f) => f.victim), ['Enemy', 'Other']);
    expect(replay.fights.single.victim, 'Enemy');
    expect(replay.focus!.at(12000)!.vehicle, 'BP_Blanc_C');
    expect(replay.focus!.at(21000)!.vehicle, isNull);
  });

  test('사격·피해·탑승 좌표로 위치 사이를 채우고 탈것 상태를 이어받는다', () {
    final payload = _payload();
    payload['events'] = [
      ...payload['events'] as List,
      {
        'type': 'shot',
        'relativeTimeMs': 5000,
        'name': 'Me',
        'x': 1500,
        'y': 1500,
      },
      {
        'type': 'leave',
        'relativeTimeMs': 15000,
        'name': 'Me',
        'x': 2500,
        'y': 2500,
      },
      {
        'type': 'shot',
        'relativeTimeMs': 16000,
        'name': 'Me',
        'x': 2600,
        'y': 2600,
      },
    ];
    final me = MatchReplay.fromJson(payload, 'Me').focus!;
    expect(me.points.map((p) => p.timeMs), [
      1000,
      5000,
      11000,
      15000,
      16000,
      21000,
    ]);
    // 수송기 기록 뒤의 사격은 수송기 상태를 이어받고, 하차 뒤에는 걷는 상태다.
    expect(me.points[1].vehicle, 'DummyTransportAircraft_C');
    expect(me.points[3].vehicle, isNull);
    expect(me.points[4].vehicle, isNull);
  });

  test('자기장 대기·이동 상태와 남은 시간을 계산한다', () {
    final replay = MatchReplay.fromJson(_payload(), 'Me');
    final waiting = replay.zoneStatusAt(5000)!;
    expect(waiting.shrinking, isFalse);
    expect(waiting.remainingMs, 5000);
    final moving = replay.zoneStatusAt(22000)!;
    expect(moving.shrinking, isTrue);
    expect(moving.remainingMs, 8000);
    expect(moving.phase, 1);
  });

  testWidgets('킬로그는 그 시점에 나타났다가 시간이 지나면 사라지고 끌 수 있다', (tester) async {
    final adapter = FakeHttpAdapter()
      ..stub('/api/pubg/telemetry', {
        'identity': _identity,
        'downloadUrl': 'https://assets.example/replay.json',
      })
      ..stub('/replay.json', _payload());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchReplayScreen(
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          mapId: 'Rondo',
          client: BgmsApiClient(
            baseUrl: 'https://bgms.kr',
            dio: createFakeDio(adapter),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final feedLine = find.textContaining('  Enemy', findRichText: true);
    expect(feedLine, findsNothing);

    // 교전 목록을 눌러 처치 시점으로 이동하면 지도 위에 킬로그가 뜬다.
    await tester.tap(find.text('Me → Enemy'));
    await tester.pumpAndSettle();
    expect(feedLine, findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, '킬로그'));
    await tester.pumpAndSettle();
    expect(feedLine, findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, '킬로그'));
    await tester.pumpAndSettle();

    // 끝(21초)으로 옮겨도 30배속 창(90초) 안이라 남아 있고, 경기 밖 시간은 없다.
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(slider.max);
    await tester.pumpAndSettle();
    expect(feedLine, findsOneWidget);
    slider.onChanged!(0);
    await tester.pumpAndSettle();
    expect(feedLine, findsNothing);
  });

  testWidgets('세로 전체화면은 상단 바를 숨기고, 팀원을 누르면 카메라가 따라가며 확대한다', (tester) async {
    final adapter = FakeHttpAdapter()
      ..stub('/api/pubg/telemetry', {
        'identity': _identity,
        'downloadUrl': 'https://assets.example/replay.json',
      })
      ..stub('/replay.json', _payload());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchReplayScreen(
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          mapId: 'Rondo',
          client: BgmsApiClient(
            baseUrl: 'https://bgms.kr',
            dio: createFakeDio(adapter),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.text('Me → Enemy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Me'));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.transformationController!.value.getMaxScaleOnViewport(), 3);

    final normalMap = tester.getSize(find.byType(InteractiveViewer));
    expect(find.text('아군 교전'), findsOneWidget);
    await tester.tap(find.byTooltip('전체화면'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('뒤로'), findsOneWidget);
    // 전체화면은 지도와 재생·필터만 남기고 교전 목록·범례는 뺀다.
    expect(find.text('아군 교전'), findsNothing);
    expect(find.textContaining('회색 점'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '동선'), findsOneWidget);
    expect(
      tester.getSize(find.byType(InteractiveViewer)).width,
      greaterThanOrEqualTo(normalMap.width),
    );
    await tester.tap(find.byTooltip('전체화면 끝내기'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('가로 화면은 자동 전체화면이고 지도 옆에 패널을 둔다', (tester) async {
    final adapter = FakeHttpAdapter()
      ..stub('/api/pubg/telemetry', {
        'identity': _identity,
        'downloadUrl': 'https://assets.example/replay.json',
      })
      ..stub('/replay.json', _payload());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(900, 420);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MatchReplayScreen(
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          mapId: 'Rondo',
          client: BgmsApiClient(
            baseUrl: 'https://bgms.kr',
            dio: createFakeDio(adapter),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    final map = tester.getRect(find.byType(InteractiveViewer));
    final slider = tester.getRect(find.byType(Slider));
    expect(map.height, 420);
    expect(slider.left, greaterThanOrEqualTo(map.right));
    expect(find.text('아군 교전'), findsNothing);
  });
}
