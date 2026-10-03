import 'package:bgms_mobile_app/features/stats/player_match_history_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('전체 이력 응답의 0 값과 페이지 정보를 보존한다', () {
    final page = PlayerMatchHistoryPage.fromJson({
      'page': 2,
      'totalPages': 4,
      'totalCount': 61,
      'matches': [
        {
          'match_id': 'match-1',
          'map_name': 'Baltic_Main',
          'game_mode': 'solo-fpp',
          'kills': 0,
          'damage': 0,
          'win_place': 20,
          'played_at': '2026-10-02T00:00:00Z',
          'match_type': 'official',
        },
      ],
    });

    expect(page.page, 2);
    expect(page.totalPages, 4);
    expect(page.totalCount, 61);
    expect(page.hasPreviousPage, isTrue);
    expect(page.hasNextPage, isTrue);
    expect(page.matches.single.kills, 0);
    expect(page.matches.single.damage, 0);
    expect(page.matches.single.rank, 20);
    expect(page.matches.single.matchType, 'official');
    expect(page.matches.single.isFallback, isFalse);
    expect(page.matches.single.mapName, 'Baltic_Main');
    expect(page.matches.single.gameMode, 'solo-fpp');
    expect(page.matches.single.createdAt, DateTime.utc(2026, 10, 2));
  });

  test('조회 불가 DB placeholder는 실제 0킬·0딜·99등과 경기 시각으로 표시하지 않는다', () {
    for (final matchType in ['unavailable', ' Unavailable ']) {
      final page = PlayerMatchHistoryPage.fromJson({
        'page': 1,
        'totalPages': 1,
        'totalCount': 1,
        'matches': [
          {
            'match_id': 'expired-match',
            'map_name': 'Baltic_Main',
            'game_mode': 'squad-fpp',
            'kills': 0,
            'damage': 0,
            'win_place': 99,
            'survival_time': 120,
            'played_at': '2026-10-02T00:00:00Z',
            'match_type': matchType,
          },
        ],
      });
      final match = page.matches.single;
      expect(page.totalCount, 1);
      expect(match.matchId, 'expired-match');
      expect(match.isFallback, isTrue);
      expect(match.kills, isNull);
      expect(match.damage, isNull);
      expect(match.rank, isNull);
      expect(match.createdAt, isNull);
      expect(match.mapName, '경기 정보 없음');
      expect(match.gameMode, '모드 정보 없음');
      expect(match.matchType, isNull);
      expect(match.timeSurvived, 0);
    }
  });
  test('수집 상태 null과 미확인 필드는 대기 0건으로 만들지 않는다', () {
    expect(
      PlayerMatchHistoryPage.fromJson({'historyIngest': null}).historyIngest,
      isNull,
    );
    final ingest = HistoryIngest.tryParse({
      'pendingCount': 43,
      'unavailableCount': 2,
      'lastSavedAt': '2026-10-02T12:00:00Z',
    })!;
    expect(ingest.pendingCount, 43);
    expect(ingest.unavailableCount, 2);
    expect(ingest.lastSavedAt, DateTime.utc(2026, 10, 2, 12));
    expect(HistoryIngest.tryParse({})!.pendingCount, isNull);
  });

  test('기존 저장 확인을 신규 저장에서 제외하고 누락된 optional 필드는 추정하지 않는다', () {
    final result = PlayerMatchCollectionResult.fromJson({
      'collection': {
        'claimed': 3,
        'saved': 3,
        'alreadyStored': 2,
        'retry': 0,
        'unavailable': 0,
        'rateLimited': false,
        'durationMs': 12,
        'failureCounts': {'network_error:none': 1},
      },
      'historyIngest': {'pendingCount': 0, 'unavailableCount': 1},
    });
    expect(result.collection!.newSaved, 1);
    expect(result.collection!.alreadyStored, 2);
    expect(result.collection!.failureCounts, {'network_error:none': 1});
    expect(result.historyIngest!.pendingCount, 0);
    expect(MatchCollection.tryParse({'saved': 3})!.newSaved, isNull);
    expect(
      MatchCollection.tryParse({'saved': 1, 'alreadyStored': 2})!.newSaved,
      isNull,
    );
  });
}
