import 'package:shared_preferences/shared_preferences.dart';

class StoredPlayer {
  const StoredPlayer({required this.nickname, required this.platform});

  final String nickname;
  final String platform;

  String get id => '${platform.toLowerCase()}:${nickname.toLowerCase()}';
}

class LocalPlayerStore {
  LocalPlayerStore(this._prefs);

  final SharedPreferences _prefs;

  static const _recentKey = 'bgms_recent_searches';
  static const _favoriteKey = 'bgms_favorite_players';

  Future<List<String>> getRecentSearches() async {
    return (await getRecentPlayers()).map((player) => player.nickname).toList();
  }

  Future<List<StoredPlayer>> getRecentPlayers() async {
    return _readPlayers(_recentKey);
  }

  Future<void> addRecentSearch(
    String nickname, {
    String platform = 'steam',
  }) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return;

    final player = StoredPlayer(nickname: clean, platform: platform);
    final current = await getRecentPlayers();
    final next = <StoredPlayer>[
      player,
      ...current.where((item) => item.id != player.id),
    ].take(10).toList();

    await _writePlayers(_recentKey, next);
  }

  Future<List<String>> getFavorites() async {
    return (await getFavoritePlayers())
        .map((player) => player.nickname)
        .toList();
  }

  Future<List<StoredPlayer>> getFavoritePlayers() async {
    return _readPlayers(_favoriteKey);
  }

  Future<void> toggleFavorite(
    String nickname, {
    String platform = 'steam',
  }) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return;

    final player = StoredPlayer(nickname: clean, platform: platform);
    final current = await getFavoritePlayers();
    final exists = current.any((item) => item.id == player.id);
    final next = exists
        ? current.where((item) => item.id != player.id).toList()
        : <StoredPlayer>[player, ...current].take(30).toList();

    await _writePlayers(_favoriteKey, next);
  }

  Future<bool> isFavorite(String nickname, {String platform = 'steam'}) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return false;
    final id = '${platform.toLowerCase()}:${clean.toLowerCase()}';
    return (await getFavoritePlayers()).any((player) => player.id == id);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(_recentKey);
  }

  Future<void> clearFavorites() async {
    await _prefs.remove(_favoriteKey);
  }

  List<StoredPlayer> _readPlayers(String key) {
    final raw = _prefs.getStringList(key) ?? <String>[];
    return raw
        .map(_decodePlayer)
        .whereType<StoredPlayer>()
        .fold<List<StoredPlayer>>(<StoredPlayer>[], (players, player) {
          if (!players.any((item) => item.id == player.id)) {
            players.add(player);
          }
          return players;
        });
  }

  Future<void> _writePlayers(String key, List<StoredPlayer> players) async {
    await _prefs.setStringList(
      key,
      players
          .map((player) => '${player.platform}\t${player.nickname}')
          .toList(),
    );
  }

  StoredPlayer? _decodePlayer(String raw) {
    final separatorIndex = raw.indexOf('\t');
    if (separatorIndex > 0) {
      final platform = raw.substring(0, separatorIndex).trim();
      final nickname = raw.substring(separatorIndex + 1).trim();
      if (platform.isNotEmpty && nickname.isNotEmpty) {
        return StoredPlayer(nickname: nickname, platform: platform);
      }
    }

    final legacyNickname = raw.trim();
    if (legacyNickname.isEmpty) return null;
    return StoredPlayer(nickname: legacyNickname, platform: 'steam');
  }
}
