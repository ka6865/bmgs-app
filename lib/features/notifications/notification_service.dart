import '../../core/network/api_exception.dart';
import '../../core/observability/app_logger.dart';
import '../../core/storage/local_player_store.dart';
import '../stats/player_stats_repository.dart';
import 'notification_detector.dart';
import 'notification_models.dart';
import 'notification_presenter.dart';
import 'notification_settings.dart';
import 'notification_store.dart';

/// 즐겨찾기 플레이어의 전적 변화를 확인해 알림을 만든다.
///
/// 저장소에서 스냅샷을 읽고, 전적을 조회하고, 감지 함수를 돌리고, 결과를 저장하고
/// OS 알림을 띄우는 순서를 조율한다. 변화 판단 자체는 [detectNotifications]가 한다.
class NotificationService {
  NotificationService({
    required this.store,
    required this.playerStore,
    required this.statsRepository,
    this.presenter = const NoopNotificationPresenter(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NotificationStore store;
  final LocalPlayerStore playerStore;
  final PlayerStatsRepository statsRepository;
  final NotificationPresenter presenter;
  final DateTime Function() _clock;

  /// 한 번에 확인할 즐겨찾기 최대 인원. PUBG API 호출 한도를 고려한 상한이다.
  static const maxPlayersPerRun = 5;

  /// 확인 주기가 지났을 때만 감지를 실행한다. 생성된 알림 수를 반환한다.
  Future<int> checkIfDue() async {
    final settings = store.getSettings();
    final now = _clock();
    if (!settings.shouldCheck(
      lastCheckedAt: store.getLastCheckedAt(),
      now: now,
    )) {
      return 0;
    }
    return checkNow();
  }

  /// 주기를 무시하고 즉시 감지한다. 사용자가 직접 새로고침할 때 쓴다.
  Future<int> checkNow() async {
    final settings = store.getSettings();
    if (!settings.hasAnyEnabled) return 0;

    final favorites = await playerStore.getFavoritePlayers();
    if (favorites.isEmpty) {
      await store.saveLastCheckedAt(_clock());
      return 0;
    }

    final created = <BgmsNotification>[];
    for (final player in favorites.take(maxPlayersPerRun)) {
      created.addAll(await _checkPlayer(player, settings: settings));
    }

    await store.saveLastCheckedAt(_clock());
    if (created.isEmpty) return 0;

    await store.addAll(created);
    await _present(created);
    return created.length;
  }

  Future<List<BgmsNotification>> _checkPlayer(
    StoredPlayer player, {
    required NotificationSettings settings,
  }) async {
    try {
      final bundle = await statsRepository.fetchPlayerStats(
        nickname: player.nickname,
        platform: player.platform,
      );
      final current = PlayerSnapshot.fromProfile(
        bundle.profile,
        capturedAt: _clock(),
      );
      final previous = store.getSnapshot(current.playerId);

      final events = detectNotifications(
        previous: previous,
        current: current,
        settings: settings,
      );
      await store.saveSnapshot(current);
      return events;
    } catch (error, stackTrace) {
      // 알림은 보조 기능이므로 실패가 주 화면 흐름을 막지 않는다.
      final apiError = error is PlayerStatsException
          ? null
          : ApiException.from(error);
      AppObservability.logger.warning(
        '즐겨찾기 플레이어 전적 확인에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'feature': 'notifications',
          'operation': 'check_player',
          'platform': player.platform,
          if (apiError != null) 'kind': apiError.kind.name,
        },
      );
      return const [];
    }
  }

  Future<void> _present(List<BgmsNotification> notifications) async {
    if (!await presenter.hasPermission()) return;
    for (final notification in notifications) {
      await presenter.show(notification);
    }
  }
}
