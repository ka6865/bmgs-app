import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/bgms_card.dart';
import '../../maps/map_models.dart';
import '../player_stats_models.dart';
import 'tier_style.dart';

/// 매치 한 건을 고도화된 모던 카드 형태로 보여주는 위젯.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.profile});

  final MatchSummary match;
  final PlayerStatsProfile profile;

  String _formatElapsedTime(DateTime? dateTime) {
    if (dateTime == null) return '경기 시간 확인 전';
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.isNegative) return '시간 확인 중';
    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    return '${difference.inDays}일 전';
  }

  Color get _statusColor {
    final rank = match.rank;
    if (rank == null) return BgmsColors.defeat.withValues(alpha: 0.25);
    if (rank == 1) return BgmsColors.accent;
    if (rank <= 10) return BgmsColors.top10;
    return BgmsColors.defeat.withValues(alpha: 0.25);
  }

  Color get _rankColor {
    final rank = match.rank;
    if (rank == null) return BgmsColors.textMuted;
    if (rank == 1) return BgmsColors.accent;
    if (rank <= 10) return BgmsColors.top10;
    return BgmsColors.textSecondary;
  }

  String get _modeLabel {
    final mode = match.gameMode.toLowerCase();
    final base = mode.contains('squad')
        ? '스쿼드'
        : mode.contains('duo')
        ? '듀오'
        : mode.contains('solo')
        ? '솔로'
        : match.gameMode;
    return mode.contains('fpp') ? '$base 1인칭' : base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChicken = match.rank == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackStats =
              constraints.maxWidth < 352 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          final stats = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MatchStat(label: '킬', value: match.kills?.toString() ?? '-'),
              const SizedBox(width: 14),
              _MatchStat(
                label: '딜량',
                value: match.damage?.toStringAsFixed(0) ?? '-',
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: BgmsColors.textMuted,
              ),
            ],
          );
          return BgmsCard(
            statusColor: _statusColor,
            isGlow: isChicken,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: isChicken
                ? BgmsColors.accent.withValues(alpha: 0.05)
                : BgmsColors.surface,
            onTap: () {
              context.push(
                '/stats/match/${match.matchId}',
                extra: {
                  'nickname': profile.nickname,
                  'platform': profile.platform,
                  'summary': match,
                },
              );
            },
            child: Row(
              children: [
                _RankBlock(
                  rank: match.rank,
                  color: _rankColor,
                  isChicken: isChicken,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bgmsMapDisplayName(match.mapName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isChicken) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BgmsColors.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.emoji_events,
                                    size: 12,
                                    color: BgmsColors.accent,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'WIN',
                                    style: TextStyle(
                                      color: BgmsColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _modeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: BgmsColors.textMuted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (match.tier != null) ...[
                            const _DotSeparator(),
                            Flexible(
                              child: Text(
                                match.tierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: getStatsTierColor(match.tierName),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                          const _DotSeparator(),
                          Flexible(
                            child: Text(
                              _formatElapsedTime(match.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: BgmsColors.textMuted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (stackStats) ...[const SizedBox(height: 8), stats],
                    ],
                  ),
                ),
                if (!stackStats) ...[const SizedBox(width: 12), stats],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RankBlock extends StatelessWidget {
  const _RankBlock({
    required this.rank,
    required this.color,
    required this.isChicken,
  });

  final int? rank;
  final Color color;
  final bool isChicken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank == null ? '-' : '#$rank',
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            isChicken ? '치킨' : '순위',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isChicken ? BgmsColors.accent : BgmsColors.textMuted,
              fontSize: 10,
              fontWeight: isChicken ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchStat extends StatelessWidget {
  const _MatchStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BgmsColors.textMuted,
            fontSize: 10,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '·',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
      ),
    );
  }
}
