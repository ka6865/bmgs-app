import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import 'player_stats_models.dart';
import 'widgets/match_card.dart';

/// 최근 매치 전체 목록 화면.
///
/// 전적 화면은 앞쪽 몇 건만 미리 보여주고, 전체 확인과 모드 필터는 여기서 한다.
class AllMatchesScreen extends StatefulWidget {
  const AllMatchesScreen({
    super.key,
    required this.matches,
    required this.profile,
    this.summaryFallback = false,
  });

  final List<MatchSummary> matches;
  final PlayerStatsProfile profile;
  final bool summaryFallback;

  @override
  State<AllMatchesScreen> createState() => _AllMatchesScreenState();
}

class _AllMatchesScreenState extends State<AllMatchesScreen> {
  /// 기본은 전체다. 사용자가 원할 때만 모드를 좁힌다.
  String _modeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final modes = MatchModeFilters.availableModes(widget.matches);
    final filtered = MatchModeFilters.apply(widget.matches, _modeFilter);

    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 매치'),
            Text(
              widget.profile.nickname,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (modes.length > 1)
            _ModeFilterBar(
              modes: modes,
              selected: _modeFilter,
              total: widget.matches.length,
              filteredCount: filtered.length,
              onChanged: (mode) => setState(() => _modeFilter = mode),
            ),
          if (widget.summaryFallback)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '일부 매치는 서버 분석이 끝나지 않아 요약만 표시합니다.',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyMatches(hasAnyMatch: widget.matches.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => MatchCard(
                      match: filtered[index],
                      profile: widget.profile,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 모드 필터 칩과 현재 표시 건수를 담은 상단 바.
class _ModeFilterBar extends StatelessWidget {
  const _ModeFilterBar({
    required this.modes,
    required this.selected,
    required this.total,
    required this.filteredCount,
    required this.onChanged,
  });

  final List<String> modes;
  final String selected;
  final int total;
  final int filteredCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in ['all', ...modes])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        mode == 'all' ? '전체' : MatchModeFilters.label(mode),
                      ),
                      selected: selected == mode,
                      showCheckmark: false,
                      onSelected: (isSelected) {
                        if (!isSelected || selected == mode) return;
                        onChanged(mode);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selected == 'all' ? '$total경기' : '$filteredCount경기 / 전체 $total경기',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches({required this.hasAnyMatch});

  final bool hasAnyMatch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 40,
              color: BgmsColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              hasAnyMatch
                  ? '이 모드의 매치가 없습니다.\n다른 모드를 선택해 보세요.'
                  : '최근 매치가 없거나 아직 서버에 분석된 매치가 없습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
