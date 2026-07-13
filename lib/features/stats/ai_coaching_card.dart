import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import 'ai_coaching_models.dart';
import 'ai_coaching_repository.dart';
import 'player_stats_models.dart';

class AiCoachingCard extends StatefulWidget {
  const AiCoachingCard({super.key, required this.bundle});

  final PlayerStatsBundle bundle;

  @override
  State<AiCoachingCard> createState() => _AiCoachingCardState();
}

class _AiCoachingCardState extends State<AiCoachingCard> {
  late final AiCoachingRepository _repository;
  Future<AiCoachingSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _repository = AiCoachingRepository();
  }

  @override
  void didUpdateWidget(covariant AiCoachingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.profile.nickname != widget.bundle.profile.nickname ||
        oldWidget.bundle.profile.platform != widget.bundle.profile.platform) {
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
    setState(() => _summaryFuture = _loadSummary());
  }

  @override
  Widget build(BuildContext context) {
    if (_summaryFuture == null) {
      return _AiCardShell(
        title: 'BGMS AI COACH',
        statusLabel: '대기',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 10경기를 기반으로 한 AI 전술 코칭 리포트는 수동으로 실행됩니다.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _retry,
                style: FilledButton.styleFrom(
                  backgroundColor: BgmsColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.psychology_alt, size: 20),
                label: const Text('AI 스쿼드 분석 및 코칭 받기', style: TextStyle(fontWeight: FontWeight.bold)),
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
            title: 'BGMS AI COACH',
            statusLabel: '전술 분석 중',
            child: Column(
              children: [
                LinearProgressIndicator(color: BgmsColors.accent, backgroundColor: Colors.white10),
                SizedBox(height: 12),
                Text(
                  'AI 분석관들이 텔레메트리 리플레이 조각들을 모으고 있습니다...',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
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
          title: 'BGMS AI COACH',
          statusLabel: _statusLabel(summary.status),
          onRetry: _retry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: BgmsColors.accent,
                      ),
                    ),
                  ),
                  if (summary.grade != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purpleAccent, width: 0.5),
                      ),
                      child: Text(
                        summary.grade!,
                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // AI 코칭 핵심 본문에 부드러운 타이핑 효과 적용
              _TypingText(
                text: summary.summary,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              ),
              if (summary.hasActionableItems) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF232b3c), height: 1),
                const SizedBox(height: 14),
                _InsightGroup(title: '🌟 장점 & 전술적 강점', items: summary.strengths, color: Colors.greenAccent),
                _InsightGroup(title: '🚨 보완이 급한 약점', items: summary.weaknesses, color: Colors.amberAccent),
                _InsightGroup(title: '⚠️ 교전 경고 지표', items: summary.warnings, color: Colors.redAccent),
                _InsightGroup(title: '🎯 즉각 개선을 위한 추천 액션', items: summary.improvements, color: BgmsColors.accent),
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
    return Card(
      color: const Color(0xFF161b26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232b3c)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_alt_outlined, size: 22, color: BgmsColors.accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF232b3c),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (onRetry != null)
                  IconButton(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                    tooltip: '다시 분석',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InsightGroup extends StatelessWidget {
  const _InsightGroup({required this.title, required this.items, required this.color});

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
