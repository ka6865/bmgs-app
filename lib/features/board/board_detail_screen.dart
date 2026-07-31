import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import 'board_models.dart';
import 'board_repository.dart';

class BoardDetailScreen extends StatefulWidget {
  const BoardDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  final BoardRepository _repository = BoardRepository();
  final TextEditingController _commentController = TextEditingController();
  late Future<BoardPostDetail> _future;
  bool _commentSubmitting = false;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchPost(widget.postId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _repository.fetchPost(widget.postId));
  }

  Future<void> _submitComment() async {
    setState(() {
      _commentSubmitting = true;
      _commentError = null;
    });
    try {
      await _repository.createComment(
        postId: widget.postId,
        content: _commentController.text,
      );
      _commentController.clear();
      _reload();
    } on BoardException catch (error) {
      setState(() => _commentError = error.message);
    } finally {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BoardPostDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(BgmsSpacing.xl),
            child: LoadingCard(lines: 6, label: '게시글을 불러오고 있습니다'),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(BgmsSpacing.xl),
            children: [
              ErrorPanel(
                error: snapshot.error ?? '게시글 응답이 비어 있습니다.',
                onRetry: _reload,
                title: '게시글을 불러오지 못했습니다',
              ),
            ],
          );
        }

        final post = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              post.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${post.author} · ${_shortDate(post.createdAt)} · 조회 ${post.views} · 추천 ${post.likes}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (post.imageUrls.isNotEmpty) ...[
              ...post.imageUrls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('이미지를 불러오지 못했습니다.'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  post.contentText.isEmpty ? '내용이 없습니다.' : post.contentText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '댓글 ${post.comments.length}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (post.comments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('댓글이 없습니다.'),
                ),
              )
            else
              ...post.comments.map((comment) => _CommentTile(comment: comment)),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_commentError != null) ...[
                      Text(
                        _commentError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // 입력 후 401을 받는 대신 로그인 필요를 먼저 알린다.
                    if (!_repository.canWrite)
                      _CommentLoginNotice(onLogin: () => context.go('/my'))
                    else ...[
                      TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          labelText: '댓글',
                          helperText: '사진 첨부는 앱에서 지원하지 않습니다.',
                        ),
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _commentSubmitting ? null : _submitComment,
                          icon: const Icon(Icons.send),
                          label: Text(_commentSubmitting ? '등록 중...' : '댓글 등록'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final BoardComment comment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 18,
                  color: BgmsColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${comment.author} · ${_shortDate(comment.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.content),
          ],
        ),
      ),
    );
  }
}

String _shortDate(String value) {
  if (value.length >= 10) return value.substring(0, 10);
  return value;
}

/// 댓글을 쓰려면 로그인이 필요하다는 안내.
///
/// 입력을 받아놓고 401로 실패시키지 않도록 입력창 대신 노출한다.
class _CommentLoginNotice extends StatelessWidget {
  const _CommentLoginNotice({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: BgmsColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BgmsColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: BgmsColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '댓글은 로그인 후 작성할 수 있습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BgmsColors.textSecondary),
            ),
          ),
          TextButton(onPressed: onLogin, child: const Text('로그인')),
        ],
      ),
    );
  }
}
