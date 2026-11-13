import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/features/squad/squad_models.dart';
import 'package:bgms_mobile_app/features/squad/squad_repository.dart';
import 'package:bgms_mobile_app/features/squad/squad_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSquadRepository extends SquadRepository {
  _FakeSquadRepository({this.loggedIn = true, this.grade = 'B-'});

  final bool loggedIn;
  final String? grade;
  final aiStyles = <bool>[];

  @override
  Future<List<SquadGroup>> fetchGroups({
    required String nickname,
    required String platform,
  }) async => const [
    SquadGroup(
      groupKey: 'g1',
      teamMode: 'duo',
      matchCount: 10,
      members: ['팀원A'],
    ),
  ];

  @override
  Future<SquadAnalysis> fetchAnalysis({
    required String nickname,
    required String platform,
    required String groupKey,
  }) async => SquadAnalysis(
    groupKey: groupKey,
    matchCount: 10,
    grade: grade,
    windowDays: 14,
    scores: const {
      'survivalCare': 52,
      'backupSpeed': 72,
      'smokeRescue': null,
      'damageBalance': 80,
      'placement': 14,
    },
    roles: const [
      SquadRole(
        name: '나',
        role: '해결사',
        roleDescription: '교전을 마무리합니다.',
        avgDamage: 181,
        avgKills: 1.4,
        damageShare: 55,
        killShare: 67,
      ),
    ],
    scenes: const [
      SquadScene(
        title: '팀 전원 치명 이벤트',
        reason: '짧은 시간 안에 전원이 기절했습니다.',
        mapName: '미라마',
        displayTime: '1:40',
        isDanger: true,
      ),
    ],
  );

  @override
  Future<SquadAiResult> fetchAi({
    required String nickname,
    required String platform,
    required String groupKey,
    required bool spicy,
  }) async {
    aiStyles.add(spicy);
    if (!loggedIn) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: '로그인이 필요합니다.',
      );
    }
    return const SquadAiResult(
      summary: '백업은 빠르지만 순위가 낮습니다.',
      strength: '백업 속도가 빠릅니다.',
      weakness: '',
      coaching: '마지막 원 진입을 서두르세요.',
      overall: '다음 판도 같이 갑시다.',
      members: [
        SquadMemberFeedback(
          name: '나',
          praise: '딜 비중이 높습니다.',
          fault: '',
          advice: '',
        ),
      ],
    );
  }
}

Future<void> _pump(WidgetTester tester, SquadRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SquadScreen(
        nickname: '나',
        platform: 'steam',
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _runAi(WidgetTester tester) async {
  final button = find.text('AI 코칭 받기');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('팀 묶음을 고르면 등급·축 점수·역할·장면을 보여주고 측정 없는 축은 -로 둔다', (tester) async {
    await _pump(tester, _FakeSquadRepository());

    expect(find.text('듀오 · 팀원A · 10경기'), findsOneWidget);
    expect(find.text('B-'), findsOneWidget);
    expect(find.text('분석 10경기 · 최근 14일'), findsOneWidget);
    // 측정하지 못한 연막 구출 축은 0점이 아니라 -로 둔다.
    expect(find.text('연막 구출'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('해결사'), findsOneWidget);
    expect(find.text('팀 전원 치명 이벤트'), findsOneWidget);
  });

  testWidgets('등급이 보류되면 보류 이유를 보여준다', (tester) async {
    await _pump(tester, _FakeSquadRepository(grade: null));

    expect(find.text('보류'), findsOneWidget);
    expect(find.text('측정한 지표가 부족해 등급을 매기지 않았습니다.'), findsOneWidget);
  });

  testWidgets('AI 코칭은 버튼을 눌러야 부르고 빈 칸은 숨긴다', (tester) async {
    final repository = _FakeSquadRepository();
    await _pump(tester, repository);
    expect(repository.aiStyles, isEmpty);

    await _runAi(tester);

    expect(repository.aiStyles, [true]);
    expect(find.text('백업 속도가 빠릅니다.'), findsOneWidget);
    expect(find.text('아쉬운 점'), findsNothing);
    expect(find.text('못한 점'), findsNothing);
    expect(find.text('다음 판도 같이 갑시다.'), findsOneWidget);
  });

  testWidgets('로그인하지 않았으면 로그인 안내를 보여준다', (tester) async {
    await _pump(tester, _FakeSquadRepository(loggedIn: false));

    await _runAi(tester);

    expect(find.text('로그인이 필요합니다'), findsOneWidget);
    expect(find.text('로그인하러 가기'), findsOneWidget);
  });
}
