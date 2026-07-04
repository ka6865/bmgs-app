import 'package:bgms_mobile_app/core/storage/local_player_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('recent searches are unique and newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await store.addRecentSearch('Alpha');
    await store.addRecentSearch('Bravo');
    await store.addRecentSearch('Alpha');

    expect(await store.getRecentSearches(), ['Alpha', 'Bravo']);
  });

  test('favorites toggle on and off case-insensitively', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalPlayerStore(await SharedPreferences.getInstance());

    await store.toggleFavorite('KangHeeSung_');
    await store.toggleFavorite('kangheesung_');

    expect(await store.getFavorites(), isEmpty);
  });
}
