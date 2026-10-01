import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_panels.dart';
import 'support_models.dart';
import 'support_repository.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.repository});
  final SupportRepository? repository;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportRepository _repository;
  final _search = TextEditingController();
  String _category = '';
  late Future<List<SupportFaq>> _faqs;
  Future<List<SupportTicket>>? _tickets;
  StreamSubscription<String?>? _authSubscription;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupportRepository();
    _faqs = _repository.fetchFaqs();
    _reloadTickets();
    _authSubscription = _repository.authChanges.listen((_) {
      if (mounted) setState(_reloadTickets);
    });
  }

  void _reloadTickets() {
    _tickets = _repository.canReadPrivate ? _repository.fetchTickets() : null;
  }

  void _reloadFaqs() {
    setState(() {
      _faqs = _repository.fetchFaqs(category: _category, query: _search.text);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await context.push('/support/new');
    if (mounted) setState(_reloadTickets);
  }

  Future<void> _open(String id) async {
    await context.push('/support/$id');
    if (mounted) setState(_reloadTickets);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('고객센터')),
    body: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        decoration: const InputDecoration(
          labelText: 'FAQ 검색',
          prefixIcon: Icon(Icons.search),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _reloadFaqs(),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: supportFaqCategories.entries
            .map(
              (entry) => ChoiceChip(
                label: Text(entry.value),
                selected: _category == entry.key,
                onSelected: (selected) {
                  if (!selected) return;
                  _category = entry.key;
                  _reloadFaqs();
                },
              ),
            )
            .toList(),
      ),
      FutureBuilder<List<SupportFaq>>(
        future: _faqs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingCard(lines: 3, label: 'FAQ를 불러오고 있습니다');
          }
          if (snapshot.hasError) {
            return ErrorPanel(
              error: snapshot.error!,
              onRetry: _reloadFaqs,
              title: 'FAQ를 불러오지 못했습니다',
            );
          }
          final faqs = snapshot.data ?? [];
          if (faqs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('이 조건에 맞는 FAQ가 없습니다.'),
            );
          }
          return Column(
            children: faqs
                .map(
                  (faq) => Card(
                    child: ExpansionTile(
                      key: ValueKey(faq.id),
                      title: Text(faq.question),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(faq.answer),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 24),
      Text('내 문의', style: Theme.of(context).textTheme.titleLarge),
      const Text('문의 내용과 관리자 답변은 본인에게만 제공됩니다.'),
      const SizedBox(height: 8),
      if (_tickets == null)
        OutlinedButton(
          onPressed: () => context.go('/my'),
          child: const Text('로그인 후 문의하기'),
        )
      else ...[
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('새 문의'),
        ),
        FutureBuilder<List<SupportTicket>>(
          key: ValueKey(_repository.userId),
          future: _tickets,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingCard(lines: 3, label: '내 문의를 불러오고 있습니다');
            }
            if (snapshot.hasError) {
              return ErrorPanel(
                error: snapshot.error!,
                onRetry: () => setState(_reloadTickets),
                title: '내 문의를 불러오지 못했습니다',
              );
            }
            final tickets = snapshot.data ?? [];
            if (tickets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('등록된 문의가 없습니다.'),
              );
            }
            return Column(
              children: tickets
                  .map(
                    (ticket) => Card(
                      child: ListTile(
                        title: Text(ticket.subject),
                        subtitle: Text(
                          '${ticket.statusLabel} · ${ticket.updatedAt}',
                        ),
                        leading: ticket.unread
                            ? const Icon(Icons.mark_email_unread_outlined)
                            : const Icon(Icons.mail_outline),
                        onTap: () => _open(ticket.id),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ],
  );
}
