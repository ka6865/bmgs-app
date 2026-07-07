import 'package:flutter/material.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'ranking_models.dart';
import 'rankings_repository.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final RankingsRepository _repository = RankingsRepository();
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

  Future<RankingBoard> _loadBoard() {
    return _repository.fetchBoard(
      RankingQuery(
        tab: _tab,
        mode: _mode,
        perspective: _perspective,
        matchType: _matchType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const BgmsBrandHeader(
          title: '랭킹',
          subtitle: 'damage, kills, tier 기준의 모바일 랭킹 보드입니다.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'damage', label: Text('딜량')),
            ButtonSegment(value: 'kills', label: Text('킬')),
            ButtonSegment(value: 'tier', label: Text('티어')),
          ],
          selected: {_tab},
          onSelectionChanged: (selection) {
            setState(() {
              _tab = selection.first;
              _boardFuture = _loadBoard();
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: '모드'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('전체')),
            DropdownMenuItem(value: 'squad', child: Text('스쿼드')),
            DropdownMenuItem(value: 'duo', child: Text('듀오')),
            DropdownMenuItem(value: 'solo', child: Text('솔로')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _mode = value;
              _boardFuture = _loadBoard();
            });
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _perspective,
                decoration: const InputDecoration(labelText: '시점'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'fpp', child: Text('FPP')),
                  DropdownMenuItem(value: 'tpp', child: Text('TPP')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _perspective = value;
                    _boardFuture = _loadBoard();
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _matchType,
                decoration: const InputDecoration(labelText: '매치'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'official', child: Text('공식')),
                  DropdownMenuItem(value: 'competitive', child: Text('경쟁')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _matchType = value;
                    _boardFuture = _loadBoard();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<RankingBoard>(
          future: _boardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              );
            }

            final board =
                snapshot.data ??
                RankingBoard.fallback(
                  query: RankingQuery(tab: _tab, mode: _mode),
                );
            return _RankingBoardCard(board: board);
          },
        ),
      ],
    );
  }
}

class _RankingBoardCard extends StatelessWidget {
  const _RankingBoardCard({required this.board});

  final RankingBoard board;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title(board.query.tab),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(board.source.name)),
              ],
            ),
            const SizedBox(height: 8),
            Text(board.message),
            const SizedBox(height: 12),
            if (board.entries.isEmpty)
              const Text('표시할 랭킹 데이터가 없습니다.')
            else
              ...board.entries.map((entry) => _RankingTile(entry: entry)),
          ],
        ),
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
  const _RankingTile({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: BgmsColors.elevated,
        foregroundColor: BgmsColors.accent,
        child: Text('${entry.rank}'),
      ),
      title: Text(entry.nickname, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(entry.platform),
      trailing: Text(
        entry.value > 0 ? entry.value.toStringAsFixed(0) : entry.label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
