import 'package:bgms_mobile_app/core/observability/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bgms_mobile_app/core/player/player_search_flow.dart';
import 'package:bgms_mobile_app/core/storage/local_player_store.dart';

void main() {
  test(
    'preparePlayerSearch trims, stores, and builds stats location',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalPlayerStore(prefs);

      final result = await preparePlayerSearch(
        store: store,
        nickname: '  kangheesung_  ',
        platform: 'steam',
      );

      expect(result?.nickname, 'kangheesung_');
      expect(result?.location, '/stats?nickname=kangheesung_&platform=steam');
      expect((await store.getRecentPlayers()).first.nickname, 'kangheesung_');
    },
  );

  test('preparePlayerSearch rejects blank nickname', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalPlayerStore(prefs);

    final result = await preparePlayerSearch(
      store: store,
      nickname: '   ',
      platform: 'kakao',
    );

    expect(result, isNull);
    expect(await store.getRecentPlayers(), isEmpty);
  });

  test(
    'preparePlayerSearch navigates when recent search storage fails',
    () async {
      final logger = InMemoryAppLogger();
      AppObservability.configure(logger: logger);
      addTearDown(() => AppObservability.configure(logger: DebugAppLogger()));

      final result = await preparePlayerSearch(
        store: _FailingLocalPlayerStore(),
        nickname: '  KakaoPlayer  ',
        platform: 'kakao',
      );

      expect(result?.location, '/stats?nickname=KakaoPlayer&platform=kakao');
      expect(logger.entries, hasLength(1));
      expect(logger.entries.single.level, AppLogLevel.warning);
      expect(logger.entries.single.context['operation'], 'add_recent_search');
    },
  );
}

class _FailingLocalPlayerStore extends Fake implements LocalPlayerStore {
  @override
  Future<void> addRecentSearch(String nickname, {String platform = 'steam'}) {
    throw StateError('storage unavailable');
  }
}
