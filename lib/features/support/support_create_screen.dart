import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import 'support_models.dart';
import 'support_repository.dart';

class SupportCreateScreen extends StatefulWidget {
  const SupportCreateScreen({super.key, this.repository});
  final SupportRepository? repository;
  @override
  State<SupportCreateScreen> createState() => _SupportCreateScreenState();
}

class _SupportCreateScreenState extends State<SupportCreateScreen> {
  late final SupportRepository _repository;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = 'bug';
  String? _error;
  bool _sending = false;
  String? _draftUserId;
  int _generation = 0;
  StreamSubscription<String?>? _authSubscription;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRepository();
    _draftUserId = _repository.userId;
    _authSubscription = _repository.authChanges.listen((userId) {
      if (!mounted || userId == _draftUserId) return;
      setState(() => _resetDraft(userId));
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _resetDraft(String? userId) {
    _generation++;
    _draftUserId = userId;
    _subject.clear();
    _body.clear();
    _category = 'bug';
    _error = null;
    _sending = false;
  }

  Future<void> _submit() async {
    final userId = _repository.userId;
    if (userId == null || userId != _draftUserId) {
      setState(() {
        _resetDraft(userId);
        _error = '로그인 상태가 변경되었습니다. 문의 내용을 다시 작성해 주세요.';
      });
      return;
    }
    if (_sending) return;
    final generation = _generation;
    setState(() {
      _sending = true;
      _error = null;
    });
    bool isCurrentDraft() =>
        mounted &&
        generation == _generation &&
        userId == _draftUserId &&
        userId == _repository.userId;
    try {
      final ticket = await _repository.createTicket(
        category: _category,
        subject: _subject.text,
        body: _body.text,
      );
      if (!mounted || !isCurrentDraft()) return;
      context.pushReplacement('/support/${ticket.id}');
    } on SupportException catch (error) {
      if (isCurrentDraft()) setState(() => _error = error.message);
    } finally {
      if (isCurrentDraft()) setState(() => _sending = false);
    }
  }

  Future<void> _webSupport() async {
    final generation = _generation;
    try {
      final opened = await launchUrl(
        Uri.parse('${AppConfig.local.normalizedBaseUrl}/support/new'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted && generation == _generation) {
        setState(() => _error = '웹 고객센터를 열지 못했습니다. 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '웹 고객센터를 열지 못했습니다. 다시 시도해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('새 문의')),
    body: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SizedBox(height: 12),
      const Text(
        '일반 문의는 앱에서 작성할 수 있습니다. 현재 신규 증빙 첨부와 전적 비공개 요청은 웹 고객센터를 이용해 주세요.',
      ),
      TextButton(
        onPressed: _sending ? null : _webSupport,
        child: const Text('증빙·전적 비공개 문의는 웹에서 작성'),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (!_repository.canReadPrivate)
        OutlinedButton(
          onPressed: () => context.go('/my'),
          child: const Text('로그인 후 문의 작성'),
        )
      else ...[
        DropdownButtonFormField<String>(
          key: ValueKey(_draftUserId),
          initialValue: _category,
          decoration: const InputDecoration(labelText: '분류'),
          items: supportCategories.entries
              .where((entry) => entry.key != 'privacy')
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: _sending
              ? null
              : (value) => setState(() => _category = value ?? 'bug'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subject,
          enabled: !_sending,
          maxLength: 120,
          decoration: const InputDecoration(labelText: '제목'),
        ),
        TextField(
          controller: _body,
          enabled: !_sending,
          maxLength: 5000,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '문의 내용',
            helperText: '비밀번호·인증 토큰 등 비밀정보를 적지 마세요.',
          ),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? '제출 중...' : '문의 제출'),
        ),
      ],
    ],
  );
}
