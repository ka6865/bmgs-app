import 'dart:async';

import '../network/api_exception.dart';

/// 닉네임 질의로 후보 목록을 가져오는 함수.
typedef PlayerSuggestionFetcher =
    Future<List<PlayerSuggestion>> Function(String query);

/// 조회 실패를 알리는 콜백. 화면 계층에서 로깅으로 연결한다.
typedef PlayerSuggestionErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// 닉네임 자동완성 상태를 관리한다.
///
/// 입력이 바뀔 때마다 서버를 때리지 않도록 디바운스를 걸고, 늦게 도착한
/// 응답이 최신 질의 결과를 덮어쓰지 않게 질의 문자열로 검증한다.
class PlayerSuggestionController {
  PlayerSuggestionController({
    required this._fetch,
    this.debounce = const Duration(milliseconds: 300),
    this.minQueryLength = 2,
    this.maxResults = 8,
    this.onError,
    this.retryCount = 1,
    this.retryDelay = const Duration(milliseconds: 400),
  });

  final PlayerSuggestionFetcher _fetch;

  /// 조회 실패 처리. 자동완성은 보조 기능이므로 화면을 막지 않는다.
  final PlayerSuggestionErrorHandler? onError;

  /// 일시적 서버 오류에 대한 추가 시도 횟수.
  final int retryCount;
  final Duration retryDelay;

  /// 입력이 멈춘 뒤 요청까지 기다리는 시간.
  final Duration debounce;

  /// 이 길이 미만이면 요청하지 않는다. 서버도 짧은 질의에는 빈 목록을 준다.
  final int minQueryLength;
  final int maxResults;

  Timer? _timer;
  String _lastQuery = '';
  bool _disposed = false;

  List<PlayerSuggestion> _suggestions = const [];
  List<PlayerSuggestion> get suggestions => _suggestions;

  bool _loading = false;
  bool get loading => _loading;

  /// 결과가 바뀔 때 호출된다.
  void Function()? onChanged;

  /// 입력 변화를 받아 디바운스 후 조회한다.
  void onQueryChanged(String rawQuery) {
    final query = rawQuery.trim();
    _timer?.cancel();

    if (query.length < minQueryLength) {
      _lastQuery = query;
      _update(const [], loading: false);
      return;
    }
    if (query == _lastQuery && _suggestions.isNotEmpty) return;

    _lastQuery = query;
    _timer = Timer(debounce, () => _run(query));
  }

  /// 목록을 즉시 비운다. 검색을 실행했거나 입력을 지웠을 때 쓴다.
  void clear() {
    _timer?.cancel();
    _lastQuery = '';
    _update(const [], loading: false);
  }

  Future<void> _run(String query) async {
    _update(_suggestions, loading: true);
    // 서버가 일시적으로 5xx를 낼 수 있어 재시도 여유를 한 번 둔다.
    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final result = await _fetch(query);
        // 사용자가 그 사이 다른 질의로 넘어갔으면 버린다.
        if (_disposed || query != _lastQuery) return;
        _update(
          result.take(maxResults).toList(growable: false),
          loading: false,
        );
        return;
      } catch (error, stackTrace) {
        if (_disposed || query != _lastQuery) return;
        if (attempt < retryCount && _isRetryable(error)) {
          await Future<void>.delayed(retryDelay);
          if (_disposed || query != _lastQuery) return;
          continue;
        }
        onError?.call(error, stackTrace);
        _update(const [], loading: false);
        return;
      }
    }
  }

  /// 재시도할 가치가 있는 오류인지 판단한다.
  ///
  /// 네트워크, 타임아웃, 서버 오류만 다시 시도한다.
  /// 404나 잘못된 요청은 재시도해도 결과가 같다.
  static bool _isRetryable(Object error) {
    if (error is ApiException) return error.isRetryable;
    return false;
  }

  void _update(List<PlayerSuggestion> next, {required bool loading}) {
    if (_disposed) return;
    final changed = loading != _loading || !_isSameList(next, _suggestions);
    _suggestions = next;
    _loading = loading;
    if (changed) onChanged?.call();
  }

  static bool _isSameList(List<PlayerSuggestion> a, List<PlayerSuggestion> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].nickname != b[i].nickname || a[i].platform != b[i].platform) {
        return false;
      }
    }
    return true;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    onChanged = null;
  }
}
