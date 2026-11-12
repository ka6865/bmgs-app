import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/board/board_categories.dart';
import 'package:bgms_mobile_app/features/board/board_models.dart';
import 'package:bgms_mobile_app/features/board/board_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_http_adapter.dart';

void main() {
  test('웹과 기존 앱 분류는 같은 필터에 포함한다', () {
    expect(BoardCategories.matches('자유', 'free'), isTrue);
    expect(BoardCategories.matches('클랜홍보', 'clan'), isTrue);
    expect(BoardCategories.matches('클랜홍보', '클랜'), isTrue);
    expect(BoardCategories.matches('공략', 'strategy'), isTrue);
    expect(BoardCategories.matches('듀오/스쿼드 모집', '자유'), isFalse);
  });
  test('서버 분류 필터와 커서를 유지하고 별칭을 인식한다', () async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/mobile/board/posts': {
          'items': [
            {'id': 1, 'category': 'question'},
          ],
          'hasMore': true,
          'nextCursor': 'older',
        },
      },
    );
    final repository = BoardRepository(
      client: BgmsApiClient(
        baseUrl: 'https://example.test',
        dio: createFakeDio(adapter),
      ),
    );
    final page = await repository.fetchPosts(
      category: '자유',
      query: '검색',
      cursor: 'before',
    );
    expect(page.items, isEmpty);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'older');
    final uri = Uri.parse(adapter.requestedPaths.single);
    expect(uri.queryParameters['category'], '자유');
    expect(uri.queryParameters['cursor'], 'before');
    expect(uri.queryParameters['q'], '검색');
  });
  test('답글 부모와 서버 50개 조회 한계를 모델에 보존한다', () {
    final detail = BoardPostDetail.fromJson({
      'post': {'id': 1},
      'comments': List.generate(
        50,
        (id) => {'id': id + 1, 'parentId': id == 0 ? null : 1},
      ),
    });
    expect(detail.comments[1].parentId, 1);
    expect(detail.commentsMayBeTruncated, isTrue);
  });
}
