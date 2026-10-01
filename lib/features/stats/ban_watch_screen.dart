import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import '../maps/map_models.dart';
import 'ban_watch_models.dart';
import 'ban_watch_repository.dart';

class BanWatchScreen extends StatefulWidget {
  const BanWatchScreen({super.key, this.repository});

  final BanWatchRepository? repository;

  @override
  State<BanWatchScreen> createState() => _BanWatchScreenState();
}

class _BanWatchScreenState extends State<BanWatchScreen> {
  late final BanWatchRepository _repository;
  Future<BanWatchList>? _future;
  StreamSubscription<AuthState>? _authSubscription;
  String? _accessToken;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BanWatchRepository();
    try {
      _accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((state) {
            final accessToken = state.session?.accessToken;
            if (!mounted || accessToken == _accessToken) {
              return;
            }
            setState(() {
              _accessToken = accessToken;
              _future = null;
              _deletingId = null;
              if (accessToken != null) {
                _load();
              }
            });
          });
    } catch (_) {
      _accessToken = null;
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
    _future = _repository.fetch(accessToken: token);
  }

  Future<void> _confirmRemove(BanWatchItem item) async {
    final tokenAtConfirmation = _accessToken;
    if (tokenAtConfirmation == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관심 추적을 삭제할까요?'),
        content: Text('${item.nickname}의 제재 추적 기록을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || tokenAtConfirmation != _accessToken) {
      return;
    }
    await _remove(item, tokenAtConfirmation);
  }

  Future<void> _remove(BanWatchItem item, String accessToken) async {
    if (item.id.isEmpty || _deletingId != null || accessToken != _accessToken) {
      return;
    }
    setState(() => _deletingId = item.id);
    try {
      await _repository.remove(watchId: item.id, accessToken: accessToken);
      if (!mounted || accessToken != _accessToken) {
        return;
      }
      setState(_load);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관심 추적을 삭제했습니다.')));
    } catch (error) {
      if (mounted && accessToken == _accessToken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiException.from(error).message)),
        );
      }
    } finally {
      if (mounted && accessToken == _accessToken) {
        setState(() => _deletingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BgmsColors.bgBase,
    appBar: AppBar(
      backgroundColor: BgmsColors.bgBase,
      title: const Text('관심 추적'),
    ),
    body: _accessToken == null
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '관심 추적 목록은 로그인 후 이용할 수 있습니다.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : FutureBuilder<BanWatchList>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _BanWatchError(
                  message: ApiException.from(snapshot.error!).message,
                  onRetry: () => setState(_load),
                );
              }
              final items = snapshot.data?.items ?? const <BanWatchItem>[];
              if (items.isEmpty) {
                return const Center(child: Text('등록한 관심 추적 상대가 없습니다.'));
              }
              return RefreshIndicator(
                onRefresh: () async => setState(_load),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _BanWatchCard(
                      item: item,
                      deleting: _deletingId == item.id,
                      onDelete: () => _confirmRemove(item),
                    );
                  },
                ),
              );
            },
          ),
  );
}

class _BanWatchCard extends StatelessWidget {
  const _BanWatchCard({
    required this.item,
    required this.deleting,
    required this.onDelete,
  });

  final BanWatchItem item;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.currentStatus) {
      'permanent' || 'temporary' => BgmsColors.danger,
      'none' => BgmsColors.accent,
      _ => BgmsColors.textMuted,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  item.statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                item.weapon ?? '무기 정보 없음',
                bgmsMapDisplayName(item.mapName),
                _dateLabel(item.eventAt),
              ].join(' · '),
              style: const TextStyle(color: BgmsColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              item.currentCheckedAt == null
                  ? '제재 상태 확인 대기 · 추적 만료 ${_dateLabel(item.activeUntil)}'
                  : '마지막 확인 ${_dateLabel(item.currentCheckedAt)} · 추적 만료 ${_dateLabel(item.activeUntil)}',
              style: const TextStyle(color: BgmsColors.textMuted, fontSize: 11),
            ),
            if (item.hasStatusChange) ...[
              const SizedBox(height: 8),
              const Text(
                '등록 당시와 제재 상태가 달라졌습니다.',
                style: TextStyle(color: BgmsColors.danger, fontSize: 12),
              ),
            ],
            if (item.currentError != null) ...[
              const SizedBox(height: 8),
              const Text(
                '상태 확인이 지연되어 이전 결과를 표시합니다.',
                style: TextStyle(color: BgmsColors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: deleting ? null : onDelete,
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(deleting ? '삭제 중' : '삭제'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BanWatchError extends StatelessWidget {
  const _BanWatchError({required this.message, required this.onRetry});

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

String _dateLabel(DateTime? value) {
  if (value == null) {
    return '정보 없음';
  }
  return '${value.year}.${value.month}.${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
