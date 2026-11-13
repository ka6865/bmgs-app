import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'board_models.dart';
import 'board_categories.dart';
import 'board_repository.dart';
import 'board_write_dialog.dart';
import '../../core/widgets/cached_image.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardRepository _repository = BoardRepository();
  final TextEditingController _searchController = TextEditingController();
  final List<BoardPostSummary> _posts = [];
  String _category = 'all';
  String? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  static const _categories = BoardCategories.filters;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
        _posts.clear();
        _hasMore = false;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await _repository.fetchPosts(
        category: _category,
        cursor: reset ? null : _cursor,
        query: _searchController.text,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on BoardException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openWriteDialog() async {
    // 글을 다 쓴 뒤 401을 받는 대신, 로그인 여부를 먼저 알린다.
    if (!_repository.canWrite) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('글쓰기는 로그인 후 이용할 수 있습니다.'),
          action: SnackBarAction(
            label: '로그인',
            onPressed: () => context.push('/my'),
          ),
        ),
      );
      return;
    }

    final createdId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BoardWriteDialog(repository: _repository),
    );
    if (!mounted || createdId == null) return;
    await _load(reset: true);
    if (createdId > 0 && mounted) context.push('/board/$createdId');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ScreenHeader(
            title: '커뮤니티',
            trailing: Tooltip(
              message: '글쓰기',
              child: FilledButton.icon(
                onPressed: _openWriteDialog,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('글쓰기'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 지우기 버튼만 입력값에 반응하도록 해서 화면 전체 재빌드를 피한다.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              return TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '제목이나 내용 검색',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: '검색어 지우기',
                          onPressed: () {
                            _searchController.clear();
                            _load(reset: true);
                          },
                        ),
                ),
                onSubmitted: (_) => _load(reset: true),
              );
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.value),
                      selected: _category == category.key,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (!selected || _category == category.key) return;
                        setState(() => _category = category.key);
                        _load(reset: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingCard(lines: 5, label: '게시글을 불러오고 있습니다')
          else if (_error != null)
            ErrorPanel(
              error: _error!,
              onRetry: () => _load(reset: true),
              title: '게시글을 불러오지 못했습니다',
            )
          else if (_posts.isEmpty)
            InfoPanel(
              icon: Icons.forum_outlined,
              title: '게시글이 없습니다',
              body: _hasMore
                  ? '조회한 구간에는 해당 분류의 글이 없습니다. 더 보기로 이전 글을 확인하세요.'
                  : '이 조건에 맞는 글이 없습니다. 다른 분류를 선택해 보세요.',
            )
          else
            Material(
              color: BgmsColors.surface,
              shape: BgmsShape.panel(
                side: const BorderSide(color: BgmsColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (index, post) in _posts.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, color: BgmsColors.border),
                    _PostTile(post: post),
                  ],
                ],
              ),
            ),
          if (_hasMore && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                child: Text(_loadingMore ? '불러오는 중...' : '더 보기'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 웹 모바일 게시판(components/board/PostItem.tsx)과 같은 한 줄 구성.
class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final BoardPostSummary post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: BgmsColors.textMuted,
    );
    final category = post.isNotice
        ? '공지'
        : BoardCategories.canonical(post.category);

    return Material(
      color: post.isNotice
          ? BgmsColors.accent.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/board/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryLabel(
                          text: category,
                          highlight: post.isNotice,
                        ),
                        const Spacer(),
                        Text(_timeAgo(post.createdAt), style: muted),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: post.title,
                        children: [
                          if (post.imageUrl != null)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 14,
                                  color: BgmsColors.success,
                                ),
                              ),
                            ),
                          if (post.commentCount > 0)
                            TextSpan(
                              text: ' [${post.commentCount}]',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: BgmsColors.accent.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: post.isNotice
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: post.isNotice
                            ? BgmsColors.accent
                            : BgmsColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: BgmsColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '조회 ${post.views} · 추천 ${post.likes}',
                          style: muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (post.imageUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BgmsRadius.md,
                  child: Image(
                    image: cachedImageProvider(post.imageUrl!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox.square(dimension: 56),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.text, required this.highlight});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? BgmsColors.accent : BgmsColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.2 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BgmsRadius.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 웹 formatTimeAgo처럼 하루 안은 상대 시간, 그 뒤는 날짜만 보여준다.
String _timeAgo(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value.length >= 10 ? value.substring(0, 10) : value;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
