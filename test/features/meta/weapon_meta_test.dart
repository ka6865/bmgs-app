import 'package:bgms_mobile_app/features/meta/weapon_meta_screen.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  testWidgets('잘못된 목록 응답은 화면을 깨뜨리지 않는다', (tester) async {
    final adapter = FakeHttpAdapter(
      responses: {
        '/api/pubg/meta': {'weapons': 'invalid', 'patches': {}},
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WeaponMetaScreen(
          client: BgmsApiClient(
            baseUrl: 'https://example.test',
            dio: createFakeDio(adapter),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('표시할 총기 표본이 없습니다.'), findsOneWidget);
  });
  test('표본이 없는 수치와 부족한 연속 명중 표본을 실제 0으로 표시하지 않는다', () {
    expect(metaMetric({'match_count': 0, 'avg_damage': 0}, 'avg_damage'), '-');
    expect(
      metaMetric({
        'match_count': 100,
        'sustained_hits': 0,
        'burst_available': false,
      }, 'sustained_hits'),
      '표본 부족',
    );
    expect(
      metaMetric({
        'match_count': 100,
        'active_pick_count': 0,
        'avg_damage': 0,
      }, 'avg_damage'),
      '-',
    );
    expect(
      metaMetric({'match_count': 100, 'pick_share': 0}, 'pick_share'),
      '0.0%',
    );
  });
}
