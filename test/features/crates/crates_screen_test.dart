import 'package:bgms_mobile_app/features/crates/crate_models.dart';
import 'package:bgms_mobile_app/features/crates/crates_repository.dart';
import 'package:bgms_mobile_app/features/crates/crates_screen.dart';
import 'package:bgms_mobile_app/features/crates/widgets/crate_reveal_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CrateTemplate _template() {
  return const CrateTemplate(
    id: 'tpl-1',
    name: '코스믹 칼리버',
    priceGcoin: 200,
    bundlePriceGcoin: 1800,
    items: [
      CrateItem(
        id: 'a',
        name: '레전더리 스킨',
        rarity: CrateRarity.legendary,
        probability: 0.01,
        imageUrl: null,
      ),
      CrateItem(
        id: 'b',
        name: '일반 아이템',
        rarity: CrateRarity.common,
        probability: 0.99,
        imageUrl: null,
        tokenCount: 5,
      ),
    ],
  );
}

class _FakeCratesRepository extends Fake implements CratesRepository {
  @override
  Future<List<CrateTemplate>> fetchActiveCrates() {
    return SynchronousFuture([_template()]);
  }
}

class _FailingCratesRepository extends Fake implements CratesRepository {
  @override
  Future<List<CrateTemplate>> fetchActiveCrates() {
    throw const CratesException('진행 중인 상자가 없습니다.');
  }
}

// 희귀 아이템의 glow는 반복되므로 애니메이션 정지를 기다리지 않는다.
Future<void> _pumpReveals(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('상자와 확률 표를 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CratesScreen(repository: _FakeCratesRepository())),
    );
    await _pumpReveals(tester);

    expect(find.text('상자깡 시뮬'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '코스믹 칼리버'), findsOneWidget);

    // 가격이 버튼에 드러난다.
    expect(find.text('1회 · 200G'), findsOneWidget);
    expect(find.text('10연차 · 1800G'), findsOneWidget);

    // 공식 확률을 함께 노출한다.
    expect(find.text('공식 확률'), findsOneWidget);
    expect(find.text('1.00%'), findsOneWidget);
    expect(find.text('99.00%'), findsOneWidget);
  });

  testWidgets('10연차를 뽑으면 결과 10장과 누적이 갱신된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CratesScreen(repository: _FakeCratesRepository())),
    );
    await _pumpReveals(tester);

    await tester.tap(find.text('10연차 · 1800G'));
    await _pumpReveals(tester);

    expect(find.text('결과'), findsOneWidget);
    expect(find.byType(CrateRevealCard), findsNWidgets(10));
    // 누적 패널은 결과 아래에 있어 스크롤로 노출한다.
    await tester.scrollUntilVisible(
      find.text('누적'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpReveals(tester);
    // 묶음 가격이 누적에 반영된다.
    expect(find.text('1800'), findsOneWidget);
  });

  testWidgets('단발을 뽑으면 단가가 누적된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CratesScreen(repository: _FakeCratesRepository())),
    );
    await _pumpReveals(tester);

    await tester.tap(find.text('1회 · 200G'));
    await _pumpReveals(tester);

    await tester.scrollUntilVisible(
      find.text('누적'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpReveals(tester);
    expect(find.text('200'), findsWidgets);
    expect(find.text('초기화'), findsOneWidget);
  });

  testWidgets('누적을 초기화하면 결과가 사라진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CratesScreen(repository: _FakeCratesRepository())),
    );
    await _pumpReveals(tester);

    await tester.tap(find.text('1회 · 200G'));
    await _pumpReveals(tester);
    await tester.scrollUntilVisible(
      find.text('초기화'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpReveals(tester);
    await tester.tap(find.text('초기화'));
    await _pumpReveals(tester);

    expect(find.text('결과'), findsNothing);
    expect(find.text('초기화'), findsNothing);
  });

  testWidgets('조회 실패 시 재시도를 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CratesScreen(repository: _FailingCratesRepository())),
    );
    await _pumpReveals(tester);

    expect(find.text('상자 정보를 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
