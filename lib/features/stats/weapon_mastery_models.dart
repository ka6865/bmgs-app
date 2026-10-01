class WeaponMasteryItem {
  const WeaponMasteryItem({
    required this.weaponId,
    required this.category,
    required this.level,
    required this.kills,
    required this.rankKills,
    required this.damage,
    required this.rankDamage,
  });

  final String weaponId;
  final String category;
  final int level;
  final int kills;
  final int rankKills;
  final double damage;
  final double rankDamage;

  int get totalKills => kills + rankKills;
  double get totalDamage => damage + rankDamage;
  String get label => weaponId
      .replaceFirst(RegExp(r'^Item_Weapon_', caseSensitive: false), '')
      .replaceFirst(RegExp(r'_C$', caseSensitive: false), '')
      .replaceAll('_', ' ');

  static WeaponMasteryItem fromJson(Map<String, dynamic> json) =>
      WeaponMasteryItem(
        weaponId: json['weaponId']?.toString() ?? '',
        category: json['category']?.toString() ?? '기타',
        level: _int(json['level']),
        kills: _int(json['kills']),
        rankKills: _int(json['rankKills']),
        damage: _double(json['damagePlayer']),
        rankDamage: _double(json['rankDamagePlayer']),
      );

  static List<WeaponMasteryItem> parseList(Object? raw) =>
      (raw as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                WeaponMasteryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.weaponId.isNotEmpty)
          .toList()
        ..sort((a, b) => b.totalKills.compareTo(a.totalKills));
}

int _int(Object? value) =>
    value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;
double _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
