import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/theme/bgms_theme.dart';
import 'package:bgms_mobile_app/core/widgets/bgms_card.dart';

void main() {
  group('BgmsCard Tests', () {
    testWidgets('자식 위젯을 정상적으로 렌더링한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: const Scaffold(body: BgmsCard(child: Text('카드 콘텐츠'))),
        ),
      );

      expect(find.text('카드 콘텐츠'), findsOneWidget);
    });

    testWidgets('statusColor 지정 시 좌측 상태 인디케이터가 적용된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: const Scaffold(
            body: BgmsCard(
              statusColor: BgmsColors.accent,
              child: Text('치킨 달성'),
            ),
          ),
        ),
      );

      expect(find.text('치킨 달성'), findsOneWidget);
    });

    testWidgets('onTap 지정 시 탭 이벤트를 처리한다', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BgmsTheme.dark(),
          home: Scaffold(
            body: BgmsCard(
              onTap: () => tapped = true,
              child: const Text('탭 가능한 카드'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('탭 가능한 카드'));
      expect(tapped, isTrue);
    });
  });
}
