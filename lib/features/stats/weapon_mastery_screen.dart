import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/bgms_theme.dart';
import 'weapon_mastery_models.dart';
import 'weapon_mastery_repository.dart';

class WeaponMasteryScreen extends StatefulWidget {
  const WeaponMasteryScreen({
    super.key,
    required this.nickname,
    required this.platform,
    this.repository,
  });
  final String nickname;
  final String platform;
  final WeaponMasteryRepository? repository;
  @override
  State<WeaponMasteryScreen> createState() => _WeaponMasteryScreenState();
}

class _WeaponMasteryScreenState extends State<WeaponMasteryScreen> {
  late final WeaponMasteryRepository _repository;
  List<WeaponMasteryItem> _items = const [];
  bool _loading = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WeaponMasteryRepository();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final items = await _repository.refresh(
        nickname: widget.nickname,
        platform: widget.platform,
      );
      if (mounted) {
        setState(() => _items = items);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = ApiException.from(error).message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BgmsColors.bgBase,
    appBar: AppBar(
      backgroundColor: BgmsColors.bgBase,
      title: const Text('무기 숙련도'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '갱신을 누를 때만 서버가 플레이어 캐시와 PUBG API를 확인합니다.',
          style: TextStyle(color: BgmsColors.textMuted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _refresh,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_loading ? '갱신 중' : '무기 숙련도 갱신'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _message!,
              style: const TextStyle(color: BgmsColors.danger),
            ),
          ),
        if (!_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(child: Text('저장된 무기 숙련도가 없습니다.')),
          ),
        for (final item in _items)
          Card(
            child: ListTile(
              title: Text(item.label),
              subtitle: Text('${item.category} · 레벨 ${item.level}'),
              trailing: Text(
                '${item.totalKills}킬\n${item.totalDamage.toStringAsFixed(0)} 딜',
                textAlign: TextAlign.end,
              ),
            ),
          ),
      ],
    ),
  );
}
