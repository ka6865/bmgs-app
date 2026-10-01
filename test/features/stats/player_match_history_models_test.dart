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
  });
}
