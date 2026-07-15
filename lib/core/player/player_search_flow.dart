import '../observability/app_logger.dart';
import '../storage/local_player_store.dart';

String normalizePlayerPlatform(String platform) {
  return platform.trim().toLowerCase() == 'kakao' ? 'kakao' : 'steam';
}

bool isPlayerSearchNavigationCurrent({
  required Uri requestUri,
  required Uri currentUri,
}) {
  return requestUri == currentUri;
}

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
  final normalizedPlatform = normalizePlayerPlatform(platform);

  if (store != null) {
    try {
      await store.addRecentSearch(cleanNickname, platform: normalizedPlatform);
    } catch (error, stackTrace) {
      AppObservability.logger.warning(
        '최근 검색 저장에 실패했습니다.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'feature': 'player_search',
          'operation': 'add_recent_search',
          'platform': normalizedPlatform,
        },
      );
    }
  }

  return PlayerSearchDestination(
    nickname: cleanNickname,
    platform: normalizedPlatform,
  );
}
