import 'dart:async';
import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:bgms_mobile_app/features/maps/map_marker_overlay.dart';
import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:bgms_mobile_app/features/maps/maps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends MapsRepository {
  final firstSettings = Completer<Map<String, List<String>>>();
  int calls = 0;
  @override
  List<BgmsMap> get availableMaps => const [
    BgmsMap(id: 'Erangel', name: '에란겔', tilePath: 'Erangel'),
    BgmsMap(id: 'Miramar', name: '미라마', tilePath: 'Miramar'),
  ];
  @override
  Future<Map<String, List<String>>> fetchMapCategorySettings() => calls++ == 0
      ? firstSettings.future
      : Future.value({
          'Miramar': ['Boat'],
        });
  @override
  Future<MapMarkerLayer> fetchMarkers({
    required String mapId,
    required List<String> layers,
  }) async => MapMarkerLayer(
    mapId: mapId,
    source: MapMarkerSource.api,
    message: 'DB',
    markers: [
      MapMarker(
        id: mapId,
        label: mapId,
        layer: mapId == 'Miramar' ? 'Boat' : 'Garage',
        x: 0.1,
        y: 0.5,
        source: MapMarkerSource.api,
      ),
    ],
  );
}

void main() {
  MapMarker marker(String id, double x) => MapMarker(
    id: id,
    label: id,
    layer: 'Garage',
    x: x,
    y: 0.5,
    source: MapMarkerSource.api,
  );

  test('격자 경계의 겹치는 마커를 묶고 확대 후 떨어진 마커는 나눈다', () {
    final boundary = clusterMapMarkers(
      [marker('left', 0.47), marker('right', 0.49)],
      width: 100,
      height: 100,
      scale: 1,
    );
    expect(boundary.single.map((m) => m.id), ['left', 'right']);
    final chain = [marker('a', 0.1), marker('b', 0.4), marker('c', 0.7)];
    expect(
      clusterMapMarkers(chain, width: 100, height: 100, scale: 1).single,
      hasLength(3),
    );
    expect(
      clusterMapMarkers(chain, width: 100, height: 100, scale: 2),
      hasLength(3),
    );
  });

  testWidgets('경계 클러스터의 두 지점을 목록에서 각각 선택할 수 있다', (tester) async {
    MapMarker? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: MapMarkerOverlay(
                markers: [marker('왼쪽', 0.47), marker('오른쪽', 0.49)],
                scale: 1,
                onMarkerTap: (m) => selected = m,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(MapMarkerWidget), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '2'));
    await tester.pumpAndSettle();
    expect(find.text('왼쪽'), findsOneWidget);
    expect(find.text('오른쪽'), findsOneWidget);
    await tester.tap(find.text('오른쪽'));
    await tester.pumpAndSettle();
    expect(selected?.id, '오른쪽');
  });

  testWidgets('DB 설정 이후에도 필터와 마커는 처음에 숨기며 이전 맵 응답을 무시한다', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapsScreen(repository: repository)),
      ),
    );
    await tester.pump();
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(MapMarkerWidget), findsNothing);
    await tester.tap(find.text('미라마'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(MapMarkerWidget), findsNothing);
    await tester.tap(find.text('마커 필터'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, '보트'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '보트'));
    await tester.pumpAndSettle();
    expect(find.byType(MapMarkerWidget), findsOneWidget);
    repository.firstSettings.complete({
      'Erangel': ['Garage'],
    });
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, '보트'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '차량'), findsNothing);
    final mapRect = tester.getRect(find.byType(MapTileMosaic));
    final center = tester.getCenter(find.byType(MapMarkerWidget));
    expect(center.dx, closeTo(mapRect.left + mapRect.width * 0.1, 0.01));
    expect(center.dy, closeTo(mapRect.top + mapRect.height * 0.5, 0.01));
  });
}
