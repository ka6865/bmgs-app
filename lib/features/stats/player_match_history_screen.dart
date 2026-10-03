import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import 'player_match_history_models.dart';
import 'player_match_history_repository.dart';
import 'player_stats_models.dart';
import 'widgets/match_card.dart';

class PlayerMatchHistoryScreen extends StatefulWidget {
  const PlayerMatchHistoryScreen({
    super.key,
    required this.profile,
    this.repository,
    this.initialCollectAvailableAt,
  });

  final PlayerStatsProfile profile;
  final PlayerMatchHistoryRepository? repository;
  final DateTime? initialCollectAvailableAt;

  @override
  State<PlayerMatchHistoryScreen> createState() =>
      _PlayerMatchHistoryScreenState();
}

class _PlayerMatchHistoryScreenState extends State<PlayerMatchHistoryScreen> {
  late final PlayerMatchHistoryRepository _repository;
  PlayerMatchHistoryPage? _result;
  PlayerMatchCollectionResult? _collection;
  String? _error;
  bool _loading = false;
  bool _collecting = false;
  int _generation = 0;
  DateTime? _collectAvailableAt;
  Timer? _cooldownTimer;

  bool get _busy => _loading || _collecting;
  bool get _coolingDown =>
      _collectAvailableAt?.isAfter(DateTime.now()) ?? false;
  var _page = 1;
  var _filter = 'all';

  static const _filters = <String, String>{
    'all': '전체',
    'normal': '일반',
    'ranked': '경쟁',
    'casual': '캐주얼',
    'tdm': 'TDM',
  };

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PlayerMatchHistoryRepository();
    final availableAt = widget.initialCollectAvailableAt;
    if (availableAt != null) {
      final remaining = availableAt.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _setCooldown(remaining);
      }
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerMatchHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.nickname != widget.profile.nickname ||
        oldWidget.profile.platform != widget.profile.platform) {
      _page = 1;
      _filter = 'all';
      _result = null;
      _collection = null;
      _error = null;
      _collecting = false;
      _cooldownTimer?.cancel();
      _collectAvailableAt = null;
      _load();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _load() {
    final generation = ++_generation;
    final nickname = widget.profile.nickname;
    final platform = widget.profile.platform;
    final page = _page;
    final filter = _filter;
    _loading = true;
    _error = null;
    unawaited(_readPage(generation, nickname, platform, page, filter));
  }

  Future<void> _readPage(
    int generation,
    String nickname,
    String platform,
    int page,
    String filter,
  ) async {
    try {
      final result = await _repository.fetchPage(
        nickname: nickname,
        platform: platform,
        page: page,
        filter: filter,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectFilter(String filter) {
    if (_busy || _filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
      _result = null;
      _load();
    });
  }

  void _moveToPage(int page) {
    if (_busy) return;
    setState(() {
      _page = page;
      _result = null;
      _load();
    });
  }

  Future<void> _collect() async {
    if (_busy || _coolingDown) return;
    final generation = ++_generation;
    final nickname = widget.profile.nickname;
    final platform = widget.profile.platform;
    final filter = _filter;
    setState(() {
      _collecting = true;
      _error = null;
      _collection = null;
    });
    try {
      final collected = await _repository.collect(
        nickname: nickname,
        platform: platform,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _collection = collected);
      if (collected.collection?.rateLimited == true) {
        _setCooldown(const Duration(seconds: 60));
      }
      // 신규 저장으로 페이지 경계가 바뀔 수 있어 첫 페이지를 다시 읽는다.
      final result = await _repository.fetchPage(
        nickname: nickname,
        platform: platform,
        page: 1,
        filter: filter,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = 1;
        _result = result;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final apiError = ApiException.from(error);
      if (apiError.kind == ApiErrorKind.rateLimited) {
        _setCooldown(apiError.retryAfter ?? const Duration(seconds: 60));
      }
      setState(
        () => _error = '수집 또는 목록 갱신 실패 · 이전 이력을 유지합니다. ${apiError.message}',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _collecting = false);
      }
    }
  }

  void _setCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    _collectAvailableAt = DateTime.now().add(duration);
    _cooldownTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _collectAvailableAt = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        title: Text('${widget.profile.nickname} DB 경기 이력'),
        actions: [
          IconButton(
            tooltip: '저장 이력 새로고침',
            onPressed: _busy ? null : () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: _filters.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        showCheckmark: false,
                        onSelected: _busy
                            ? null
                            : (_) => _selectFilter(entry.key),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _busy || _coolingDown ? null : _collect,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(
                _collecting
                    ? '수집 중…'
                    : _coolingDown
                    ? '호출 제한 · 잠시 후 수집 가능'
                    : '대기 경기 수집 · 새로고침',
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null && _result != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: BgmsColors.textSecondary),
              ),
            ),
          Expanded(child: _buildHistory()),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final result = _result;
    if (result == null) {
      if (_busy) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return _HistoryError(onRetry: () => setState(_load), message: _error!);
      }
      return const Center(child: Text('이 조건의 저장된 경기 기록이 없습니다.'));
    }
    return Column(
      children: [
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.3,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'DB 저장 ${result.totalCount}경기 · ${result.page}/${result.totalPages > 0 ? result.totalPages : 1}페이지',
                    style: const TextStyle(
                      color: BgmsColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _HistoryProgress(
                    ingest: result.historyIngest,
                    collection: _collection?.collection,
                    collectionAttempted: _collection != null,
                  ),
                  if (_filter != 'all')
                    const Text('DB 건수는 선택한 필터에 맞는 경기 수입니다.'),
                  const Text('수집 버튼은 대기 목록에서 최대 3경기만 확인합니다.'),
                  const Text(
                    '수집되어 DB에 저장된 경기만 조회합니다. 최근 20경기 목록이나 PUBG 전체 플레이 이력과 다릅니다. DB에 없는 기간 만료 기록을 전부 복구할 수는 없습니다.',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: result.matches.isEmpty
              ? const Center(
                  child: Text(
                    '이 페이지에 표시할 저장 경기가 없습니다. 이전 페이지 또는 다른 필터를 확인하세요.',
                  ),
                )
              : ListView.builder(
                  key: ValueKey('$_filter:${result.page}'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: result.matches.length,
                  itemBuilder: (context, index) => MatchCard(
                    match: result.matches[index],
                    profile: widget.profile,
                  ),
                ),
        ),
        _Pagination(
          result: result,
          onPrevious: _busy ? null : () => _moveToPage(result.page - 1),
          onNext: _busy ? null : () => _moveToPage(result.page + 1),
        ),
      ],
    );
  }
}

class _HistoryProgress extends StatelessWidget {
  const _HistoryProgress({
    required this.ingest,
    required this.collection,
    this.collectionAttempted = false,
  });

  final HistoryIngest? ingest;
  final MatchCollection? collection;
  final bool collectionAttempted;

  @override
  Widget build(BuildContext context) {
    final pending = ingest?.pendingCount;
    final unavailable = ingest?.unavailableCount;
    final messages = <String>[
      pending == null ? '수집 대기 상태 불명' : '수집 대기 $pending경기',
      unavailable == null ? '수집 불가 상태 불명' : '만료·조회 불가 $unavailable경기',
      if (ingest?.lastSavedAt != null)
        '최근 수집 저장: ${ingest!.lastSavedAt!.toLocal()}',
    ];
    final summary = collection;
    if (collectionAttempted && summary == null) messages.add('이번 수집 결과 상태 불명');
    if (summary != null) {
      messages.add(
        summary.newSaved == null
            ? '이번 수집 DB 저장 확인 ${summary.saved ?? '?'}경기 (신규 저장 구분 불가)'
            : '이번 수집 신규 저장 ${summary.newSaved}경기 · 기존 저장 확인 ${summary.alreadyStored}경기',
      );
      if ((summary.retry ?? 0) > 0) messages.add('재시도 대기 ${summary.retry}경기');
      if ((summary.unavailable ?? 0) > 0) {
        messages.add('이번 수집 만료·조회 불가 ${summary.unavailable}경기');
      }
      if (summary.rateLimited == true) {
        messages.add('호출 한도 도달 · 남은 수집은 대기 중입니다.');
      }
    }
    return Text(
      messages.join(' · '),
      style: const TextStyle(color: BgmsColors.textSecondary, fontSize: 12),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.result,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayerMatchHistoryPage result;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: result.hasPreviousPage ? onPrevious : null,
            child: const Text('이전'),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${result.page} / ${result.totalPages > 0 ? result.totalPages : 1}',
              ),
            ),
          ),
          OutlinedButton(
            onPressed: result.hasNextPage ? onNext : null,
            child: const Text('다음'),
          ),
        ],
      ),
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    ),
  );
}
