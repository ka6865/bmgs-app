import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import '../maps/map_models.dart';
import 'encounter_models.dart';
import 'encounter_repository.dart';

class EncounterScreen extends StatefulWidget {
  const EncounterScreen({
    super.key,
    required this.nickname,
    required this.platform,
    this.repository,
  });

  final String nickname;
  final String platform;
  final EncounterRepository? repository;

  @override
  State<EncounterScreen> createState() => _EncounterScreenState();
}

class _EncounterScreenState extends State<EncounterScreen> {
  late final EncounterRepository _repository;
  Future<EncounterPage>? _future;
  String? _accessToken;
  StreamSubscription<AuthState>? _authSubscription;
  String? _collectingMatchId;
  BuildContext? _profileDialogContext;
  var _page = 1;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EncounterRepository();
    try {
      _accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      _accessToken = null;
    }
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((state) {
            final accessToken = state.session?.accessToken;
            if (!mounted || accessToken == _accessToken) {
              return;
            }
            final profileDialogContext = _profileDialogContext;
            if (profileDialogContext != null && profileDialogContext.mounted) {
              Navigator.of(profileDialogContext).pop();
            }
            _profileDialogContext = null;
            setState(() {
              _accessToken = accessToken;
              _page = 1;
              _future = null;
              _collectingMatchId = null;
              if (accessToken != null) {
                _load();
              }
            });
          });
    } catch (_) {
      _authSubscription = null;
    }
    if (_accessToken != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _load() {
    final token = _accessToken;
    if (token == null) {
      return;
    }
    _future = _repository.fetch(
      nickname: widget.nickname,
      platform: widget.platform,
      accessToken: token,
      page: _page,
    );
  }

  Future<void> _collect(EncounterMatch match) async {
    final token = _accessToken;
    if (token == null || match.matchId.isEmpty) {
      return;
    }
    setState(() => _collectingMatchId = match.matchId);
    try {
      await _repository.collect(
        nickname: widget.nickname,
        platform: widget.platform,
        matchId: match.matchId,
        accessToken: token,
      );
      if (mounted && token == _accessToken) {
        setState(_load);
      }
    } catch (error) {
      if (token == _accessToken) {
        _showError(error);
      }
    } finally {
      if (mounted && token == _accessToken) {
        setState(() => _collectingMatchId = null);
      }
    }
  }

  void _movePage(int page) {
    if (page < 1) {
      return;
    }
    setState(() {
      _page = page;
      _load();
    });
  }

  Future<void> _showProfile(
    EncounterMatch match,
    EncounterEntry entry, {
    bool refresh = false,
  }) async {
    final token = _accessToken;
    if (token == null || entry.targetAccountId.isEmpty) {
      return;
    }
    try {
      final profile = await _repository.fetchProfile(
        nickname: widget.nickname,
        platform: widget.platform,
        matchId: match.matchId,
        targetAccountId: entry.targetAccountId,
        accessToken: token,
        refresh: refresh,
      );
      if (!mounted || token != _accessToken) {
        return;
      }
      final requestedRefresh = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          _profileDialogContext = dialogContext;
          return AlertDialog(
            title: Text(entry.nickname),
            content: Text(_profileText(profile)),
            actions: [
              if (!refresh)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('티어·평균 피해량 갱신'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      );
      _profileDialogContext = null;
      if (requestedRefresh == true && mounted && token == _accessToken) {
        await _showProfile(match, entry, refresh: true);
      }
    } catch (error) {
      if (token == _accessToken) {
        _showError(error);
      }
    }
  }

  Future<void> _watch(
    EncounterPage page,
    EncounterMatch match,
    EncounterEntry entry,
  ) async {
    final token = _accessToken;
    if (token == null ||
        page.subjectAccountId.isEmpty ||
        page.subjectNickname.isEmpty ||
        entry.targetAccountId.isEmpty ||
        entry.eventAt.isEmpty) {
      return;
    }
    try {
      await _repository.watch(
        accessToken: token,
        payload: {
          'platform': widget.platform,
          'subjectAccountId': page.subjectAccountId,
          'subjectNicknameAtMatch': page.subjectNickname,
          'targetAccountId': entry.targetAccountId,
          'matchId': match.matchId,
          'eventAt': entry.eventAt,
          'role': entry.role,
          'nicknameAtMatch': entry.nickname,
          'mapName': match.mapName,
          if (entry.weapon != null) 'weapon': entry.weapon,
        },
      );
      if (mounted && token == _accessToken) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('관심 목록에 등록했습니다.')));
      }
    } catch (error) {
      if (token == _accessToken) {
        _showError(error);
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ApiException.from(error).message)));
  }

  String _profileText(EncounterProfile profile) {
    if (profile.pending) {
      return profile.retryAt == null
          ? '상대 통계를 확인하고 있습니다. 잠시 후 다시 확인해 주세요.'
          : '상대 통계를 확인하고 있습니다.\n${profile.retryAt!.toLocal()} 이후 다시 확인해 주세요.';
    }
    return '공식 경쟁전 티어: ${profile.tier ?? '기록 없음'}\n'
        '시즌 평균 딜량: ${profile.averageDamage ?? '—'}\n'
        '경기 수: ${profile.rounds ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    final token = _accessToken;
    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        title: const Text('만난 상대'),
      ),
      body: token == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '상대 기록과 관심 등록은 로그인 후 이용할 수 있습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<EncounterPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorPanel(
                    message: ApiException.from(snapshot.error!).message,
                    onRetry: () => setState(_load),
                  );
                }
                final page = snapshot.data;
                if (page == null || page.matches.isEmpty) {
                  return const Center(child: Text('최근 90일 저장 경기 기록이 없습니다.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      '상대 기록 수집은 선택한 경기에서만 실행됩니다.',
                      style: TextStyle(color: BgmsColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    for (final match in page.matches)
                      _EncounterMatchCard(
                        match: match,
                        page: page,
                        collecting: _collectingMatchId != null,
                        onCollect: () => _collect(match),
                        onProfile: (entry) => _showProfile(match, entry),
                        onWatch: (entry) => _watch(page, match, entry),
                      ),
                    if (page.totalPages > 1)
                      _Pagination(
                        page: page.page,
                        totalPages: page.totalPages,
                        onPrevious: page.page > 1
                            ? () => _movePage(page.page - 1)
                            : null,
                        onNext: page.page < page.totalPages
                            ? () => _movePage(page.page + 1)
                            : null,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _EncounterMatchCard extends StatelessWidget {
  const _EncounterMatchCard({
    required this.match,
    required this.page,
    required this.collecting,
    required this.onCollect,
    required this.onProfile,
    required this.onWatch,
  });

  final EncounterMatch match;
  final EncounterPage page;
  final bool collecting;
  final VoidCallback onCollect;
  final ValueChanged<EncounterEntry> onProfile;
  final ValueChanged<EncounterEntry> onWatch;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${bgmsMapDisplayName(match.mapName)} · ${match.gameMode}'),
          if (match.entries.isEmpty)
            TextButton.icon(
              onPressed: collecting ? null : onCollect,
              icon: const Icon(Icons.manage_search),
              label: Text(collecting ? '상대 기록 수집 중' : '이 경기 상대 기록 수집'),
            )
          else
            for (final entry in match.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.nickname),
                subtitle: Text(
                  '${entry.roleLabel} · ${entry.weapon ?? '무기 정보 없음'}',
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_search),
                      tooltip: '상대 전적 확인',
                      onPressed: () => onProfile(entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: '관심 등록',
                      onPressed:
                          page.subjectAccountId.isEmpty ||
                              page.subjectNickname.isEmpty
                          ? null
                          : () => onWatch(entry),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        OutlinedButton(onPressed: onPrevious, child: const Text('이전')),
        Expanded(child: Center(child: Text('$page / $totalPages'))),
        OutlinedButton(onPressed: onNext, child: const Text('다음')),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
