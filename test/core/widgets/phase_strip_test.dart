import 'package:bgms_mobile_app/core/theme/bgms_theme.dart';
import 'package:bgms_mobile_app/core/widgets/phase_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Color?>> _cellColors(WidgetTester tester, PhaseStrip strip) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(child: SizedBox(width: 180, child: strip)),
    ),
  );
  final boxes = find.descendant(
    of: find.byType(PhaseStrip),
    matching: find.byType(DecoratedBox),
  );
  expect(tester.getSize(boxes.first).height, strip.height);
  return tester
      .widgetList<DecoratedBox>(boxes)
      .map((box) => (box.decoration as BoxDecoration).color)
      .toList();
}

void main() {
  testWidgets('사망 페이즈까지만 채운다', (tester) async {
    final colors = await _cellColors(
      tester,
      const PhaseStrip(deathPhase: 4, rank: 13),
    );
    expect(colors.where((c) => c == BgmsColors.defeat), hasLength(4));
    expect(find.bySemanticsLabel('자기장 4페이즈에서 탈락'), findsOneWidget);
  });

  testWidgets('치킨은 모든 칸을 골드로 채운다', (tester) async {
    final colors = await _cellColors(
      tester,
      const PhaseStrip(deathPhase: 3, rank: 1),
    );
    expect(colors.every((c) => c == BgmsColors.accent), isTrue);
  });

  testWidgets('페이즈 정보가 없으면 채우지 않고 없음으로 읽는다', (tester) async {
    final colors = await _cellColors(
      tester,
      const PhaseStrip(deathPhase: null, rank: 20),
    );
    expect(colors.every((c) => c == Colors.transparent), isTrue);
    expect(find.bySemanticsLabel('페이즈 정보 없음'), findsOneWidget);
  });
}
