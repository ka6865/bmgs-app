import 'package:flutter/material.dart';

import '../../../core/theme/bgms_theme.dart';
import '../../../core/widgets/app_panels.dart';
import '../../board/board_models.dart';
import '../../board/board_repository.dart';
import '../../rankings/ranking_models.dart';
import '../../rankings/rankings_repository.dart';

/// 홈의 주간 딜량 랭킹 상위 3명. 전체 랭킹 화면으로 이어진다.
class HomeRankingSection extends StatefulWidget {
  const HomeRankingSection({
    super.key,
    required this.onOpenAll,
    required this.onPlayerTap,
    this.repository,
  });

  final VoidCallback onOpenAll;
  final void Function(RankingEntry entry) onPlayerTap;
  final RankingsRepository? repository;

  @override
  State<HomeRankingSection> createState() => _HomeRankingSectionState();
}

class _HomeRankingSectionState extends State<HomeRankingSection> {
  late final Future<RankingBoard> _future =
      (widget.repository ?? RankingsRepository()).fetchBoard(
        const RankingQuery(tab: 'damage'),
      );

  @override
  Widget build(BuildContext context) {
    return SectionBand(
      title: '이번 주 딜량 랭킹',
      action: TextButton(onPressed: widget.onOpenAll, child: const Text('전체')),
      child: FutureBuilder<RankingBoard>(
        future: _future,
        builder: (context, snapshot) {
          final board = snapshot.data;
          if (board == null) return const SkeletonBox(height: 132);
          if (board.isFallback || board.entries.isEmpty) {
            return _QuietNote(text: board.displayMessage);
          }
          return _Panel(
            children: [
              for (final entry in board.entries.take(3))
                ListTile(
                  minTileHeight: 48,
                  onTap: () => widget.onPlayerTap(entry),
                  leading: SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.rank}',
                      style: BgmsText.number(
                        22,
                        color: entry.rank == 1
                            ? BgmsColors.accent
                            : BgmsColors.textPrimary,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    '${entry.value.toStringAsFixed(0)} 딜',
                    style: BgmsText.number(18, color: BgmsColors.accent),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 홈의 커뮤니티 최신글 3개.
class HomeCommunitySection extends StatefulWidget {
  const HomeCommunitySection({
    super.key,
    required this.onOpenAll,
    required this.onPostTap,
    this.repository,
  });

  final VoidCallback onOpenAll;
  final void Function(int postId) onPostTap;
  final BoardRepository? repository;

  @override
  State<HomeCommunitySection> createState() => _HomeCommunitySectionState();
}

class _HomeCommunitySectionState extends State<HomeCommunitySection> {
  late final Future<BoardPostPage> _future =
      (widget.repository ?? BoardRepository()).fetchPosts();

  @override
  Widget build(BuildContext context) {
    return SectionBand(
      title: '커뮤니티 새 글',
      action: TextButton(onPressed: widget.onOpenAll, child: const Text('전체')),
      child: FutureBuilder<BoardPostPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SkeletonBox(height: 132);
          }
          final posts = snapshot.data?.items.take(3).toList() ?? const [];
          if (snapshot.hasError) {
            return const _QuietNote(text: '커뮤니티 글을 불러오지 못했습니다.');
          }
          if (posts.isEmpty) return const _QuietNote(text: '아직 글이 없습니다.');
          return _Panel(
            children: [
              for (final post in posts)
                ListTile(
                  minTileHeight: 48,
                  onTap: () => widget.onPostTap(post.id),
                  title: Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${post.author} · 댓글 ${post.commentCount} · 추천 ${post.likes}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BgmsColors.surface,
      shape: BgmsShape.panel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
    );
  }
}
