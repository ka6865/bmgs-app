import 'package:bgms_mobile_app/features/meta/weapon_meta_screen.dart';
import 'package:bgms_mobile_app/features/meta/weapon_meta_trend.dart';
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

  test('일별 추세는 카테고리별 선과 패치 당일 전·후 점으로 나눈다', () {
    Map<String, Object> row(
      String date,
      String scope,
      String name,
      String category,
      int picks, {
      String? period,
    }) => {
      'date': date,
      'scope': scope,
      'weapon_name': name,
      'weapon_category': category,
      'weapon_pick_count': picks,
      'player_match_count': 100,
      'period': ?period,
    };
    final data = <String, dynamic>{
      'patchStartedAt': '2026-09-10T08:30:00+00:00',
      'dailyWeaponTrend': [
        row('2026-09-09', 'category', 'ALL', 'ALL', 99),
        row('2026-09-09', 'category', 'AR', 'AR', 60),
        row('2026-09-09', 'category', 'DMR', 'DMR', 30),
        row('2026-09-10', 'category', 'AR', 'AR', 55, period: 'pre'),
        row('2026-09-10', 'category', 'AR', 'AR', 70, period: 'post'),
        row('2026-09-10', 'weapon', 'M416', 'AR', 40, period: 'post'),
        {
          'date': '2026-09-11',
          'scope': 'category',
          'weapon_category': 'AR',
          'weapon_pick_count': 5,
          'player_match_count': 0,
        },
      ],
    };

    final all = metaTrendLines(data);
    expect(all.map((line) => line.name), ['AR', 'DMR']);
    expect(all.first.points.map((p) => p.label), [
      '09/09',
      '09/10 전',
      '09/10 후',
    ]);
    expect(all.first.points.last.share, 70);

    final ar = metaTrendLines(data, category: 'AR');
    expect(ar.single.points, hasLength(3));

    final m416 = metaTrendLines(data, category: 'AR', weapon: 'M416');
    expect(m416.single.name, 'M416');
    expect(m416.single.points.single.share, 40);
    expect(metaTrendLines({'dailyWeaponTrend': 'bad'}), isEmpty);
  });
}
