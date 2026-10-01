import 'package:bgms_mobile_app/features/tools/backpack_screen.dart';
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

  @override
  Future<BackpackData> fetchBackpackData() async => const BackpackData(
    items: [
      BackpackItem(
        id: 'heal',
        name: '회복',
        category: 'consumables',
        weight: 200,
      ),
      BackpackItem(
        id: 'weapon',
        name: '큰 무기',
        category: 'weapons',
        weight: 50,
        canBeInBackpack: false,
      ),
    ],
    vehicles: [GameVehicle(id: 'porter', name: '포터', capacity: 100)],
  );
}

void main() {
  testWidgets('무기 두 개를 선택해 기본 수치를 비교하고 미제공 값은 숨기지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '총기 A'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(CheckboxListTile, '총기 B'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(CheckboxListTile, '총기 B'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('선택한 무기 비교'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('선택한 무기 비교'), findsOneWidget);
    expect(find.text('기본 피해 45 · 탄속 - m/s'), findsOneWidget);
  });

  testWidgets('공개 데이터 조회 실패를 가짜 무기 목록으로 대신하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository(fail: true))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('공개 무기 데이터를 확인할 수 없습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('무기별 슬롯에서 부착물을 선택하면 DB 변화량을 비교한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WeaponsScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '총기 A'));
    await tester.pumpAndSettle();
    final muzzle = find.byKey(const ValueKey('a:muzzle'));
    await tester.ensureVisible(muzzle);
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

  testWidgets('수량·가방 용량 초과와 트렁크 전용 제한을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BackpackScreen(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    final add = find.byTooltip('회복 수량 늘리기');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('가방 400.0 / 320'), findsOneWidget);
    expect(find.text('용량을 초과했습니다. 수량을 줄이세요.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('큰 무기 수량 늘리기'));
    final weapon = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('큰 무기 수량 늘리기'),
        matching: find.byType(IconButton),
      ),
    );
    expect(weapon.onPressed, isNull);
  });
}
