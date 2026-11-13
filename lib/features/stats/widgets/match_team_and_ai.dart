import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/bgms_card.dart';
import '../match_ai_models.dart';
import '../match_ai_repository.dart';
import '../match_detail_models.dart';

/// 웹 경기 상세의 '팀원 · 경기 전체'처럼 팀원별 킬·어시·기절·피해량을 보여준다.
class MatchTeamCard extends StatelessWidget {
  const MatchTeamCard({super.key, required this.team, required this.nickname});

  final List<MatchTeamMember> team;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String value(num? number) =>
        number == null ? '-' : number.toStringAsFixed(0);

    return BgmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '팀원 성적',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              for (final label in const ['킬', '어시', '기절', '피해량'])
                SizedBox(
                  width: label == '피해량' ? 56 : 40,
                  child: Text(
                    label,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BgmsColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          for (final member in team)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _isMe(member)
                                  ? BgmsColors.accent
                                  : BgmsColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final number in [
                    member.kills,
                    member.assists,
                    member.knocks,
                  ])
                    SizedBox(
                      width: 40,
                      child: Text(
                        value(number),
                        textAlign: TextAlign.end,
                        style: BgmsText.number(18),
                      ),
                    ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      value(member.damage),
                      textAlign: TextAlign.end,
                      style: BgmsText.number(18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isMe(MatchTeamMember member) =>
      member.name.toLowerCase() == nickname.toLowerCase();
}

/// 웹 경기 상세의 단일 경기 AI 코칭. 로그인한 사용자가 누를 때만 서버에 요청한다.
class MatchAiSection extends StatefulWidget {
  const MatchAiSection({
    super.key,
    required this.matchId,
    required this.nickname,
    required this.platform,
    this.repository,
  });

  final String matchId;
  final String nickname;
  final String platform;
  final MatchAiRepository? repository;

  @override
  State<MatchAiSection> createState() => _MatchAiSectionState();
}

class _MatchAiSectionState extends State<MatchAiSection> {
  late final _repository = widget.repository ?? MatchAiRepository();
  bool _spicy = true;
  Future<MatchAiResult>? _future;

  void _run() {
    final result = _repository.analyze(
      matchId: widget.matchId,
      nickname: widget.nickname,
      platform: widget.platform,
      spicy: _spicy,
    );
    // 화면이 결과를 받기 전에 실패해도 처리되지 않은 오류로 남지 않게 한다.
    result.ignore();
    setState(() {
      _future = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BgmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AI 경기 분석',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '이 한 경기의 교전·운영 기록을 AI가 해석합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BgmsColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('매운맛')),
              ButtonSegment(value: false, label: Text('순한맛')),
            ],
            selected: {_spicy},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _spicy = selection.first),
          ),
          const SizedBox(height: 8),
          FutureBuilder<MatchAiResult>(
            future: _future,
            builder: (context, snapshot) {
              final waiting =
                  _future != null &&
                  snapshot.connectionState != ConnectionState.done;
              final button = FilledButton.icon(
                onPressed: waiting ? null : _run,
                icon: waiting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  waiting
                      ? '분석 중...'
                      : _future == null
                      ? 'AI 분석 받기'
                      : '다시 분석',
                ),
              );
              if (_future == null || waiting) return button;
              final error = snapshot.error;
              if (error != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _errorMessage(error),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BgmsColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (error is ApiException &&
                        error.kind == ApiErrorKind.unauthorized)
                      FilledButton(
                        onPressed: () => context.push('/my'),
                        child: const Text('로그인하러 가기'),
                      )
                    else
                      button,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MatchAiResultView(result: snapshot.data!),
                  const SizedBox(height: 8),
                  button,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is FormatException) return error.message;
    final api = ApiException.from(error);
    if (api.statusCode == 409) {
      return '이 경기의 분석 데이터가 아직 준비되지 않았습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (api.statusCode == 410) {
      return '상세 기록 보관 기간이 지난 경기라 AI 분석을 할 수 없습니다.';
    }
    return api.message;
  }
}

class _MatchAiResultView extends StatelessWidget {
  const _MatchAiResultView({required this.result});

  final MatchAiResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdown = result.markdown;
    if (markdown != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          markdown
              .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
              .replaceAll('**', ''),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (result.coach != null)
          Text(
            result.coach!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: BgmsColors.accent,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (result.signature != null)
          Text(
            result.signature!,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        if (result.signatureSub != null)
          Text(
            result.signatureSub!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: BgmsColors.textSecondary,
            ),
          ),
        const SizedBox(height: 12),
        for (final (index, point) in result.feedback.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    style: BgmsText.number(18, color: BgmsColors.accent),
                  ),
                ),
                Expanded(child: Text(point)),
              ],
            ),
          ),
        if (result.verdict != null) ...[
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: BgmsColors.elevated,
              border: Border(
                left: BorderSide(color: BgmsColors.accent, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '종합 진단',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    result.verdict!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (result.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final action in result.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      action.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (action.desc.isNotEmpty)
                          Text(
                            action.desc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: BgmsColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
