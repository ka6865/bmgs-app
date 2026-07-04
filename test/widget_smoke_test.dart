import 'package:bgms_mobile_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BGMS app renders home tab with search controls', (tester) async {
    await tester.pumpWidget(const BgmsApp());

    expect(find.text('BGMS'), findsWidgets);
    expect(find.text('닉네임 검색'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);
    expect(find.text('steam'), findsOneWidget);
    expect(find.text('kakao'), findsOneWidget);
  });
}
