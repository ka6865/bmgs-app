import 'package:bgms_mobile_app/features/stats/player_match_history_models.dart';
import 'package:bgms_mobile_app/features/stats/player_match_history_repository.dart';
import 'package:bgms_mobile_app/features/stats/player_match_history_screen.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'dart:async';

import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('최근 전적 수집 쿨다운은 이력 GET을 허용하고 만료·계정 변경 시 해제된다', (tester) async {
    final repository = _CollectHistoryRepository();
    final availableAt = DateTime.now().add(const Duration(seconds: 60));
    await tester.pumpWidget(
      _historyApp(repository, initialCollectAvailableAt: availableAt),
    );
    await tester.pumpAndSettle();
    expect(find.text('DB 저장 1경기 · 1/1페이지'), findsOneWidget);
    expect(find.text('호출 제한 · 잠시 후 수집 가능'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('저장 이력 새로고침'));
    await tester.pumpAndSettle();
    expect(repository.calls, ['GET:Player:1', 'GET:Player:1']);
    expect(repository.collectCalls, 0);
    await tester.pump(const Duration(seconds: 61));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox());
    final nextAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    await tester.pumpWidget(
      _historyApp(repository, initialCollectAvailableAt: nextAvailableAt),
    );
    await tester.pumpAndSettle();
    expect(find.text('호출 제한 · 잠시 후 수집 가능'), findsOneWidget);
    await tester.pumpWidget(
      _historyApp(
        repository,
        nickname: 'Other',
        initialCollectAvailableAt: nextAvailableAt,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other DB 경기 이력'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _historyApp(
        repository,
        initialCollectAvailableAt: DateTime.now().subtract(
          const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(repository.collectCalls, 0);
  });

  testWidgets('빈 중간 페이지에서도 다음 페이지와 DB 총 건수를 표시한다', (tester) async {
    final repository = _HistoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerMatchHistoryScreen(
          profile: PlayerStatsProfile.fromJson({
            'nickname': 'Player',
            'platform': 'steam',
          }),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DB 저장 25경기 · 1/2페이지'), findsOneWidget);
    expect(find.textContaining('수집 대기 상태 불명'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.pages, [1, 2]);
    expect(find.text('DB 저장 25경기 · 2/2페이지'), findsOneWidget);
    expect(find.text('에란겔'), findsOneWidget);
    await tester.tap(find.text('경쟁'));
    await tester.pumpAndSettle();
    expect(repository.pages, [1, 2, 1]);
    expect(repository.filters.last, 'ranked');
  });
  testWidgets('수집은 중복 요청 없이 POST 후 첫 페이지 GET을 읽는다', (tester) async {
    final repository = _CollectHistoryRepository();
    await tester.pumpWidget(_historyApp(repository));
    await tester.pumpAndSettle();
    final collect = find.text('대기 경기 수집 · 새로고침');
    await tester.tap(collect);
    await tester.pump();
    expect(repository.collectCalls, 1);
    final active = find.text('수집 중…');
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: active, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    repository.completer.complete(
      PlayerMatchCollectionResult.fromJson({
        'collection': {
          'claimed': 3,
          'saved': 3,
          'alreadyStored': 2,
          'retry': 0,
          'unavailable': 0,
          'rateLimited': false,
        },
        'historyIngest': {'pendingCount': 0, 'unavailableCount': 1},
      }),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, ['GET:Player:1', 'POST:Player', 'GET:Player:1']);
    expect(find.text('DB 저장 3경기 · 1/1페이지'), findsOneWidget);
    expect(find.textContaining('신규 저장 1경기 · 기존 저장 확인 2경기'), findsOneWidget);
    expect(find.textContaining('수집 대기 0경기'), findsOneWidget);
  });

  testWidgets('수집 429는 이전 DB 이력과 페이지를 유지하고 수집 버튼만 제한한다', (tester) async {
    final repository = _CollectHistoryRepository();
    await tester.pumpWidget(_historyApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대기 경기 수집 · 새로고침'));
    await tester.pump();
    repository.completer.completeError(
      const ApiException(
        kind: ApiErrorKind.rateLimited,
        message: '수집 한도',
        retryAfter: Duration(seconds: 60),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DB 저장 1경기 · 1/1페이지'), findsOneWidget);
    expect(find.text('에란겔'), findsOneWidget);
    expect(find.textContaining('이전 이력을 유지합니다.'), findsOneWidget);
    expect(repository.calls, ['GET:Player:1', 'POST:Player']);
    final cooling = find.text('호출 제한 · 잠시 후 수집 가능');
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: cooling, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('프로필 변경 후 늦게 온 수집 결과가 새 프로필 이력을 덮지 않는다', (tester) async {
    final repository = _CollectHistoryRepository();
    await tester.pumpWidget(_historyApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대기 경기 수집 · 새로고침'));
    await tester.pump();
    await tester.pumpWidget(_historyApp(repository, nickname: 'Other'));
    await tester.pumpAndSettle();
    repository.completer.complete(
      PlayerMatchCollectionResult.fromJson({
        'collection': {'saved': 3, 'alreadyStored': 0},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other DB 경기 이력'), findsOneWidget);
    expect(repository.calls, ['GET:Player:1', 'POST:Player', 'GET:Other:1']);
    expect(find.textContaining('신규 저장 3경기'), findsNothing);
    expect(find.text('DB 저장 7경기 · 1/1페이지'), findsOneWidget);
  });
}

class _HistoryRepository extends Fake implements PlayerMatchHistoryRepository {
  final pages = <int>[];
  final filters = <String>[];

  @override
  Future<PlayerMatchHistoryPage> fetchPage({
    required String nickname,
    required String platform,
    int page = 1,
    String filter = 'all',
  }) async {
    pages.add(page);
    filters.add(filter);
    return PlayerMatchHistoryPage.fromJson({
      'page': page,
      'totalPages': 2,
      'totalCount': 25,
      'matches': page == 1
          ? []
          : [
              {
                'match_id': 'last-match',
                'map_name': 'Baltic_Main',
                'game_mode': 'squad',
                'kills': 0,
                'damage': 0,
                'win_place': 30,
              },
            ],
    });
  }
}

Widget _historyApp(
  PlayerMatchHistoryRepository repository, {
  String nickname = 'Player',
  DateTime? initialCollectAvailableAt,
}) => MaterialApp(
  home: PlayerMatchHistoryScreen(
    profile: PlayerStatsProfile.fromJson({
      'nickname': nickname,
      'platform': 'steam',
    }),
    repository: repository,
    initialCollectAvailableAt: initialCollectAvailableAt,
  ),
);

class _CollectHistoryRepository extends Fake
    implements PlayerMatchHistoryRepository {
  final calls = <String>[];
  final completer = Completer<PlayerMatchCollectionResult>();
  int collectCalls = 0;
  int getCalls = 0;

  @override
  Future<PlayerMatchHistoryPage> fetchPage({
    required String nickname,
    required String platform,
    int page = 1,
    String filter = 'all',
  }) async {
    calls.add('GET:$nickname:$page');
    getCalls++;
    return PlayerMatchHistoryPage.fromJson({
      'page': page,
      'totalPages': 1,
      'totalCount': nickname == 'Other'
          ? 7
          : getCalls == 1
          ? 1
          : 3,
      'historyIngest': {
        'pendingCount': getCalls == 1 ? 2 : 0,
        'unavailableCount': 1,
      },
      'matches': [
        {
          'match_id': nickname,
          'map_name': 'Baltic_Main',
          'game_mode': 'squad',
          'kills': 0,
          'damage': 0,
          'win_place': 20,
        },
      ],
    });
  }

  @override
  Future<PlayerMatchCollectionResult> collect({
    required String nickname,
    required String platform,
  }) {
    collectCalls++;
    calls.add('POST:$nickname');
    return completer.future;
  }
}
