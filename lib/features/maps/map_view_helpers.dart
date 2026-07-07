import 'package:flutter/material.dart';
import '../../core/theme/bgms_theme.dart';

IconData getMarkerIcon(String layer) {
  return switch (layer) {
    'Garage' => Icons.local_taxi,
    'SecretRoom' => Icons.vpn_key,
    'Esports' => Icons.emoji_events,
    'HotDrop' => Icons.local_fire_department,
    _ => Icons.location_on,
  };
}

Color getMarkerColor(String layer) {
  return switch (layer) {
    'Garage' => Colors.greenAccent,
    'SecretRoom' => Colors.amberAccent,
    'Esports' => Colors.blueAccent,
    'HotDrop' => Colors.redAccent,
    _ => BgmsColors.accent,
  };
}

String getCategoryLabel(String layer) {
  return switch (layer) {
    'Garage' => '차량',
    'SecretRoom' => '비밀방',
    'Esports' => '이스포츠',
    'HotDrop' => '핫드랍',
    _ => '기타',
  };
}
