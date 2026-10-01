import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'network/bgms_api_client.dart';
import 'storage/local_player_store.dart';

/// 실행 환경 설정. 테스트에서 override 한다.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.local);

/// Supabase 클라이언트. 초기화되지 않았으면 null이다.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.canInitializeSupabase) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    // main()에서 초기화되지 않은 환경(테스트 등)에서는 null로 취급한다.
    return null;
  }
});

/// 인증이 필요한 API에 붙일 access token을 제공한다. 만료 시 한 번 갱신한다.
final authTokenProvider = Provider<AuthTokenProvider>((ref) {
  return () async {
    final client = ref.read(supabaseClientProvider);
    final session = client?.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        final refreshed = await client!.auth.refreshSession();
        return refreshed.session?.accessToken;
      } catch (_) {
        return null;
      }
    }
    return session.accessToken;
  };
});

final dioProvider = Provider<Dio>((ref) => Dio());

/// 로그인 세션 변화를 구독한다. Supabase 미초기화 시 항상 null이다.
final authSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream<Session?>.value(null);
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// 설정 화면에 표기할 앱 버전.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final apiClientProvider = Provider<BgmsApiClient>((ref) {
  return BgmsApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    dio: ref.watch(dioProvider),
    authTokenProvider: ref.watch(authTokenProvider),
  );
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// 최근 검색/즐겨찾기 로컬 저장소.
final localPlayerStoreProvider = FutureProvider<LocalPlayerStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalPlayerStore(prefs);
});

final recentPlayersProvider = FutureProvider<List<StoredPlayer>>((ref) async {
  final store = await ref.watch(localPlayerStoreProvider.future);
  return store.getRecentPlayers();
});

final favoritePlayersProvider = FutureProvider<List<StoredPlayer>>((ref) async {
  final store = await ref.watch(localPlayerStoreProvider.future);
  return store.getFavoritePlayers();
});

/// 최근 검색/즐겨찾기 변경을 담당한다. 변경 후 관련 provider를 무효화한다.
class PlayerLibraryController {
  PlayerLibraryController(this._ref);

  final Ref _ref;

  Future<LocalPlayerStore> get _store =>
      _ref.read(localPlayerStoreProvider.future);

  void _invalidate() {
    _ref.invalidate(recentPlayersProvider);
    _ref.invalidate(favoritePlayersProvider);
  }

  Future<void> addRecent(String nickname, {required String platform}) async {
    final store = await _store;
    await store.addRecentSearch(nickname, platform: platform);
    _invalidate();
  }

  Future<void> toggleFavorite(
    String nickname, {
    required String platform,
  }) async {
    final store = await _store;
    await store.toggleFavorite(nickname, platform: platform);
    _invalidate();
  }

  Future<void> clearRecent() async {
    final store = await _store;
    await store.clearRecentSearches();
    _invalidate();
  }

  Future<void> clearFavorites() async {
    final store = await _store;
    await store.clearFavorites();
    _invalidate();
  }
}

final playerLibraryControllerProvider = Provider<PlayerLibraryController>(
  (ref) => PlayerLibraryController(ref),
);
