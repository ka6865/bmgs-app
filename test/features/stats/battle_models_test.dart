import 'dart:async';

import 'package:bgms_mobile_app/features/stats/battle_models.dart';
import 'package:bgms_mobile_app/features/stats/battle_repository.dart';
import 'package:bgms_mobile_app/features/stats/battle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('비교 응답에서 비공개 전술 지표와 점수를 읽는다', () {
    final result = BattleResult.fromJson({
      'nick1': 'alpha',
      'nick2': 'beta',
      'platform1': 'steam',
      'platform2': 'kakao',
      'comparisonMatchCount': 12,
      'tacticalComparable': false,
      'withheldCount': 8,
      'score': {'nick1': 1, 'nick2': 0, 'draw': 1},
      'overallWinner': 'alpha',
      'comparisons': [
        {
          'key': 'damage',
          'label': '평균 딜량',
          'unit': '',
          'v1': 321.2,
          'v2': 280,
          'winner': 'nick1',
        },
        {
          'key': 'duel_win_rate',
          'label': '1:1 교전 승률',
          'unit': '%',
          'v1': null,
          'v2': null,
          'winner': 'draw',
        },
      ],
    });

    expect(result.firstNickname, 'alpha');
    expect(result.comparisonMatchCount, 12);
    expect(result.tacticalComparable, isFalse);
    expect(result.withheldCount, 8);
    expect(result.comparisons[0].firstValue, 321.2);
    expect(result.comparisons[1].firstValue, isNull);
  });

  testWidgets('비교 요청 중에는 중복 탭을 보내지 않는다', (tester) async {
    final repository = _PendingBattleRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(
          initialNickname: 'alpha',
          initialPlatform: 'steam',
          repository: repository,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(1), 'beta');

    await tester.tap(find.text('비교하기'));
    await tester.pump();
    await tester.tap(find.text('비교하기'));
    await tester.pump();

    expect(repository.calls, 1);

    repository.completer.complete(_battleResult);
    await tester.pump();
  });
}

class _PendingBattleRepository extends BattleRepository {
  final completer = Completer<BattleResult>();
  var calls = 0;

  @override
  Future<BattleResult> compare({
    required String firstNickname,
    required String secondNickname,
    required String firstPlatform,
    String? secondPlatform,
    String matchType = 'all',
  }) {
    calls += 1;
    return completer.future;
  }
}

const _battleResult = BattleResult(
  firstNickname: 'alpha',
  secondNickname: 'beta',
  firstPlatform: 'steam',
  secondPlatform: 'steam',
  comparisons: [],
  firstScore: 0,
  secondScore: 0,
  drawScore: 0,
  overallWinner: 'draw',
  comparisonMatchCount: 0,
  tacticalComparable: true,
  withheldCount: 0,
);
