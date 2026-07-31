import 'package:flutter/material.dart';

import '../../../core/storage/local_player_store.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/app_panels.dart';

/// 최근 검색한 플레이어를 강조해 다시 진입하도록 돕는 히어로 카드.
///
/// 홈에서 유일하게 강조 색을 크게 쓰는 요소다.
class ContinuePlayerCard extends StatelessWidget {
  const ContinuePlayerCard({
    super.key,
    required this.player,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final StoredPlayer player;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkSurface(
      borderRadius: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BgmsColors.accent.withValues(alpha: 0.45)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            BgmsColors.accent.withValues(alpha: 0.16),
            BgmsColors.elevated,
          ],
        ),
      ),
      child: InkWell(
        key: const Key('home_continue_player'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _PlayerAvatar(nickname: player.nickname, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이어서 보기',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: BgmsColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${player.nickname} · ${player.platform}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                ),
                color: isFavorite
                    ? BgmsColors.accent
                    : BgmsColors.textSecondary,
                tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기에 추가',
                visualDensity: VisualDensity.compact,
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: BgmsColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 닉네임 첫 글자를 쓰는 단색 아바타. 서버가 프로필 이미지를 주지 않아 대체 표현이다.
class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.nickname, this.size = 32});

  final String nickname;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = nickname.trim().isEmpty
        ? '?'
        : nickname.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: BgmsColors.border),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: BgmsColors.accent,
          fontWeight: FontWeight.w800,
        ),
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
      return SectionBand(
        title: '즐겨찾는 플레이어',
        icon: Icons.star_outline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: BgmsColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BgmsColors.border),
          ),
          child: Text(
            '즐겨찾기를 추가하면 빠르게 전적을 확인할 수 있습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
          ),
        ),
      );
    }

    return SectionBand(
      title: '즐겨찾는 플레이어',
      icon: Icons.star_outline,
      child: loading
          ? const LinearProgressIndicator()
          : SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: players.take(5).length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final player = players[index];
                  return _FavoritePlayerButton(
                    player: player,
                    onTap: () => onTap(player),
                  );
                },
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
    required this.onNotificationsTap,
  });

  final VoidCallback onRankingsTap;
  final VoidCallback onMapsTap;
  final VoidCallback onBoardTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return SectionBand(
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
          const SizedBox(width: 8),
          // 알림 센터는 하단 탭에 없으므로 홈에서 진입 경로를 제공한다.
          Expanded(
            child: _QuickAction(
              label: '알림',
              icon: Icons.notifications_outlined,
              onTap: onNotificationsTap,
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

    return SectionBand(
      title: '최근 활동',
      icon: Icons.history,
      child: loading
          ? const LinearProgressIndicator()
          : InkSurface(
              borderRadius: 8,
              decoration: BoxDecoration(
                color: BgmsColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BgmsColors.border),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < players.length; index++)
                    _PlayerRow(
                      player: players[index],
                      isLast: index == players.length - 1,
                      onTap: () => onTap(players[index]),
                    ),
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
    return Tooltip(
      message: label,
      child: InkSurface(
        borderRadius: 8,
        decoration: BoxDecoration(
          color: BgmsColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BgmsColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: BgmsColors.accent),
                const SizedBox(height: 6),
                // 좁은 화면에서도 라벨이 잘리지 않도록 가로 폭에 맞춰 축소한다.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: BgmsColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.onTap,
    this.isLast = false,
  });

  final StoredPlayer player;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: BgmsColors.border)),
        ),
        child: Row(
          children: [
            _PlayerAvatar(nickname: player.nickname, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                player.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _PlatformBadge(platform: player.platform),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: BgmsColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// 플랫폼을 짧게 표기하는 배지.
class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: BgmsColors.border),
      ),
      child: Text(
        platform,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: BgmsColors.textMuted,
          letterSpacing: 0,
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
    return InkSurface(
      borderRadius: 8,
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BgmsColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 132,
          height: 84,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PlayerAvatar(nickname: player.nickname, size: 26),
                  const Spacer(),
                  const Icon(Icons.star, size: 13, color: BgmsColors.accent),
                ],
              ),
              const Spacer(),
              Text(
                player.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                player.platform,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BgmsColors.textMuted,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
