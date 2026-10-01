import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/app_panels.dart';
import 'support_models.dart';
import 'support_repository.dart';

class SupportDetailScreen extends StatefulWidget {
  const SupportDetailScreen({
    super.key,
    required this.ticketId,
    this.repository,
  });
  final String ticketId;
  final SupportRepository? repository;
  @override
  State<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends State<SupportDetailScreen> {
  late final SupportRepository _repository;
  Future<SupportTicket>? _future;
  final _body = TextEditingController();
  StreamSubscription<String?>? _authSubscription;
  String? _error;
  String? _messageKey;
  bool _sending = false;
  String? _openingAttachment;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRepository();
    _future = _repository.canReadPrivate
        ? _repository.fetchTicket(widget.ticketId)
        : null;
    _authSubscription = _repository.authChanges.listen((_) {
      if (!mounted) return;
      setState(() {
        _body.clear();
        _messageKey = null;
        _error = null;
        _future = _repository.canReadPrivate
            ? _repository.fetchTicket(widget.ticketId)
            : null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant SupportDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticketId != widget.ticketId) {
      _body.clear();
      _messageKey = null;
      _future = _repository.canReadPrivate
          ? _repository.fetchTicket(widget.ticketId)
          : null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _body.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repository.canReadPrivate
          ? _repository.fetchTicket(widget.ticketId)
          : null;
    });
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _send() async {
    final ticketId = widget.ticketId;
    final userId = _repository.userId;
    _messageKey ??= _uuid();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _repository.sendMessage(
        ticketId: ticketId,
        body: _body.text,
        idempotencyKey: _messageKey!,
      );
      if (!mounted ||
          ticketId != widget.ticketId ||
          userId != _repository.userId) {
        return;
      }
      _body.clear();
      _messageKey = null;
      _reload();
    } on SupportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(SupportAttachment attachment) async {
    setState(() {
      _openingAttachment = attachment.id;
      _error = null;
    });
    try {
      // 열 때마다 새 URL을 요청해 300초 만료 주소를 재사용하지 않는다.
      final url = await _repository.attachmentUrl(attachment.id);
      if (!mounted) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const SupportException('첨부파일을 열지 못했습니다.');
      }
    } on SupportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '첨부파일을 열지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _openingAttachment = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('문의 상세')),
    body: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    if (!_repository.canReadPrivate) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('문의 상세는 로그인 후 확인할 수 있습니다.'),
          OutlinedButton(
            onPressed: () => context.go('/my'),
            child: const Text('로그인'),
          ),
        ],
      );
    }
    return FutureBuilder<SupportTicket>(
      key: ValueKey(_repository.userId),
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard(lines: 5, label: '문의를 불러오고 있습니다');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorPanel(
                error: snapshot.error ?? '문의 응답이 없습니다.',
                onRetry: _reload,
                title: '문의를 불러오지 못했습니다',
              ),
            ],
          );
        }
        final ticket = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              ticket.subject,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${supportCategories[ticket.category] ?? ticket.category} · ${ticket.statusLabel}',
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              tooltip: '문의 새로고침',
            ),
            if (ticket.messages.isEmpty) const Text('표시할 메시지가 없습니다.'),
            ...ticket.messages.map(
              (message) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${message.fromAdmin ? '관리자' : '나'} · ${message.createdAt}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(message.body),
                    ],
                  ),
                ),
              ),
            ),
            if (ticket.attachments.isNotEmpty) ...[
              const Text('첨부 증빙'),
              ...ticket.attachments.map(
                (attachment) => ListTile(
                  title: Text(attachment.name),
                  subtitle: Text(
                    attachment.status == 'ready'
                        ? '열 때 새 조회 주소를 발급합니다.'
                        : '현재 열 수 없는 첨부파일입니다.',
                  ),
                  trailing: TextButton(
                    onPressed:
                        attachment.status != 'ready' ||
                            _openingAttachment != null
                        ? null
                        : () => _open(attachment),
                    child: Text(
                      _openingAttachment == attachment.id ? '여는 중...' : '열기',
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextField(
              controller: _body,
              enabled: !_sending,
              minLines: 2,
              maxLines: 8,
              maxLength: 5000,
              onChanged: (_) => _messageKey = null,
              decoration: const InputDecoration(labelText: '추가로 전달할 내용'),
            ),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Text(_sending ? '보내는 중...' : '추가 메시지 보내기'),
            ),
          ],
        );
      },
    );
  }
}
