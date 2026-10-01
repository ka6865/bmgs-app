import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_screen.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_models.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_repository.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';

void main() {
  testWidgets('MatchDetailScreen - "리플레이 지도에서 동선 확인" 버튼이 표시되지 않는지 검증', (
    WidgetTester tester,
  ) async {
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
          repository: _DetailRepository(
            MatchDetail.fromSummary(summary, nickname: 'TestUser'),
          ),
        ),
      ),
    );

    // FutureBuilder 완료 대기
    await tester.pumpAndSettle();

    expect(find.text('리플레이 지도에서 동선 확인'), findsNothing);
  });

  testWidgets('기본 전적 전용 응답은 분석 불가를 알리고 실제 전적을 유지한다', (tester) async {
    final summary = MatchSummary(
      matchId: 'basic-match',
      mapName: 'Erangel',
      gameMode: 'squad',
      kills: 4,
      damage: 350,
      rank: 2,
      isFallback: false,
      createdAt: DateTime(2026, 10, 1),
    );
    final detail = MatchDetail.fromJson(summary.matchId, {
      'analysisAvailability': 'basic_only',
      'analysisUnavailableReason': 'calculation_upgrade_required',
      'mapName': 'Erangel',
      'gameMode': 'squad',
      'stats': {
        'name': 'TestUser',
        'kills': 4,
        'damageDealt': 350,
        'winPlace': 2,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MatchDetailScreen(
          matchId: summary.matchId,
          nickname: 'TestUser',
          platform: 'steam',
          summary: summary,
          repository: _DetailRepository(detail),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('분석 불가'), findsOneWidget);
    expect(find.text('분석 완료'), findsNothing);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    expect(find.text('상위권 벤치마크 점수'), findsNothing);
    expect(find.text('교전 포지셔닝 및 고립 지수'), findsNothing);
    expect(find.text('전술 분석을 사용할 수 없습니다. 기본 전적은 정상적으로 표시합니다.'), findsOneWidget);
  });
}

class _DetailRepository extends Fake implements MatchDetailRepository {
  _DetailRepository(this.detail);

  final MatchDetail detail;

  @override
  Future<MatchDetail> fetchMatchDetail({
    required MatchSummary summary,
    required String nickname,
    required String platform,
  }) async => detail;
}
