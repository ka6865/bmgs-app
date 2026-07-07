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
    expect(getMarkerIcon('GoldenMirado'), Icons.directions_car);
    expect(getMarkerIcon('EsportsMirado'), Icons.directions_car);
    expect(getMarkerIcon('EsportsPickup'), Icons.local_shipping);
    expect(getMarkerIcon('Porter'), Icons.local_shipping);
    expect(getMarkerIcon('PoliceCar'), Icons.local_police);
    expect(getMarkerIcon('Snowmobile'), Icons.snowmobile);
    expect(getMarkerIcon('BearCave'), Icons.pets);
    expect(getMarkerIcon('GasPump'), Icons.local_gas_station);
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
    expect(getMarkerColor('GoldenMirado'), const Color(0xFFEAB308));
    expect(getMarkerColor('EsportsMirado'), const Color(0xFFA855F7));
    expect(getMarkerColor('EsportsPickup'), const Color(0xFFD8B4FE));
    expect(getMarkerColor('Porter'), const Color(0xFF14B8A6));
    expect(getMarkerColor('PoliceCar'), const Color(0xFF3B82F6));
    expect(getMarkerColor('Snowmobile'), const Color(0xFF0EA5E9));
    expect(getMarkerColor('BearCave'), const Color(0xFF228B22));
    expect(getMarkerColor('GasPump'), const Color(0xFF84CC16));
  });

  test('getCategoryLabel maps english layer to korean label', () {
    expect(getCategoryLabel('Garage'), '차량');
    expect(getCategoryLabel('SecretRoom'), '비밀방');
    expect(getCategoryLabel('Esports'), '이스포츠');
    expect(getCategoryLabel('HotDrop'), '핫드랍');
    expect(getCategoryLabel('Glider'), '글라이더');
    expect(getCategoryLabel('Boat'), '보트');
    expect(getCategoryLabel('EsportsBoat'), '대회 보트');
    expect(getCategoryLabel('GoldenMirado'), '황금 미라도');
    expect(getCategoryLabel('EsportsMirado'), '대회 미라도');
    expect(getCategoryLabel('EsportsPickup'), '대회 픽업');
    expect(getCategoryLabel('Porter'), '포터');
    expect(getCategoryLabel('PoliceCar'), '경찰차');
    expect(getCategoryLabel('Snowmobile'), '스노우모빌');
    expect(getCategoryLabel('BearCave'), '곰 동굴');
    expect(getCategoryLabel('GasPump'), '주유소');
    expect(getCategoryLabel('Unknown'), '기타');
  });
}
