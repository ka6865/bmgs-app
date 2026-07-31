import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_search_flow.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
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
    'tier': '티어',
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

  void _resetFilters() {
    setState(() {
      _mode = 'all';
      _perspective = 'all';
      _matchType = 'all';
      _boardFuture = _loadBoard();
    });
  }

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
      onRefresh: () async {
        _reload();
        await _boardFuture;
      },
      child: ListView(
        padding: const EdgeInsets.all(BgmsSpacing.lg),
        children: [
          ScreenHeader(
            title: '랭킹',
            trailing: IconButton(
              tooltip: '새로고침',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ),
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
          const SizedBox(height: BgmsSpacing.md),
          for (final axis in axes) ...[
            _FilterChipRow(axis: axis),
            const SizedBox(height: BgmsSpacing.sm),
          ],
          if (_hasActiveFilters)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('필터 초기화'),
              ),
            ),
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

    return SectionCard(
      title: _title(board.query.tab),
      subtitle: board.displayMessage,
      action: Chip(
        label: Text(board.displaySourceLabel),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        children: [
          for (final entry in board.entries)
            _RankingTile(entry: entry, tab: board.query.tab),
        ],
      ),
    );
  }

  String _title(String tab) {
    return switch (tab) {
      'kills' => '주간 킬 랭킹',
      'tier' => '티어 랭킹',
      _ => '주간 딜량 랭킹',
    };
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, required this.tab});

  final RankingEntry entry;
  final String tab;

  /// 1~3위는 메달 색으로 강조하고 나머지는 기본 표면색을 쓴다.
  Color get _rankColor => switch (entry.rank) {
    1 => const Color(0xFFFFD54F),
    2 => const Color(0xFFCFD8DC),
    3 => const Color(0xFFD98A55),
    _ => BgmsColors.textSecondary,
  };

  String get _valueText {
    if (entry.value <= 0) return entry.label;
    return switch (tab) {
      'kills' => '${entry.value.toStringAsFixed(0)} 킬',
      'tier' =>
        entry.label.isNotEmpty ? entry.label : entry.value.toStringAsFixed(0),
      _ => '${entry.value.toStringAsFixed(0)} 딜',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.rank <= 3;

    return InkWell(
      borderRadius: BgmsRadius.md,
      onTap: () {
        final destination = PlayerSearchDestination(
          nickname: entry.nickname,
          platform: normalizePlayerPlatform(entry.platform),
        );
        context.go(destination.location);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BgmsSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _rankColor,
                  fontWeight: isTopThree ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: BgmsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    entry.platform.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BgmsColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BgmsSpacing.sm),
            Text(
              _valueText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isTopThree ? BgmsColors.accent : BgmsColors.textPrimary,
              ),
            ),
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
