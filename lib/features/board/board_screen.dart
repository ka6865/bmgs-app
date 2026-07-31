import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_brand_header.dart';
import 'board_models.dart';
import 'board_repository.dart';

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

  /// 게시판 분류 키와 표시 라벨.
  static const _categories = <MapEntry<String, String>>[
    MapEntry('all', '전체'),
    MapEntry('free', '자유'),
    MapEntry('strategy', '공략'),
    MapEntry('question', '질문'),
  ];

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
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
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
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on BoardException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
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
            onPressed: () => context.go('/my'),
          ),
        ),
      );
      return;
    }

    final createdId = await showDialog<int>(
      context: context,
      builder: (context) => const _BoardWriteDialog(),
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
            trailing: IconButton(
              onPressed: _openWriteDialog,
              icon: const Icon(Icons.edit_outlined),
              tooltip: '글쓰기',
              style: IconButton.styleFrom(
                backgroundColor: BgmsColors.accent,
                foregroundColor: BgmsColors.bgBase,
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
            const InfoPanel(
              icon: Icons.forum_outlined,
              title: '게시글이 없습니다',
              body: '아직 이 조건에 맞는 글이 없습니다. 다른 분류를 선택하거나 첫 글을 남겨 보세요.',
            )
          else
            ..._posts.map((post) => _PostTile(post: post)),
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

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final BoardPostSummary post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/board/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    post.imageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    // 실패해도 72px 자리를 유지해 목록 행 높이가 흔들리지 않게 한다.
                    errorBuilder: (_, _, _) => const _ThumbnailPlaceholder(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _ThumbnailPlaceholder();
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (post.isNotice)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.campaign,
                              size: 16,
                              color: BgmsColors.accent,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${post.author} · ${_shortDate(post.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.forum,
                          text: '${post.commentCount}',
                        ),
                        _MetaChip(
                          icon: Icons.visibility,
                          text: '${post.views}',
                        ),
                        _MetaChip(icon: Icons.thumb_up, text: '${post.likes}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BoardWriteDialog extends StatefulWidget {
  const _BoardWriteDialog();

  @override
  State<_BoardWriteDialog> createState() => _BoardWriteDialogState();
}

class _BoardWriteDialogState extends State<_BoardWriteDialog> {
  final BoardRepository _repository = BoardRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _category = 'free';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await _repository.createPost(
        title: _titleController.text,
        content: _contentController.text,
        category: _category,
      );
      if (mounted) Navigator.of(context).pop(id);
    } on BoardException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('게시글 작성'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: const [
                DropdownMenuItem(value: 'free', child: Text('자유')),
                DropdownMenuItem(value: 'strategy', child: Text('공략')),
                DropdownMenuItem(value: 'question', child: Text('질문')),
              ],
              onChanged: (value) => setState(() => _category = value ?? 'free'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
              maxLength: 80,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '본문',
                helperText: '사진 첨부는 앱에서 지원하지 않습니다.',
              ),
              minLines: 5,
              maxLines: 8,
              maxLength: 5000,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '저장 중...' : '등록'),
        ),
      ],
    );
  }
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return value;
}

/// 게시글 썸네일 자리를 지키는 대체 박스.
///
/// 로딩 중과 실패 상황 모두 같은 크기를 차지해 목록 행 높이가 변하지 않는다.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BgmsColors.border),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: BgmsColors.textMuted,
      ),
    );
  }
}
