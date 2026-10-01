import 'package:bgms_mobile_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 실기기/시뮬레이터에서 운영 API(bgms.kr)에 실제로 붙어 6개 탭을 순회한다.
///
/// 실행 예:
/// ```bash
/// flutter drive \
///   --driver test_driver/integration_test.dart \
///   --target integration_test/app_walkthrough_test.dart \
///   -d <deviceId>
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 네트워크 응답을 기다린다. `pumpAndSettle`은 무한 애니메이션에서 멈추지 않으므로
  /// 고정 시간 pump를 반복한다.
  Future<void> settle(WidgetTester tester, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> shoot(String name) async {
    await binding.takeScreenshot(name);
  }

  /// 스크롤 가능한 목록이 있을 때만 드래그한다.
  Future<void> scrollDown(WidgetTester tester, double distance) async {
    final list = find.byType(Scrollable);
    if (list.evaluate().isEmpty) return;
    await tester.drag(list.first, Offset(0, -distance));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await settle(tester, seconds: 3);
  }

  testWidgets('운영 API 기준 전체 탭 워크스루', (tester) async {
    await tester.pumpWidget(const BgmsApp());
    await settle(tester, seconds: 3);
    // Android는 테스트당 한 번 변환하며, iOS에서는 no-op이다.
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // 홈: 개인화 대시보드
    expect(find.text('PUBG 플레이어 검색'), findsOneWidget);
    expect(find.text('즐겨찾는 플레이어'), findsOneWidget);
    await shoot('01_home');

    // 전적: 분석 대상 선택 화면
    await openTab(tester, '전적');
    expect(find.text('전적 분석'), findsOneWidget);
    expect(find.byKey(const Key('player_search_submit')), findsOneWidget);
    await shoot('02_stats_hub');

    // 랭킹: 운영 /api/rankings 실데이터
    await openTab(tester, '랭킹');
    await settle(tester);
    expect(find.text('딜량'), findsOneWidget);
    await shoot('03_rankings');

    // 지도: 운영 타일 + 마커
    await openTab(tester, '지도');
    await settle(tester);
    expect(find.text('전술 지도'), findsOneWidget);
    await shoot('04_maps');

    await scrollDown(tester, 700);
    await settle(tester, seconds: 3);
    await shoot('05_maps_layers');

    // 게시판: 운영 커뮤니티 목록
    await openTab(tester, '게시판');
    await settle(tester);
    await shoot('06_board');

    // 마이: 로그인/저장 목록 상태
    await openTab(tester, '마이');
    await shoot('07_my');

    // 전적 결과: 홈에서 실제 닉네임을 검색한다.
    await openTab(tester, '홈');
    // Profile 모드에서도 유효한 입력 client ID를 사용한다. OS 키보드는 별도 QA 대상이다.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    await tester.enterText(find.byType(TextField).first, 'TGLTN');
    await settle(tester, seconds: 2);
    await tester.tap(find.byKey(const Key('player_search_submit')));
    await settle(tester, seconds: 15);

    expect(find.textContaining('TGLTN'), findsWidgets);
    await shoot('08_stats');

    await scrollDown(tester, 600);
    await settle(tester, seconds: 3);
    await shoot('09_stats_metrics');

    await scrollDown(tester, 900);
    await settle(tester, seconds: 3);
    await shoot('10_stats_matches');
  });
}
