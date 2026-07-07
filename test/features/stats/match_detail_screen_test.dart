import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_screen.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';

void main() {
  testWidgets('MatchDetailScreen - "리플레이 지도에서 동선 확인" 버튼이 표시되지 않는지 검증', (WidgetTester tester) async {
    final summary = MatchSummary(
      matchId: 'test-match-id-123',
      mapName: 'Erangel',
      gameMode: 'squad',
      kills: 5,
      damage: 450.0,
      rank: 3,
      isFallback: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MatchDetailScreen(
          matchId: 'test-match-id-123',
          nickname: 'TestUser',
          platform: 'steam',
          summary: summary,
        ),
      ),
    );

    // FutureBuilder 완료 대기
    await tester.pumpAndSettle();

    // TDD 실패 테스트: 현재 코드에는 버튼이 여전히 존재하므로, findsNothing 단언이 실패해야 정상입니다.
    expect(find.text('리플레이 지도에서 동선 확인'), findsNothing);
  });
}
