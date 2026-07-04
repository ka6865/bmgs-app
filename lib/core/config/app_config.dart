class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.supabaseUrl,
    this.supabaseAnonKey,
  });

  final String apiBaseUrl;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

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
    supabaseUrl: String.fromEnvironment('BGMS_SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('BGMS_SUPABASE_ANON_KEY'),
  );
}
