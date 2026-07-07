import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/local_player_store.dart';
import '../../core/widgets/bgms_brand_header.dart';

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
    final resolvedNickname = (nickname ?? _nicknameController.text).trim();
    final resolvedPlatform = platform ?? _platform;
    if (resolvedNickname.isEmpty) return;

    await _store?.addRecentSearch(resolvedNickname, platform: resolvedPlatform);
    await _refreshPlayers();
    if (!mounted) return;

    context.go(
      Uri(
        path: '/stats',
        queryParameters: {
          'nickname': resolvedNickname,
          'platform': resolvedPlatform,
        },
      ).toString(),
    );
  }

  Future<void> _toggleFavorite(StoredPlayer player) async {
    await _store?.toggleFavorite(player.nickname, platform: player.platform);
    await _refreshPlayers();
  }

  Future<void> _clearRecentSearches() async {
    await _store?.clearRecentSearches();
    await _refreshPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const BgmsBrandHeader(
          title: 'BGMS',
          subtitle: 'PUBG 전적과 최근 매치를 빠르게 확인하세요.',
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nicknameController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: '닉네임 검색',
                    hintText: 'KangHeeSung_',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: '검색',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('전적 검색'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PlayerSection(
          title: '최근 검색',
          icon: Icons.history,
          players: _recentPlayers,
          favorites: _favoritePlayers,
          loading: _loadingStore,
          emptyText: '검색한 닉네임이 여기에 저장됩니다.',
          trailing: _recentPlayers.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: _clearRecentSearches,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                ),
          onTap: (player) =>
              _search(nickname: player.nickname, platform: player.platform),
          onFavoriteTap: _toggleFavorite,
        ),
        const SizedBox(height: 12),
        _PlayerSection(
          title: '즐겨찾기',
          icon: Icons.star_outline,
          players: _favoritePlayers,
          favorites: _favoritePlayers,
          loading: _loadingStore,
          emptyText: '자주 보는 플레이어를 별표로 추가하세요.',
          onTap: (player) =>
              _search(nickname: player.nickname, platform: player.platform),
          onFavoriteTap: _toggleFavorite,
        ),
      ],
    );
  }
}

class _PlayerSection extends StatelessWidget {
  const _PlayerSection({
    required this.title,
    required this.icon,
    required this.players,
    required this.favorites,
    required this.loading,
    required this.emptyText,
    required this.onTap,
    required this.onFavoriteTap,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<StoredPlayer> players;
  final List<StoredPlayer> favorites;
  final bool loading;
  final String emptyText;
  final Widget? trailing;
  final ValueChanged<StoredPlayer> onTap;
  final ValueChanged<StoredPlayer> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else if (players.isEmpty)
              Text(emptyText)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((player) {
                  final favorite = favorites.any(
                    (item) => item.id == player.id,
                  );
                  return InputChip(
                    avatar: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    label: Text('${player.nickname} · ${player.platform}'),
                    onPressed: () => onTap(player),
                    onDeleted: () => onFavoriteTap(player),
                    deleteIcon: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    deleteButtonTooltipMessage: favorite
                        ? '즐겨찾기 해제'
                        : '즐겨찾기 추가',
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
