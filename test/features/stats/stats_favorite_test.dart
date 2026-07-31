import 'package:bgms_mobile_app/core/storage/local_player_store.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyStatsRepository extends Fake implements PlayerStatsRepository {
  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) {
    return SynchronousFuture(
      PlayerStatsBundle(
        profile: PlayerStatsProfile(
          nickname: nickname,
          platform: platform,
          seasonId: 'division.bro.official.pc-2018-42',
          kd: 1,
          adr: 100,
          winRate: 0,
          averageRank: 20,
          roundsPlayed: 1,
          recentMatches: const [],
          matchModes: const {},
          seasonsList: const ['division.bro.official.pc-2018-42'],
          updatedAt: DateTime(2026, 8, 1),
          modeStats: const {},
        ),
        matches: const [],
        summaryFallback: false,
      ),
    );
  }
}

void main() {
  testWidgets('전적 화면에서 즐겨찾기를 등록하고 해제한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: 'kakaoPlayer',
            platform: 'kakao',
            repository: _EmptyStatsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 홈으로 돌아가지 않고 전적 화면에서 바로 등록할 수 있다.
    await tester.tap(find.byTooltip('즐겨찾기에 추가'));
    await tester.pumpAndSettle();

    expect(await store.isFavorite('kakaoPlayer', platform: 'kakao'), isTrue);
    expect(find.byTooltip('즐겨찾기 해제'), findsOneWidget);
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);

    await tester.tap(find.byTooltip('즐겨찾기 해제'));
    await tester.pumpAndSettle();

    expect(await store.isFavorite('kakaoPlayer', platform: 'kakao'), isFalse);
    expect(find.byTooltip('즐겨찾기에 추가'), findsOneWidget);
  });

  testWidgets('검색 전 화면에는 즐겨찾기 버튼이 없다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsDetailScreen(
            nickname: null,
            platform: 'steam',
            repository: _EmptyStatsRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('즐겨찾기에 추가'), findsNothing);
  });
}
