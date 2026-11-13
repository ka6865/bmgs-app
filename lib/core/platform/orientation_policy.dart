import 'package:flutter/services.dart';

/// 휴대폰은 세로로 고정하고, 리플레이 화면과 넓은 화면(태블릿·펼친 폴드)은 회전을 허용한다.
class OrientationPolicy {
  OrientationPolicy._();

  static bool? _wide;
  static int _rotatableScreens = 0;

  /// 앱 루트가 화면 크기가 바뀔 때마다 알린다. 짧은 변 600 이상이면 넓은 화면이다.
  static void setWide(bool wide) {
    if (_wide == wide) return;
    _wide = wide;
    _apply();
  }

  /// 회전이 필요한 화면이 열릴 때와 닫힐 때 짝지어 부른다.
  static void enterRotatable() {
    _rotatableScreens++;
    _apply();
  }

  static void exitRotatable() {
    if (_rotatableScreens > 0) _rotatableScreens--;
    _apply();
  }

  static void _apply() {
    final free = (_wide ?? false) || _rotatableScreens > 0;
    // 빈 목록은 기기가 지원하는 모든 방향을 뜻한다.
    SystemChrome.setPreferredOrientations(
      free ? const [] : const [DeviceOrientation.portraitUp],
    );
  }
}
