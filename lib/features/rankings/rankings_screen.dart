import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_search_flow.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
import '../maps/map_models.dart';
import 'ranking_models.dart';
import 'rankings_repository.dart';

/// 랭킹 필터 축 하나를 표현한다.
class _FilterAxis {
  const _FilterAxis({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
}

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.repository});

  /// 테스트에서 fake repository를 주입한다.
  final RankingsRepository? repository;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  late final RankingsRepository _repository =
      widget.repository ?? RankingsRepository();

  static const _tabs = <String, String>{
    'damage': '딜량',
    'kills': '킬',
    'tier': 'BGMS 점수',
  };
  static const _modes = <String, String>{
    'all': '전체',
    'squad': '스쿼드',
    'duo': '듀오',
    'solo': '솔로',
  };
  static const _perspectives = <String, String>{
    'all': '전체',
    'fpp': 'FPP',
    'tpp': 'TPP',
  };
  static const _matchTypes = <String, String>{
    'all': '전체',
    'official': '공식',
    'competitive': '경쟁',
  };

  String _tab = 'damage';
  String _mode = 'all';
  String _perspective = 'all';
  String _matchType = 'all';
  late Future<RankingBoard> _boardFuture;

  @override
  void initState() {
    super.initState();
    _boardFuture = _loadBoard();
  }

  RankingQuery get _query => RankingQuery(
    tab: _tab,
    mode: _mode,
    perspective: _perspective,
    matchType: _matchType,
  );

  Future<RankingBoard> _loadBoard() => _repository.fetchBoard(_query);

  void _reload() {
    setState(() {
      _boardFuture = _loadBoard();
    });
  }

  /// 당겨서 새로고침용. 새로 만든 future를 직접 기다려
  /// 인디케이터가 완료 시점에 맞춰 사라지게 한다.
  Future<void> _refresh() async {
    final future = _loadBoard();
    setState(() {
      _boardFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // 실패는 FutureBuilder의 ErrorPanel이 표시한다.
    }
  }

  void _resetFilters() {
    setState(() {
      _mode = 'all';
      _perspective = 'all';
      _matchType = 'all';
      _boardFuture = _loadBoard();
    });
  }

  bool _showFilters = false;

  bool get _hasActiveFilters =>
      _mode != 'all' || _perspective != 'all' || _matchType != 'all';

  @override
  Widget build(BuildContext context) {
    final axes = <_FilterAxis>[
      _FilterAxis(
        label: '모드',
        options: _modes,
        value: _mode,
        onChanged: (value) {
          setState(() {
            _mode = value;
            _boardFuture = _loadBoard();
          });
        },
      ),
      _FilterAxis(
        label: '시점',
        options: _perspectives,
        value: _perspective,
        onChanged: (value) {
          setState(() {
            _perspective = value;
            _boardFuture = _loadBoard();
          });
        },
      ),
      _FilterAxis(
        label: '매치',
        options: _matchTypes,
        value: _matchType,
        onChanged: (value) {
          setState(() {
            _matchType = value;
            _boardFuture = _loadBoard();
          });
        },
      ),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const ScreenHeader(title: '랭킹'),
          const SizedBox(height: BgmsSpacing.lg),
          SegmentedButton<String>(
            segments: [
              for (final entry in _tabs.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() {
                _tab = selection.first;
                _boardFuture = _loadBoard();
              });
            },
          ),
          const SizedBox(height: BgmsSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(
                  _showFilters ? Icons.expand_less : Icons.tune,
                  size: 18,
                ),
                label: Text(
                  _hasActiveFilters
                      ? '필터 · ${[for (final axis in axes)
                          if (axis.value != 'all') axis.options[axis.value]].join(' · ')}'
                      : '필터',
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('필터 초기화'),
                ),
            ],
          ),
          if (_showFilters)
            for (final axis in axes) ...[
              _FilterChipRow(axis: axis),
              const SizedBox(height: BgmsSpacing.sm),
            ],
          const SizedBox(height: BgmsSpacing.sm),
          FutureBuilder<RankingBoard>(
            future: _boardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingCard(lines: 6, label: '랭킹을 집계하고 있습니다');
              }
              if (snapshot.hasError) {
                return ErrorPanel(
                  error: snapshot.error!,
                  onRetry: _reload,
                  title: '랭킹을 불러오지 못했습니다',
                );
              }

              final board = snapshot.data;
              if (board == null) {
                return ErrorPanel(error: '랭킹 응답이 비어 있습니다.', onRetry: _reload);
              }
              return _RankingBoardView(
                board: board,
                onRetry: _reload,
                onResetFilters: _hasActiveFilters ? _resetFilters : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.axis});

  final _FilterAxis axis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            axis.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in axis.options.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: BgmsSpacing.sm),
                    child: ChoiceChip(
                      label: Text(option.value),
                      selected: axis.value == option.key,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (!selected) return;
                        axis.onChanged(option.key);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingBoardView extends StatelessWidget {
  const _RankingBoardView({
    required this.board,
    required this.onRetry,
    this.onResetFilters,
  });

  final RankingBoard board;
  final VoidCallback onRetry;
  final VoidCallback? onResetFilters;

  @override
  Widget build(BuildContext context) {
    if (board.source != RankingSource.api) {
      return InfoPanel(
        icon: Icons.leaderboard_outlined,
        title: '${_title(board.query.tab)} 준비 중',
        body: board.displayMessage,
        action: Wrap(
          spacing: BgmsSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
            ),
            if (onResetFilters != null)
              OutlinedButton(
                onPressed: onResetFilters,
                child: const Text('필터 초기화'),
              ),
          ],
        ),
      );
    }

    final entries = board.entries;
    // 동점·누락으로 1~3위가 온전하지 않으면 시상대 없이 목록만 보여준다.
    final podium =
        entries.length >= 3 &&
            [for (final entry in entries.take(3)) entry.rank].join() == '123'
        ? entries.take(3).toList()
        : const <RankingEntry>[];
    final rest = entries.skip(podium.length).toList();
    final tab = board.query.tab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title(tab),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          [
            board.displayMessage,
            board.displaySourceLabel,
          ].where((text) => text.isNotEmpty).join(' · '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BgmsColors.textMuted),
        ),
        const SizedBox(height: BgmsSpacing.md),
        if (podium.isNotEmpty) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 가운데가 1위가 되도록 2-1-3 순서로 놓는다.
                for (final entry in [podium[1], podium[0], podium[2]])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _PodiumCard(entry: entry, tab: tab),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BgmsSpacing.md),
        ],
        if (rest.isNotEmpty)
          Material(
            color: BgmsColors.surface,
            shape: BgmsShape.panel(
              side: const BorderSide(color: BgmsColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, entry) in rest.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, color: BgmsColors.border),
                  _RankingTile(entry: entry, tab: tab),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _title(String tab) {
    return switch (tab) {
      'kills' => '주간 킬 랭킹',
      'tier' => 'BGMS 최고 경기',
      _ => '주간 딜량 랭킹',
    };
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.tab});

  final RankingEntry entry;
  final String tab;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPlayer(context, entry),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: BgmsText.number(20, color: BgmsColors.textSecondary),
              ),
            ),
            const SizedBox(width: BgmsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.platform.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BgmsColors.textMuted,
                        ),
                      ),
                      if (entry.label.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          entry.label,
                          style: const TextStyle(color: BgmsColors.accent),
                        ),
                      ],
                    ],
                  ),
                  if (entry.mapName != null || entry.gameMode != null)
                    Text(
                      [
                            if (entry.mapName != null)
                              bgmsMapDisplayName(entry.mapName),
                            entry.gameMode,
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: BgmsColors.textSecondary,
                      fontSize: 12,
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (entry.secondary != null)
                          Text(
                            tab == 'damage'
                                ? '${entry.secondary!.toStringAsFixed(0)} 킬'
                                : '${entry.secondary!.toStringAsFixed(0)} 딜',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BgmsSpacing.sm),
            Text(_valueText(entry, tab), style: BgmsText.number(20)),
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

String _valueText(RankingEntry entry, String tab) => switch (tab) {
  'kills' => '${entry.value.toStringAsFixed(0)} 킬',
  'tier' => '${entry.value.toStringAsFixed(1)} 점',
  _ => '${entry.value.toStringAsFixed(0)} 딜',
};

void _openPlayer(BuildContext context, RankingEntry entry) {
  final destination = PlayerSearchDestination(
    nickname: entry.nickname,
    platform: normalizePlayerPlatform(entry.platform),
  );
  context.go(destination.location);
}

/// 1~3위 시상대. 1위만 골드, 높이로 순위를 보여준다.
class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry, required this.tab});

  final RankingEntry entry;
  final String tab;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    final theme = Theme.of(context);
    return Material(
      color: first ? BgmsColors.elevated : BgmsColors.surface,
      shape: BgmsShape.panel(
        side: BorderSide(color: first ? BgmsColors.accent : BgmsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlayer(context, entry),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, first ? 18 : 10, 8, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${entry.rank}',
                style: BgmsText.number(
                  first ? 40 : 30,
                  color: first ? BgmsColors.accent : BgmsColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                [
                  entry.platform.toUpperCase(),
                  if (entry.label.isNotEmpty) entry.label,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: BgmsColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _valueText(entry, tab),
                  style: BgmsText.number(
                    first ? 24 : 20,
                    color: first ? BgmsColors.accent : BgmsColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
