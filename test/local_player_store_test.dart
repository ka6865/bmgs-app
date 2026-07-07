import 'package:bgms_mobile_app/core/storage/local_player_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('recent searches are unique and newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await store.addRecentSearch('Alpha', platform: 'steam');
    await store.addRecentSearch('Bravo', platform: 'kakao');
    await store.addRecentSearch('Alpha', platform: 'steam');

    expect(await store.getRecentSearches(), ['Alpha', 'Bravo']);
    final recentPlayers = await store.getRecentPlayers();
    expect(recentPlayers.first.platform, 'steam');
    expect(recentPlayers.last.platform, 'kakao');
  });

  test('favorites toggle on and off case-insensitively', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await store.toggleFavorite('KangHeeSung_', platform: 'steam');
    await store.toggleFavorite('kangheesung_', platform: 'steam');

    expect(await store.getFavorites(), isEmpty);
  });

  test('same nickname can be stored separately by platform', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await store.addRecentSearch('Player', platform: 'steam');
    await store.addRecentSearch('Player', platform: 'kakao');

    final players = await store.getRecentPlayers();
    expect(players.map((player) => player.platform), ['kakao', 'steam']);
  });
}
