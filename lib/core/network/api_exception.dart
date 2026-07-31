import 'dart:io';

import 'package:dio/dio.dart';

/// 앱 전역에서 사용하는 단일 에러 모델.
///
/// 화면은 [message]만 노출하고, 재시도 가능 여부는 [isRetryable]로 판단한다.
enum ApiErrorKind {
  network,
  timeout,
  notFound,
  unauthorized,
  rateLimited,
  server,
  parse,
  unknown,
}

/// 서버가 제안하는 유사 플레이어. `/api/pubg/player` 404 응답과
/// `/api/pubg/suggest` 응답이 같은 형태로 내려준다.
class PlayerSuggestion {
  const PlayerSuggestion({required this.nickname, required this.platform});

  final String nickname;
  final String platform;

  /// 응답 항목은 객체 또는 문자열일 수 있다. 해석 불가하면 null을 준다.
  static PlayerSuggestion? tryParse(Object? item) {
    if (item is Map) {
      final nickname = (item['nickname'] ?? item['name'] ?? '')
          .toString()
          .trim();
      if (nickname.isEmpty) return null;
      final platform = (item['platform'] ?? 'steam').toString().trim();
      return PlayerSuggestion(
        nickname: nickname,
        platform: platform.toLowerCase() == 'kakao' ? 'kakao' : 'steam',
      );
    }
    if (item is String) {
      final nickname = item.trim();
      if (nickname.isEmpty) return null;
      return PlayerSuggestion(nickname: nickname, platform: 'steam');
    }
    return null;
  }

  static List<PlayerSuggestion> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(PlayerSuggestion.tryParse)
        .whereType<PlayerSuggestion>()
        .toList(growable: false);
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.diagnostic,
    this.suggestions = const [],
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// 로그 전용 원인 문자열. 화면에는 노출하지 않는다.
  final String? diagnostic;

  /// 서버가 404와 함께 내려주는 유사 닉네임 후보. 검색 오타 복구에 쓴다.
  final List<PlayerSuggestion> suggestions;

  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server ||
      kind == ApiErrorKind.rateLimited;

  /// 서버가 준비되지 않은 경로인지 여부. fallback 문구 분기에 쓴다.
  bool get isMissingEndpoint => kind == ApiErrorKind.notFound;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return ApiException._fromDio(error);
    if (error is SocketException) {
      return const ApiException(
        kind: ApiErrorKind.network,
        message: '네트워크에 연결할 수 없습니다. 연결 상태를 확인해 주세요.',
      );
    }
    if (error is FormatException || error is TypeError) {
      return const ApiException(
        kind: ApiErrorKind.parse,
        message: '서버 응답 형식을 해석할 수 없습니다.',
      );
    }
    return ApiException(
      kind: ApiErrorKind.unknown,
      message: '알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      diagnostic: error.toString(),
    );
  }

  factory ApiException._fromDio(DioException error) {
    final status = error.response?.statusCode;
    final serverMessage = _serverMessage(error.response?.data);
    final responseData = error.response?.data;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: '서버에 연결할 수 없습니다. 네트워크 상태를 확인해 주세요.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.unknown,
          message: '요청이 취소되었습니다.',
        );
      default:
        break;
    }

    if (status == null) {
      return ApiException(
        kind: ApiErrorKind.network,
        message: serverMessage ?? '서버에 연결할 수 없습니다.',
      );
    }
    if (status == 400) {
      return ApiException(
        kind: ApiErrorKind.unknown,
        message: serverMessage ?? '요청 형식이 올바르지 않습니다.',
        statusCode: status,
      );
    }
    if (status == 401 || status == 403) {
      return ApiException(
        kind: ApiErrorKind.unauthorized,
        message: serverMessage ?? '로그인이 필요한 기능입니다.',
        statusCode: status,
      );
    }
    if (status == 404) {
      return ApiException(
        kind: ApiErrorKind.notFound,
        message: serverMessage ?? '요청한 데이터를 찾을 수 없습니다.',
        statusCode: status,
        suggestions: responseData is Map
            ? PlayerSuggestion.parseList(responseData['suggestions'])
            : const [],
      );
    }
    if (status == 429) {
      return ApiException(
        kind: ApiErrorKind.rateLimited,
        message: serverMessage ?? '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
        statusCode: status,
      );
    }
    if (status >= 500) {
      return ApiException(
        kind: ApiErrorKind.server,
        message: serverMessage ?? '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        statusCode: status,
      );
    }
    return ApiException(
      kind: ApiErrorKind.unknown,
      message: serverMessage ?? '요청을 처리하지 못했습니다. (HTTP $status)',
      statusCode: status,
    );
  }

  static String? _serverMessage(Object? data) {
    if (data is Map) {
      for (final key in const ['error', 'message', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
