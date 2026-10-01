import 'package:bgms_mobile_app/features/stats/ban_watch_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('관심 추적 목록과 대상별 제재 상태를 결합한다', () {
    final watches = BanWatchList.fromJson({
      'items': [
        {
          'id': 'watch-1',
          'platform': 'steam',
          'targetAccountId': 'account.target',
          'nicknameAtMatch': 'Opponent',
          'eventAt': '2026-10-01T12:00:00.000Z',
          'createdAt': '2026-10-01T13:00:00.000Z',
          'activeUntil': '2026-11-01T13:00:00.000Z',
          'baselineStatus': 'none',
          'weapon': 'WeapAK47_C',
        },
      ],
      'statuses': [
        {
          'platform': 'steam',
          'accountId': 'account.target',
          'status': 'temporary',
          'checkedAt': '2026-10-02T12:00:00.000Z',
        },
      ],
      'events': const [],
    });

    final item = watches.items.single;
    expect(item.nickname, 'Opponent');
    expect(item.statusLabel, '임시 제재 확인');
    expect(item.hasStatusChange, isTrue);
    expect(item.currentCheckedAt, isNotNull);
  });

  test('응답에 합쳐진 현재 상태도 그대로 사용한다', () {
    final watches = BanWatchList.fromJson({
      'items': [
        {
          'id': 'watch-2',
          'platform': 'kakao',
          'targetAccountId': 'account.target',
          'nicknameAtMatch': 'Opponent',
          'eventAt': '2026-10-01T12:00:00.000Z',
          'createdAt': '2026-10-01T13:00:00.000Z',
          'activeUntil': '2026-11-01T13:00:00.000Z',
          'currentStatus': 'none',
          'currentError': 'upstream delayed',
        },
      ],
    });

    expect(watches.items.single.statusLabel, '현재 제재 표시 없음');
    expect(watches.items.single.currentError, 'upstream delayed');
  });
}
