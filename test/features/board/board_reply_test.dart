import 'package:bgms_mobile_app/features/board/board_detail_screen.dart';
import 'package:bgms_mobile_app/features/board/board_models.dart';
import 'package:bgms_mobile_app/features/board/board_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReplyRepository extends BoardRepository {
  int? sentParentId;
  String? sentContent;
  @override
  bool get canWrite => true;
  @override
  Future<BoardPostDetail> fetchPost(int postId, {bool refresh = false}) async =>
      BoardPostDetail.fromJson({
        'post': {'id': postId, 'title': '게시글', 'contentText': '본문'},
        'comments': [
          {'id': 9, 'author': '원댓글 작성자', 'content': '원댓글 내용'},
          {'id': 10, 'author': '답글 작성자', 'content': '답글 내용', 'parentId': 9},
        ],
      });
  @override
  Future<BoardCommentPage> fetchComments(int postId, {String? cursor}) async {
    final post = await fetchPost(postId);
    return BoardCommentPage(
      items: post.comments,
      totalCount: post.comments.length,
      hasMore: false,
    );
  }

  @override
  Future<void> createComment({
    required int postId,
    required String content,
    int? parentId,
  }) async {
    sentParentId = parentId;
    sentContent = content;
  }
}

void main() {
  testWidgets('답글 대상을 선택하고 부모 ID와 내용을 전송한다', (tester) async {
    final repository = _ReplyRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardDetailScreen(postId: 1, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('원댓글 작성자님에게 답글'), findsOneWidget);
    expect(find.text('댓글 2개'), findsOneWidget);
    expect(find.text('현재 서버는 오래된 댓글부터 최대 50개를 제공합니다.'), findsNothing);
    await tester.ensureVisible(find.text('답글').first);
    await tester.tap(find.text('답글').first);
    await tester.pumpAndSettle();
    expect(find.text('원댓글 작성자님에게 답글'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), '답글을 남깁니다');
    final send = find.text('댓글 등록');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repository.sentParentId, 9);
    expect(repository.sentContent, '답글을 남깁니다');
    expect(find.text('원댓글 작성자님에게 답글'), findsOneWidget);
  });
}
