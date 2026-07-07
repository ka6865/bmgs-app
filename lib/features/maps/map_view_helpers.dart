import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/bgms_theme.dart';

IconData getMarkerIcon(String layer) {
  return switch (layer) {
    'Garage' => Icons.local_taxi,
    'SecretRoom' => Icons.vpn_key,
    'Esports' => Icons.emoji_events,
    'HotDrop' => Icons.local_fire_department,
    'Glider' => Icons.airplanemode_active,
    'Boat' => Icons.directions_boat,
    'EsportsBoat' => Icons.sailing,
    'GoldenMirado' => Icons.directions_car,
    'EsportsMirado' => Icons.directions_car,
    'EsportsPickup' => Icons.local_shipping,
    'Porter' => Icons.local_shipping,
    'PoliceCar' => Icons.local_police,
    'Snowmobile' => Icons.snowmobile,
    'BearCave' => Icons.pets,
    'GasPump' => Icons.local_gas_station,
    _ => Icons.location_on,
  };
}

Color getMarkerColor(String layer) {
  return switch (layer) {
    'Garage' => Colors.greenAccent,
    'SecretRoom' => Colors.amberAccent,
    'Esports' => Colors.blueAccent,
    'HotDrop' => Colors.redAccent,
    'Glider' => Colors.cyanAccent,
    'Boat' => Colors.tealAccent,
    'EsportsBoat' => Colors.purpleAccent,
    'GoldenMirado' => const Color(0xFFEAB308),
    'EsportsMirado' => const Color(0xFFA855F7),
    'EsportsPickup' => const Color(0xFFD8B4FE),
    'Porter' => const Color(0xFF14B8A6),
    'PoliceCar' => const Color(0xFF3B82F6),
    'Snowmobile' => const Color(0xFF0EA5E9),
    'BearCave' => const Color(0xFF228B22),
    'GasPump' => const Color(0xFF84CC16),
    _ => BgmsColors.accent,
  };
}

String getCategoryLabel(String layer) {
  return switch (layer) {
    'Garage' => '차량',
    'SecretRoom' => '비밀방',
    'Esports' => '이스포츠',
    'HotDrop' => '핫드랍',
    'Glider' => '글라이더',
    'Boat' => '보트',
    'EsportsBoat' => '대회 보트',
    'GoldenMirado' => '황금 미라도',
    'EsportsMirado' => '대회 미라도',
    'EsportsPickup' => '대회 픽업',
    'Porter' => '포터',
    'PoliceCar' => '경찰차',
    'Snowmobile' => '스노우모빌',
    'BearCave' => '곰 동굴',
    'GasPump' => '주유소',
    _ => '기타',
  };
}

extension Matrix4ScaleExtension on Matrix4 {
  double getMaxScaleOnViewport() {
    final double x = storage[0];
    final double y = storage[1];
    final double z = storage[2];
    return math.sqrt(x * x + y * y + z * z);
  }
}
