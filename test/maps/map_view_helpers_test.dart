import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/maps/map_view_helpers.dart';

void main() {
  test('getMarkerIcon returns valid IconData for each layer type', () {
    expect(getMarkerIcon('Garage'), Icons.local_taxi);
    expect(getMarkerIcon('SecretRoom'), Icons.vpn_key);
    expect(getMarkerIcon('Esports'), Icons.emoji_events);
    expect(getMarkerIcon('HotDrop'), Icons.local_fire_department);
    expect(getMarkerIcon('Glider'), Icons.airplanemode_active);
    expect(getMarkerIcon('Boat'), Icons.directions_boat);
    expect(getMarkerIcon('EsportsBoat'), Icons.sailing);
    expect(getMarkerIcon('Unknown'), Icons.location_on);
  });

  test('getMarkerColor returns corresponding color for layer', () {
    expect(getMarkerColor('Garage'), Colors.greenAccent);
    expect(getMarkerColor('SecretRoom'), Colors.amberAccent);
    expect(getMarkerColor('Esports'), Colors.blueAccent);
    expect(getMarkerColor('HotDrop'), Colors.redAccent);
    expect(getMarkerColor('Glider'), Colors.cyanAccent);
    expect(getMarkerColor('Boat'), Colors.tealAccent);
    expect(getMarkerColor('EsportsBoat'), Colors.purpleAccent);
  });

  test('getCategoryLabel maps english layer to korean label', () {
    expect(getCategoryLabel('Garage'), '차량');
    expect(getCategoryLabel('SecretRoom'), '비밀방');
    expect(getCategoryLabel('Esports'), '이스포츠');
    expect(getCategoryLabel('HotDrop'), '핫드랍');
    expect(getCategoryLabel('Glider'), '글라이더');
    expect(getCategoryLabel('Boat'), '보트');
    expect(getCategoryLabel('EsportsBoat'), '대회 보트');
    expect(getCategoryLabel('Unknown'), '기타');
  });
}
