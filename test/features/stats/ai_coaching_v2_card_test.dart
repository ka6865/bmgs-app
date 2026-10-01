import 'package:bgms_mobile_app/features/stats/ai_coaching_card.dart';
import 'package:bgms_mobile_app/features/stats/ai_coaching_models.dart';
import 'package:bgms_mobile_app/features/stats/ai_coaching_repository.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _V2Repository extends AiCoachingRepository {
  @override
  Future<AiCoachingSummary> summarize({
    required PlayerStatsProfile profile,
    required List<MatchSummary> matches,
    bool allowRemote = true,
  }) async => AiCoachingSummary.fromJson({
    'schemaVersion': 2,
    'signature': '경기 코치',
    'signatureSub': '확인한 경기의 사실과 해석',
    'finalVerdict': '교전 위치를 점검하세요',
    'cards': [
      {
        'topicId': 'firepower',
        'topic': '화력',
        'question': '화력은 어떤가?',
        'context': {
          'gameMode': 'squad-fpp',
          'matchType': 'competitive',
          'userMatchCount': 3,
        },
        'evidenceIds': ['damage'],
        'evidence': [
          {
            'id': 'damage',
            'label': '평균 화력',
            'userValue': '240',
            'status': 'user_only',
          },
        ],
        'analysisStatus': 'ready',
        'kindOpinion': '엄폐를 확보하세요',
      },
    ],
    'actionItems': [
      {'title': '위치 점검', 'desc': '다음 경기에서 엄폐를 확인하세요'},
    ],
  });
}

void main() {
  testWidgets('v2 카드와 함께 부제·질문·추천 액션도 표시한다', (tester) async {
    final bundle = PlayerStatsBundle(
      profile: PlayerStatsProfile.fromJson({
        'nickname': 'tester',
        'platform': 'steam',
        'recentMatches': ['m1'],
      }),
      matches: const [],
      summaryFallback: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiCoachingCard(bundle: bundle, repository: _V2Repository()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('최근 경기 AI 코칭 받기'));
    await tester.pumpAndSettle();
    expect(find.text('확인한 경기의 사실과 해석'), findsOneWidget);
    expect(find.text('화력은 어떤가?'), findsOneWidget);
    expect(find.text('추천 액션'), findsOneWidget);
    expect(find.text('위치 점검 - 다음 경기에서 엄폐를 확인하세요'), findsOneWidget);
    expect(find.textContaining('평균 화력: 240'), findsOneWidget);
  });
}
