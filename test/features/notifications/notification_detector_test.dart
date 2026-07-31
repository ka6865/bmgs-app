import 'package:bgms_mobile_app/features/notifications/notification_detector.dart';
import 'package:bgms_mobile_app/features/notifications/notification_models.dart';
import 'package:bgms_mobile_app/features/notifications/notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 7, 31, 12);

PlayerSnapshot _snapshot({
  String latestMatchId = 'match-1',
  int matchCount = 10,
  String tierName = 'Platinum 3',
  String seasonId = 'division.bro.official.pc-2018-42',
}) {
  return PlayerSnapshot(
    nickname: 'tester',
    platform: 'steam',
    latestMatchId: latestMatchId,
    matchCount: matchCount,
    tierName: tierName,
    seasonId: seasonId,
    capturedAt: _now,
  );
}

List<BgmsNotification> _detect({
  PlayerSnapshot? previous,
  required PlayerSnapshot current,
  NotificationSettings settings = NotificationSettings.defaults,
}) {
  return detectNotifications(
    previous: previous,
    current: current,
    settings: settings,
  );
}

void main() {
  test('첫 확인에는 알림을 만들지 않는다', () {
    final events = _detect(previous: null, current: _snapshot());
    expect(events, isEmpty);
  });

  test('변화가 없으면 알림이 없다', () {
    final events = _detect(previous: _snapshot(), current: _snapshot());
    expect(events, isEmpty);
  });

  test('최신 매치 ID가 바뀌면 새 매치 알림을 만든다', () {
    final events = _detect(
      previous: _snapshot(latestMatchId: 'match-1', matchCount: 10),
      current: _snapshot(latestMatchId: 'match-2', matchCount: 11),
    );

    expect(events, hasLength(1));
    expect(events.single.kind, BgmsNotificationKind.newMatch);
    expect(events.single.body, '새 매치가 기록되었습니다.');
  });

  test('매치가 여러 건 늘면 건수를 문구에 담는다', () {
    final events = _detect(
      previous: _snapshot(latestMatchId: 'match-1', matchCount: 10),
      current: _snapshot(latestMatchId: 'match-4', matchCount: 13),
    );

    expect(events.single.body, '새 매치 3건이 기록되었습니다.');
  });

  test('티어 상승과 하락을 구분한다', () {
    final promoted = _detect(
      previous: _snapshot(tierName: 'Platinum 3'),
      current: _snapshot(tierName: 'Diamond 5'),
    );
    expect(promoted.single.title, '티어가 올랐습니다');

    final demoted = _detect(
      previous: _snapshot(tierName: 'Diamond 5'),
      current: _snapshot(tierName: 'Platinum 3'),
    );
    expect(demoted.single.title, '티어가 내려갔습니다');
  });

  test('Crystal은 Diamond보다 높고 Master보다 낮은 등급으로 판정한다', () {
    // 랭크 에셋에 Crystal-1~5가 실제로 존재하는 등급이다.
    final toCrystal = _detect(
      previous: _snapshot(tierName: 'Diamond 1'),
      current: _snapshot(tierName: 'Crystal 5'),
    );
    expect(toCrystal.single.title, '티어가 올랐습니다');

    final toMaster = _detect(
      previous: _snapshot(tierName: 'Crystal 1'),
      current: _snapshot(tierName: 'Master'),
    );
    expect(toMaster.single.title, '티어가 올랐습니다');

    final downToDiamond = _detect(
      previous: _snapshot(tierName: 'Crystal 5'),
      current: _snapshot(tierName: 'Diamond 1'),
    );
    expect(downToDiamond.single.title, '티어가 내려갔습니다');
  });

  test('같은 등급에서는 서브티어 숫자가 작아질 때 승급으로 본다', () {
    final promoted = _detect(
      previous: _snapshot(tierName: 'Gold 4'),
      current: _snapshot(tierName: 'Gold 2'),
    );
    expect(promoted.single.title, '티어가 올랐습니다');

    final demoted = _detect(
      previous: _snapshot(tierName: 'Gold 2'),
      current: _snapshot(tierName: 'Gold 4'),
    );
    expect(demoted.single.title, '티어가 내려갔습니다');
  });

  test('시즌이 바뀌면 시즌 알림을 만들고 티어 하락은 알리지 않는다', () {
    final events = _detect(
      previous: _snapshot(
        tierName: 'Diamond 1',
        seasonId: 'division.bro.official.pc-2018-42',
      ),
      current: _snapshot(
        tierName: 'Unranked',
        seasonId: 'division.bro.official.pc-2018-43',
      ),
    );

    expect(
      events.map((event) => event.kind),
      contains(BgmsNotificationKind.seasonChange),
    );
    expect(
      events.map((event) => event.kind),
      isNot(contains(BgmsNotificationKind.tierChange)),
    );
  });

  test('설정에서 끈 종류는 만들지 않는다', () {
    const settings = NotificationSettings(
      enabledKinds: {BgmsNotificationKind.tierChange},
    );

    final events = _detect(
      previous: _snapshot(latestMatchId: 'match-1', tierName: 'Gold 4'),
      current: _snapshot(latestMatchId: 'match-2', tierName: 'Gold 2'),
      settings: settings,
    );

    expect(events, hasLength(1));
    expect(events.single.kind, BgmsNotificationKind.tierChange);
  });

  test('매치 기록이 비어 있으면 새 매치로 보지 않는다', () {
    final events = _detect(
      previous: _snapshot(latestMatchId: 'match-1'),
      current: _snapshot(latestMatchId: '', matchCount: 0),
    );

    expect(
      events.map((event) => event.kind),
      isNot(contains(BgmsNotificationKind.newMatch)),
    );
  });

  test('알림은 해당 플레이어 전적 경로를 가진다', () {
    final events = _detect(
      previous: _snapshot(latestMatchId: 'match-1'),
      current: _snapshot(latestMatchId: 'match-2'),
    );

    expect(events.single.destination, '/stats?nickname=tester&platform=steam');
  });
}
