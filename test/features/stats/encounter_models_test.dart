import 'package:bgms_mobile_app/features/stats/encounter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('저장된 상대 기록과 서버 검증 주체를 읽는다', () {
    final page = EncounterPage.fromJson({
      'accountId': 'subject-account',
      'nickname': 'CanonicalName',
      'page': 2,
      'totalPages': 4,
      'matches': [
        {
          'match_id': 'match-1',
          'map_name': 'Baltic_Main',
          'game_mode': 'squad-fpp',
          'encounter': {
            'encounters': [
              {
                'targetAccountId': 'target-account',
                'nicknameAtMatch': 'Opponent',
                'role': 'finisher',
                'eventAt': '2026-10-01T12:00:00.000Z',
                'weapon': 'WeapAK47_C',
              },
            ],
          },
        },
      ],
    });

    expect(page.subjectAccountId, 'subject-account');
    expect(page.subjectNickname, 'CanonicalName');
    expect(page.page, 2);
    expect(page.totalPages, 4);
    expect(page.matches.single.entries.single.roleLabel, '마무리한 상대');
    expect(page.matches.single.entries.single.weapon, 'WeapAK47_C');
  });

  test('기록이 없는 경기는 수집 전 상태로 남긴다', () {
    final match = EncounterMatch.fromJson({
      'match_id': 'match-2',
      'map_name': 'Desert_Main',
      'game_mode': 'duo',
      'encounter': null,
    });

    expect(match.entries, isEmpty);
  });

  test('상대 프로필의 준비 중 및 재시도 정보를 읽는다', () {
    final profile = EncounterProfile.fromJson({
      'tier': null,
      'averageDamage': 312.5,
      'rounds': 0,
      'pending': true,
      'retryAt': '2026-10-02T12:00:00.000Z',
    });

    expect(profile.tier, isNull);
    expect(profile.averageDamage, 312.5);
    expect(profile.rounds, 0);
    expect(profile.pending, isTrue);
    expect(profile.retryAt, DateTime.parse('2026-10-02T12:00:00.000Z'));
  });
}
