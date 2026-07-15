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

  await store?.addRecentSearch(cleanNickname, platform: platform);
  return PlayerSearchDestination(
    nickname: cleanNickname,
    platform: platform,
  );
}
