import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_card.dart';
import 'squad_models.dart';
import 'squad_repository.dart';

/// 함께 플레이한 팀 묶음별 협업 지표와 스쿼드 AI 코칭.
class SquadScreen extends StatefulWidget {
  const SquadScreen({
    super.key,
    required this.nickname,
    required this.platform,
    this.repository,
  });

  final String nickname;
  final String platform;
  final SquadRepository? repository;

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  late final SquadRepository _repository =
      widget.repository ?? SquadRepository();
  late Future<List<SquadGroup>> _groups = _loadGroups();
  String? _groupKey;

  Future<List<SquadGroup>> _loadGroups() => _repository.fetchGroups(
    nickname: widget.nickname,
    platform: widget.platform,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스쿼드 분석')),
      body: FutureBuilder<List<SquadGroup>>(
        future: _groups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingCard(lines: 4, label: '함께 플레이한 팀을 찾고 있습니다');
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorPanel(
                  error: snapshot.error!,
                  title: '팀 기록을 불러오지 못했습니다',
                  onRetry: () => setState(() {
                    _groups = _loadGroups();
                  }),
                ),
              ],
            );
          }
          final groups = snapshot.data ?? const [];
          if (groups.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                InfoPanel(
                  icon: Icons.groups_outlined,
                  title: '분석할 팀 기록이 없습니다',
                  body: '최근 14일 안에 같은 팀원과 함께 한 듀오·스쿼드 경기가 있어야 합니다.',
                ),
              ],
            );
          }
          final selected = groups.firstWhere(
            (group) => group.groupKey == _groupKey,
            orElse: () => groups.first,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final group in groups)
                      Padding(
                        padding: const EdgeInsets.only(right: BgmsSpacing.sm),
                        child: ChoiceChip(
                          showCheckmark: false,
                          selected: group == selected,
                          label: Text(
                            '${group.modeLabel} · ${group.members.join(', ')} · ${group.matchCount}경기',
                          ),
                          onSelected: (_) =>
                              setState(() => _groupKey = group.groupKey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BgmsSpacing.lg),
              _GroupAnalysis(
                key: ValueKey(selected.groupKey),
                repository: _repository,
                nickname: widget.nickname,
                platform: widget.platform,
                groupKey: selected.groupKey,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupAnalysis extends StatefulWidget {
  const _GroupAnalysis({
    super.key,
    required this.repository,
    required this.nickname,
    required this.platform,
    required this.groupKey,
  });

  final SquadRepository repository;
  final String nickname;
  final String platform;
  final String groupKey;

  @override
  State<_GroupAnalysis> createState() => _GroupAnalysisState();
}

class _GroupAnalysisState extends State<_GroupAnalysis> {
  late Future<SquadAnalysis> _analysis = _load();

  Future<SquadAnalysis> _load() => widget.repository.fetchAnalysis(
    nickname: widget.nickname,
    platform: widget.platform,
    groupKey: widget.groupKey,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SquadAnalysis>(
      future: _analysis,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingCard(lines: 5, label: '팀 지표를 계산하고 있습니다');
        }
        final analysis = snapshot.data;
        if (analysis == null) {
          return ErrorPanel(
            error: snapshot.error ?? '알 수 없는 오류',
            title: '스쿼드 분석을 불러오지 못했습니다',
            onRetry: () => setState(() {
              _analysis = _load();
            }),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GradePanel(analysis: analysis),
            if (analysis.roles.isNotEmpty) ...[
              const SizedBox(height: BgmsSpacing.xl),
              SectionBand(
                title: '팀원 역할',
                child: Column(
                  children: [
                    for (final role in analysis.roles) _RoleRow(role: role),
                  ],
                ),
              ),
            ],
            if (analysis.scenes.isNotEmpty) ...[
              const SizedBox(height: BgmsSpacing.xl),
              SectionBand(
                title: '흐름이 꺾인 장면',
                child: Column(
                  children: [
                    for (final scene in analysis.scenes)
                      _SceneRow(scene: scene),
                  ],
                ),
              ),
            ],
            const SizedBox(height: BgmsSpacing.xl),
            _SquadAiSection(
              repository: widget.repository,
              nickname: widget.nickname,
              platform: widget.platform,
              groupKey: widget.groupKey,
            ),
          ],
        );
      },
    );
  }
}

class _GradePanel extends StatelessWidget {
  const _GradePanel({required this.analysis});

  final SquadAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = analysis.windowDays;
    return BgmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: analysis.grade == null
                    ? '팀 등급 보류'
                    : '팀 등급 ${analysis.grade}',
                excludeSemantics: true,
                child: Text(
                  analysis.grade ?? '보류',
                  style: BgmsText.number(56, color: BgmsColors.accent),
                ),
              ),
              const SizedBox(width: BgmsSpacing.md),
              Expanded(
                child: Text(
                  analysis.grade == null
                      ? '측정한 지표가 부족해 등급을 매기지 않았습니다.'
                      : '분석 ${analysis.matchCount}경기${days == null ? '' : ' · 최근 $days일'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BgmsColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BgmsSpacing.lg),
          for (final (key, label) in squadScoreAxes)
            _ScoreBar(label: label, score: analysis.scores[key]),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});

  final String label;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final value = score;
    return Semantics(
      label: value == null ? '$label 측정 없음' : '$label $value점',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: BgmsColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: value == null ? 0 : value / 100,
                minHeight: 6,
                color: BgmsColors.accent,
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                value?.toString() ?? '-',
                textAlign: TextAlign.right,
                style: BgmsText.number(18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role});

  final SquadRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = [
      if (role.avgDamage != null) '평균 딜 ${role.avgDamage}',
      if (role.avgKills != null) '평균 킬 ${role.avgKills!.toStringAsFixed(1)}',
      if (role.damageShare != null) '딜 비중 ${role.damageShare}%',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: BgmsSpacing.md),
      child: BgmsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    role.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (role.role.isNotEmpty)
                  Text(
                    role.role,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: BgmsColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            if (role.roleDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(role.roleDescription, style: theme.textTheme.bodySmall),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                facts,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BgmsColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SceneRow extends StatelessWidget {
  const _SceneRow({required this.scene});

  final SquadScene scene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BgmsSpacing.md),
      child: BgmsCard(
        statusColor: scene.isDanger ? BgmsColors.danger : BgmsColors.knock,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              [
                scene.mapName,
                scene.displayTime,
              ].where((part) => part.isNotEmpty).join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(scene.reason, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// 버튼을 눌러야 AI를 부른다. 화면 진입만으로 비용이 드는 호출을 하지 않는다.
class _SquadAiSection extends StatefulWidget {
  const _SquadAiSection({
    required this.repository,
    required this.nickname,
    required this.platform,
    required this.groupKey,
  });

  final SquadRepository repository;
  final String nickname;
  final String platform;
  final String groupKey;

  @override
  State<_SquadAiSection> createState() => _SquadAiSectionState();
}

class _SquadAiSectionState extends State<_SquadAiSection> {
  bool _spicy = true;
  Future<SquadAiResult>? _result;

  void _run() {
    final result = widget.repository.fetchAi(
      nickname: widget.nickname,
      platform: widget.platform,
      groupKey: widget.groupKey,
      spicy: _spicy,
    );
    // 오류는 아래 FutureBuilder가 그린다. 빌드 전에 실패해도 처리되지 않은 오류로 올라가지 않게 한다.
    result.ignore();
    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _result != null;
    return SectionBand(
      title: '스쿼드 AI 코칭',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('매운맛')),
              ButtonSegment(value: false, label: Text('순한맛')),
            ],
            selected: {_spicy},
            onSelectionChanged: (value) => setState(() {
              _spicy = value.first;
              _result = null;
            }),
          ),
          const SizedBox(height: BgmsSpacing.md),
          if (!running)
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 코칭 받기'),
            )
          else
            FutureBuilder<SquadAiResult>(
              future: _result,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingCard(
                    lines: 4,
                    label: 'AI가 팀 기록을 읽고 있습니다',
                  );
                }
                final result = snapshot.data;
                if (result != null) return _AiResultView(result: result);
                final error = ApiException.from(snapshot.error ?? '');
                if (error.kind == ApiErrorKind.unauthorized) {
                  return InfoPanel(
                    icon: Icons.lock_outline,
                    title: '로그인이 필요합니다',
                    body: '스쿼드 AI 코칭은 로그인 후 이용할 수 있습니다.',
                    action: FilledButton(
                      onPressed: () => context.push('/my'),
                      child: const Text('로그인하러 가기'),
                    ),
                  );
                }
                return ErrorPanel(
                  error: error,
                  title: 'AI 코칭을 받지 못했습니다',
                  onRetry: error.isRetryable ? _run : null,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AiResultView extends StatelessWidget {
  const _AiResultView({required this.result});

  final SquadAiResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget block(String label, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: BgmsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: BgmsColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          );

    return BgmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block('한 줄 요약', result.summary),
          block('잘한 점', result.strength),
          block('아쉬운 점', result.weakness),
          block('코칭', result.coaching),
          for (final member in result.members) ...[
            const Divider(),
            const SizedBox(height: BgmsSpacing.sm),
            Text(
              member.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: BgmsSpacing.sm),
            block('칭찬', member.praise),
            block('못한 점', member.fault),
            block('개인 피드백', member.advice),
          ],
          if (result.overall.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: BgmsSpacing.sm),
            block('총평', result.overall),
          ],
        ],
      ),
    );
  }
}
