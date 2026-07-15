import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/player/player_search_flow.dart';
import '../../core/storage/local_player_store.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'widgets/home_dashboard_sections.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  String _platform = 'steam';
  LocalPlayerStore? _store;
  List<StoredPlayer> _recentPlayers = const [];
  List<StoredPlayer> _favoritePlayers = const [];
  bool _loadingStore = true;
  bool _searching = false;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    _store = LocalPlayerStore(prefs);
    await _refreshPlayers();
  }

  Future<void> _refreshPlayers() async {
    final store = _store;
    if (store == null) return;
    final recent = await store.getRecentPlayers();
    final favorites = await store.getFavoritePlayers();
    if (!mounted) return;
    setState(() {
      _recentPlayers = recent;
      _favoritePlayers = favorites;
      _loadingStore = false;
    });
  }

  Future<void> _search({String? nickname, String? platform}) async {
    if (_searching) return;

    final cleanNickname = (nickname ?? _nicknameController.text).trim();
    if (cleanNickname.isEmpty) {
      if (!mounted) return;
      setState(() {
        _nicknameError = '닉네임을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _searching = true;
      _nicknameError = null;
    });

    try {
      final destination = await preparePlayerSearch(
        store: _store,
        nickname: cleanNickname,
        platform: platform ?? _platform,
      );
      if (!mounted) return;
      if (destination == null) return;

      await _refreshPlayers();
      if (!mounted) return;

      context.go(destination.location);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nicknameError = '검색 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestPlayer = _recentPlayers.isEmpty ? null : _recentPlayers.first;
    final remainingRecent = _recentPlayers.skip(1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BgmsBrandHeader(title: 'BGMS'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nicknameController,
                    textInputAction: TextInputAction.search,
                    enabled: !_searching,
                    onChanged: (_) {
                      if (_nicknameError == null) return;
                      setState(() => _nicknameError = null);
                    },
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'PUBG 플레이어 검색',
                      hintText: 'KangHeeSung_',
                      errorText: _nicknameError,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _searching ? null : _search,
                        icon: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        tooltip: '검색',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'steam', label: Text('Steam')),
                        ButtonSegment(value: 'kakao', label: Text('Kakao')),
                      ],
                      selected: {_platform},
                      onSelectionChanged: (selection) {
                        setState(() => _platform = selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_searching ? '검색 중...' : '전적 검색'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (latestPlayer != null) ...[
            const SizedBox(height: 12),
            ContinuePlayerCard(
              player: latestPlayer,
              onTap: () => _search(
                nickname: latestPlayer.nickname,
                platform: latestPlayer.platform,
              ),
            ),
          ],
          if (_loadingStore || _favoritePlayers.isNotEmpty) ...[
            const SizedBox(height: 12),
            FavoritePlayersSection(
              players: _favoritePlayers,
              loading: _loadingStore,
              onTap: (player) =>
                  _search(nickname: player.nickname, platform: player.platform),
            ),
          ],
          const SizedBox(height: 12),
          HomeQuickActions(
            onRankingsTap: () => context.go('/rankings'),
            onMapsTap: () => context.go('/maps'),
            onBoardTap: () => context.go('/board'),
          ),
          if (_loadingStore || remainingRecent.isNotEmpty) ...[
            const SizedBox(height: 12),
            RecentActivitySection(
              players: remainingRecent,
              loading: _loadingStore,
              onTap: (player) =>
                  _search(nickname: player.nickname, platform: player.platform),
            ),
          ],
        ],
      ),
    );
  }
}
