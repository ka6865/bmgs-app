import 'package:bgms_mobile_app/features/tools/game_data.dart';
import 'package:bgms_mobile_app/features/tools/weapons_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends GameDataRepository {
  _Repository({this.fail = false});
  final bool fail;
  @override
  Future<List<GameAttachment>> fetchAttachments() async => const [
    GameAttachment(
      id: 'muzzle',
      name: '보정기',
      slot: 'muzzle',
      verticalRecoil: -20,
      horizontalRecoil: -10,
      adsSpeed: 5,
    ),
  ];
  @override
  Future<List<GameWeapon>> fetchWeapons() async {
    if (fail) throw StateError('permission denied');
    return const [
      GameWeapon(
        id: 'a',
        name: '총기 A',
        type: 'AR',
        damage: 40,
        bulletSpeed: 800,
      ),
      GameWeapon(id: 'b', name: '총기 B', type: 'AR', damage: 45),
    ];
  }
}

void main() {
  testWidgets('무기 두 개를 골라 수치를 나란히 비교하고 미제공 값은 -로 둔다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('총기 A 비교에 추가'));
    await tester.pumpAndSettle();
    expect(find.text('비교할 무기를 하나 더 고르세요.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('총기 B 비교에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('총기 B 비교에 추가'));
    await tester.pumpAndSettle();

    expect(find.text('선택한 무기 비교'), findsOneWidget);
    // 총기 B는 탄속이 없으므로 비교표에 -로 남는다.
    expect(find.text('-'), findsWidgets);
    expect(find.text('45'), findsWidgets);
    // 두 개를 고른 뒤에는 다른 무기를 더 담지 못한다.
    await tester.ensureVisible(find.byTooltip('총기 A 비교에서 빼기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('총기 A 비교에서 빼기').first);
    await tester.pumpAndSettle();
    expect(find.text('비교할 무기를 하나 더 고르세요.'), findsOneWidget);
  });

  testWidgets('분류 칩으로 무기를 좁힌다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'SMG'));
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 무기가 없습니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'AR'));
    await tester.pumpAndSettle();
    expect(find.text('총기 A'), findsOneWidget);
  });

  testWidgets('공개 데이터 조회 실패를 가짜 무기 목록으로 대신하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository(fail: true))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('공개 무기 데이터를 확인할 수 없습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('총기 A'), findsNothing);
  });

  testWidgets('상세 시트에서 부착물을 선택하면 DB 변화량을 계산한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('총기 A'));
    await tester.pumpAndSettle();
    final muzzle = find.byKey(const ValueKey('a:muzzle'));
    await tester.scrollUntilVisible(
      muzzle,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(muzzle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('보정기').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('수직 반동 80% · 수평 반동 90% · 장전 시간 100%'),
      findsOneWidget,
    );
    expect(find.text('보정기 · 조준 속도 변화 +5%'), findsOneWidget);
  });
}
