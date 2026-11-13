import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_card.dart';
import 'ai_coaching_models.dart';
import 'ai_coaching_repository.dart';
import 'player_stats_models.dart';

class AiCoachingCard extends StatefulWidget {
  const AiCoachingCard({super.key, required this.bundle, this.repository});

  final PlayerStatsBundle bundle;
  final AiCoachingRepository? repository;

  @override
  State<AiCoachingCard> createState() => _AiCoachingCardState();
}

class _AiCoachingCardState extends State<AiCoachingCard> {
  late final AiCoachingRepository _repository;
  Future<AiCoachingSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AiCoachingRepository();
  }

  @override
  void didUpdateWidget(covariant AiCoachingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.profile.nickname != widget.bundle.profile.nickname ||
        oldWidget.bundle.profile.platform != widget.bundle.profile.platform ||
        !listEquals(
          oldWidget.bundle.profile.recentMatches,
          widget.bundle.profile.recentMatches,
        )) {
      _summaryFuture = null;
    }
  }

  Future<AiCoachingSummary> _loadSummary() {
    return _repository.summarize(
      profile: widget.bundle.profile,
      matches: widget.bundle.matches,
    );
  }

  void _retry() {
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_summaryFuture == null) {
      return _AiCardShell(
        title: 'AI 코치',
        statusLabel: '대기',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 10경기를 기반으로 한 AI 전술 코칭 리포트는 수동으로 실행됩니다.',
              style: TextStyle(color: BgmsColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.psychology_alt, size: 20),
                label: const Text(
                  '최근 경기 AI 코칭 받기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<AiCoachingSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AiCardShell(
            title: 'AI 코치',
            statusLabel: '전술 분석 중',
            child: Column(
              children: [
                LinearProgressIndicator(
                  color: BgmsColors.accent,
                  backgroundColor: BgmsColors.border,
                ),
                SizedBox(height: 12),
                Text(
                  '최근 경기 지표와 AI 해석을 불러오고 있습니다...',
                  style: TextStyle(
                    color: BgmsColors.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final summary =
            snapshot.data ??
            AiCoachingSummary.unavailable('AI 코칭 상태를 불러오지 못했습니다.');

        return _AiCardShell(
          title: 'AI 코치',
          statusLabel: _statusLabel(summary.status),
          onRetry: _retry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.grade != null) ...[
                    _GradeBadge(grade: summary.grade!),
                    const SizedBox(width: BgmsSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (summary.subtitle != null &&
                            summary.subtitle!.isNotEmpty)
                          Text(
                            summary.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: BgmsColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // AI 코칭 핵심 본문에 부드러운 타이핑 효과 적용
              _Quote(
                child: _TypingText(
                  text: summary.summary,
                  style: const TextStyle(
                    color: BgmsColors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              if (summary.cards.isNotEmpty) ...[
                const SizedBox(height: 20),
                ...summary.cards.map((card) => _FactCard(card: card)),
                _ActionList(items: summary.improvements),
              ],
              if (summary.hasActionableItems && summary.cards.isEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: BgmsColors.border, height: 1),
                const SizedBox(height: 14),
                _InsightGroup(
                  title: '장점 및 전술적 강점',
                  items: summary.strengths,
                  color: BgmsColors.success,
                  icon: Icons.trending_up,
                ),
                _InsightGroup(
                  title: '보완이 급한 약점',
                  items: summary.weaknesses,
                  color: BgmsColors.accent,
                  icon: Icons.priority_high,
                ),
                _InsightGroup(
                  title: '교전 경고 지표',
                  items: summary.warnings,
                  color: BgmsColors.danger,
                  icon: Icons.warning_amber_outlined,
                ),
                _InsightGroup(
                  title: '즉각 개선을 위한 추천 액션',
                  items: summary.improvements,
                  color: BgmsColors.accent,
                  icon: Icons.track_changes,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(AiCoachingStatus status) {
    return switch (status) {
      AiCoachingStatus.available => 'AI 리포트',
      AiCoachingStatus.loginRequired => '로그인 필요',
      AiCoachingStatus.costRestricted => '일일 제한',
      AiCoachingStatus.fallback => '로컬 분석',
      AiCoachingStatus.unavailable => '분석 실패',
    };
  }
}

class _AiCardShell extends StatelessWidget {
  const _AiCardShell({
    required this.title,
    required this.statusLabel,
    required this.child,
    this.onRetry,
  });

  final String title;
  final String statusLabel;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return BgmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BgmsColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
              ),
              const Spacer(),
              if (onRetry != null)
                IconButton(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  color: BgmsColors.textSecondary,
                  tooltip: '다시 분석',
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InsightGroup extends StatelessWidget {
  const _InsightGroup({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.keyboard_arrow_right, size: 16, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BgmsColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 글자가 조금씩 딜레이를 가지고 타이핑되면서 나타나는 텍스트 위젯
// ---------------------------------------------------------------------------
class _TypingText extends StatefulWidget {
  const _TypingText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayedText = '';
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant _TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _displayedText = '';
      _charIndex = 0;
      _startTyping();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer?.cancel();
    // 평균 타이핑 속도: 한 글자당 8ms로 고속 드로잉
    const interval = Duration(milliseconds: 8);
    _timer = Timer.periodic(interval, (timer) {
      if (_charIndex >= widget.text.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _displayedText += widget.text[_charIndex];
        _charIndex++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final String grade;

  @override
  Widget build(BuildContext context) => Material(
    color: BgmsColors.elevated,
    shape: BgmsShape.panel(side: const BorderSide(color: BgmsColors.accent)),
    child: SizedBox(
      width: 64,
      height: 64,
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              grade,
              style: BgmsText.number(36, color: BgmsColors.accent),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 왼쪽 골드 선으로 AI 해석 문장을 지표와 구분한다.
class _Quote extends StatelessWidget {
  const _Quote({required this.child, this.label});
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: BgmsColors.elevated,
      border: Border(left: BorderSide(color: BgmsColors.accent, width: 3)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BgmsColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          child,
        ],
      ),
    ),
  );
}

class _ActionList extends StatelessWidget {
  const _ActionList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('추천 액션', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final (index, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: BgmsText.number(20, color: BgmsColors.accent),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _modeLabel(String mode) {
  final lower = mode.toLowerCase();
  final team = lower.startsWith('solo')
      ? '솔로'
      : lower.startsWith('duo')
      ? '듀오'
      : lower.startsWith('squad')
      ? '스쿼드'
      : mode;
  return lower.contains('fpp') ? '$team FPP' : team;
}

String _matchTypeLabel(String type) => switch (type) {
  'competitive' => '경쟁전',
  'official' || 'normal' => '일반전',
  _ => type,
};

class _FactCard extends StatelessWidget {
  const _FactCard({required this.card});
  final AiCoachingFactCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final context_ = [
      if (card.gameMode.isNotEmpty) _modeLabel(card.gameMode),
      if (card.matchType.isNotEmpty) _matchTypeLabel(card.matchType),
      '${card.matchCount}경기',
    ].join(' · ');
    final details = [
      if (card.spicyOpinion.isNotEmpty) ('다른 관점', card.spicyOpinion),
      if (card.reason.isNotEmpty) ('근거 해석', card.reason),
      if (card.evaluation.isNotEmpty) ('평가', card.evaluation),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                card.topic,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context_,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: BgmsColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (card.question.isNotEmpty)
            Text(
              card.question,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          if (card.evidence.isEmpty)
            Text(
              '확인된 지표가 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final row in card.evidence)
                      SizedBox(
                        width: width,
                        child: _EvidenceTile(row: row),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          if (card.analysisReady) ...[
            if (card.kindOpinion.isNotEmpty)
              _Quote(label: '코치 의견', child: Text(card.kindOpinion)),
            if (details.isNotEmpty)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    '자세히 보기',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                  children: [
                    for (final (label, text) in details)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: BgmsColors.textMuted,
                              ),
                            ),
                            Text(text),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ] else
            Text(
              card.analysisStatus == 'pending'
                  ? 'AI 해석이 완료되지 않았습니다.'
                  : 'AI 해석을 표시할 수 없습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            ),
          if (!card.analysisReady && card.analysisReason.isNotEmpty)
            Text(
              card.analysisReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// 지표 하나. 내 값을 크게, 비교값이 있으면 막대로 같이 보여준다.
class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.row});
  final AiCoachingEvidence row;

  static double? _numeric(String? value) => value == null
      ? null
      : double.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), ''));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = _numeric(row.userValue);
    final benchmark = _numeric(row.benchmarkValue);
    final hasBar = mine != null && benchmark != null && benchmark > 0;
    final better = hasBar && mine >= benchmark;

    return Material(
      color: BgmsColors.elevated,
      shape: BgmsShape.panel(size: BgmsShape.cutSmall),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                row.userValue ?? '-',
                style: BgmsText.number(
                  24,
                  color: hasBar
                      ? (better ? BgmsColors.top10 : BgmsColors.knock)
                      : BgmsColors.textPrimary,
                ),
              ),
            ),
            if (hasBar) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BgmsRadius.sm,
                child: LinearProgressIndicator(
                  value: (mine / (benchmark * 2)).clamp(0, 1),
                  minHeight: 4,
                  color: better ? BgmsColors.top10 : BgmsColors.knock,
                  backgroundColor: BgmsColors.border,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              [
                row.benchmarkValue == null
                    ? (row.unavailableReason ?? '비교 자료 없음')
                    : '${row.benchmarkLabel} ${row.benchmarkValue}',
                if (row.userMatchCount != null) '${row.userMatchCount}경기 기준',
                if (row.sampleCount != null) '비교 표본 ${row.sampleCount}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: BgmsColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
