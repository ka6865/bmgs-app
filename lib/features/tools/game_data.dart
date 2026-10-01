import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

double? gameNumber(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite && number >= 0 ? number : null;
}

double? _signedNumber(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

class GameAttachment {
  const GameAttachment({
    required this.id,
    required this.name,
    required this.slot,
    this.verticalRecoil,
    this.horizontalRecoil,
    this.reloadSpeed,
    this.adsSpeed,
  });

  final String id;
  final String name;
  final String slot;
  final double? verticalRecoil;
  final double? horizontalRecoil;
  final double? reloadSpeed;
  final double? adsSpeed;

  factory GameAttachment.fromJson(Map<String, dynamic> json) => GameAttachment(
    id: json['id'].toString(),
    name: json['name'].toString(),
    slot: json['slot']?.toString() ?? '',
    verticalRecoil: _signedNumber(json['vertical_recoil']),
    horizontalRecoil: _signedNumber(json['horizontal_recoil']),
    reloadSpeed: _signedNumber(json['reload_speed']),
    adsSpeed: _signedNumber(json['ads_speed']),
  );
}

/// 웹 도감의 슬롯 규칙이다. 개별 파츠 호환표를 보증하지 않는다.
List<String> weaponAttachmentSlots(GameWeapon weapon) {
  if (const ['sr_win94', 'sr_lynx', 'smg_p90'].contains(weapon.id)) {
    return const [];
  }
  final standard = const ['AR', 'DMR', 'SMG', 'SR'].contains(weapon.type);
  final shotgun = const ['sg_s12k', 'sg_o12'].contains(weapon.id);
  return [
    'sight',
    if (standard || shotgun) 'muzzle',
    if (const ['AR', 'DMR', 'SMG'].contains(weapon.type)) 'grip',
    if (standard || shotgun) 'magazine',
    if (const [
      'ar_m416',
      'ar_m16a4',
      'ar_mk47',
      'ar_ace32',
      'lmg_m249',
      'smg_vector',
      'smg_mp5k',
      'smg_uzi',
      'dmr_sks',
      'dmr_slr',
      'dmr_mk14',
      'dmr_mk12',
      'dmr_dragunov',
      'sr_kar98k',
      'sr_m24',
      'sr_awm',
      'sr_mosin',
    ].contains(weapon.id))
      'stock',
  ];
}

/// DB의 퍼센트 변화량을 슬롯별로 더한다. 실측 반동·장전 초는 추정하지 않는다.
double? attachmentEffect(
  List<GameAttachment> parts,
  List<String> slots,
  double? Function(GameAttachment) read,
) {
  var total = 0.0;
  for (final part in parts.where((part) => slots.contains(part.slot))) {
    final value = read(part);
    if (value == null) return null;
    total += value;
  }
  return total;
}

class GameWeapon {
  const GameWeapon({
    required this.id,
    required this.name,
    required this.type,
    this.ammo,
    this.damage,
    this.bulletSpeed,
    this.spawnMaps,
  });
  final String id;
  final String name;
  final String type;
  final String? ammo;
  final double? damage;
  final double? bulletSpeed;
  final String? spawnMaps;

  factory GameWeapon.fromJson(Map<String, dynamic> json) => GameWeapon(
    id: json['id'].toString(),
    name: json['name'].toString(),
    type: json['type']?.toString() ?? '',
    ammo: json['ammo']?.toString(),
    damage: gameNumber(json['damage']),
    bulletSpeed: gameNumber(json['bullet_speed']),
    spawnMaps: json['spawn_maps']?.toString(),
  );
}

class BackpackItem {
  const BackpackItem({
    required this.id,
    required this.name,
    required this.weight,
    required this.category,
    this.canBeInBackpack = true,
  });
  final String id;
  final String name;
  final double weight;
  final String category;
  final bool canBeInBackpack;
}

class GameVehicle {
  const GameVehicle({
    required this.id,
    required this.name,
    required this.capacity,
  });
  final String id;
  final String name;
  final double capacity;
}

class BackpackData {
  const BackpackData({required this.items, required this.vehicles});
  final List<BackpackItem> items;
  final List<GameVehicle> vehicles;
}

double backpackCapacity({required bool hasVest, required int level}) =>
    70 +
    (hasVest ? 50 : 0) +
    switch (level) {
      1 => 150,
      2 => 200,
      3 => 250,
      _ => 0,
    };

double inventoryWeight(List<BackpackItem> items, Map<String, int> quantities) =>
    items.fold(
      0,
      (sum, item) => sum + item.weight * (quantities[item.id] ?? 0),
    );

/// 웹의 공개 SELECT 정책을 사용한다. 관리 API나 서버 키는 사용하지 않는다.
class GameDataRepository {
  const GameDataRepository();

  SupabaseClient get _client {
    if (!AppConfig.local.canInitializeSupabase) {
      throw StateError('공개 게임 데이터 연결 설정이 없습니다.');
    }
    return Supabase.instance.client;
  }

  Future<List<GameWeapon>> fetchWeapons() async {
    final rows = await _client
        .from('weapons')
        .select('id, name, type, ammo, damage, bullet_speed, spawn_maps')
        .isFilter('removed_at', null)
        .order('name');
    final weapons = rows.map(GameWeapon.fromJson).toList();
    if (weapons.isEmpty) throw StateError('공개 무기 데이터가 없습니다.');
    return weapons;
  }

  Future<List<GameAttachment>> fetchAttachments() async {
    final rows = await _client
        .from('attachments')
        .select(
          'id, name, slot, vertical_recoil, horizontal_recoil, reload_speed, ads_speed',
        )
        .isFilter('removed_at', null)
        .order('name');
    final parts = rows.map(GameAttachment.fromJson).toList();
    if (parts.isEmpty) throw StateError('공개 부착물 데이터가 없습니다.');
    return parts;
  }

  Future<BackpackData> fetchBackpackData() async {
    final items = <BackpackItem>[];
    // 공개 테이블만 읽고 제거된 항목과 무게 미제공 항목은 계산에서 제외한다.
    for (final table in const [
      'consumables',
      'throwables',
      'attachments',
      'ammo',
      'weapons',
    ]) {
      final rows = await _client
          .from(table)
          .select('id, name, weight, can_be_in_backpack')
          .isFilter('removed_at', null)
          .order('name');
      for (final row in rows) {
        final weight = gameNumber(row['weight']);
        if (weight == null) continue;
        items.add(
          BackpackItem(
            id: '$table:${row['id']}',
            name: row['name'].toString(),
            category: table,
            weight: weight,
            canBeInBackpack: row['can_be_in_backpack'] != false,
          ),
        );
      }
    }
    final rows = await _client
        .from('vehicles')
        .select('id, name, trunk_capacity')
        .isFilter('removed_at', null)
        .order('name');
    final vehicles = <GameVehicle>[
      for (final row in rows)
        if (gameNumber(row['trunk_capacity']) != null)
          GameVehicle(
            id: row['id'].toString(),
            name: row['name'].toString(),
            capacity: gameNumber(row['trunk_capacity'])!,
          ),
    ];
    if (items.isEmpty) throw StateError('공개 아이템 무게 데이터가 없습니다.');
    return BackpackData(items: items, vehicles: vehicles);
  }
}
