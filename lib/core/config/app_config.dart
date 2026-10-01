class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.authRedirectUrl,
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  final String apiBaseUrl;
  final String authRedirectUrl;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  static const defaultAuthRedirectUrl = 'bgms://auth-callback';

  String get resolvedAuthRedirectUrl =>
      authRedirectUrl.isEmpty ? defaultAuthRedirectUrl : authRedirectUrl;

  bool get canInitializeSupabase =>
      supabaseUrl != null &&
      supabaseUrl!.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey!.isNotEmpty;

  /// 끝의 슬래시를 제거한 기준 URL.
  String get normalizedBaseUrl => apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  String get termsUrl => '$normalizedBaseUrl/terms';

  String get privacyUrl => '$normalizedBaseUrl/privacy';

  /// 웹과 동일한 랭크 티어 아이콘 경로를 만든다.
  ///
  /// 예: `Platinum`, `3` -> `https://bgms.kr/assets/rank/Platinum-3.webp`
  String tierIconUrl(String? tier, Object? subTier) {
    const unranked = 'Unranked';
    if (tier == null || tier.isEmpty || tier == '일반전' || tier == unranked) {
      return '$normalizedBaseUrl/assets/rank/$unranked.webp';
    }

    final clean = tier[0].toUpperCase() + tier.substring(1).toLowerCase();
    if (clean == 'Master' || clean == 'Survivor') {
      return '$normalizedBaseUrl/assets/rank/$clean.webp';
    }

    final sub = subTier?.toString();
    if (sub != null && const ['1', '2', '3', '4', '5'].contains(sub)) {
      return '$normalizedBaseUrl/assets/rank/$clean-$sub.webp';
    }
    return '$normalizedBaseUrl/assets/rank/$clean-1.webp';
  }

  /// 지도 타일 URL. 웹 Leaflet 타일 피라미드와 동일한 규칙이다.
  ///
  /// 한 변의 타일 수는 2^zoom이고 y좌표는 음수다. 화면 최상단 행이 가장 작은
  /// 값(-2^zoom)이고 최하단 행이 -1이다. 이 부호 규칙을 뒤집으면 지도가 남북으로
  /// 반전되고 행 경계에 이음선이 생긴다.
  ///
  /// 예: `Erangel`, z=3, col=0, row=0 -> `/tiles/Erangel/3/0/-8.jpg`
  String mapTileUrl({
    required String mapId,
    required int zoom,
    required int column,
    required int row,
  }) {
    final tilesPerSide = 1 << zoom;
    return '$normalizedBaseUrl/tiles/$mapId/$zoom/$column/${row - tilesPerSide}.jpg';
  }

  static const local = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'BGMS_API_BASE_URL',
      // 기본값은 운영 서버다. 로컬 개발 서버는
      // `--dart-define=BGMS_API_BASE_URL=http://localhost:3000`으로 지정한다.
      defaultValue: 'https://bgms.kr',
    ),
    authRedirectUrl: String.fromEnvironment(
      'BGMS_AUTH_REDIRECT_URL',
      defaultValue: defaultAuthRedirectUrl,
    ),
    supabaseUrl: String.fromEnvironment('BGMS_SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('BGMS_SUPABASE_ANON_KEY'),
  );
}
