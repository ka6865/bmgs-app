import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/app_panels.dart';
import '../player_stats_models.dart';
import 'tier_style.dart';

/// 매치 한 건을 한 행으로 보여주는 카드.
///
/// 전적 화면의 미리보기와 전체 매치 화면이 같은 위젯을 공유한다.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.profile});

  final MatchSummary match;
  final PlayerStatsProfile profile;

  String _formatElapsedTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    return '${difference.inDays}일 전';
  }

  /// 순위 구간별 강조 색. 1등은 골드, 상위권은 강조색을 쓴다.
  Color get _rankColor {
    final rank = match.rank;
    if (rank == null) return BgmsColors.textMuted;
    if (rank == 1) return BgmsColors.accent;
    if (rank <= 10) return BgmsColors.success;
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
      padding: const EdgeInsets.only(bottom: 8),
      child: InkSurface(
        borderRadius: 10,
        decoration: BoxDecoration(
          color: isChicken
              ? BgmsColors.accent.withValues(alpha: 0.08)
              : BgmsColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isChicken
                ? BgmsColors.accent.withValues(alpha: 0.45)
                : BgmsColors.border,
          ),
        ),
        child: InkWell(
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
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _RankBlock(rank: match.rank, color: _rankColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.mapName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isChicken) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.emoji_events,
                              size: 14,
                              color: BgmsColors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
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
                            _DotSeparator(),
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
                          _DotSeparator(),
                          Text(
                            _formatElapsedTime(match.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: BgmsColors.textMuted,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MatchStat(label: '킬', value: '${match.kills}'),
                const SizedBox(width: 14),
                _MatchStat(label: '딜량', value: match.damage.toStringAsFixed(0)),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: BgmsColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 매치 순위를 좌측에 고정 폭으로 표시한다.
///
/// 폭을 고정해 매치마다 본문 시작 위치가 흔들리지 않게 한다.
class _RankBlock extends StatelessWidget {
  const _RankBlock({required this.rank, required this.color});

  final int? rank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank == null ? '-' : '#$rank',
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '순위',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BgmsColors.textMuted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 매치 카드 우측의 소형 지표.
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BgmsColors.textMuted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// 메타 정보 사이의 가운뎃점 구분자.
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
