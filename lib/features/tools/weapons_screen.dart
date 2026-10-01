import 'package:flutter/material.dart';

import '../../core/widgets/app_panels.dart';
import 'game_data.dart';

class WeaponsScreen extends StatefulWidget {
  const WeaponsScreen({
    super.key,
    this.repository = const GameDataRepository(),
  });
  final GameDataRepository repository;
  @override
  State<WeaponsScreen> createState() => _WeaponsScreenState();
}

class _WeaponsScreenState extends State<WeaponsScreen> {
  late Future<List<GameWeapon>> _future = widget.repository.fetchWeapons();
  Future<List<GameAttachment>>? _partsFuture;
  final Set<String> _selected = {};
  String _search = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('무기 도감·비교')),
    body: FutureBuilder<List<GameWeapon>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard(lines: 5, label: '무기 데이터를 불러오고 있습니다');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '공개 무기 데이터를 확인할 수 없습니다. 연결 설정 또는 읽기 권한을 확인한 후 다시 시도하세요.',
              ),
              FilledButton(
                onPressed: () =>
                    setState(() => _future = widget.repository.fetchWeapons()),
                child: const Text('다시 시도'),
              ),
            ],
          );
        }
        final weapons = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '무기 이름 검색'),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            const Text('두 무기를 선택해 기본 수치를 비교합니다. 미제공 수치는 -로 표시합니다.'),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: '선택한 무기 비교',
                child: Column(
                  children: [
                    for (final weapon in weapons.where(
                      (weapon) => _selected.contains(weapon.id),
                    ))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: Text(weapon.name),
                            subtitle: Text(_stats(weapon)),
                          ),
                          FutureBuilder<List<GameAttachment>>(
                            future: _partsFuture ??= widget.repository
                                .fetchAttachments(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Column(
                                  children: [
                                    const Text(
                                      '부착물 데이터는 확인할 수 없습니다. 기본 수치만 표시합니다.',
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _partsFuture = widget.repository
                                            .fetchAttachments(),
                                      ),
                                      child: const Text('부착물 다시 시도'),
                                    ),
                                  ],
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Text('부착물 불러오는 중');
                              }
                              return _AttachmentComparison(
                                key: ValueKey(weapon.id),
                                weapon: weapon,
                                parts: snapshot.data!,
                              );
                            },
                          ),
                          const Divider(),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            for (final weapon in weapons.where(
              (weapon) => weapon.name.toLowerCase().contains(_search),
            ))
              CheckboxListTile(
                value: _selected.contains(weapon.id),
                title: Text(weapon.name),
                subtitle: Text(
                  '${weapon.type} · ${weapon.ammo ?? '-'}\n${_stats(weapon)}\n등장 맵: ${weapon.spawnMaps ?? '-'}',
                ),
                onChanged:
                    !_selected.contains(weapon.id) && _selected.length == 2
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selected.add(weapon.id);
                        } else {
                          _selected.remove(weapon.id);
                        }
                      }),
              ),
          ],
        );
      },
    ),
  );

  String _stats(GameWeapon weapon) =>
      '기본 피해 ${weapon.damage?.toStringAsFixed(0) ?? '-'} · 탄속 ${weapon.bulletSpeed?.toStringAsFixed(0) ?? '-'} m/s';
}

class _AttachmentComparison extends StatefulWidget {
  const _AttachmentComparison({
    super.key,
    required this.weapon,
    required this.parts,
  });
  final GameWeapon weapon;
  final List<GameAttachment> parts;

  @override
  State<_AttachmentComparison> createState() => _AttachmentComparisonState();
}

class _AttachmentComparisonState extends State<_AttachmentComparison> {
  final Map<String, String?> _selected = {};
  static const _labels = {
    'muzzle': '총구',
    'grip': '손잡이',
    'magazine': '탄창',
    'sight': '조준경',
    'stock': '개머리판',
  };

  @override
  Widget build(BuildContext context) {
    final slots = weaponAttachmentSlots(widget.weapon);
    final selected = widget.parts
        .where((part) => _selected[part.slot] == part.id)
        .toList();
    final vertical = attachmentEffect(selected, [
      'muzzle',
      'grip',
      'stock',
    ], (p) => p.verticalRecoil);
    final horizontal = attachmentEffect(selected, [
      'muzzle',
      'grip',
      'stock',
    ], (p) => p.horizontalRecoil);
    final reload = attachmentEffect(selected, [
      'magazine',
      'stock',
    ], (p) => p.reloadSpeed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '웹 도감의 슬롯 기준으로 부착물 효과를 더합니다. 개별 파츠 호환·실측 반동·장탄수는 보증하지 않습니다.',
        ),
        if (slots.isEmpty) const Text('웹 도감 기준 부착물 슬롯이 없습니다.'),
        for (final slot in slots)
          DropdownButtonFormField<String>(
            key: ValueKey('${widget.weapon.id}:$slot'),
            isExpanded: true,
            initialValue: _selected[slot],
            decoration: InputDecoration(
              labelText: '${widget.weapon.name} ${_labels[slot]}',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('미장착')),
              for (final part in widget.parts.where(
                (part) => part.slot == slot,
              ))
                DropdownMenuItem(
                  value: part.id,
                  child: Text(part.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _selected[slot] = value),
          ),
        Text(
          '미장착 100 기준 · 수직 반동 ${_relative(vertical, 30)} · 수평 반동 ${_relative(horizontal, 30)} · 장전 시간 ${_relative(reload, 40)}',
        ),
        for (final part in selected)
          Text('${part.name} · 조준 속도 변화 ${_percent(part.adsSpeed)}'),
      ],
    );
  }

  String _relative(double? offset, double minimum) => offset == null
      ? '-'
      : '${(100 + offset).clamp(minimum, double.infinity).toStringAsFixed(0)}%';

  String _percent(double? value) => value == null
      ? '-'
      : '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)}%';
}
