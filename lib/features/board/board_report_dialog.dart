import 'dart:async';
import 'package:flutter/material.dart';
import 'board_repository.dart';

typedef BoardReportDraft = ({String reason, String detail});

class BoardReportDialog extends StatefulWidget {
  const BoardReportDialog({super.key, required this.repository});
  final BoardRepository repository;
  @override
  State<BoardReportDialog> createState() => _BoardReportDialogState();
}

class _BoardReportDialogState extends State<BoardReportDialog> {
  final _detail = TextEditingController();
  String _reason = '스팸/광고';
  late final String? _actor;
  bool _sessionChanged = false;
  StreamSubscription<String?>? _auth;
  @override
  void initState() {
    super.initState();
    _actor = widget.repository.userId;
    _auth = widget.repository.authChanges.listen((user) {
      if (!mounted || user == _actor) return;
      setState(() {
        _detail.clear();
        _reason = '스팸/광고';
        _sessionChanged = true;
      });
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('신고'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sessionChanged) const Text('계정이 변경되었습니다. 창을 닫고 다시 확인해 주세요.'),
          DropdownButtonFormField<String>(
            key: ValueKey(_sessionChanged),
            initialValue: _reason,
            items: ['스팸/광고', '욕설/비방', '음란/불법 콘텐츠', '기타']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: _sessionChanged
                ? null
                : (value) => setState(() => _reason = value ?? _reason),
          ),
          TextField(
            controller: _detail,
            enabled: !_sessionChanged,
            maxLength: 500,
            decoration: const InputDecoration(labelText: '상세 사유 (선택)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _sessionChanged
            ? null
            : () {
                if (_actor == null || _actor != widget.repository.userId) {
                  setState(() {
                    _detail.clear();
                    _sessionChanged = true;
                  });
                  return;
                }
                Navigator.pop(context, (
                  reason: _reason,
                  detail: _detail.text.trim(),
                ));
              },
        child: const Text('신고 접수'),
      ),
    ],
  );
}
