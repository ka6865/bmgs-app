import 'package:flutter/material.dart';

class StatsDetailScreen extends StatelessWidget {
  const StatsDetailScreen({
    super.key,
    required this.nickname,
    required this.platform,
  });

  final String? nickname;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final hasNickname = nickname != null && nickname!.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '전적',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNickname ? nickname! : '검색할 닉네임이 없습니다',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('플랫폼: $platform'),
                const SizedBox(height: 16),
                const LinearProgressIndicator(value: 0),
                const SizedBox(height: 12),
                const Text('기존 Next API 연결을 위한 화면 골격입니다.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _PlaceholderPanel(
          title: '최근 매치',
          body: '/api/pubg/matches-summary 응답을 카드로 표시할 예정입니다.',
        ),
        const SizedBox(height: 12),
        const _PlaceholderPanel(
          title: 'AI 요약',
          body: '로그인/비용 정책 확정 후 /api/pubg/ai-summary와 연결합니다.',
        ),
      ],
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
