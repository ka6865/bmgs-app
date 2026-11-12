import 'dart:async';
import 'dart:typed_data';
import 'package:bgms_mobile_app/features/board/board_detail_screen.dart';
import 'package:bgms_mobile_app/features/board/board_models.dart';
import 'package:bgms_mobile_app/features/board/board_repository.dart';
import 'package:bgms_mobile_app/features/board/board_report_dialog.dart';
import 'package:bgms_mobile_app/features/board/board_write_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Repository extends BoardRepository {
  String? actor = 'a';
  final changes = StreamController<String?>.broadcast(sync: true);
  @override
  String? get userId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;
  void changeUser(String? user) {
    actor = user;
    changes.add(user);
  }

  bool conflict = false;
  bool owner = true;
  int writes = 0;
  int deletes = 0;
  int recommendations = 0;
  bool duplicateLike = false;
  String? submittedContent;
  List<String>? submittedImages;
  List<String?> cursors = [];
  Completer<BoardUploadedImage>? imageUpload;
  Completer<void>? pendingWrite;
  final released = <String>[];
  @override
  Future<BoardPostEdit> fetchEdit(int postId) async => _original;

  @override
  Future<BoardPostDetail> fetchPost(int postId, {bool refresh = false}) async =>
      BoardPostDetail.fromJson({
        'post': {
          'id': postId,
          'title': '게시글',
          'contentText': '본문',
          'canEdit': owner && actor != null,
          'revision': 2,
        },
        'comments': [],
      });
  @override
  Future<BoardCommentPage> fetchComments(int postId, {String? cursor}) async {
    cursors.add(cursor);
    return BoardCommentPage(
      items: [
        const BoardComment(
          id: 1,
          author: '작성자',
          content: '첫 댓글',
          createdAt: '',
        ),
        if (cursor != null)
          const BoardComment(
            id: 2,
            author: '작성자',
            content: '다음 댓글',
            createdAt: '',
            parentId: 1,
          ),
      ],
      totalCount: 2,
      hasMore: cursor == null,
      nextCursor: cursor == null ? 'next' : null,
    );
  }

  @override
  Future<int> likePost(int postId) async {
    recommendations++;
    if (duplicateLike) {
      throw const BoardException('이미 추천한 게시글입니다.', statusCode: 409);
    }
    return 5;
  }

  @override
  Future<void> deletePost(int postId, int revision) async {
    expect(revision, 2);
    deletes++;
  }

  @override
  Future<void> updatePost({
    required BoardPostEdit original,
    required String title,
    required String content,
    required String category,
    required List<String> contentImageIds,
    String? thumbnailImageId,
  }) async {
    writes++;
    submittedContent = content;
    submittedImages = contentImageIds;
    if (conflict) throw const BoardException('충돌', statusCode: 409);
    await pendingWrite?.future;
  }

  @override
  Future<int> createPost({
    required String title,
    required String content,
    required String category,
    List<String> contentImageIds = const [],
    String? thumbnailImageId,
  }) async {
    writes++;
    submittedContent = content;
    submittedImages = contentImageIds;
    await pendingWrite?.future;
    return 7;
  }

  @override
  Future<BoardUploadedImage> uploadImage(Uint8List bytes) async {
    final pending = imageUpload;
    if (pending != null) return pending.future;
    return const BoardUploadedImage(
      id: 'photo',
      url: 'https://example.test/photo.jpg',
    );
  }

  @override
  Future<bool> releaseImages(List<String> ids) async {
    released.addAll(ids);
    return true;
  }
}

const _original = BoardPostEdit(
  id: 1,
  title: '원래 제목',
  content: '<p><b>서식 유지</b></p><img src="https://example.test/original.jpg">',
  category: '자유',
  revision: 2,
  contentImageIds: ['original'],
  thumbnailImageId: 'original',
);

Future<void> _openWrite(
  WidgetTester tester,
  _Repository repository, {
  BoardPostEdit? original,
  Future<Uint8List?> Function()? picker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<int>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BoardWriteDialog(
                repository: repository,
                original: original,
                pickImage: picker,
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  for (final editing in [false, true]) {
    testWidgets('${editing ? '수정' : '작성'}창은 바깥 터치와 저장 중 뒤로 닫히지 않고 성공 시 닫힌다', (
      tester,
    ) async {
      final repo = _Repository()..pendingWrite = Completer<void>();
      addTearDown(repo.changes.close);
      if (editing) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardDetailScreen(postId: 1, repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '수정'));
        await tester.pumpAndSettle();
      } else {
        await _openWrite(tester, repo);
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BoardWriteDialog), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '제목'), '저장 제목');
      await tester.enterText(find.widgetWithText(TextField, '본문'), '저장 본문');
      await tester.tap(find.text('등록'));
      await tester.pump();
      expect(repo.writes, 1);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BoardWriteDialog), findsOneWidget);
      expect(find.text('저장 중...'), findsOneWidget);
      repo.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(BoardWriteDialog), findsNothing);
      expect(repo.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('사진 선택·업로드 중에는 뒤로가기와 취소를 막고 완료 후 다시 닫을 수 있다', (tester) async {
    final repo = _Repository()..imageUpload = Completer<BoardUploadedImage>();
    addTearDown(repo.changes.close);
    final selection = Completer<Uint8List?>();
    await _openWrite(tester, repo, picker: () => selection.future);
    await tester.ensureVisible(find.text('사진 첨부'));
    await tester.tap(find.text('사진 첨부'));
    await tester.pump();
    for (final uploading in [false, true]) {
      if (uploading) {
        selection.complete(Uint8List.fromList([255, 216, 255]));
        await tester.pump();
      }
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BoardWriteDialog), findsOneWidget);
      expect(find.text('사진 업로드 중...'), findsOneWidget);
    }
    repo.imageUpload!.completeError(const BoardException('업로드 실패'));
    await tester.pumpAndSettle();
    expect(find.text('업로드 실패'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
          .onPressed,
      isNotNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BoardWriteDialog), findsNothing);
    expect(repo.writes, 0);
  });

  testWidgets('비회원도 댓글 다음 페이지를 읽고 중복 ID는 한 번만 표시한다', (tester) async {
    final repo = _Repository()..actor = null;
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoardDetailScreen(postId: 1, repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('첫 댓글'), findsOneWidget);
    await tester.ensureVisible(find.text('댓글 더 보기'));
    await tester.tap(find.text('댓글 더 보기'));
    await tester.pumpAndSettle();
    expect(repo.cursors, [null, 'next']);
    expect(find.text('첫 댓글'), findsOneWidget);
    expect(find.text('다음 댓글'), findsOneWidget);
    expect(find.text('댓글 더 보기'), findsNothing);
    expect(find.text('댓글은 로그인 후 작성할 수 있습니다.'), findsOneWidget);
  });
  testWidgets('추천은 서버 수만 표시하고 완료 후 재전송하지 않는다', (tester) async {
    final repo = _Repository();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoardDetailScreen(postId: 1, repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '추천'));
    await tester.pumpAndSettle();
    expect(repo.recommendations, 1);
    expect(find.textContaining('추천 5'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '추천 완료'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('추천 409는 수를 증가시키지 않고 계정 변경 시 완료 표시를 초기화한다', (tester) async {
    final repo = _Repository()..duplicateLike = true;
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoardDetailScreen(postId: 1, repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '추천'));
    await tester.pumpAndSettle();
    expect(find.textContaining('추천 0'), findsOneWidget);
    expect(find.text('이미 추천한 게시글입니다.'), findsOneWidget);
    repo.changeUser('b');
    await tester.pumpAndSettle();
    expect(find.text('추천 완료'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '추천'))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('편집 충돌은 입력을 유지하고 기존 이미지 연결을 보존한다', (tester) async {
    final repo = _Repository()..conflict = true;
    addTearDown(repo.changes.close);
    await _openWrite(tester, repo, original: _original);
    await tester.enterText(find.widgetWithText(TextField, '제목'), '변경 제목');
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();
    expect(find.textContaining('입력 내용은 유지됩니다.'), findsOneWidget);
    expect(find.text('변경 제목'), findsOneWidget);
    expect(repo.submittedContent, _original.content);
    expect(repo.submittedImages, ['original']);
  });
  testWidgets('새 첨부 ID는 글 저장에 연결하고 계정 변경 시 초안과 사진을 지운다', (tester) async {
    final repo = _Repository();
    addTearDown(repo.changes.close);
    await _openWrite(
      tester,
      repo,
      picker: () async => Uint8List.fromList([255, 216, 255]),
    );
    await tester.enterText(find.widgetWithText(TextField, '제목'), '개인 제목');
    await tester.enterText(find.widgetWithText(TextField, '본문'), '개인 본문');
    await tester.ensureVisible(find.text('사진 첨부'));
    await tester.tap(find.text('사진 첨부'));
    await tester.pumpAndSettle();
    expect(find.text('첨부 사진'), findsOneWidget);
    repo.changeUser('b');
    await tester.pumpAndSettle();
    expect(find.text('개인 제목'), findsNothing);
    expect(find.text('개인 본문'), findsNothing);
    expect(find.text('첨부 사진'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '등록'))
          .onPressed,
      isNull,
    );
    expect(repo.writes, 0);
  });
  testWidgets('작성→사진 첨부→저장은 서버 이미지 ID와 안전한 본문으로 왕복한다', (tester) async {
    final repo = _Repository();
    addTearDown(repo.changes.close);
    await _openWrite(
      tester,
      repo,
      picker: () async => Uint8List.fromList([255, 216, 255]),
    );
    await tester.enterText(find.widgetWithText(TextField, '제목'), '사진 글');
    await tester.enterText(find.widgetWithText(TextField, '본문'), '<본문>');
    await tester.ensureVisible(find.text('사진 첨부'));
    await tester.tap(find.text('사진 첨부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(repo.submittedImages, ['photo']);
    expect(
      repo.submittedContent,
      '<p>&lt;본문&gt;</p><img src="https://example.test/photo.jpg">',
    );
    expect(find.byType(BoardWriteDialog), findsNothing);
    expect(repo.released, isEmpty);
  });
  testWidgets('사진 업로드 중 로그아웃하면 늦은 업로드 결과를 새 초안에 붙이지 않는다', (tester) async {
    final repo = _Repository()..imageUpload = Completer<BoardUploadedImage>();
    addTearDown(repo.changes.close);
    await _openWrite(
      tester,
      repo,
      picker: () async => Uint8List.fromList([255, 216, 255]),
    );
    await tester.ensureVisible(find.text('사진 첨부'));
    await tester.tap(find.text('사진 첨부'));
    await tester.pump();
    repo.changeUser(null);
    await tester.pump();
    repo.imageUpload!.complete(
      const BoardUploadedImage(
        id: 'old-photo',
        url: 'https://example.test/photo.jpg',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('첨부 사진'), findsNothing);
    expect(repo.released, isEmpty);
    expect(repo.writes, 0);
  });
  testWidgets('회원 글 삭제는 revision 확인 후 실제 router 목록으로 돌아간다', (tester) async {
    final repo = _Repository();
    addTearDown(repo.changes.close);
    final router = GoRouter(
      initialLocation: '/board/1',
      routes: [
        GoRoute(
          path: '/board',
          builder: (_, _) => const Scaffold(body: Text('게시판 목록')),
        ),
        GoRoute(
          path: '/board/:id',
          builder: (_, _) =>
              Scaffold(body: BoardDetailScreen(postId: 1, repository: repo)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('게시판 목록'), findsOneWidget);
  });
  testWidgets('신고 상세 사유도 계정 변경 시 지우고 타계정 접수를 막는다', (tester) async {
    final repo = _Repository();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BoardReportDialog(repository: repo)),
      ),
    );
    await tester.enterText(find.byType(TextField), '개인 신고 내용');
    repo.changeUser('b');
    await tester.pumpAndSettle();
    expect(find.text('개인 신고 내용'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '신고 접수'))
          .onPressed,
      isNull,
    );
  });
}
