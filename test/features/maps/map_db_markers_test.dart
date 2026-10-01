import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('좌표가 없거나 DB 원좌표가 잘못된 마커를 새 좌표로 보충하지 않는다', () {
    final layer = MapMarkerLayer.fromJson({
      'markers': [
        {
          'id': 'valid',
          'layer': 'Garage',
          'x': 0.3,
          'y': 0.5,
          'rawX': 2457.6,
          'rawY': 4096,
        },
        {'id': 'missing', 'layer': 'Garage'},
        {
          'id': 'invalid',
          'layer': 'Garage',
          'x': 0.5,
          'y': 0.5,
          'rawX': null,
          'rawY': 100,
        },
        {'id': 'bad', 'layer': 'Garage', 'x': -1, 'y': 0.5},
      ],
    }, mapId: 'Erangel');
    expect(layer.markers.map((marker) => marker.id), ['valid']);
    expect(layer.markers.single.x, 0.3);
  });
}
