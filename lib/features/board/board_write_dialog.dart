import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'board_categories.dart';
import 'board_models.dart';
import 'board_repository.dart';
import 'board_image_picker.dart';

class BoardWriteDialog extends StatefulWidget {
  const BoardWriteDialog({
    super.key,
    required this.repository,
    this.original,
    this.pickImage,
  });
  final BoardRepository repository;
  final BoardPostEdit? original;
  final Future<Uint8List?> Function()? pickImage;

  @override
  State<BoardWriteDialog> createState() => _BoardWriteDialogState();
}

class _BoardWriteDialogState extends State<BoardWriteDialog> {
  BoardRepository get _repository => widget.repository;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _category = '자유';
  bool _submitting = false;
  String? _error;

  final List<BoardUploadedImage> _images = [];
  bool _uploading = false;
  bool _committed = false;
  Future<void> _addImage() async {
    if (_images.length + (widget.original?.contentImageIds.length ?? 0) >= 20) {
      setState(() => _error = '사진은 최대 20개까지 첨부할 수 있습니다.');
      return;
    }
    final actor = _draftUser;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes =
          await (widget.pickImage?.call() ??
              pickBoardPhoto(
                confirmRecovery: () async {
                  if (!mounted ||
                      _sessionChanged ||
                      actor != _repository.userId) {
                    return false;
                  }
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('사진 선택 복구'),
                          content: const Text(
                            '이전에 선택한 사진을 현재 계정의 이 글에 첨부하시겠습니까?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('다시 선택'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('첨부'),
                            ),
                          ],
                        ),
                      ) ==
                      true;
                },
              ));
      if (bytes == null ||
          !mounted ||
          _sessionChanged ||
          actor != _repository.userId) {
        return;
      }
      final image = await _repository.uploadImage(bytes);
      if (!mounted || _sessionChanged || actor != _repository.userId) {
        if (actor == _repository.userId) {
          await _repository.releaseImages([image.id]);
        }
        return;
      }
      setState(() => _images.add(image));
    } catch (error) {
      if (mounted && !_sessionChanged && actor == _repository.userId) {
        setState(
          () => _error = error is BoardException
              ? error.message
              : '사진을 선택하거나 올리지 못했습니다. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeImage(BoardUploadedImage image) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final released = await _repository.releaseImages([image.id]);
      if (!mounted || _sessionChanged) return;
      setState(() {
        _images.remove(image);
        if (!released) _error = '사진은 글에서 제외했으며 서버 정리를 기다리고 있습니다.';
      });
    } on BoardException catch (error) {
      if (mounted && !_sessionChanged) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _sessionChanged = false;
  String? _draftUser;
  StreamSubscription<String?>? _auth;
  @override
  void initState() {
    super.initState();
    _draftUser = _repository.userId;
    final original = widget.original;
    if (original != null) {
      _titleController.text = original.title;
      _contentController.text = boardPlainText(original.content);
      _category = BoardCategories.canonical(original.category);
    }
    _auth = _repository.authChanges.listen((user) {
      if (user == _draftUser || !mounted) return;
      setState(() {
        _sessionChanged = true;
        _draftUser = user;
        _titleController.clear();
        _contentController.clear();
        _images.clear();
        _category = '자유';
        _uploading = false;
        _submitting = false;
        _error = '계정이 변경되었습니다. 창을 닫고 다시 작성해 주세요.';
      });
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    if (!_committed &&
        _images.isNotEmpty &&
        !_sessionChanged &&
        _draftUser == _repository.userId) {
      unawaited(
        _repository
            .releaseImages(_images.map((image) => image.id).toList())
            .catchError((_) => false),
      );
    }
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final actor = _repository.userId;
    try {
      if (_sessionChanged || actor == null || actor != _draftUser) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 작성해 주세요.');
      }
      final original = widget.original;
      final text = _contentController.text;
      final baseContent =
          original != null && text == boardPlainText(original.content)
          ? original.content
          : boardTextHtml(text) +
                (original == null ? '' : boardImageHtml(original.content));
      final content =
          baseContent +
          _images
              .map(
                (image) =>
                    '<img src="${image.url.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}">',
              )
              .join();
      final imageIds = [
        ...?original?.contentImageIds,
        ..._images.map((image) => image.id),
      ];
      final thumbnail =
          original?.thumbnailImageId ??
          (_images.isEmpty ? null : _images.first.id);
      int id;
      if (original != null) {
        await _repository.updatePost(
          original: original,
          title: _titleController.text,
          content: content,
          category: _category,
          contentImageIds: imageIds,
          thumbnailImageId: thumbnail,
        );
        id = original.id;
      } else {
        id = await _repository.createPost(
          title: _titleController.text,
          content: content,
          category: _category,
          contentImageIds: imageIds,
          thumbnailImageId: thumbnail,
        );
      }
      if (mounted &&
          actor == _repository.userId &&
          actor == _draftUser &&
          !_sessionChanged) {
        _committed = true;
        Navigator.of(context).pop(id);
      }
    } on BoardException catch (error) {
      if (mounted && actor == _repository.userId && !_sessionChanged) {
        setState(
          () => _error = error.statusCode == 409
              ? '다른 곳에서 수정된 글입니다. 입력 내용은 유지됩니다. 취소 후 글을 다시 열어 최신 내용을 확인해 주세요.'
              : error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: !_submitting && !_uploading,
      child: AlertDialog(
        title: Text(widget.original == null ? '게시글 작성' : '게시글 수정'),
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
                key: ValueKey(_sessionChanged),
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: '카테고리',
                  helperText:
                      BoardCategories.writable.any(
                        (entry) => entry.key == _category,
                      )
                      ? null
                      : '이전 분류입니다. 저장할 현재 분류를 선택해 주세요.',
                ),
                items:
                    [
                          if (!BoardCategories.writable.any(
                            (entry) => entry.key == _category,
                          ))
                            MapEntry(_category, _category),
                          ...BoardCategories.writable,
                        ]
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.key,
                            child: Text(category.value),
                          ),
                        )
                        .toList(),
                onChanged: _submitting || _uploading || _sessionChanged
                    ? null
                    : (value) => setState(() => _category = value ?? '자유'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                enabled: !_submitting && !_sessionChanged,
                decoration: const InputDecoration(labelText: '제목'),
                maxLength: 50,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                enabled: !_submitting && !_sessionChanged,
                decoration: InputDecoration(
                  labelText: '본문',
                  helperText: widget.original == null
                      ? '본문을 입력해 주세요.'
                      : '본문을 바꾸면 글꼴·링크 서식은 일반 텍스트로 바뀌며 기존 사진은 유지됩니다.',
                ),
                minLines: 5,
                maxLines: 8,
                maxLength: 5000,
              ),
              const SizedBox(height: 12),
              if (!_sessionChanged &&
                  widget.original?.contentImageIds.isNotEmpty == true)
                Text(
                  '기존 사진 ${widget.original!.contentImageIds.length}개는 유지됩니다.',
                ),
              ..._images.map(
                (image) => ListTile(
                  title: const Text('첨부 사진'),
                  leading: Image.network(
                    image.url,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) => const Icon(Icons.image),
                  ),
                  trailing: IconButton(
                    tooltip: '첨부 사진 제외',
                    onPressed: _uploading || _submitting || _sessionChanged
                        ? null
                        : () => _removeImage(image),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _uploading || _submitting || _sessionChanged
                    ? null
                    : _addImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_uploading ? '사진 업로드 중...' : '사진 첨부'),
              ),
              const Text('PNG·JPEG·WebP, 파일당 1.5MiB 이하, 최대 20개'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting || _uploading
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _submitting || _uploading || _sessionChanged
                ? null
                : _submit,
            child: Text(_submitting ? '저장 중...' : '등록'),
          ),
        ],
      ),
    );
  }
}

String boardPlainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .trim();
String boardTextHtml(String text) =>
    '<p>${text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll('\n', '<br>')}</p>';
String boardImageHtml(String html) => RegExp(
  r'<img\b[^>]*>',
  caseSensitive: false,
).allMatches(html).map((match) => match.group(0)!).join();
