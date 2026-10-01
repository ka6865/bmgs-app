import 'package:bgms_mobile_app/features/maps/maps_repository.dart';
import 'package:bgms_mobile_app/features/maps/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = MapsRepository();

  test('맵 별칭을 한국어로 표시하고 미지원 이름은 보존한다', () {
    for (final entry in const {
      ' Baltic_Main ': '에란겔',
      'Desert_Main': '미라마',
      'TIGER_MAIN': '태이고',
      'Neon_Main': '론도',
      'DihorOtok_Main': '비켄디',
      'Kiki_Main': '데스턴',
      'Erangel': '에란겔',
      '미라마': '미라마',
      'Savage_Main': '사녹',
      'Sanhok': '사녹',
      '사녹': '사녹',
      'Summerland_Main': '카라킨',
      'Karakin': '카라킨',
      '카라킨': '카라킨',
      'Chimera_Main': '파라모',
      'Paramo': '파라모',
      '파라모': '파라모',
      'Heaven_Main': '헤이븐',
      'Haven': '헤이븐',
      '헤이븐': '헤이븐',
      'Range_Main': '훈련장',
      'Range': '훈련장',
      'Training': '훈련장',
      '훈련장': '훈련장',
      'PillarCompound_Main': '필라 기지 (TDM)',
      'PillarCompound': '필라 기지 (TDM)',
      '필라 기지 (TDM)': '필라 기지 (TDM)',
      'Italy_TDM_Main': '리틀 이탈리아 (TDM)',
      'Italy': '리틀 이탈리아 (TDM)',
      '리틀 이탈리아 (TDM)': '리틀 이탈리아 (TDM)',
      'Unknown_Main': 'Unknown_Main',
    }.entries) {
      expect(bgmsMapDisplayName(entry.key), entry.value);
    }
    expect(bgmsMapDisplayName(null), '맵 정보 없음');
    expect(repository.availableMaps, same(bgmsMapCatalog));
    expect(bgmsMapCatalog, hasLength(6));
    expect(normalizeBgmsMapId('Savage_Main'), 'savage_main');
    expect(repository.resolveMap('Desert_Main').id, 'Miramar');
  });

  test('DB 설정이 없거나 맵 설정이 없으면 레이어를 노출하지 않는다', () {
    expect(
      repository.filterActiveLayers('Erangel', ['Garage', 'Boat'], {}),
      isEmpty,
    );
    expect(
      repository.filterActiveLayers(
        'Deston',
        ['Garage'],
        {
          'Erangel': ['Garage'],
        },
      ),
      isEmpty,
    );
    expect(
      repository.filterActiveLayers('Erangel', ['Garage'], {'Erangel': []}),
      isEmpty,
    );
  });

  test('DB의 허용 목록만 대소문자 구분 없이 노출한다', () {
    expect(
      repository.filterActiveLayers(
        'erangel',
        ['Garage', 'Boat', 'Glider'],
        {
          'Erangel': [' garage ', 'Glider'],
        },
      ),
      ['Garage', 'Glider'],
    );
  });
}
