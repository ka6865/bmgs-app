import 'package:bgms_mobile_app/app.dart';
import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:bgms_mobile_app/features/maps/maps_screen.dart';
import 'package:bgms_mobile_app/features/maps/map_view_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('BGMS app renders home tab with search controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp());
    await tester.pumpAndSettle();

    expect(find.text('BGMS'), findsWidgets);
    expect(find.text('닉네임 검색'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);
    expect(find.text('Steam'), findsOneWidget);
    expect(find.text('Kakao'), findsOneWidget);
    expect(find.text('검색한 닉네임이 여기에 저장됩니다.'), findsOneWidget);
  });

  testWidgets('stats tab shows empty state without nickname', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('전적'));
    await tester.pumpAndSettle();

    expect(find.text('검색할 닉네임이 없습니다'), findsOneWidget);
    expect(find.textContaining('홈에서 Steam 또는 Kakao'), findsOneWidget);
  });

  testWidgets('rankings tab renders ranking controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('랭킹'), findsWidgets);
    expect(find.text('딜량'), findsOneWidget);
  });

  testWidgets('maps tab renders map selectors and layers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();

    expect(find.text('지도'), findsWidgets);
    expect(find.text('맵 선택'), findsOneWidget);
    expect(find.text('차량'), findsWidgets);
  });

  testWidgets('my tab renders empty local store state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BgmsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    expect(find.text('마이'), findsWidgets);
    expect(find.text('로그인 준비 상태'), findsOneWidget);
    expect(find.text('최근 검색이 없습니다.'), findsOneWidget);
    expect(find.text('즐겨찾기가 없습니다.'), findsOneWidget);
  });

  testWidgets('maps screen renders markers and opens bottom sheet on tap', (tester) async {
    final fakeRepo = FakeMapsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapsScreen(repository: fakeRepo),
        ),
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

  testWidgets('maps screen opens fullscreen map and handles marker tap and back', (tester) async {
    final fakeRepo = FakeMapsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapsScreen(repository: fakeRepo),
        ),
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
    expect(find.textContaining('위치 좌표: (X: 50.0%, Y: 50.0%)'), findsOneWidget);

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
  });

  testWidgets('maps screen zoom in compensates marker scale', (tester) async {
    final fakeRepo = FakeMapsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapsScreen(repository: fakeRepo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. InteractiveViewer 찾기
    final interactiveViewerFinder = find.byType(InteractiveViewer);
    expect(interactiveViewerFinder, findsOneWidget);

    final interactiveViewer = tester.widget<InteractiveViewer>(interactiveViewerFinder);
    final controller = interactiveViewer.transformationController;
    expect(controller, isNotNull, reason: 'InteractiveViewer should have a transformationController assigned');

    // 2. 초기 줌 배율 (1.0) 확인 - Transform.scale의 scale이 1.0인지 확인
    final transformFinder = find.ancestor(
      of: find.byType(MapMarkerWidget),
      matching: find.byType(Transform),
    ).first;
    expect(transformFinder, findsOneWidget);
    
    Transform transformWidget = tester.widget<Transform>(transformFinder);
    expect(transformWidget.transform.getMaxScaleOnViewport(), closeTo(1.0, 0.001));

    // 3. 줌 배율을 3.0으로 변경
    controller!.value = Matrix4.diagonal3Values(3.0, 3.0, 1.0);
    // 리스너 호출 및 리빌드
    await tester.pump();

    // 4. 역보정된 스케일(1/3.0 = 0.3333) 확인
    final transformFinderAfter = find.ancestor(
      of: find.byType(MapMarkerWidget),
      matching: find.byType(Transform),
    ).first;
    transformWidget = tester.widget<Transform>(transformFinderAfter);
    expect(transformWidget.transform.getMaxScaleOnViewport(), closeTo(1.0 / 3.0, 0.001));
  });
}

class FakeMapsRepository extends Fake implements MapsRepository {
  @override
  List<BgmsMap> get availableMaps => const [
        BgmsMap(
          id: 'Erangel',
          name: 'Erangel',
          assetPath: 'assets/maps/Erangel_HeightMap.jpg',
          tilePath: 'Erangel',
        ),
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
  List<String> filterActiveLayers(
    String mapId,
    List<String> availableLayers,
    Map<String, dynamic> settings,
  ) {
    return availableLayers;
  }
}
