import 'package:bgms_mobile_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = AppConfig(
  apiBaseUrl: 'https://bgms.kr/',
  authRedirectUrl: '',
);

void main() {
  test('후행 슬래시를 제거한 기준 URL을 만든다', () {
    expect(_config.normalizedBaseUrl, 'https://bgms.kr');
    expect(_config.termsUrl, 'https://bgms.kr/terms');
    expect(_config.privacyUrl, 'https://bgms.kr/privacy');
  });

  test('authRedirectUrl이 비면 기본 딥링크로 대체한다', () {
    expect(_config.resolvedAuthRedirectUrl, AppConfig.defaultAuthRedirectUrl);
  });

  group('tierIconUrl', () {
    test('티어와 서브티어를 조합한다', () {
      expect(
        _config.tierIconUrl('Platinum', 3),
        'https://bgms.kr/assets/rank/Platinum-3.webp',
      );
      expect(
        _config.tierIconUrl('platinum', '3'),
        'https://bgms.kr/assets/rank/Platinum-3.webp',
      );
    });

    test('Master와 Survivor는 서브티어가 없다', () {
      expect(
        _config.tierIconUrl('Master', 1),
        'https://bgms.kr/assets/rank/Master.webp',
      );
      expect(
        _config.tierIconUrl('Survivor', null),
        'https://bgms.kr/assets/rank/Survivor.webp',
      );
    });

    test('서브티어가 범위를 벗어나면 1로 보정한다', () {
      expect(
        _config.tierIconUrl('Gold', 9),
        'https://bgms.kr/assets/rank/Gold-1.webp',
      );
    });

    test('티어가 없거나 일반전이면 Unranked를 쓴다', () {
      const unranked = 'https://bgms.kr/assets/rank/Unranked.webp';
      expect(_config.tierIconUrl(null, null), unranked);
      expect(_config.tierIconUrl('', null), unranked);
      expect(_config.tierIconUrl('일반전', null), unranked);
      expect(_config.tierIconUrl('Unranked', null), unranked);
    });
  });

  group('mapTileUrl', () {
    test('행 좌표를 음수로 변환한다', () {
      expect(
        _config.mapTileUrl(mapId: 'Erangel', zoom: 3, column: 0, row: 0),
        'https://bgms.kr/tiles/Erangel/3/0/-8.jpg',
      );
    });

    test('최하단 행은 -1이 된다', () {
      expect(
        _config.mapTileUrl(mapId: 'Erangel', zoom: 2, column: 3, row: 3),
        'https://bgms.kr/tiles/Erangel/2/3/-1.jpg',
      );
    });

    test('줌 레벨에 따라 타일 수가 2의 거듭제곱으로 늘어난다', () {
      expect(
        _config.mapTileUrl(mapId: 'Miramar', zoom: 4, column: 1, row: 0),
        'https://bgms.kr/tiles/Miramar/4/1/-16.jpg',
      );
    });
  });
}
