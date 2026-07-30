import 'dart:io';

import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dioError({
  int? statusCode,
  Object? data,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final requestOptions = RequestOptions(path: '/api/pubg/player');
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(
            requestOptions: requestOptions,
            statusCode: statusCode,
            data: data,
          ),
  );
}

void main() {
  test('HTTP 상태 코드를 에러 종류로 정규화한다', () {
    expect(
      ApiException.from(_dioError(statusCode: 404)).kind,
      ApiErrorKind.notFound,
    );
    expect(
      ApiException.from(_dioError(statusCode: 401)).kind,
      ApiErrorKind.unauthorized,
    );
    expect(
      ApiException.from(_dioError(statusCode: 403)).kind,
      ApiErrorKind.unauthorized,
    );
    expect(
      ApiException.from(_dioError(statusCode: 429)).kind,
      ApiErrorKind.rateLimited,
    );
    expect(
      ApiException.from(_dioError(statusCode: 503)).kind,
      ApiErrorKind.server,
    );
  });

  test('타임아웃과 연결 오류를 구분한다', () {
    expect(
      ApiException.from(
        _dioError(type: DioExceptionType.receiveTimeout),
      ).kind,
      ApiErrorKind.timeout,
    );
    expect(
      ApiException.from(
        _dioError(type: DioExceptionType.connectionError),
      ).kind,
      ApiErrorKind.network,
    );
    expect(
      ApiException.from(const SocketException('offline')).kind,
      ApiErrorKind.network,
    );
  });

  test('서버가 준 메시지를 우선 노출한다', () {
    final error = ApiException.from(
      _dioError(statusCode: 400, data: {'error': '닉네임이 필요합니다.'}),
    );
    expect(error.message, '닉네임이 필요합니다.');
    expect(error.statusCode, 400);
  });

  test('재시도 가능 여부를 종류로 판단한다', () {
    expect(ApiException.from(_dioError(statusCode: 500)).isRetryable, isTrue);
    expect(ApiException.from(_dioError(statusCode: 429)).isRetryable, isTrue);
    expect(ApiException.from(_dioError(statusCode: 404)).isRetryable, isFalse);
    expect(ApiException.from(_dioError(statusCode: 401)).isRetryable, isFalse);
  });

  test('404는 미구현 엔드포인트 분기로 쓸 수 있다', () {
    expect(
      ApiException.from(_dioError(statusCode: 404)).isMissingEndpoint,
      isTrue,
    );
    expect(
      ApiException.from(_dioError(statusCode: 500)).isMissingEndpoint,
      isFalse,
    );
  });

  test('이미 정규화된 예외는 그대로 통과한다', () {
    const original = ApiException(
      kind: ApiErrorKind.parse,
      message: '파싱 실패',
    );
    expect(ApiException.from(original), same(original));
  });

  test('파싱 오류는 parse 종류로 분류한다', () {
    expect(
      ApiException.from(const FormatException('bad json')).kind,
      ApiErrorKind.parse,
    );
  });
}
