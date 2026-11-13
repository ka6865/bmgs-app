import 'package:flutter/material.dart';

import '../../../core/storage/local_player_store.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/app_panels.dart';

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
