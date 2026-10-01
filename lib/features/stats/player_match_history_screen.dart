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
  });

  final PlayerStatsProfile profile;
  final PlayerMatchHistoryRepository? repository;

  @override
  State<PlayerMatchHistoryScreen> createState() =>
      _PlayerMatchHistoryScreenState();
}

class _PlayerMatchHistoryScreenState extends State<PlayerMatchHistoryScreen> {
  late final PlayerMatchHistoryRepository _repository;
  Future<PlayerMatchHistoryPage>? _future;
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
    _load();
  }

  void _load() {
    _future = _repository.fetchPage(
      nickname: widget.profile.nickname,
      platform: widget.profile.platform,
      page: _page,
      filter: _filter,
    );
  }

  void _selectFilter(String filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
      _load();
    });
  }

  void _moveToPage(int page) {
    setState(() {
      _page = page;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        title: Text('${widget.profile.nickname} 전체 경기'),
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
                        onSelected: (_) => _selectFilter(entry.key),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: FutureBuilder<PlayerMatchHistoryPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final message = ApiException.from(snapshot.error!).message;
                  return _HistoryError(
                    onRetry: () => setState(_load),
                    message: message,
                  );
                }
                final result = snapshot.data;
                if (result == null || result.matches.isEmpty) {
                  return const Center(child: Text('이 조건의 저장된 경기 기록이 없습니다.'));
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${result.totalCount}경기 · ${result.page}/${result.totalPages}페이지',
                          style: const TextStyle(
                            color: BgmsColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
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
                      onPrevious: () => _moveToPage(result.page - 1),
                      onNext: () => _moveToPage(result.page + 1),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
            child: Center(child: Text('${result.page} / ${result.totalPages}')),
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
