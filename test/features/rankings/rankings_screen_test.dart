import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/core/theme/app_theme.dart';
import 'package:bgms_mobile_app/features/rankings/rankings_repository.dart';
import 'package:bgms_mobile_app/features/rankings/rankings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

Map<String, Object> _rankingsResponse() {
  return {
    'entries': [
      {'rank': 1, 'nickname': 'alpha', 'platform': 'steam', 'damage': 812.5},
      {'rank': 2, 'nickname': 'beta', 'platform': 'kakao', 'damage': 640.0},
      {'rank': 4, 'nickname': 'delta', 'platform': 'steam', 'damage': 320.0},
    ],
  };
}

Future<void> _pumpRankings(WidgetTester tester, FakeHttpAdapter adapter) async {
  final repository = RankingsRepository(
    client: BgmsApiClient(
      baseUrl: 'https://bgms.kr',
      dio: createFakeDio(adapter),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: RankingsScreen(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('랭킹 응답을 순위 목록으로 렌더링한다', (tester) async {
    final adapter = FakeHttpAdapter();
    adapter.stub('/api/rankings', _rankingsResponse());

    await _pumpRankings(tester, adapter);

    expect(find.text('주간 딜량 랭킹'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('813 딜'), findsOneWidget);
    expect(find.text('KAKAO'), findsOneWidget);
  });

  testWidgets('탭을 바꾸면 해당 지표 단위로 표시한다', (tester) async {
    final adapter = FakeHttpAdapter();
    adapter.stub('/api/rankings', {
      'entries': [
        {'rank': 1, 'nickname': 'alpha', 'platform': 'steam', 'kills': 12},
      ],
    });

    await _pumpRankings(tester, adapter);
    await tester.tap(find.text('킬'));
    await tester.pumpAndSettle();

    expect(find.text('주간 킬 랭킹'), findsOneWidget);
    expect(find.text('12 킬'), findsOneWidget);
  });

  testWidgets('필터를 고르면 쿼리에 반영하고 초기화 버튼이 나온다', (tester) async {
    final adapter = FakeHttpAdapter();
    adapter.stub('/api/rankings', _rankingsResponse());

    await _pumpRankings(tester, adapter);
    expect(find.text('필터 초기화'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '스쿼드'));
    await tester.pumpAndSettle();

    expect(adapter.requestedPaths.last, contains('mode=squad'));
    expect(find.text('필터 초기화'), findsOneWidget);

    await tester.tap(find.text('필터 초기화'));
    await tester.pumpAndSettle();

    expect(adapter.requestedPaths.last, contains('mode=all'));
    expect(find.text('필터 초기화'), findsNothing);
  });

  testWidgets('API가 없으면 준비 중 안내와 재시도를 보여준다', (tester) async {
    final adapter = FakeHttpAdapter();
    adapter.stub('/api/rankings', {'error': 'not found'}, statusCode: 404);

    await _pumpRankings(tester, adapter);

    expect(find.textContaining('준비 중'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('재시도를 누르면 랭킹을 다시 요청한다', (tester) async {
    final adapter = FakeHttpAdapter();
    adapter.stub('/api/rankings', {}, statusCode: 500);

    await _pumpRankings(tester, adapter);
    final requestsBefore = adapter.requestedPaths.length;

    adapter.stub('/api/rankings', _rankingsResponse());
    await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
    await tester.pumpAndSettle();

    expect(adapter.requestedPaths.length, greaterThan(requestsBefore));
    expect(find.text('alpha'), findsOneWidget);
  });
}
