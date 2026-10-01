import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'crate_draw.dart';
import 'crate_models.dart';
import 'crate_rarity_style.dart';
import 'crates_repository.dart';
import 'widgets/crate_reveal_card.dart';

/// 상자깡 시뮬레이터.
///
/// 실제 결제 없이 공식 확률로 결과를 보여준다. 화면은 상자 선택,
/// 뽑기 실행, 결과 연출, 누적 통계 순서로 배치한다.
class CratesScreen extends StatefulWidget {
  const CratesScreen({super.key, this.repository});

  final CratesRepository? repository;

  @override
  State<CratesScreen> createState() => _CratesScreenState();
}

class _CratesScreenState extends State<CratesScreen> {
  late final CratesRepository _repository;
  late Future<List<CrateTemplate>> _cratesFuture;
  final CrateDrawMachine _machine = CrateDrawMachine();

  CrateTemplate? _selected;
  List<CrateDrawResult> _results = const [];
  CrateSessionStats _stats = const CrateSessionStats();

  /// 결과가 바뀔 때마다 카드 위젯을 새로 만들어 연출을 다시 재생한다.
  int _drawSeq = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const CratesRepository();
    _cratesFuture = _load();
  }

  /// 조회를 감싸 동기 예외도 Future 오류로 만든다.
  ///
  /// 이렇게 하지 않으면 build 전에 예외가 던져져 화면이 뜨지 않는다.
  Future<List<CrateTemplate>> _load() async {
    return _repository.fetchActiveCrates();
  }

  void _reload() {
    setState(() {
      _cratesFuture = _load();
      _selected = null;
      _results = const [];
      _stats = const CrateSessionStats();
    });
  }

  void _draw(int count) {
    final template = _selected;
    if (template == null) return;

    final pool = template.baseItems;
    if (pool.isEmpty) return;

    final unit = template.priceGcoin ?? 0;
    final bundle = template.bundlePriceGcoin;
    // 10연차는 묶음 가격이 있으면 그것을 쓴다.
    final cost = count >= 10 && bundle != null ? bundle : unit * count;

    final results = _machine.draw(pool, count: count);
    setState(() {
      _results = results;
      _stats = _stats.apply(results, cost: cost);
      _drawSeq++;
    });
  }

  void _resetStats() {
    setState(() {
      _results = const [];
      _stats = const CrateSessionStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BgmsColors.bgBase,
      child: FutureBuilder<List<CrateTemplate>>(
        future: _cratesFuture,
        builder: (context, snapshot) {
          final children = <Widget>[
            const ScreenHeader(title: '상자깡 시뮬'),
            const SizedBox(height: 14),
          ];

          if (snapshot.connectionState == ConnectionState.waiting) {
            children.add(
              const LoadingCard(lines: 5, label: '상자 정보를 불러오고 있습니다'),
            );
          } else if (snapshot.hasError) {
            children.add(
              ErrorPanel(
                error: snapshot.error!,
                onRetry: _reload,
                title: '상자 정보를 불러오지 못했습니다',
              ),
            );
          } else {
            final crates = snapshot.data ?? const <CrateTemplate>[];
            final selected =
                _selected ?? (crates.isEmpty ? null : crates.first);
            if (selected != null && _selected == null) {
              // 최초 진입 시 첫 상자를 자동 선택한다.
              _selected = selected;
            }

            children.addAll([
              _CrateSelector(
                crates: crates,
                selectedId: selected?.id,
                onSelected: (template) {
                  setState(() {
                    _selected = template;
                    _results = const [];
                  });
                },
              ),
              const SizedBox(height: 18),
              if (selected != null) ...[
                _DrawActions(template: selected, onDraw: _draw),
                const SizedBox(height: 18),
                if (_results.isNotEmpty) ...[
                  _ResultGrid(key: ValueKey(_drawSeq), results: _results),
                  const SizedBox(height: 18),
                ],
                _StatsPanel(stats: _stats, onReset: _resetStats),
                const SizedBox(height: 18),
                _ProbabilityTable(template: selected),
              ],
            ]);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: children,
          );
        },
      ),
    );
  }
}

/// 상자 선택 칩.
class _CrateSelector extends StatelessWidget {
  const _CrateSelector({
    required this.crates,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CrateTemplate> crates;
  final String? selectedId;
  final ValueChanged<CrateTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return SectionBand(
      title: '상자 선택',
      icon: Icons.inventory_2_outlined,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final crate in crates)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(crate.name),
                  selected: crate.id == selectedId,
                  showCheckmark: false,
                  onSelected: (isSelected) {
                    if (!isSelected || crate.id == selectedId) return;
                    onSelected(crate);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 단발과 10연차 실행 버튼.
class _DrawActions extends StatelessWidget {
  const _DrawActions({required this.template, required this.onDraw});

  final CrateTemplate template;
  final ValueChanged<int> onDraw;

  @override
  Widget build(BuildContext context) {
    final unit = template.priceGcoin;
    final bundle = template.bundlePriceGcoin;

    return SectionBand(
      title: '뽑기',
      icon: Icons.casino_outlined,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => onDraw(1),
              child: Text(unit == null ? '1회' : '1회 · ${unit}G'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => onDraw(10),
              child: Text(bundle == null ? '10연차' : '10연차 · ${bundle}G'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 카드 격자. 카드가 순서대로 열린다.
class _ResultGrid extends StatelessWidget {
  const _ResultGrid({super.key, required this.results});

  final List<CrateDrawResult> results;

  @override
  Widget build(BuildContext context) {
    final best = results
        .map((r) => r.item.rarity)
        .reduce((a, b) => a.index < b.index ? a : b);

    return SectionBand(
      title: '결과',
      icon: Icons.auto_awesome,
      action: Text(
        '최고 ${best.label}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: crateRarityColor(best),
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.78,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          return CrateRevealCard(
            result: results[index],
            // 카드가 차례로 열리도록 순번만큼 지연을 준다.
            revealDelay: Duration(milliseconds: 120 * index),
          );
        },
      ),
    );
  }
}

/// 누적 통계.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.onReset});

  final CrateSessionStats stats;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SectionBand(
      title: '누적',
      icon: Icons.query_stats,
      action: stats.drawCount == 0
          ? null
          : TextButton(onPressed: onReset, child: const Text('초기화')),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BgmsColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BgmsColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _StatCell(label: '뽑은 횟수', value: '${stats.drawCount}'),
                _StatCell(label: '소모 G코인', value: '${stats.spentGcoin}'),
                _StatCell(label: '중복 토큰', value: '${stats.tokens}'),
              ],
            ),
            if (stats.drawCount > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: BgmsColors.border),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rarity in CrateRarity.values)
                    if (stats.countOf(rarity) > 0)
                      _RarityTally(
                        rarity: rarity,
                        count: stats.countOf(rarity),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

class _RarityTally extends StatelessWidget {
  const _RarityTally({required this.rarity, required this.count});

  final CrateRarity rarity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = crateRarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(crateRarityIcon(rarity), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '${rarity.label} $count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공식 확률 표. 시뮬레이터의 신뢰를 위해 함께 보여준다.
class _ProbabilityTable extends StatelessWidget {
  const _ProbabilityTable({required this.template});

  final CrateTemplate template;

  @override
  Widget build(BuildContext context) {
    final items = [...template.baseItems]
      ..sort((a, b) {
        final byRarity = a.rarity.index.compareTo(b.rarity.index);
        if (byRarity != 0) return byRarity;
        return b.probability.compareTo(a.probability);
      });

    return SectionBand(
      title: '공식 확률',
      icon: Icons.percent,
      action: Text(
        '${items.length}종',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: BgmsColors.textMuted),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: BgmsColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BgmsColors.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              _ProbabilityRow(item: items[i], isLast: i == items.length - 1),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({required this.item, required this.isLast});

  final CrateItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = crateRarityColor(item.rarity);
    final percent = (item.probability * 100).toStringAsFixed(
      item.probability < 0.001 ? 4 : 2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: BgmsColors.border)),
      ),
      child: Row(
        children: [
          Icon(crateRarityIcon(item.rarity), size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BgmsColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
