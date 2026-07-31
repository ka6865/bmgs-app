import 'dart:async';

import 'package:bgms_mobile_app/app.dart';
import 'package:bgms_mobile_app/core/storage/local_player_store.dart';
import 'package:bgms_mobile_app/features/home/home_screen.dart';
import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:bgms_mobile_app/features/maps/maps_screen.dart';
import 'package:bgms_mobile_app/features/maps/map_view_helpers.dart';
import 'package:bgms_mobile_app/features/stats/stats_detail_screen.dart';
import 'package:bgms_mobile_app/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home renders compact dashboard in empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    expect(find.text('PUBG 플레이어 검색'), findsOneWidget);
    expect(find.text('랭킹'), findsWidgets);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('게시판'), findsWidgets);
    expect(find.text('이어서 보기'), findsNothing);
    expect(find.text('즐겨찾는 플레이어'), findsOneWidget);
    expect(find.text('즐겨찾기를 추가하면 빠르게 전적을 확인할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('home separates latest, favorites, and activity', (tester) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': [
        'steam\tlatestPlayer',
        'kakao\tolderPlayer',
        'steam\toldestPlayer',
      ],
      'bgms_favorite_players': [
        'steam\tfavorite0',
        'steam\tfavorite1',
        'steam\tfavorite2',
        'steam\tfavorite3',
        'steam\tfavorite4',
        'steam\tfavorite5',
      ],
    });
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    expect(find.text('이어서 보기'), findsOneWidget);
    expect(find.textContaining('latestPlayer'), findsOneWidget);
    expect(find.text('즐겨찾는 플레이어'), findsOneWidget);
    expect(find.textContaining('favorite0'), findsOneWidget);
    expect(find.textContaining('favorite1'), findsOneWidget);
    expect(find.textContaining('favorite2'), findsOneWidget);
    expect(find.textContaining('favorite3'), findsOneWidget);
    expect(find.textContaining('favorite4'), findsOneWidget);
    expect(find.textContaining('favorite5'), findsNothing);
    expect(find.text('최근 활동'), findsOneWidget);
    expect(find.textContaining('olderPlayer'), findsOneWidget);
    expect(find.textContaining('oldestPlayer'), findsOneWidget);
  });

  testWidgets(
    'home startup search waits for storage and preserves platform URI',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencesReady = Completer<SharedPreferences>();
      final router = _createHomeSearchRouter(
        preferencesLoader: () => preferencesReady.future,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('Kakao'));
      await tester.enterText(find.byType(TextField), 'firstLaunchPlayer');
      await tester.tap(find.byKey(const Key('player_search_submit')));
      await tester.pump();

      await tester.tap(find.text('Kakao'));
      await tester.pump();

      expect(
        find.text('/stats?nickname=firstLaunchPlayer&platform=kakao'),
        findsNothing,
      );

      preferencesReady.complete(prefs);
      await tester.pumpAndSettle();

      expect(
        find.text('/stats?nickname=firstLaunchPlayer&platform=kakao'),
        findsOneWidget,
      );
      final store = LocalPlayerStore(await SharedPreferences.getInstance());
      final recent = await store.getRecentPlayers();
      expect(recent, hasLength(1));
      expect(recent.single.nickname, 'firstLaunchPlayer');
      expect(recent.single.platform, 'kakao');
    },
  );

  testWidgets(
    'home delayed search does not replace navigation after moving tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencesReady = Completer<SharedPreferences>();
      final router = createAppRouter(
        homePreferencesLoader: () => preferencesReady.future,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.enterText(find.byType(TextField), 'homeDelayedPlayer');
      await tester.tap(find.byKey(const Key('player_search_submit')));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.map).last);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/maps');

      preferencesReady.complete(prefs);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/maps');
    },
  );

  testWidgets('continue player tap preserves the stored platform', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['kakao\tcontinueKakaoPlayer'],
    });
    final router = _createHomeSearchRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final continuePlayer = find.byKey(const Key('home_continue_player'));
    expect(continuePlayer, findsOneWidget);
    await tester.tap(continuePlayer);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/stats?nickname=continueKakaoPlayer&platform=kakao',
    );
  });

  testWidgets(
    'home continue player favorite toggle updates storage and dashboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'bgms_recent_searches': ['kakao\tfavoriteCandidate'],
      });
      final store = LocalPlayerStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('즐겨찾기에 추가'));
      await tester.pumpAndSettle();

      expect(
        await store.isFavorite('favoriteCandidate', platform: 'kakao'),
        isTrue,
      );
      // 히어로 카드는 '닉네임 · 플랫폼' 한 줄, 즐겨찾기 타일은 닉네임과 플랫폼을 두 줄로 나눠 표시한다.
      expect(find.text('favoriteCandidate · kakao'), findsOneWidget);
      expect(find.text('favoriteCandidate'), findsOneWidget);
      expect(find.byTooltip('즐겨찾기 해제'), findsOneWidget);

      await tester.tap(find.byTooltip('즐겨찾기 해제'));
      await tester.pumpAndSettle();

      expect(
        await store.isFavorite('favoriteCandidate', platform: 'kakao'),
        isFalse,
      );
      expect(find.text('favoriteCandidate · kakao'), findsOneWidget);
      expect(find.text('favoriteCandidate'), findsNothing);
      expect(find.text('즐겨찾기를 추가하면 빠르게 전적을 확인할 수 있습니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'home refreshes recent players after a stats search and tab return',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = createAppRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.query_stats));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'searchedFromStats');
      await tester.tap(find.byKey(const Key('player_search_submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
      await tester.pumpAndSettle();

      expect(find.text('searchedFromStats · steam'), findsOneWidget);
    },
  );

  testWidgets('home refreshes after my clears recent players and favorites', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['steam\tmanagedPlayer'],
      'bgms_favorite_players': ['steam\tmanagedPlayer'],
    });
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('즐겨찾기 해제'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();

    expect(find.text('managedPlayer · steam'), findsNothing);
    expect(find.text('즐겨찾기를 추가하면 빠르게 전적을 확인할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('home search shows validation message for empty nickname', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('player_search_submit')));
    await tester.pumpAndSettle();

    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
    expect(find.text('PUBG 플레이어 검색'), findsOneWidget);
  });

  testWidgets('home search clear button appears with input and resets it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    // 입력이 비어 있으면 지우기 버튼을 노출하지 않는다.
    expect(find.byTooltip('입력 지우기'), findsNothing);

    await tester.enterText(find.byType(TextField), 'typoNickname');
    await tester.pump();
    expect(find.byTooltip('입력 지우기'), findsOneWidget);

    await tester.tap(find.byTooltip('입력 지우기'));
    await tester.pump();

    expect(find.text('typoNickname'), findsNothing);
    expect(find.byTooltip('입력 지우기'), findsNothing);
  });

  testWidgets('bottom tab opens rankings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('랭킹').last);
    await tester.pumpAndSettle();

    expect(find.text('딜량'), findsOneWidget);
  });

  testWidgets('bottom tab opens maps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지도').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '에란겔'), findsOneWidget);
  });

  testWidgets('bottom tab opens board', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('게시판').last);
    await tester.pumpAndSettle();

    // 하단 탭에 '게시판'이 있으므로 화면 제목은 중복되지 않는 이름을 쓴다.
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.byTooltip('글쓰기'), findsOneWidget);
  });

  testWidgets('home bell opens the notification center', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    // 앞선 테스트가 남긴 라우터 위치와 무관하게 홈에서 시작한다.
    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();

    // 알림 센터는 하단 탭에 없고 홈 헤더의 벨이 진입 경로다.
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();

    expect(find.byTooltip('모두 읽음'), findsOneWidget);

    // push로 열린 화면이므로 닫아서 다음 테스트에 셸 상태를 남기지 않는다.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
  });

  testWidgets('stats tab shows analysis workspace without home duplicates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['steam\tkangheesung_'],
      'bgms_favorite_players': ['kakao\tbgmsTester'],
    });
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('전적'));
    await tester.pumpAndSettle();

    expect(find.text('전적 분석'), findsOneWidget);
    expect(find.byKey(const Key('player_search_submit')), findsOneWidget);
    expect(find.text('최근 분석'), findsOneWidget);
    expect(find.text('kangheesung_ · steam'), findsOneWidget);
    expect(find.text('즐겨찾기'), findsNothing);
    expect(find.text('다음 업데이트'), findsNothing);
    expect(find.textContaining('비교 모드'), findsNothing);
    expect(find.textContaining('bgmsTester'), findsNothing);
  });

  testWidgets('stats search hub uses the selected and recent player platform', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['kakao\trecentKakaoPlayer'],
    });
    final router = _createStatsSearchRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kakao'));
    await tester.enterText(find.byType(TextField), 'analysisKakaoPlayer');
    await tester.tap(find.byKey(const Key('player_search_submit')));
    await tester.pump();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/stats?nickname=analysisKakaoPlayer&platform=kakao',
    );

    router.go('/stats');
    await tester.pumpAndSettle();
    final recentPlayer = find.text('recentKakaoPlayer · kakao');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: recentPlayer, matching: find.byType(InputChip)),
    );
    await tester.pump();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/stats?nickname=recentKakaoPlayer&platform=kakao',
    );
  });

  testWidgets('rankings tab renders ranking controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('랭킹'), findsWidgets);
    expect(find.text('딜량'), findsOneWidget);
    expect(find.textContaining('주간 딜량'), findsWidgets);
  });

  testWidgets('maps tab renders map selectors and layers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();

    expect(find.text('지도'), findsWidgets);
    expect(find.widgetWithText(ChoiceChip, '에란겔'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '미라마'), findsOneWidget);
    expect(find.text('차량'), findsWidgets);
  });

  testWidgets('my tab renders empty local store state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    // 하단 탭 라벨이 '마이'이므로 화면 제목은 '내 정보'로 구분한다.
    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('로그인 준비 상태'), findsOneWidget);
    expect(find.text('최근 검색이 없습니다.'), findsOneWidget);
    expect(find.text('즐겨찾기가 없습니다.'), findsOneWidget);
  });

  testWidgets('my tab player row opens stats with stored platform', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['kakao\tmyTabPlayer'],
    });
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    await tester.tap(find.text('myTabPlayer'));
    await tester.pumpAndSettle();

    // 전적 화면으로 이동해 저장된 플랫폼(kakao)이 유지되는지 확인한다.
    expect(find.text('전적'), findsWidgets);
    expect(find.text('myTabPlayer'), findsWidgets);
    expect(find.text('최근 검색이 없습니다.'), findsNothing);
  });

  testWidgets('my tab clear recent offers undo and restores the list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bgms_recent_searches': ['steam\tundoPlayer'],
    });
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    await tester.tap(find.text('전체 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('최근 검색이 없습니다.'), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    // 되돌리기로 삭제한 항목이 복구된다.
    expect(find.text('undoPlayer'), findsOneWidget);
    expect(find.text('최근 검색이 없습니다.'), findsNothing);
  });

  testWidgets('my tab exposes terms, privacy policy and app version', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp(enableSuggestions: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('약관 및 정보'), 200);
    await tester.pumpAndSettle();

    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
    expect(find.text('BGMS 웹사이트'), findsOneWidget);
    expect(find.text('앱 버전'), findsOneWidget);
  });

  testWidgets('maps screen renders markers and opens bottom sheet on tap', (
    tester,
  ) async {
    final fakeRepo = FakeMapsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapsScreen(repository: fakeRepo)),
      ),
    );

    // FutureBuilder 완료 대기
    await tester.pumpAndSettle();

    final markerFinder = find.byIcon(Icons.local_taxi);
    await tester.ensureVisible(markerFinder);
    await tester.pumpAndSettle();

    // 마커 아이콘 렌더링 확인 (Garage 레이어는 local_taxi 아이콘)
    expect(markerFinder, findsOneWidget);

    // 마커 탭 실행
    await tester.tap(markerFinder);
    await tester.pumpAndSettle();

    // 바텀시트 콘텐츠 확인
    expect(find.text('강남 차고지'), findsWidgets);
    expect(find.text('차량'), findsWidgets);
    expect(find.textContaining('위치 좌표: (X: 50.0%, Y: 50.0%)'), findsOneWidget);
    expect(find.textContaining('강남 차고지은(는) 차량 분류 지점입니다.'), findsOneWidget);

    // 닫기 버튼 탭 후 바텀시트가 사라지는지 검증
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('위치 좌표: (X: 50.0%, Y: 50.0%)'), findsNothing);
  });

  testWidgets(
    'maps screen opens fullscreen map and handles marker tap and back',
    (tester) async {
      final fakeRepo = FakeMapsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapsScreen(repository: fakeRepo)),
        ),
      );

      await tester.pumpAndSettle();

      // 1. 전체화면 버튼 확인 및 탭
      final fullscreenBtnFinder = find.byIcon(Icons.fullscreen);
      expect(fullscreenBtnFinder, findsOneWidget);
      await tester.ensureVisible(fullscreenBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(fullscreenBtnFinder);
      await tester.pumpAndSettle();

      // 2. 전체화면 모달 진입 확인 (정밀 지도 타이틀 확인)
      expect(find.text('Erangel 정밀 지도'), findsOneWidget);

      // 3. 전체화면 뷰 내의 마커 탭 실행
      final markerFinder = find.byIcon(Icons.local_taxi);
      expect(markerFinder, findsOneWidget);
      await tester.tap(markerFinder);
      await tester.pumpAndSettle();

      // 4. 바텀시트 콘텐츠 확인 (전체화면 내에서 onTap -> showMarkerDetails 실행됨)
      expect(find.text('강남 차고지'), findsWidgets);
      expect(
        find.textContaining('위치 좌표: (X: 50.0%, Y: 50.0%)'),
        findsOneWidget,
      );

      // 5. 바텀시트 닫기 버튼 탭 (가장 나중에 렌더링된 close 아이콘)
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      // 바텀시트가 닫혀서 전체화면 정밀 지도가 다시 단독 노출되는지 확인
      expect(find.textContaining('위치 좌표: (X: 50.0%, Y: 50.0%)'), findsNothing);

      // 6. 전체화면 AppBar의 닫기 버튼 탭
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 원래 화면으로 돌아왔는지 확인
      expect(find.text('Erangel 정밀 지도'), findsNothing);
    },
  );

  testWidgets('maps screen zoom in compensates marker scale', (tester) async {
    final fakeRepo = FakeMapsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapsScreen(repository: fakeRepo)),
      ),
    );

    await tester.pumpAndSettle();

    // 1. InteractiveViewer 찾기
    final interactiveViewerFinder = find.byType(InteractiveViewer);
    expect(interactiveViewerFinder, findsOneWidget);

    final interactiveViewer = tester.widget<InteractiveViewer>(
      interactiveViewerFinder,
    );
    final controller = interactiveViewer.transformationController;
    expect(
      controller,
      isNotNull,
      reason:
          'InteractiveViewer should have a transformationController assigned',
    );

    // 2. 초기 줌 배율 (1.0) 확인 - Transform.scale의 scale이 1.0인지 확인
    final transformFinder = find
        .ancestor(
          of: find.byType(MapMarkerWidget),
          matching: find.byType(Transform),
        )
        .first;
    expect(transformFinder, findsOneWidget);

    Transform transformWidget = tester.widget<Transform>(transformFinder);
    expect(
      transformWidget.transform.getMaxScaleOnViewport(),
      closeTo(1.0, 0.001),
    );

    // 3. 줌 배율을 3.0으로 변경
    controller!.value = Matrix4.diagonal3Values(3.0, 3.0, 1.0);
    // 리스너 호출 및 리빌드
    await tester.pump();

    // 4. 역보정된 스케일(1/3.0 = 0.3333) 확인
    final transformFinderAfter = find
        .ancestor(
          of: find.byType(MapMarkerWidget),
          matching: find.byType(Transform),
        )
        .first;
    transformWidget = tester.widget<Transform>(transformFinderAfter);
    expect(
      transformWidget.transform.getMaxScaleOnViewport(),
      closeTo(1.0 / 3.0, 0.001),
    );
  });
}

GoRouter _createHomeSearchRouter({
  Future<SharedPreferences> Function()? preferencesLoader,
}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(preferencesLoader: preferencesLoader),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => Text(state.uri.toString()),
      ),
    ],
  );
}

GoRouter _createStatsSearchRouter() {
  return GoRouter(
    initialLocation: '/stats',
    routes: [
      GoRoute(
        path: '/stats',
        builder: (context, state) {
          if (state.uri.queryParameters['nickname'] != null) {
            return Text(state.uri.toString());
          }
          return const StatsDetailScreen(nickname: null, platform: 'steam');
        },
      ),
    ],
  );
}

class FakeMapsRepository extends Fake implements MapsRepository {
  @override
  List<BgmsMap> get availableMaps => const [
    BgmsMap(id: 'Erangel', name: 'Erangel', tilePath: 'Erangel'),
  ];

  @override
  BgmsMap resolveMap(String? mapId) => availableMaps.first;

  @override
  Future<MapMarkerLayer> fetchMarkers({
    required String mapId,
    required List<String> layers,
  }) async {
    return const MapMarkerLayer(
      mapId: 'Erangel',
      source: MapMarkerSource.api,
      message: 'Mocked markers',
      markers: [
        MapMarker(
          id: '1',
          label: '강남 차고지',
          layer: 'Garage',
          x: 0.5,
          y: 0.5,
          source: MapMarkerSource.api,
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> fetchAdminSettings() async {
    return {};
  }

  @override
  Future<Map<String, List<String>>> fetchMapCategorySettings() async {
    return {};
  }

  @override
  List<String> filterActiveLayers(
    String mapId,
    List<String> availableLayers,
    Map<String, List<String>> settings,
  ) {
    return availableLayers;
  }
}
