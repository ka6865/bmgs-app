import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
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
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on BoardException catch (error) {
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
        padding: const EdgeInsets.all(20),
        children: [
          const BgmsBrandHeader(
            title: '게시판',
            subtitle: 'BGMS 커뮤니티 글을 확인하고 로그인 후 글과 댓글을 작성합니다.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: '검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _load(reset: true),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _openWriteDialog,
                icon: const Icon(Icons.edit),
                label: const Text('글쓰기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('전체')),
                ButtonSegment(value: 'free', label: Text('자유')),
                ButtonSegment(value: 'strategy', label: Text('공략')),
                ButtonSegment(value: 'question', label: Text('질문')),
              ],
              selected: {_category},
              onSelectionChanged: (values) {
                setState(() => _category = values.first);
                _load(reset: true);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(message: _error!, onRetry: () => _load(reset: true))
          else if (_posts.isEmpty)
            const _EmptyPanel()
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
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(padding: EdgeInsets.all(20), child: Text('게시글이 없습니다.')),
    );
  }
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return value;
}
