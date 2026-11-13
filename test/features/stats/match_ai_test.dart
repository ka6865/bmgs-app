import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/features/stats/match_ai_models.dart';
import 'package:bgms_mobile_app/features/stats/match_ai_repository.dart';
import 'package:bgms_mobile_app/features/stats/match_detail_models.dart';
import 'package:bgms_mobile_app/features/stats/widgets/match_team_and_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AiRepository extends MatchAiRepository {
  _AiRepository(this.answer);
  final Future<MatchAiResult> Function(bool spicy) answer;
  final styles = <bool>[];

  @override
  Future<MatchAiResult> analyze({
    required String matchId,
    required String nickname,
    required String platform,
    required bool spicy,
  }) {
    styles.add(spicy);
    return answer(spicy);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('NDJSON 청크를 이어 JSON 카드 필드로 읽고 실패 신호는 오류로 올린다', () {
    final result = MatchAiResult.fromNdjson(
      '{"type":"chunk","data":"```json\\n{\\"coach\\":\\"SPICY\\",\\"signature\\":\\"돌격대장\\","}\n'
      '{"type":"chunk","data":"\\"briefFeedback\\":[\\"첫째\\",\\"둘째\\"],\\"finalVerdict\\":\\"엄폐하세요\\",'
      '\\"actionItems\\":[{\\"icon\\":\\"🎯\\",\\"title\\":\\"사선 확보\\",\\"desc\\":\\"설명\\"}]}\\n```"}\n'
      '{"type":"done","valid":true}\n',
    );
    expect(result.coach, 'SPICY');
    expect(result.signature, '돌격대장');
    expect(result.feedback, ['첫째', '둘째']);
    expect(result.verdict, '엄폐하세요');
    expect(result.actions.single.title, '사선 확보');
    expect(result.markdown, isNull);

    final text = MatchAiResult.fromNdjson(
      '{"type":"chunk","data":"## 요약\\n좋았어요"}\n',
    );
    expect(text.markdown, contains('좋았어요'));

    expect(
      () => MatchAiResult.fromNdjson('{"type":"error","error":"한도 초과"}\n'),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'message', '한도 초과'),
      ),
    );
    expect(
      () => MatchAiResult.fromNdjson('{"type":"done","valid":true}\n'),
      throwsA(isA<FormatException>()),
    );
  });

  test('팀원 기록은 없는 값을 0으로 꾸미지 않는다', () {
    final member = MatchTeamMember.fromJson({
      'name': 'Mate',
      'kills': 2,
      'damageDealt': 183.9,
      'DBNOs': null,
    });
    expect(member.kills, 2);
    expect(member.damage, 183.9);
    expect(member.knocks, isNull);
  });

  testWidgets('팀원 성적은 내 이름만 강조하고 값이 없으면 -로 둔다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MatchTeamCard(
          nickname: 'me',
          team: [
            MatchTeamMember(
              name: 'Me',
              kills: 3,
              assists: 1,
              knocks: 2,
              damage: 412,
            ),
            MatchTeamMember(name: 'Mate', kills: 0),
          ],
        ),
      ),
    );
    expect(find.text('팀원 성적'), findsOneWidget);
    expect(find.text('나'), findsNothing);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(3));
  });

  testWidgets('AI 분석은 누를 때만 요청하고 고른 맛과 결과를 보여준다', (tester) async {
    final repository = _AiRepository(
      (_) async => const MatchAiResult(
        signature: '돌격대장',
        feedback: ['교전 각이 좋았습니다'],
        verdict: '엄폐하세요',
      ),
    );
    await tester.pumpWidget(
      _wrap(
        MatchAiSection(
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          repository: repository,
        ),
      ),
    );
    expect(repository.styles, isEmpty);
    await tester.tap(find.text('순한맛'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 분석 받기'));
    await tester.pumpAndSettle();
    expect(repository.styles, [false]);
    expect(find.text('돌격대장'), findsOneWidget);
    expect(find.text('엄폐하세요'), findsOneWidget);
    expect(find.text('다시 분석'), findsOneWidget);
  });

  testWidgets('로그인이 없으면 로그인 안내를, 분석 준비 전이면 다시 시도를 안내한다', (tester) async {
    var error = const ApiException(
      kind: ApiErrorKind.unauthorized,
      message: 'AI 분석은 로그인 후 이용할 수 있습니다.',
    );
    final repository = _AiRepository((_) => Future.error(error));
    await tester.pumpWidget(
      _wrap(
        MatchAiSection(
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          repository: repository,
        ),
      ),
    );
    await tester.tap(find.text('AI 분석 받기'));
    await tester.pumpAndSettle();
    expect(find.text('로그인하러 가기'), findsOneWidget);

    error = const ApiException(
      kind: ApiErrorKind.unknown,
      message: 'canonical match analysis is not ready',
      statusCode: 409,
    );
    await tester.pumpWidget(
      _wrap(
        MatchAiSection(
          key: const ValueKey('again'),
          matchId: 'm',
          nickname: 'Me',
          platform: 'steam',
          repository: repository,
        ),
      ),
    );
    await tester.tap(find.text('AI 분석 받기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 준비되지 않았습니다'), findsOneWidget);
    expect(find.text('다시 분석'), findsOneWidget);
  });
}
