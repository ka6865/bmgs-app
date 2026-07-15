import '../observability/app_logger.dart';
import '../storage/local_player_store.dart';

class PlayerSearchDestination {
  const PlayerSearchDestination({
    required this.nickname,
    required this.platform,
  });

  final String nickname;
  final String platform;

  String get location => Uri(
    path: '/stats',
    queryParameters: {'nickname': nickname, 'platform': platform},
  ).toString();
}

Future<PlayerSearchDestination?> preparePlayerSearch({
  required LocalPlayerStore? store,
  required String nickname,
  required String platform,
}) async {
  final cleanNickname = nickname.trim();
  if (cleanNickname.isEmpty) return null;

  if (store != null) {
    try {
      await store.addRecentSearch(cleanNickname, platform: platform);
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '최근 검색 저장에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'feature': 'player_search',
          'operation': 'add_recent_search',
          'platform': platform,
        },
      );
    }
  }

  return PlayerSearchDestination(nickname: cleanNickname, platform: platform);
}
