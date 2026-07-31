import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면과 이동 결과 화면만 담은 최소 라우터.
GoRouter _createRouter({
  required Future<List<PlayerSuggestion>> Function(String query) fetcher,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: HomeScreen(suggestionFetcher: fetcher)),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => Text(state.uri.toString()),
      ),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('입력하면 후보 목록이 뜨고 플랫폼 배지를 함께 보여준다', (tester) async {
    final router = _createRouter(
      fetcher: (query) async => const [
        PlayerSuggestion(nickname: 'kangHeeSung_', platform: 'steam'),
        PlayerSuggestion(nickname: 'kangHee_kakao', platform: 'kakao'),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kang');
    // 디바운스(기본 300ms)가 지나야 조회가 시작된다.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('kangHeeSung_'), findsOneWidget);
    expect(find.text('kangHee_kakao'), findsOneWidget);
    expect(find.text('kakao'), findsOneWidget);
  });

  testWidgets('후보를 누르면 해당 플랫폼으로 전적 화면으로 이동한다', (tester) async {
    final router = _createRouter(
      fetcher: (query) async => const [
        PlayerSuggestion(nickname: 'kakaoOnlyPlayer', platform: 'kakao'),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kakao');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('kakaoOnlyPlayer'));
    await tester.pumpAndSettle();

    // 홈의 플랫폼 토글이 steam이어도 후보의 플랫폼을 따른다.
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/stats?nickname=kakaoOnlyPlayer&platform=kakao',
    );
  });

  testWidgets('두 글자 미만은 조회하지 않는다', (tester) async {
    var callCount = 0;
    final router = _createRouter(
      fetcher: (query) async {
        callCount++;
        return const [
          PlayerSuggestion(nickname: 'shouldNotAppear', platform: 'steam'),
        ];
      },
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'k');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.text('shouldNotAppear'), findsNothing);
  });

  testWidgets('조회가 실패해도 화면이 유지된다', (tester) async {
    final router = _createRouter(
      fetcher: (query) async => throw const ApiException(
        kind: ApiErrorKind.network,
        message: '네트워크 오류',
      ),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kang');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 자동완성은 보조 기능이므로 에러 화면으로 전환되지 않는다.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('빠른 메뉴'), findsOneWidget);
  });

  testWidgets('자동완성을 주입하지 않으면 후보 목록을 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kang');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_search), findsNothing);
  });
}
