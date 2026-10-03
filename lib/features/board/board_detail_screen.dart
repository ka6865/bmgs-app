import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import 'board_models.dart';
import 'board_repository.dart';
import 'board_write_dialog.dart';
import 'board_report_dialog.dart';

class BoardDetailScreen extends StatefulWidget {
  const BoardDetailScreen({super.key, required this.postId, this.repository});

  final int postId;
  final BoardRepository? repository;

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  late final BoardRepository _repository;
  final TextEditingController _commentController = TextEditingController();
  late Future<BoardPostDetail> _future;
  bool _commentSubmitting = false;
  String? _commentError;
  BoardComment? _replyingTo;
  final _commentFormKey = GlobalKey();
  StreamSubscription<String?>? _auth;
  int _generation = 0;
  final List<BoardComment> _comments = [];
  BoardCommentPage? _commentPage;
  bool _loadingComments = false;
  String? _commentsError;
  bool _acting = false;
  String? _observedUser;
  bool _liked = false;
  int? _likes;
  String? _actionError;

  Future<BoardPostDetail> _fetchPost({bool refresh = false}) async {
    final generation = _generation;
    final post = await _repository.fetchPost(widget.postId, refresh: refresh);
    if (!mounted || generation != _generation) return post;
    _likes = post.likes;
    _comments
      ..clear()
      ..addAll(post.comments);
    _commentPage = null;
    _commentsError = null;
    try {
      final page = await _repository.fetchComments(widget.postId);
      if (!mounted || generation != _generation) return post;
      _comments
        ..clear()
        ..addAll(page.items);
      _commentPage = page;
    } on BoardException catch (error) {
      if (generation == _generation) _commentsError = error.message;
    }
    return post;
  }

  Future<void> _moreComments() async {
    if (_loadingComments) return;
    final generation = _generation;
    setState(() {
      _loadingComments = true;
      _commentsError = null;
    });
    try {
      final page = await _repository.fetchComments(
        widget.postId,
        cursor: _commentPage?.nextCursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (_commentPage == null) _comments.clear();
        final ids = _comments.map((item) => item.id).toSet();
        _comments.addAll(page.items.where((item) => ids.add(item.id)));
        _commentPage = page;
      });
    } on BoardException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _commentsError = error.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _editPost(BoardPostDetail post) async {
    final generation = _generation;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      final original = await _repository.fetchEdit(post.id);
      if (!mounted || generation != _generation) return;
      final result = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            BoardWriteDialog(repository: _repository, original: original),
      );
      if (!mounted || generation != _generation) return;
      if (result != null) _reload();
    } on BoardException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _actionError = error.message);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _acting = false);
    }
  }

  Future<void> _deletePost(BoardPostDetail post) async {
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('삭제한 글은 되돌릴 수 없습니다. 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || generation != _generation || confirmed != true) return;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      await _repository.deletePost(post.id, post.revision!);
      if (!mounted || generation != _generation) return;
      context.go('/board');
    } on BoardException catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _actionError = error.statusCode == 409
              ? '다른 곳에서 수정된 글입니다. 새로고침 후 다시 확인해 주세요.'
              : error.message,
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _acting = false);
    }
  }

  Future<void> _like(int postId) async {
    if (_acting || _liked) return;
    final generation = _generation;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      final count = await _repository.likePost(postId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _likes = count;
        _liked = true;
      });
    } on BoardException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        if (error.statusCode == 409) _liked = true;
        _actionError = error.message;
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _acting = false);
    }
  }

  Future<void> _report(String targetType, int targetId) async {
    final generation = _generation;
    final actor = _repository.userId;
    final draft = await showDialog<BoardReportDraft>(
      context: context,
      builder: (_) => BoardReportDialog(repository: _repository),
    );
    if (!mounted ||
        generation != _generation ||
        draft == null ||
        actor != _repository.userId) {
      return;
    }
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      await _repository.reportContent(
        targetType: targetType,
        targetId: targetId,
        reason: draft.reason,
        detail: draft.detail,
      );
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    } on BoardException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _actionError = error.message);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _acting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BoardRepository();
    _observedUser = _repository.userId;
    _future = _fetchPost();
    _auth = _repository.authChanges.listen((user) {
      if (!mounted || user == _observedUser) return;
      _observedUser = user;
      setState(() {
        _generation++;
        _liked = false;
        _likes = null;
        _commentController.clear();
        _replyingTo = null;
        _commentError = null;
        _comments.clear();
        _commentPage = null;
        _actionError = null;
        _acting = false;
        _commentSubmitting = false;
        _loadingComments = false;
        _future = _fetchPost(refresh: true);
      });
    });
  }

  @override
  void didUpdateWidget(covariant BoardDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _replyingTo = null;
      _commentController.clear();
      _commentError = null;
      _actionError = null;
      _acting = false;
      _liked = false;
      _likes = null;
      _commentsError = null;
      _comments.clear();
      _commentPage = null;
      _generation++;
      _commentSubmitting = false;
      _loadingComments = false;
      _future = _fetchPost();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _generation++;
      _acting = false;
      _commentSubmitting = false;
      _loadingComments = false;
      _future = _fetchPost(refresh: true);
    });
  }

  Future<void> _submitComment() async {
    final postId = widget.postId;
    final generation = _generation;
    final actor = _repository.userId;
    setState(() {
      _commentSubmitting = true;
      _commentError = null;
    });
    try {
      await _repository.createComment(
        postId: postId,
        content: _commentController.text,
        parentId: _replyingTo?.id,
      );
      if (!mounted ||
          widget.postId != postId ||
          generation != _generation ||
          actor != _repository.userId) {
        return;
      }
      _commentController.clear();
      _replyingTo = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글이 등록되었습니다.')));
      _reload();
    } on BoardException catch (error) {
      if (mounted && widget.postId == postId && generation == _generation) {
        setState(() => _commentError = error.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _commentSubmitting = false);
      }
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
              '${post.author} · ${_shortDate(post.createdAt)} · 조회 ${post.views} · 추천 ${_likes ?? post.likes}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_actionError != null)
              Text(
                _actionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (post.canEdit && post.revision != null && _repository.canWrite)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _acting ? null : () => _editPost(post),
                    icon: const Icon(Icons.edit),
                    label: const Text('수정'),
                  ),
                  TextButton.icon(
                    onPressed: _acting ? null : () => _deletePost(post),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                  ),
                ],
              ),
            FilledButton.tonalIcon(
              onPressed: _acting || _liked
                  ? null
                  : () {
                      if (!_repository.canWrite) {
                        context.go('/my');
                        return;
                      }
                      _like(post.id);
                    },
              icon: Icon(_liked ? Icons.thumb_up : Icons.thumb_up_outlined),
              label: Text(_liked ? '추천 완료' : '추천'),
            ),
            if (_repository.canWrite)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _acting ? null : () => _report('post', post.id),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('게시글 신고'),
                ),
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
              '댓글 ${_commentPage?.totalCount ?? _comments.length}${_commentPage == null && post.commentsMayBeTruncated ? '개 이상' : '개'}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_commentPage == null)
              const Text('현재 서버는 오래된 댓글부터 최대 50개를 제공합니다.'),
            if (_commentPage == null && post.commentsMayBeTruncated)
              const Text('댓글 페이지를 불러오지 못해 일부 댓글만 표시됩니다.'),
            if (_commentsError != null)
              Text(
                _commentsError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_comments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('댓글이 없습니다.'),
                ),
              )
            else
              ..._comments.map(
                (comment) => _CommentTile(
                  comment: comment,
                  onReport: !_repository.canWrite || _acting
                      ? null
                      : () => _report('comment', comment.id),
                  parentAuthor: _comments
                      .where((item) => item.id == comment.parentId)
                      .firstOrNull
                      ?.author,
                  onReply: !_repository.canWrite || _commentSubmitting
                      ? null
                      : () {
                          setState(() => _replyingTo = comment);
                          final formContext = _commentFormKey.currentContext;
                          if (formContext != null) {
                            Scrollable.ensureVisible(
                              formContext,
                              duration: const Duration(milliseconds: 250),
                              alignment: 0.1,
                            );
                          }
                        },
                ),
              ),
            if ((_commentPage?.hasMore == true || _commentsError != null))
              OutlinedButton(
                onPressed: _loadingComments ? null : _moreComments,
                child: Text(_loadingComments ? '불러오는 중...' : '댓글 더 보기'),
              ),
            const SizedBox(height: 14),
            Card(
              key: _commentFormKey,
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
                      if (_replyingTo != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text('${_replyingTo!.author}님에게 답글'),
                            ),
                            TextButton(
                              onPressed: _commentSubmitting
                                  ? null
                                  : () => setState(() => _replyingTo = null),
                              child: const Text('취소'),
                            ),
                          ],
                        ),
                      TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          labelText: _replyingTo == null ? '댓글' : '답글',
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
  const _CommentTile({
    required this.comment,
    this.parentAuthor,
    this.onReply,
    this.onReport,
  });

  final BoardComment comment;
  final String? parentAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onReport;

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
            if (comment.parentId != null)
              Text(
                parentAuthor == null
                    ? '원댓글 #${comment.parentId}에 대한 답글'
                    : '$parentAuthor님에게 답글',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(comment.content),
            Wrap(
              children: [
                if (onReply != null)
                  TextButton(onPressed: onReply, child: const Text('답글')),
                if (onReport != null)
                  TextButton(onPressed: onReport, child: const Text('댓글 신고')),
              ],
            ),
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
