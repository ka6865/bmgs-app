import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/bgms_card.dart';
import '../../../core/widgets/phase_strip.dart';
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

  /// 화면 낭독기가 카드 한 장을 한 문장으로 읽게 한다.
  String get _semanticLabel {
    final rank = match.rank;
    return [
      rank == null ? '순위 정보 없음' : (rank == 1 ? '치킨' : '$rank위'),
      bgmsMapDisplayName(match.mapName),
      _modeLabel,
      '${match.kills ?? '정보 없음'}킬',
      '딜량 ${match.damage?.toStringAsFixed(0) ?? '정보 없음'}',
      _formatElapsedTime(match.createdAt),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChicken = match.rank == 1;

    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: Padding(
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
              padding: EdgeInsets.zero,
              backgroundColor: BgmsColors.surface,
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
              child: _MapBackdrop(
                mapName: match.mapName,
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
                          const SizedBox(height: 8),
                          PhaseStrip(
                            deathPhase: match.deathPhase,
                            rank: match.rank,
                          ),
                          if (stackStats) ...[
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: stats,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!stackStats) ...[const SizedBox(width: 12), stats],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 카드 오른쪽에 그 경기 맵 전체 모습을 옅게 깐다. 지도 탭과 같은 서버 타일(줌 0)이다.
class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop({required this.mapName, required this.child});

  final String mapName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeBgmsMapId(mapName);
    final map = bgmsMapCatalog
        .where((map) => map.id.toLowerCase() == normalized)
        .firstOrNull;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    );
    if (map == null) return content;
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 160,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.45,
              child: Image(
                image: cachedImageProvider(
                  AppConfig.local.mapTileUrl(
                    mapId: map.tilePath,
                    zoom: 0,
                    column: 0,
                    row: 0,
                  ),
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        // 왼쪽 글자가 지도 위에서도 읽히도록 카드 색에서 투명으로 번지게 덮는다.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  BgmsColors.surface,
                  BgmsColors.surface,
                  Color(0x99161917),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        content,
      ],
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rank == null ? '-' : '#$rank',
              maxLines: 1,
              style: BgmsText.number(24, color: color),
            ),
          ),
          if (isChicken)
            Text(
              '치킨',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BgmsColors.accent,
                fontWeight: FontWeight.w700,
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
        Text(value, maxLines: 1, style: BgmsText.number(20)),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: BgmsColors.textSecondary),
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
