import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/core/player/player_suggestion_controller.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerSuggestion _suggestion(String nickname, [String platform = 'steam']) {
  return PlayerSuggestion(nickname: nickname, platform: platform);
}

void main() {
  test('최소 길이 미만 질의는 서버를 호출하지 않는다', () async {
    final queries = <String>[];
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        queries.add(query);
        return [_suggestion('alpha')];
      },
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('a');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(queries, isEmpty);
    expect(controller.suggestions, isEmpty);
  });

  test('디바운스 동안 입력이 이어지면 마지막 질의만 조회한다', () async {
    final queries = <String>[];
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        queries.add(query);
        return [_suggestion(query)];
      },
      debounce: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('ka');
    controller.onQueryChanged('kan');
    controller.onQueryChanged('kang');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(queries, ['kang']);
    expect(controller.suggestions.single.nickname, 'kang');
  });

  test('늦게 도착한 이전 응답이 최신 결과를 덮어쓰지 않는다', () async {
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        // 앞선 질의를 의도적으로 더 늦게 응답시킨다.
        if (query == 'slow') {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return [_suggestion('slowResult')];
        }
        return [_suggestion('fastResult')];
      },
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('slow');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.onQueryChanged('fast');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(controller.suggestions.single.nickname, 'fastResult');
  });

  test('조회 실패는 목록을 비우고 예외를 전파하지 않는다', () async {
    final controller = PlayerSuggestionController(
      fetch: (query) async => throw const ApiException(
        kind: ApiErrorKind.network,
        message: '네트워크 오류',
      ),
      debounce: Duration.zero,
      // 재시도 지연을 없애 결과를 즉시 확인한다.
      retryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('kang');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.suggestions, isEmpty);
    expect(controller.loading, isFalse);
  });

  test('결과 개수를 maxResults로 제한한다', () async {
    final controller = PlayerSuggestionController(
      fetch: (query) async => [
        for (var i = 0; i < 20; i++) _suggestion('player$i'),
      ],
      debounce: Duration.zero,
      maxResults: 5,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('player');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.suggestions.length, 5);
  });

  test('clear는 대기 중인 조회를 취소한다', () async {
    var callCount = 0;
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        callCount++;
        return [_suggestion('alpha')];
      },
      debounce: const Duration(milliseconds: 30),
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('kang');
    controller.clear();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(callCount, 0);
    expect(controller.suggestions, isEmpty);
  });

  test('일시적 서버 오류는 한 번 재시도한다', () async {
    var attempts = 0;
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        attempts++;
        // 첫 시도만 5xx로 실패시킨다.
        if (attempts == 1) {
          throw const ApiException(kind: ApiErrorKind.server, message: '서버 오류');
        }
        return [_suggestion('recovered')];
      },
      debounce: Duration.zero,
      retryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('kang');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(attempts, 2);
    expect(controller.suggestions.single.nickname, 'recovered');
  });

  test('재시도해도 결과가 같은 오류는 즉시 포기한다', () async {
    var attempts = 0;
    final controller = PlayerSuggestionController(
      fetch: (query) async {
        attempts++;
        throw const ApiException(
          kind: ApiErrorKind.notFound,
          message: '찾을 수 없음',
        );
      },
      debounce: Duration.zero,
      retryDelay: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.onQueryChanged('kang');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // notFound는 재시도 대상이 아니다.
    expect(attempts, 1);
    expect(controller.suggestions, isEmpty);
  });
}
