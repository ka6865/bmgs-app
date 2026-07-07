import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/stats/widgets/radar_chart_widget.dart';

void main() {
  testWidgets('RadarChartWidget renders and draws canvas', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadarChartWidget(
            combat: 80,
            tactical: 70,
            survival: 90,
            teamwork: 60,
            grit: 85,
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(RadarChartWidget),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
