import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('지원 맵 별칭은 같은 맵 지도·핫드랍으로 전달하고 미지원 맵은 차단한다', (tester) async {
    MatchSummary summary(String map) => MatchSummary(
      matchId: 'map-match',
      createdAt: null,
      mapName: map,
      gameMode: 'squad',
      kills: 0,
      damage: 0,
      rank: 20,
      isFallback: false,
    );
    final match = summary('Desert_Main');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MatchDetailScreen(
            matchId: match.matchId,
            nickname: 'Player',
            platform: 'steam',
            summary: match,
            repository: _DetailRepository(
              MatchDetail.fromSummary(match, nickname: 'Player'),
            ),
          ),
        ),
        GoRoute(
          path: '/maps',
          builder: (_, state) =>
              Text('지도:${state.uri.queryParameters['mapId']}'),
        ),
        GoRoute(
          path: '/hotdrop',
          builder: (_, state) =>
              Text('핫드랍:${state.uri.queryParameters['mapId']}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 경기 전술 지도'));
    await tester.pumpAndSettle();
    expect(find.text('지도:Miramar'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 맵 핫드랍'));
    await tester.pumpAndSettle();
    expect(find.text('핫드랍:Miramar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();

    final unsupported = summary('Savage_Main');
    await tester.pumpWidget(
      MaterialApp(
        home: MatchDetailScreen(
          matchId: unsupported.matchId,
          nickname: 'Player',
          platform: 'steam',
          summary: unsupported,
          repository: _DetailRepository(
            MatchDetail.fromSummary(unsupported, nickname: 'Player'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['이 경기 전술 지도', '이 맵 핫드랍', '경기 2D 리플레이']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    }
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
