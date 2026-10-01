/// 상자 아이템 등급. 웹 `CrateRarity`와 같은 집합이다.
enum CrateRarity {
  ultimate,
  legendary,
  epic,
  elite,
  rare,
  special,
  common;

  /// 서버가 주는 대문자 문자열을 열거형으로 옮긴다.
  static CrateRarity parse(String? raw) {
    return switch ((raw ?? '').toUpperCase()) {
      'ULTIMATE' => CrateRarity.ultimate,
      'LEGENDARY' => CrateRarity.legendary,
      'EPIC' => CrateRarity.epic,
      'ELITE' => CrateRarity.elite,
      'RARE' => CrateRarity.rare,
      'SPECIAL' => CrateRarity.special,
      _ => CrateRarity.common,
    };
  }

  String get label => switch (this) {
    CrateRarity.ultimate => '얼티밋',
    CrateRarity.legendary => '레전더리',
    CrateRarity.epic => '에픽',
    CrateRarity.elite => '엘리트',
    CrateRarity.rare => '레어',
    CrateRarity.special => '스페셜',
    CrateRarity.common => '일반',
  };

  /// 특별 연출을 넣을 상위 등급 여부.
  bool get isHighlight =>
      this == CrateRarity.ultimate || this == CrateRarity.legendary;
}

enum CrateDropType { base, prime, bonus }

/// 상자에서 나올 수 있는 아이템 하나.
class CrateItem {
  const CrateItem({
    required this.id,
    required this.name,
    required this.rarity,
    required this.probability,
    required this.imageUrl,
    this.isPrimeParcel = false,
    this.tokenCount = 0,
    this.dropType = CrateDropType.base,
  });

  final String id;
  final String name;
  final CrateRarity rarity;

  /// 0.0 ~ 1.0 범위의 획득 확률.
  final double probability;
  final String? imageUrl;

  /// 당첨 후 별도로 개봉하는 프라임 소포 자체인지.
  final bool isPrimeParcel;
  final CrateDropType dropType;

  /// 중복 획득 시 지급되는 토큰 수.
  final int tokenCount;

  static CrateItem? tryParse(Map<String, dynamic> json) {
    final dropType = switch (json['drop_type']) {
      'base' => CrateDropType.base,
      'prime' => CrateDropType.prime,
      'bonus' => CrateDropType.bonus,
      _ => null,
    };
    if (dropType == null) return null;
    final asset = json['crate_item_assets'];
    if (asset is! Map) return null;

    final name = (asset['display_name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    final probability = _toDouble(json['probability']);
    if (!probability.isFinite || probability <= 0 || probability > 1) {
      return null;
    }

    return CrateItem(
      id: (json['id'] ?? asset['id'] ?? name).toString(),
      name: name,
      rarity: CrateRarity.parse(asset['rarity']?.toString()),
      probability: probability,
      imageUrl: (asset['image_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : asset['image_url'] as String,
      isPrimeParcel: json['is_prime_parcel'] == true,
      tokenCount: _toInt(json['token_count']),
      dropType: dropType,
    );
  }
}

/// 상자 템플릿. 가격 정책과 아이템 목록을 담는다.
class CrateTemplate {
  const CrateTemplate({
    required this.id,
    required this.name,
    required this.items,
    this.description,
    this.imageUrl,
    this.priceGcoin,
    this.bundlePriceGcoin,
  });

  final String id;
  final String name;
  final List<CrateItem> items;
  final String? description;
  final String? imageUrl;

  /// 단발 가격(G코인).
  final int? priceGcoin;

  /// 10연차 묶음 가격(G코인).
  final int? bundlePriceGcoin;

  /// 기본 당첨 그룹. 프라임 소포 자체도 기본 풀에 포함한다.
  List<CrateItem> get baseItems => items
      .where((item) => item.dropType == CrateDropType.base)
      .toList(growable: false);

  List<CrateItem> get primeItems => items
      .where((item) => item.dropType == CrateDropType.prime)
      .toList(growable: false);

  List<CrateItem> get bonusItems => items
      .where((item) => item.dropType == CrateDropType.bonus)
      .toList(growable: false);

  static CrateTemplate? tryParse(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    final rawRelations = json['crate_item_relations'];
    final items = <CrateItem>[];
    if (rawRelations is List) {
      for (final relation in rawRelations) {
        if (relation is! Map) continue;
        final item = CrateItem.tryParse(Map<String, dynamic>.from(relation));
        if (item != null) items.add(item);
      }
    }
    if (items.isEmpty) return null;

    return CrateTemplate(
      id: (json['id'] ?? name).toString(),
      name: name,
      items: items,
      description: (json['description'] as String?)?.trim(),
      imageUrl: (json['image_url'] as String?)?.trim(),
      priceGcoin: _toNullableInt(json['price_gcoin']),
      bundlePriceGcoin: _toNullableInt(json['bundle_price_gcoin']),
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(Object? value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(Object? value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
