import 'package:shared_preferences/shared_preferences.dart';

class LocalPlayerStore {
  LocalPlayerStore(this._prefs);

  final SharedPreferences _prefs;

  static const _recentKey = 'bgms_recent_searches';
  static const _favoriteKey = 'bgms_favorite_players';

  Future<List<String>> getRecentSearches() async {
    return _prefs.getStringList(_recentKey) ?? <String>[];
  }

  Future<void> addRecentSearch(String nickname) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return;

    final current = await getRecentSearches();
    final next = <String>[
      clean,
      ...current.where((item) => item.toLowerCase() != clean.toLowerCase()),
    ].take(10).toList();

    await _prefs.setStringList(_recentKey, next);
  }

  Future<List<String>> getFavorites() async {
    return _prefs.getStringList(_favoriteKey) ?? <String>[];
  }

  Future<void> toggleFavorite(String nickname) async {
    final clean = nickname.trim();
    if (clean.isEmpty) return;

    final current = await getFavorites();
    final exists = current.any(
      (item) => item.toLowerCase() == clean.toLowerCase(),
    );
    final next = exists
        ? current
              .where((item) => item.toLowerCase() != clean.toLowerCase())
              .toList()
        : <String>[clean, ...current].take(30).toList();

    await _prefs.setStringList(_favoriteKey, next);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(_recentKey);
  }
}
