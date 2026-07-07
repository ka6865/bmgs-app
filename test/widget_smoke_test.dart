import 'package:bgms_mobile_app/app.dart';
import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:bgms_mobile_app/features/maps/maps_screen.dart';
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
}
