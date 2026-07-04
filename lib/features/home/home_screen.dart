import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  String _platform = 'steam';

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _search() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    context.go(
      Uri(
        path: '/stats',
        queryParameters: {
          'nickname': nickname,
          'platform': _platform,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'BGMS',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'PUBG 전적과 AI 요약을 빠르게 확인하세요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nicknameController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: '닉네임 검색',
            hintText: 'KangHeeSung_',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: _search,
              icon: const Icon(Icons.arrow_forward),
              tooltip: '검색',
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'steam', label: Text('steam')),
            ButtonSegment(value: 'kakao', label: Text('kakao')),
          ],
          selected: {_platform},
          onSelectionChanged: (selection) {
            setState(() => _platform = selection.first);
          },
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: '최근 검색',
          icon: Icons.history,
          children: const [
            _PlayerChip(label: 'KangHeeSung_'),
            _PlayerChip(label: 'SamplePlayer'),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '즐겨찾기',
          icon: Icons.star_outline,
          children: const [
            _PlayerChip(label: '대표 닉네임을 추가하세요'),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
