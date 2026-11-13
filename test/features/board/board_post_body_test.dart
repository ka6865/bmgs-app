import 'package:bgms_mobile_app/features/board/board_post_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HTML 본문은 목록 구조를 살리고 이미지는 본문에서 빼고 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardPostBody(
            html:
                '<div class="bg-[#F2A900]/10"><h3>핵심 요약</h3></div>'
                '<ul><li class="list-none"><span class="absolute">✓</span>'
                '<strong class="text-[#F2A900]">LMG</strong> 메타 종료</li>'
                '<li class="list-none">탈것 체력 상향</li></ul>'
                '<img src="https://example.com/a.png">',
            text: '핵심 요약 LMG 메타 종료 탈것 체력 상향',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('핵심 요약', findRichText: true), findsOneWidget);
    expect(find.textContaining('메타 종료', findRichText: true), findsOneWidget);
    expect(find.textContaining('탈것 체력 상향', findRichText: true), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('HTML을 못 받으면 서버 텍스트 본문을 보여준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BoardPostBody(html: null, text: '본문')),
      ),
    );
    expect(find.text('본문'), findsOneWidget);
  });
}
