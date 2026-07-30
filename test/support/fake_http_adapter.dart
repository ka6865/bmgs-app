import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 경로별로 고정 응답을 돌려주는 테스트용 Dio 어댑터.
///
/// 위젯 테스트에서 실제 네트워크를 타지 않도록 `dioProvider`를 이 어댑터가 붙은
/// Dio로 override 한다.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter({
    Map<String, Object> responses = const {},
    Map<String, int> statusCodes = const {},
  }) : _responses = Map.of(responses),
       _statusCodes = Map.of(statusCodes);

  final Map<String, Object> _responses;
  final Map<String, int> _statusCodes;

  /// 실제로 요청된 경로 목록. 계약 검증에 사용한다.
  final List<String> requestedPaths = <String>[];

  void stub(String path, Object body, {int statusCode = 200}) {
    _responses[path] = body;
    _statusCodes[path] = statusCode;
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requestedPaths.add(options.uri.toString());

    final body = _responses[path];
    final status = _statusCodes[path] ?? (body == null ? 404 : 200);

    if (body == null) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'not stubbed: $path'}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? Headers.textPlainContentType : Headers.jsonContentType,
        ],
      },
    );
  }
}

/// 어댑터가 붙은 Dio 인스턴스를 만든다.
Dio createFakeDio(FakeHttpAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}
