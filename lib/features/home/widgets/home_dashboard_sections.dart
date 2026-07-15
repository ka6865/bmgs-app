import 'package:flutter/material.dart';

import '../../../core/storage/local_player_store.dart';
import '../../../core/theme/bgms_theme.dart';

class ContinuePlayerCard extends StatelessWidget {
  const ContinuePlayerCard({
    super.key,
    required this.player,
    required this.onTap,
  });

  final StoredPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 76,
          child: _ContinuePlayerContent(player: player),
        ),
      ),
    );
  }
}

class _ContinuePlayerContent extends StatelessWidget {
  const _ContinuePlayerContent({required this.player});

  final StoredPlayer player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: BgmsColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이어서 보기',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BgmsColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.nickname} · ${player.platform}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class FavoritePlayersSection extends StatelessWidget {
  const FavoritePlayersSection({
    super.key,
    required this.players,
    required this.loading,
    required this.onTap,
  });

  final List<StoredPlayer> players;
  final bool loading;
  final ValueChanged<StoredPlayer> onTap;

  @override
  Widget build(BuildContext context) {
    if (!loading && players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '즐겨찾는 플레이어',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '즐겨찾기를 추가하면 빠르게 전적을 확인할 수 있습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BgmsColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return _DashboardSection(
      title: '즐겨찾는 플레이어',
      icon: Icons.star_outline,
      child: loading
          ? const LinearProgressIndicator()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: players.take(5).map((player) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FavoritePlayerButton(
                      player: player,
                      onTap: () => onTap(player),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.onRankingsTap,
    required this.onMapsTap,
    required this.onBoardTap,
  });

  final VoidCallback onRankingsTap;
  final VoidCallback onMapsTap;
  final VoidCallback onBoardTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: '빠른 메뉴',
      icon: Icons.grid_view_outlined,
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              label: '랭킹',
              icon: Icons.leaderboard_outlined,
              onTap: onRankingsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              label: '지도',
              icon: Icons.map_outlined,
              onTap: onMapsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              label: '게시판',
              icon: Icons.forum_outlined,
              onTap: onBoardTap,
            ),
          ),
        ],
      ),
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.players,
    required this.loading,
    required this.onTap,
  });

  final List<StoredPlayer> players;
  final bool loading;
  final ValueChanged<StoredPlayer> onTap;

  @override
  Widget build(BuildContext context) {
    if (!loading && players.isEmpty) return const SizedBox.shrink();

    return _DashboardSection(
      title: '최근 활동',
      icon: Icons.history,
      child: loading
          ? const LinearProgressIndicator()
          : Column(
              children: players.map((player) {
                return _PlayerRow(player: player, onTap: () => onTap(player));
              }).toList(),
            ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BgmsColors.accent),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.onTap});

  final StoredPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${player.nickname} · ${player.platform}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FavoritePlayerButton extends StatelessWidget {
  const _FavoritePlayerButton({required this.player, required this.onTap});

  final StoredPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 148,
        height: 48,
        child: Row(
          children: [
            const Icon(Icons.star, size: 18, color: BgmsColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${player.nickname} · ${player.platform}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
