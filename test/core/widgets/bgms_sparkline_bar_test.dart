import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/theme/bgms_theme.dart';
import 'package:bgms_mobile_app/core/widgets/bgms_sparkline_bar.dart';

void main() {
  group('BgmsSparklineBar Tests', () {
    testWidgets('20개 이하의 순위 데이터를 바 형태로 렌더링한다', (tester) async {
      final sampleRanks = [1, 3, 10, 25, 50, 1, 5, null];

      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: Scaffold(body: BgmsSparklineBar(ranks: sampleRanks)),
        ),
      );

      expect(find.byType(BgmsSparklineBar), findsOneWidget);
    });

    testWidgets('빈 순위 목록일 때도 크래시 없이 렌더링된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: const Scaffold(body: BgmsSparklineBar(ranks: [])),
        ),
      );

      expect(find.byType(BgmsSparklineBar), findsOneWidget);
    });
  });
}
