import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import 'crate_models.dart';

/// 상자 데이터 조회 실패를 알리는 예외.
class CratesException implements Exception {
  const CratesException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 활성 상자 템플릿과 아이템을 Supabase에서 읽는다.
///
/// 웹 `getActiveCrates`와 같은 테이블을 anon 키로 조회한다.
class CratesRepository {
  const CratesRepository();

  Future<List<CrateTemplate>> fetchActiveCrates() async {
    try {
      if (!AppConfig.local.canInitializeSupabase) {
        throw const CratesException('상자 데이터를 불러올 설정이 없습니다.');
      }

      final response = await Supabase.instance.client
          .from('crate_templates')
          .select(
            'id, name, description, image_url, price_gcoin, '
            'bundle_price_gcoin, '
            'crate_item_relations(id, probability, token_count, '
            'is_prime_parcel, crate_item_assets(id, display_name, rarity, '
            'image_url))',
          )
          .eq('active', true)
          .order('created_at', ascending: false);

      final templates = <CrateTemplate>[];
      for (final row in response) {
        final template = CrateTemplate.tryParse(Map<String, dynamic>.from(row));
        if (template != null) templates.add(template);
      }

      if (templates.isEmpty) {
        throw const CratesException('진행 중인 상자가 없습니다.');
      }
      return templates;
    } on CratesException {
      rethrow;
    } catch (error) {
      throw CratesException('상자 데이터를 불러오지 못했습니다. ($error)');
    }
  }
}
