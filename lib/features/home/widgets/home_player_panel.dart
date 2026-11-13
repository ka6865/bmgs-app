import 'package:flutter/material.dart';

import '../../../core/storage/local_player_store.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/app_panels.dart';
import '../../../core/widgets/phase_strip.dart';
import '../../maps/map_models.dart';
import '../../stats/player_stats_models.dart';
import '../../stats/player_stats_repository.dart';

/// 홈 첫 화면의 주인공. 마지막으로 본 플레이어의 시즌 숫자와 최근 경기 페이즈를 보여준다.
class HomePlayerPanel extends StatefulWidget {
  const HomePlayerPanel({
    super.key,
    required this.player,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavoriteTap,
    this.repository,
  });

  static const recentCount = 5;

  final StoredPlayer player;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteTap;
  final PlayerStatsRepository? repository;

  @override
  State<HomePlayerPanel> createState() => _HomePlayerPanelState();
}

class _HomePlayerPanelState extends State<HomePlayerPanel> {
  late Future<PlayerStatsBundle> _future = _load();

  Future<PlayerStatsBundle> _load() =>
      (widget.repository ?? PlayerStatsRepository()).fetchPlayerStats(
        nickname: widget.player.nickname,
        platform: widget.player.platform,
        summaryLimit: HomePlayerPanel.recentCount,
      );

  @override
  void didUpdateWidget(covariant HomePlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.id != widget.player.id) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('home_continue_player'),
      color: BgmsColors.surface,
      shape: BgmsShape.panel(
        side: BorderSide(color: BgmsColors.accent.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.player.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.player.platform.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: BgmsColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onFavoriteTap,
                    icon: Icon(
                      widget.isFavorite ? Icons.star : Icons.star_border,
                    ),
                    color: widget.isFavorite
                        ? BgmsColors.accent
                        : BgmsColors.textSecondary,
                    tooltip: widget.isFavorite ? '즐겨찾기 해제' : '즐겨찾기에 추가',
                  ),
                  const Icon(Icons.chevron_right, color: BgmsColors.textMuted),
                ],
              ),
              const SizedBox(height: BgmsSpacing.md),
              FutureBuilder<PlayerStatsBundle>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Column(
                      children: [
                        SkeletonBox(height: 40),
                        SizedBox(height: BgmsSpacing.md),
                        SkeletonBox(height: 72),
                      ],
                    );
                  }
                  final bundle = snapshot.data;
                  if (bundle == null) {
                    return _PanelError(
                      message: snapshot.error is PlayerStatsException
                          ? (snapshot.error as PlayerStatsException).message
                          : '기록을 불러오지 못했습니다.',
                      onRetry: () => setState(() {
                        _future = _load();
                      }),
                    );
                  }
                  return _PanelBody(bundle: bundle);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.bundle});

  final PlayerStatsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final profile = bundle.profile;
    final played = profile.roundsPlayed > 0;
    final matches = bundle.matches.where((match) => !match.isFallback);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Figure(
              label: 'K/D',
              value: played ? profile.kd.toStringAsFixed(2) : '-',
            ),
            _Figure(
              label: '평균 딜',
              value: played ? profile.adr.toStringAsFixed(0) : '-',
            ),
            _Figure(
              label: '승률',
              value: played ? '${profile.winRate.toStringAsFixed(1)}%' : '-',
            ),
          ],
        ),
        const SizedBox(height: BgmsSpacing.lg),
        if (matches.isEmpty)
          Text(
            '최근 경기 기록이 없습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
          )
        else
          for (final match in matches) _RecentRow(match: match),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: BgmsText.number(30)),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
    final rank = match.rank;
    final isChicken = rank == 1;
    final kills = match.kills;
    final damage = match.damage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              rank == null ? '#-' : '#$rank',
              style: BgmsText.number(
                18,
                color: isChicken ? BgmsColors.accent : BgmsColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              bgmsMapDisplayName(match.mapName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: PhaseStrip(deathPhase: match.deathPhase, rank: rank),
          ),
          const SizedBox(width: BgmsSpacing.md),
          SizedBox(
            width: 72,
            child: Text(
              '${kills ?? '-'}킬 ${damage?.toStringAsFixed(0) ?? '-'}',
              textAlign: TextAlign.right,
              style: BgmsText.number(15, color: BgmsColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  const _PanelError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
