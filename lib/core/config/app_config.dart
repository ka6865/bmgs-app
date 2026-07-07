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

  static const local = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'BGMS_API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
    authRedirectUrl: String.fromEnvironment(
      'BGMS_AUTH_REDIRECT_URL',
      defaultValue: defaultAuthRedirectUrl,
    ),
    supabaseUrl: String.fromEnvironment('BGMS_SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('BGMS_SUPABASE_ANON_KEY'),
  );
}
