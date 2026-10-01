import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import 'battle_models.dart';
import 'battle_repository.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.initialNickname,
    required this.initialPlatform,
    this.repository,
  });

  final String initialNickname;
  final String initialPlatform;
  final BattleRepository? repository;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final BattleRepository _repository;
  late final TextEditingController _firstController;
  final _secondController = TextEditingController();
  late String _firstPlatform;
  var _secondPlatform = 'steam';
  var _matchType = 'all';
  Future<BattleResult>? _future;
  var _isComparing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BattleRepository();
    _firstController = TextEditingController(text: widget.initialNickname);
    _firstPlatform = widget.initialPlatform;
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    if (_isComparing) {
      return;
    }
    final first = _firstController.text.trim();
    final second = _secondController.text.trim();
    if (first.isEmpty || second.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비교할 두 플레이어를 입력해 주세요.')));
      return;
    }
    final request = _repository.compare(
      firstNickname: first,
      secondNickname: second,
      firstPlatform: _firstPlatform,
      secondPlatform: _secondPlatform,
      matchType: _matchType,
    );
    setState(() {
      _future = request;
      _isComparing = true;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder가 오류 상태를 표시한다.
    } finally {
      if (mounted && identical(_future, request)) {
        setState(() => _isComparing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BgmsColors.bgBase,
      appBar: AppBar(
        backgroundColor: BgmsColors.bgBase,
        title: const Text('전적 비교'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _playerField(_firstController, '첫 번째 플레이어', _firstPlatform, (value) {
            setState(() => _firstPlatform = value);
          }),
          const SizedBox(height: 12),
          _playerField(_secondController, '두 번째 플레이어', _secondPlatform, (
            value,
          ) {
            setState(() => _secondPlatform = value);
          }),
          const SizedBox(height: 16),
          const Text('비교 경기'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('전체')),
              ButtonSegment(value: 'official', label: Text('일반')),
              ButtonSegment(value: 'competitive', label: Text('경쟁')),
            ],
            selected: {_matchType},
            onSelectionChanged: (value) =>
                setState(() => _matchType = value.first),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isComparing ? null : _compare,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('비교하기'),
          ),
          const SizedBox(height: 20),
          if (_future != null)
            FutureBuilder<BattleResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _BattleError(
                    message: ApiException.from(snapshot.error!).message,
                    onRetry: _compare,
                  );
                }
                final result = snapshot.data;
                return result == null
                    ? const SizedBox.shrink()
                    : _BattleResultPanel(result: result);
              },
            ),
        ],
      ),
    );
  }

  Widget _playerField(
    TextEditingController controller,
    String label,
    String platform,
    ValueChanged<String> onPlatformChanged,
  ) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: label),
        ),
      ),
      const SizedBox(width: 8),
      DropdownButton<String>(
        value: platform,
        items: const [
          DropdownMenuItem(value: 'steam', child: Text('Steam')),
          DropdownMenuItem(value: 'kakao', child: Text('Kakao')),
        ],
        onChanged: (value) {
          if (value != null) onPlatformChanged(value);
        },
      ),
    ],
  );
}

class _BattleResultPanel extends StatelessWidget {
  const _BattleResultPanel({required this.result});
  final BattleResult result;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            result.overallWinner == 'draw'
                ? '무승부'
                : '${result.overallWinner} 우세',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.comparisonMatchCount}경기 기준 · ${result.firstScore} : ${result.secondScore}',
          ),
          if (!result.tacticalComparable)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '전술 분석 버전이 일치하지 않아 기본 킬·딜량만 비교합니다.',
                style: TextStyle(color: BgmsColors.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          for (final comparison in result.comparisons)
            _ComparisonRow(
              comparison: comparison,
              firstName: result.firstNickname,
              secondName: result.secondNickname,
            ),
        ],
      ),
    ),
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.comparison,
    required this.firstName,
    required this.secondName,
  });
  final BattleComparison comparison;
  final String firstName;
  final String secondName;

  String _value(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}${comparison.unit}';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _value(comparison.firstValue),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: comparison.winner == 'nick1' ? FontWeight.w800 : null,
            ),
          ),
        ),
        Expanded(
          child: Text(
            comparison.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BgmsColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _value(comparison.secondValue),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: comparison.winner == 'nick2' ? FontWeight.w800 : null,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BattleError extends StatelessWidget {
  const _BattleError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}
