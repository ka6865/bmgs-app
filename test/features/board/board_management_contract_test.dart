import 'dart:typed_data';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/board/board_repository.dart';
import 'package:bgms_mobile_app/features/board/board_write_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_http_adapter.dart';

void main() {
  const imageId = '00000000-0000-4000-8000-000000000001';
  final jpeg = Uint8List.fromList([255, 216, 255, 224]);
  BoardRepository repository(
    FakeHttpAdapter adapter, {
    String? Function()? user,
    BoardBinaryUploader? uploader,
  }) => BoardRepository(
    client: BgmsApiClient(
      baseUrl: 'https://example.test',
      dio: createFakeDio(adapter),
    ),
    userIdProvider: user ?? () => 'user-a',
    tokenProvider: () => 'token-a',
    binaryUploader: uploader,
  );
  test('회원 조회와 커서, revision 수정/삭제는 Bearer와 정확한 본문을 사용한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/mobile/board/posts/1': {
          'post': {'id': 1, 'canEdit': true, 'revision': 2},
          'success': true,
        },
        '/api/mobile/board/posts/1/edit': {
          'post': {
            'id': 1,
            'title': '제목',
            'content': '<p>본문</p>',
            'category': '자유',
            'revision': 2,
            'contentImageIds': [imageId],
            'thumbnailImageId': imageId,
            'canEdit': true,
          },
        },
        '/api/mobile/board/posts/1/comments': {
          'items': [
            {'id': 51, 'parentId': 1},
          ],
          'totalCount': 51,
          'hasMore': false,
        },
      },
    );
    final repo = repository(adapter);
    expect((await repo.fetchPost(1)).canEdit, isTrue);
    final original = await repo.fetchEdit(1);
    await repo.updatePost(
      original: original,
      title: '수정',
      content: original.content,
      category: '자유',
      contentImageIds: original.contentImageIds,
      thumbnailImageId: original.thumbnailImageId,
    );
    await repo.deletePost(1, original.revision);
    final page = await repo.fetchComments(1, cursor: 'opaque-cursor');
    expect(page.items.single.parentId, 1);
    expect(page.totalCount, 51);
    expect(
      adapter.recordedRequests.every(
        (r) => r.headers['Authorization'] == 'Bearer token-a',
      ),
      isTrue,
    );
    final patch = adapter.recordedRequests.singleWhere(
      (r) => r.method == 'PATCH',
    );
    expect(patch.data, containsPair('expectedRevision', 2));
    expect(patch.data, containsPair('contentImageIds', [imageId]));
    final delete = adapter.recordedRequests.singleWhere(
      (r) => r.method == 'DELETE',
    );
    expect(delete.data, {'expectedRevision': 2});
    expect(
      adapter.recordedRequests.last.uri.queryParameters['cursor'],
      'opaque-cursor',
    );
  });
  test('추천은 단방향 likes 계약을 읽고 409 및 잘못된 수를 성공으로 처리하지 않는다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/mobile/board/posts/1/likes': {
          'success': true,
          'liked': true,
          'likes': 4,
        },
      },
    );
    final repo = repository(adapter);
    expect(await repo.likePost(1), 4);
    expect(adapter.recordedRequests.single.method, 'POST');
    expect(
      adapter.recordedRequests.single.headers['Authorization'],
      'Bearer token-a',
    );
    adapter.stub('/api/mobile/board/posts/1/likes', {
      'error': '이미 추천한 게시글입니다.',
    }, statusCode: 409);
    await expectLater(
      repo.likePost(1),
      throwsA(isA<BoardException>().having((e) => e.statusCode, 'status', 409)),
    );
    adapter.stub('/api/mobile/board/posts/1/likes', {
      'success': true,
      'liked': true,
    });
    await expectLater(repo.likePost(1), throwsA(isA<BoardException>()));
  });
  test('비회원 댓글 조회는 Bearer 없이 공개 페이지 계약을 사용한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/mobile/board/posts/1/comments': {
          'items': [],
          'totalCount': 0,
          'hasMore': false,
        },
      },
    );
    var tokenReads = 0;
    final repo = BoardRepository(
      client: BgmsApiClient(
        baseUrl: 'https://example.test',
        dio: createFakeDio(adapter),
      ),
      userIdProvider: () => null,
      tokenProvider: () {
        tokenReads++;
        return 'stale-token';
      },
    );
    expect((await repo.fetchComments(1)).totalCount, 0);
    expect(tokenReads, 0);
    expect(adapter.recordedRequests.single.headers['Authorization'], isNull);
  });
  test('신고는 서버 snake_case 필드와 회원 Bearer를 사용하고 중복 오류를 유지한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/board/report': {'success': true},
      },
    );
    final repo = repository(adapter);
    await repo.reportContent(
      targetType: 'comment',
      targetId: 8,
      reason: '기타',
      detail: '사유',
    );
    final request = adapter.recordedRequests.single;
    expect(request.data, {
      'target_type': 'comment',
      'target_id': 8,
      'reason': '기타',
      'detail': '사유',
    });
    expect(request.headers['Authorization'], 'Bearer token-a');
    adapter.stub('/api/board/report', {
      'error': '이미 신고하신 항목입니다.',
    }, statusCode: 409);
    await expectLater(
      repo.reportContent(targetType: 'post', targetId: 1, reason: '기타'),
      throwsA(isA<BoardException>().having((e) => e.statusCode, 'status', 409)),
    );
  });
  test('신규 글은 새 중첩 성공 ID를 읽고 잘못된 성공은 거절한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/mobile/board/posts': {
          'success': true,
          'data': {'id': 7, 'revision': 0},
        },
      },
    );
    final repo = repository(adapter);
    expect(
      await repo.createPost(
        title: '제목',
        content: '<p>본문</p>',
        category: '제보/문의',
      ),
      7,
    );
    adapter.stub('/api/mobile/board/posts', {'success': true});
    await expectLater(
      repo.createPost(title: '제목', content: '본문', category: '자유'),
      throwsA(isA<BoardException>()),
    );
  });
  test('이미지는 MIME/크기 확인 후 예약→서명 업로드→완료하고 사진 ID로 글에 연결한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/board/images/reserve': {
          'imageId': imageId,
          'bucketId': 'board-images-v2',
          'storageKey': imageId,
          'token': 'signed',
        },
        '/api/board/images/complete': {
          'imageId': imageId,
          'publicUrl': 'https://example.test/photo.jpg',
        },
        '/api/mobile/board/posts': {
          'success': true,
          'data': {'id': 3},
        },
      },
    );
    final stages = <String>[];
    final repo = repository(
      adapter,
      uploader: (bucket, key, token, bytes, mime) async {
        expect(bucket, 'board-images-v2');
        expect(key, imageId);
        expect(token, 'signed');
        expect(bytes, jpeg);
        expect(mime, 'image/jpeg');
        expect(
          adapter.recordedRequests.last.uri.path,
          '/api/board/images/reserve',
        );
        stages.add('upload');
      },
    );
    final image = await repo.uploadImage(jpeg);
    expect(stages, ['upload']);
    expect(
      adapter.recordedRequests.last.uri.path,
      '/api/board/images/complete',
    );
    await repo.createPost(
      title: '사진',
      content: '<p>본문</p>',
      category: '자유',
      contentImageIds: [image.id],
      thumbnailImageId: image.id,
    );
    expect(
      adapter.recordedRequests.last.data,
      containsPair('contentImageIds', [imageId]),
    );
  });
  test('업로드 실패 시 신규 예약만 정리하고 deferred를 삭제 성공으로 처리하지 않는다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/board/images/reserve': {
          'imageId': imageId,
          'bucketId': 'board-images-v2',
          'storageKey': imageId,
          'token': 'signed',
        },
        '/api/board/images/release': {'released': 0, 'deferred': 1},
      },
    );
    final repo = repository(
      adapter,
      uploader: (_, _, _, _, _) async => throw StateError('upload failed'),
    );
    await expectLater(repo.uploadImage(jpeg), throwsA(isA<BoardException>()));
    expect(adapter.recordedRequests.last.uri.path, '/api/board/images/release');
    expect(await repo.releaseImages([imageId]), isFalse);
  });
  test('잘못된 이미지와 초과 크기는 예약 API를 호출하지 않는다', () async {
    final adapter = FakeHttpAdapter();
    final repo = repository(adapter);
    await expectLater(
      repo.uploadImage(Uint8List(1572865)),
      throwsA(isA<BoardException>()),
    );
    await expectLater(
      repo.uploadImage(Uint8List.fromList([0, 0, 0])),
      throwsA(isA<BoardException>()),
    );
    expect(adapter.recordedRequests, isEmpty);
  });
  test('계정이 토큰 조회 중 바뀌면 쓰기를 시작하지 않는다', () async {
    final adapter = FakeHttpAdapter();
    var user = 'a';
    final repo = BoardRepository(
      client: BgmsApiClient(
        baseUrl: 'https://example.test',
        dio: createFakeDio(adapter),
      ),
      userIdProvider: () => user,
      tokenProvider: () {
        user = 'b';
        return 'a-token';
      },
    );
    await expectLater(
      repo.createPost(title: '제목', content: '본문', category: '자유'),
      throwsA(isA<BoardException>()),
    );
    expect(adapter.recordedRequests, isEmpty);
  });
  test('본문 HTML은 텍스트를 escape하고 이미지 태그만 분리 보존한다', () {
    expect(boardTextHtml('<script>&\n다음'), '<p>&lt;script&gt;&amp;<br>다음</p>');
    const html = '<p>내용</p><img src="safe"><a href="x">링크</a>';
    expect(boardPlainText(html), '내용\n링크');
    expect(boardImageHtml(html), '<img src="safe">');
  });
}
