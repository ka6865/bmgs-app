import 'package:bgms_mobile_app/features/notifications/notification_models.dart';
import 'package:bgms_mobile_app/features/notifications/notification_presenter.dart';
import 'package:bgms_mobile_app/features/notifications/notification_service.dart';
import 'package:bgms_mobile_app/features/notifications/notification_settings.dart';
import 'package:bgms_mobile_app/features/notifications/notification_store.dart';
import 'package:bgms_mobile_app/core/storage/local_player_store.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 7, 31, 12);

/// 지정한 매치 목록을 돌려주는 fake. 실패를 주입할 수도 있다.
class _FakeStatsRepository extends PlayerStatsRepository {
  _FakeStatsRepository({this.matchIds = const ['match-1'], this.error});

  List<String> matchIds;
  Object? error;
  int callCount = 0;

  @override
  Future<PlayerStatsBundle> fetchPlayerStats({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
  }) async {
    callCount++;
    final failure = error;
    if (failure != null) throw failure;

    return PlayerStatsBundle(
      profile: PlayerStatsProfile(
        nickname: nickname,
        platform: platform,
        seasonId: 'season-42',
        kd: 1,
        adr: 300,
        winRate: 10,
        averageRank: 20,
        roundsPlayed: 30,
        recentMatches: matchIds,
        matchModes: const {},
        seasonsList: const [],
        updatedAt: _now,
        modeStats: const {},
      ),
      matches: const [],
      summaryFallback: false,
    );
  }
}

class _RecordingPresenter implements NotificationPresenter {
  _RecordingPresenter({this.granted = true});

  bool granted;
  final List<BgmsNotification> shown = [];

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> show(BgmsNotification notification) async {
    shown.add(notification);
  }
}

Future<({NotificationStore store, LocalPlayerStore players})> _buildStores({
  List<String> favorites = const ['tester'],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final players = LocalPlayerStore(prefs);
  for (final nickname in favorites) {
    await players.toggleFavorite(nickname, platform: 'steam');
  }
  return (store: NotificationStore(prefs), players: players);
}

void main() {
  test('첫 확인은 스냅샷만 저장하고 알림을 만들지 않는다', () async {
    final stores = await _buildStores();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: _FakeStatsRepository(),
      clock: () => _now,
    );

    expect(await service.checkNow(), 0);
    expect(stores.store.getSnapshot('steam:tester'), isNotNull);
  });

  test('두 번째 확인에서 새 매치를 알림으로 만든다', () async {
    final stores = await _buildStores();
    final repository = _FakeStatsRepository(matchIds: const ['match-1']);
    final presenter = _RecordingPresenter();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      presenter: presenter,
      clock: () => _now,
    );

    await service.checkNow();
    repository.matchIds = const ['match-2', 'match-1'];
    final created = await service.checkNow();

    expect(created, 1);
    expect(stores.store.getNotifications(), hasLength(1));
    expect(presenter.shown, hasLength(1));
  });

  test('권한이 없으면 OS 알림은 띄우지 않고 목록에만 쌓는다', () async {
    final stores = await _buildStores();
    final repository = _FakeStatsRepository(matchIds: const ['match-1']);
    final presenter = _RecordingPresenter(granted: false);
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      presenter: presenter,
      clock: () => _now,
    );

    await service.checkNow();
    repository.matchIds = const ['match-2', 'match-1'];
    await service.checkNow();

    expect(stores.store.getNotifications(), hasLength(1));
    expect(presenter.shown, isEmpty);
  });

  test('전적 조회 실패는 조용히 넘긴다', () async {
    final stores = await _buildStores();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: _FakeStatsRepository(
        error: const PlayerStatsException('닉네임을 찾을 수 없습니다.'),
      ),
      clock: () => _now,
    );

    expect(await service.checkNow(), 0);
    expect(stores.store.getNotifications(), isEmpty);
    expect(stores.store.getLastCheckedAt(), _now);
  });

  test('즐겨찾기가 없으면 조회하지 않는다', () async {
    final stores = await _buildStores(favorites: const []);
    final repository = _FakeStatsRepository();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      clock: () => _now,
    );

    expect(await service.checkNow(), 0);
    expect(repository.callCount, 0);
  });

  test('모든 종류를 끄면 감지를 건너뛴다', () async {
    final stores = await _buildStores();
    await stores.store.saveSettings(
      const NotificationSettings(enabledKinds: {}),
    );
    final repository = _FakeStatsRepository();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      clock: () => _now,
    );

    expect(await service.checkNow(), 0);
    expect(repository.callCount, 0);
  });

  test('확인 주기가 지나지 않으면 checkIfDue가 조회하지 않는다', () async {
    final stores = await _buildStores();
    await stores.store.saveSettings(
      NotificationSettings.defaults.copyWith(
        interval: NotificationInterval.daily,
      ),
    );
    await stores.store.saveLastCheckedAt(_now);

    final repository = _FakeStatsRepository();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      clock: () => _now.add(const Duration(hours: 1)),
    );

    expect(await service.checkIfDue(), 0);
    expect(repository.callCount, 0);
  });

  test('확인 주기가 지나면 checkIfDue가 조회한다', () async {
    final stores = await _buildStores();
    await stores.store.saveSettings(
      NotificationSettings.defaults.copyWith(
        interval: NotificationInterval.hourly,
      ),
    );
    await stores.store.saveLastCheckedAt(_now);

    final repository = _FakeStatsRepository();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      clock: () => _now.add(const Duration(hours: 2)),
    );

    await service.checkIfDue();
    expect(repository.callCount, 1);
  });

  test('한 번에 확인하는 즐겨찾기 인원에 상한이 있다', () async {
    final stores = await _buildStores(
      favorites: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    );
    final repository = _FakeStatsRepository();
    final service = NotificationService(
      store: stores.store,
      playerStore: stores.players,
      statsRepository: repository,
      clock: () => _now,
    );

    await service.checkNow();
    expect(repository.callCount, NotificationService.maxPlayersPerRun);
  });
}
