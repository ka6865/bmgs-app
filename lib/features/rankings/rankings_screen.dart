import 'package:flutter/material.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  String _tab = 'damage';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '랭킹',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
            setState(() => _tab = selection.first);
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('선택된 랭킹: $_tab'),
                const SizedBox(height: 8),
                const Text('/api/rankings 앱용 API가 준비되면 실제 데이터와 연결합니다.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
