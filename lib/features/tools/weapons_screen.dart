import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/bgms_theme.dart';
import '../../core/widgets/app_panels.dart';
import '../../core/widgets/bgms_card.dart';
import 'game_data.dart';
import '../../core/widgets/cached_image.dart';

/// 무기 도감. 분류·검색으로 찾고, 상세에서 부착물 효과를, 두 개를 골라 비교한다.
class WeaponsScreen extends StatefulWidget {
  const WeaponsScreen({
    super.key,
    this.repository = const GameDataRepository(),
  });
  final GameDataRepository repository;
  @override
  State<WeaponsScreen> createState() => _WeaponsScreenState();
}

/// 화면 분류. 설치형·기타 무기는 한 묶음으로 둔다.
const _categories = <(String, String)>[
  ('all', '전체'),
  ('AR', 'AR'),
  ('DMR', 'DMR'),
  ('SR', 'SR'),
  ('SMG', 'SMG'),
  ('SG', '샷건'),
  ('LMG', 'LMG'),
  ('etc', '기타'),
];

bool _inCategory(GameWeapon weapon, String category) => switch (category) {
  'all' => true,
  'etc' => !_categories.any((c) => c.$1 == weapon.type),
  _ => weapon.type == category,
};

String _number(double? value) => value?.toStringAsFixed(0) ?? '-';

class _WeaponsScreenState extends State<WeaponsScreen> {
  late Future<List<GameWeapon>> _future = widget.repository.fetchWeapons();
  Future<List<GameAttachment>>? _partsFuture;
  final List<String> _selected = [];
  String _search = '';
  String _category = 'all';

  /// 부착물은 상세를 처음 열 때 한 번 받는다. [retry]면 실패한 요청을 버리고 다시 받는다.
  Future<List<GameAttachment>> _loadParts({bool retry = false}) {
    if (retry) _partsFuture = null;
    return _partsFuture ??= widget.repository.fetchAttachments();
  }

  void _toggleCompare(GameWeapon weapon) {
    setState(() {
      if (!_selected.remove(weapon.id) && _selected.length < 2) {
        _selected.add(weapon.id);
      }
    });
  }

  void _openDetail(GameWeapon weapon) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: BgmsColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => _WeaponDetail(
          weapon: weapon,
          loadParts: _loadParts,
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('무기 도감')),
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
              const Text('공개 무기 데이터를 확인할 수 없습니다. 연결 상태를 확인한 후 다시 시도하세요.'),
              const SizedBox(height: BgmsSpacing.md),
              FilledButton(
                onPressed: () => setState(() {
                  _future = widget.repository.fetchWeapons();
                }),
                child: const Text('다시 시도'),
              ),
            ],
          );
        }
        final weapons = snapshot.data!;
        final shown = weapons
            .where((weapon) => _inCategory(weapon, _category))
            .where((weapon) => weapon.name.toLowerCase().contains(_search))
            .toList();
        final compared = [
          for (final id in _selected)
            ...weapons.where((weapon) => weapon.id == id),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: '무기 이름 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: BgmsSpacing.md),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (id, label) in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: BgmsSpacing.sm),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _category == id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = id),
                      ),
                    ),
                ],
              ),
            ),
            if (compared.isNotEmpty) ...[
              const SizedBox(height: BgmsSpacing.lg),
              _CompareTable(weapons: compared, onRemove: _toggleCompare),
            ],
            const SizedBox(height: BgmsSpacing.lg),
            if (shown.isEmpty)
              const Text('조건에 맞는 무기가 없습니다.')
            else
              Material(
                color: BgmsColors.surface,
                shape: BgmsShape.panel(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(),
                      _WeaponRow(
                        weapon: shown[i],
                        compared: _selected.contains(shown[i].id),
                        compareFull: _selected.length == 2,
                        onTap: () => _openDetail(shown[i]),
                        onCompare: () => _toggleCompare(shown[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// 무기 렌더는 투명 배경의 검은 총기라 밝은 아이템 칸 위에 올린다.
class _WeaponImage extends StatelessWidget {
  const _WeaponImage({required this.weaponId, required this.size});

  static const slotColor = Color(0xFFB4B8AC);

  final String weaponId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: slotColor,
      shape: BgmsShape.panel(side: BorderSide.none, size: BgmsShape.cutSmall),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: size,
        child: Image(
          image: cachedImageProvider(
            AppConfig.local.weaponImageUrl(weaponId),
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          ),
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.track_changes, color: BgmsColors.onAccent),
        ),
      ),
    );
  }
}

class _WeaponRow extends StatelessWidget {
  const _WeaponRow({
    required this.weapon,
    required this.compared,
    required this.compareFull,
    required this.onTap,
    required this.onCompare,
  });

  final GameWeapon weapon;
  final bool compared;
  final bool compareFull;
  final VoidCallback onTap;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            _WeaponImage(weaponId: weapon.id, size: 48),
            const SizedBox(width: BgmsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weapon.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${weapon.type} · ${weapon.ammo ?? '-'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: '기본 피해 ${_number(weapon.damage)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_number(weapon.damage), style: BgmsText.number(22)),
                  Text(
                    '피해',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BgmsColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: compared || !compareFull ? onCompare : null,
              tooltip: compared
                  ? '${weapon.name} 비교에서 빼기'
                  : '${weapon.name} 비교에 추가',
              icon: Icon(
                compared ? Icons.check_box : Icons.check_box_outline_blank,
                color: compared ? BgmsColors.accent : BgmsColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 무기의 기본 수치를 나란히 둔다. 더 높은 수치를 골드로 표시한다.
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.weapons, required this.onRemove});

  final List<GameWeapon> weapons;
  final ValueChanged<GameWeapon> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget numberRow(String label, double? Function(GameWeapon) read) {
      final values = weapons.map(read).toList();
      final best = values.length == 2 && values.every((v) => v != null)
          ? values.reduce((a, b) => a! > b! ? a : b)
          : null;
      return _CompareRow(
        label: label,
        cells: [
          for (final value in values)
            Text(
              _number(value),
              style: BgmsText.number(
                20,
                color: value != null && value == best && values[0] != values[1]
                    ? BgmsColors.accent
                    : BgmsColors.textPrimary,
              ),
            ),
        ],
      );
    }

    Widget textRow(String label, String? Function(GameWeapon) read) =>
        _CompareRow(
          label: label,
          cells: [
            for (final weapon in weapons)
              Text(read(weapon) ?? '-', style: theme.textTheme.bodySmall),
          ],
        );

    return SectionBand(
      title: '선택한 무기 비교',
      child: BgmsCard(
        child: Column(
          children: [
            _CompareRow(
              label: '',
              cells: [
                for (final weapon in weapons)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          weapon.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemove(weapon),
                        tooltip: '${weapon.name} 비교에서 빼기',
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
              ],
            ),
            numberRow('피해', (w) => w.damage),
            numberRow('탄속 m/s', (w) => w.bulletSpeed),
            textRow('탄약', (w) => w.ammo),
            textRow('분류', (w) => w.type),
            textRow('등장 맵', (w) => w.spawnMaps),
            if (weapons.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: BgmsSpacing.sm),
                child: Text(
                  '비교할 무기를 하나 더 고르세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BgmsColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.cells});

  final String label;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
          ),
          for (final cell in cells) Expanded(child: cell),
          if (cells.length == 1) const Spacer(),
        ],
      ),
    );
  }
}

/// 무기 상세 시트. 기본 수치와 슬롯별 부착물 효과 계산.
class _WeaponDetail extends StatefulWidget {
  const _WeaponDetail({
    required this.weapon,
    required this.loadParts,
    required this.controller,
  });

  final GameWeapon weapon;
  final Future<List<GameAttachment>> Function({bool retry}) loadParts;
  final ScrollController controller;

  @override
  State<_WeaponDetail> createState() => _WeaponDetailState();
}

class _WeaponDetailState extends State<_WeaponDetail> {
  late Future<List<GameAttachment>> _parts = widget.loadParts();

  @override
  Widget build(BuildContext context) {
    final weapon = widget.weapon;
    final theme = Theme.of(context);
    Widget figure(String label, String value) => Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: BgmsText.number(28)),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: BgmsColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Center(child: _WeaponImage(weaponId: weapon.id, size: 144)),
        const SizedBox(height: BgmsSpacing.md),
        Text(
          weapon.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${weapon.type} · ${weapon.ammo ?? '-'} · 등장 맵 ${weapon.spawnMaps ?? '-'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: BgmsColors.textSecondary,
          ),
        ),
        const SizedBox(height: BgmsSpacing.lg),
        Row(
          children: [
            figure('기본 피해', _number(weapon.damage)),
            figure('탄속 m/s', _number(weapon.bulletSpeed)),
          ],
        ),
        const SizedBox(height: BgmsSpacing.xl),
        SectionBand(
          title: '부착물 효과',
          child: FutureBuilder<List<GameAttachment>>(
            future: _parts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text('부착물 데이터를 확인할 수 없습니다. 기본 수치만 표시합니다.'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _parts = widget.loadParts(retry: true);
                      }),
                      child: const Text('다시 시도'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) return const SkeletonBox(height: 120);
              return _AttachmentComparison(
                key: ValueKey(weapon.id),
                weapon: weapon,
                parts: snapshot.data!,
              );
            },
          ),
        ),
      ],
    );
  }
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
