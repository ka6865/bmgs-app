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
  String get label => pubgWeaponName(weaponId);

  /// PUBG 공식 에셋 저장소의 무기 그림. 웹 숙련도 화면과 같은 출처다.
  String get imageUrl =>
      'https://raw.githubusercontent.com/pubg/api-assets/master/Assets/Item/Weapon/Main/$weaponId.png';

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

/// PUBG 무기 클래스 이름(`Item_Weapon_HK416_C`, 텔레메트리의 `WeapHK416_C`)을 표시 이름으로 바꾼다.
String pubgWeaponName(String raw) {
  // 맨손 처치는 캐릭터 클래스(PlayerFemale_A_C 등)로 기록된다.
  if (raw.startsWith('Player')) return '주먹';
  final core = raw
      .replaceFirst(RegExp(r'^(Item_Weapon_|Weap)', caseSensitive: false), '')
      .replaceFirst(RegExp(r'_C$', caseSensitive: false), '');
  return _weaponNames['Item_Weapon_${core}_C'] ?? core.replaceAll('_', ' ');
}

// 웹 app/stats/[platform]/[nickname]/weapons/WeaponsClient.tsx WEAPON_NAME_MAP과 같은 표기.
const _weaponNames = {
  'Item_Weapon_HK416_C': 'M416',
  'Item_Weapon_ACE32_C': 'ACE32',
  'Item_Weapon_BerylM762_C': '베릴 M762',
  'Item_Weapon_AKM_C': 'AKM',
  'Item_Weapon_AK47_C': 'AKM',
  'Item_Weapon_SCAR_C': 'SCAR-L',
  'Item_Weapon_SCAR_L_C': 'SCAR-L',
  'Item_Weapon_SCAR-L_C': 'SCAR-L',
  'Item_Weapon_G36C_C': 'G36C',
  'Item_Weapon_FAMASG2_C': 'FAMAS',
  'Item_Weapon_K2_C': 'K2',
  'Item_Weapon_Mk47Mutant_C': 'Mk47 Mutant',
  'Item_Weapon_Mk12_C': 'Mk12',
  'Item_Weapon_Mini14_C': 'Mini-14',
  'Item_Weapon_Mk14_C': 'Mk14',
  'Item_Weapon_QBZ95_C': 'QBZ95',
  'Item_Weapon_QBU88_C': 'QBU',
  'Item_Weapon_Dragunov_C': '드라구노프',
  'Item_Weapon_AUG_C': 'AUG',
  'Item_Weapon_Groza_C': 'Groza',
  'Item_Weapon_M16A4_C': 'M16A4',
  'Item_Weapon_M249_C': 'M249',
  'Item_Weapon_DP28_C': 'DP-28',
  'Item_Weapon_MG3_C': 'MG3',
  'Item_Weapon_AWM_C': 'AWM',
  'Item_Weapon_Kar98k_C': 'Kar98k',
  'Item_Weapon_M24_C': 'M24',
  'Item_Weapon_L6_C': '링스 AMR',
  'Item_Weapon_Mosin_C': '모신나강',
  'Item_Weapon_Win1894_C': 'Win94',
  'Item_Weapon_SLR_C': 'SLR',
  'Item_Weapon_FNFal_C': 'SLR',
  'Item_Weapon_SKS_C': 'SKS',
  'Item_Weapon_VSS_C': 'VSS',
  'Item_Weapon_Vector_C': 'Vector',
  'Item_Weapon_UMP_C': 'UMP45',
  'Item_Weapon_UMP45_C': 'UMP45',
  'Item_Weapon_Bizon_C': 'PP-19 Bizon',
  'Item_Weapon_BizonPP19_C': 'PP-19 Bizon',
  'Item_Weapon_MP5K_C': 'MP5K',
  'Item_Weapon_MP9_C': 'MP9',
  'Item_Weapon_P90_C': 'P90',
  'Item_Weapon_Thompson_C': 'Tommy Gun',
  'Item_Weapon_UZI_C': 'Micro UZI',
  'Item_Weapon_Saiga12_C': 'S12K',
  'Item_Weapon_Shotgun_C': 'S12K',
  'Item_Weapon_Winchester_C': 'S1897',
  'Item_Weapon_Lynx_C': 'Lynx AMR',
  'Item_Weapon_DBS_C': 'DBS',
  'Item_Weapon_DP12_C': 'DBS',
  'Item_Weapon_O12_C': 'O12',
  'Item_Weapon_OriginS12_C': 'O12',
  'Item_Weapon_Berreta686_C': 'S686',
  'Item_Weapon_Sawnoff_C': '소드오프',
  'Item_Weapon_SawedOff_C': '소드오프',
  'Item_Weapon_M9_C': 'P92',
  'Item_Weapon_M1911_C': 'M1911',
  'Item_Weapon_NagantM1895_C': 'R1895',
  'Item_Weapon_DesertEagle_C': '데저트 이글',
  'Item_Weapon_Grenade_C': '수류탄',
  'Item_Weapon_Molotov_C': '화염병',
  'Item_Weapon_SmokeBomb_C': '연막탄',
  'Item_Weapon_FlashBang_C': '섬광탄',
  'Item_Weapon_C4_C': 'C4',
  'Item_Weapon_BluezoneGrenade_C': '블루존 수류탄',
  'Item_Weapon_SpikeStrip_C': '접이식 스파이크',
  'Item_Weapon_DecoyGrenade_C': '디코이 수류탄',
  'Item_Weapon_Mortar_C': '박격포',
  'Item_Weapon_PanzerFaust_C': '판저파우스트',
  'Item_Weapon_M79_C': 'M79',
  'Item_Weapon_Pan_C': '프라이팬',
  'Item_Weapon_Sickle_C': '낫',
  'Item_Weapon_Machete_C': '마체테',
  'Item_Weapon_Crowbar_C': '빠루',
};
