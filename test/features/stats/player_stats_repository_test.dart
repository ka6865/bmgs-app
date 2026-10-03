import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/core/network/api_exception.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_models.dart';
import 'package:bgms_mobile_app/features/stats/player_stats_repository.dart';

import '../../support/fake_http_adapter.dart';

class MockBgmsApiClient extends Fake implements BgmsApiClient {
  String? lastNickname;
  String? lastPlatform;
  String? lastSeason;
  bool? lastRefresh;
  bool? lastAutoRefresh;
  bool collectionRateLimited = false;
  ApiException? collectionError;

  @override
  Future<Map<String, dynamic>> fetchPlayer({
    required String nickname,
    required String platform,
    String? season,
    bool refresh = false,
    bool autoRefresh = false,
  }) async {
    lastNickname = nickname;
    lastPlatform = platform;
    lastSeason = season;
    lastRefresh = refresh;
    lastAutoRefresh = autoRefresh;
    return {
      'nickname': nickname,
      'platform': platform,
      'seasonId': season,
      'stats': {},
      'recentMatches': [],
      'matchModes': {},
      'seasonsList': [],
    };
  }

  @override
  Future<Map<String, dynamic>> collectPlayerMatches({
    required String nickname,
    required String platform,
  }) async {
    final error = collectionError;
    if (error != null) throw error;
    return {
      'collection': {
        'saved': 0,
        'alreadyStored': 0,
        'rateLimited': collectionRateLimited,
      },
      'historyIngest': {'pendingCount': 0, 'unavailableCount': 0},
    };
  }
}

void main() {
  group('PlayerStatsRepository Tests', () {
    test(
      'fetchPlayerStats forwards refresh parameter to BgmsApiClient',
      () async {
        final mockClient = MockBgmsApiClient();
        final repository = PlayerStatsRepository(client: mockClient);

        await repository.fetchPlayerStats(
          nickname: 'TestUser',
          platform: 'steam',
          refresh: true,
        );

        expect(mockClient.lastRefresh, isTrue);
        expect(mockClient.lastAutoRefresh, isFalse);
      },
    );

    test('기본 시즌 화면 조회만 자동 갱신하고 알림·과거 시즌은 DB만 읽는다', () async {
      final client = MockBgmsApiClient();
      final repository = PlayerStatsRepository(client: client);
      await repository.fetchPlayerStats(nickname: 'Player', platform: 'steam');
      expect(client.lastAutoRefresh, isTrue);
      await repository.fetchPlayerStats(
        nickname: 'Player',
        platform: 'steam',
        includeSummaries: false,
      );
      expect(client.lastAutoRefresh, isFalse);
      await repository.fetchPlayerStats(
        nickname: 'Player',
        platform: 'steam',
        season: 'division.bro.official.pc-2018-41',
      );
      expect(client.lastAutoRefresh, isFalse);
    });

    test('경기 수집 성공과 429의 대기 시간을 DB 이력 진입에 전달한다', () async {
      for (final scenario in [
        (limited: false, error: null, seconds: 15),
        (limited: true, error: null, seconds: 60),
        (
          limited: false,
          error: const ApiException(
            kind: ApiErrorKind.rateLimited,
            message: '수집 한도',
            retryAfter: Duration(seconds: 23),
          ),
          seconds: 23,
        ),
        (
          limited: false,
          error: const ApiException(
            kind: ApiErrorKind.rateLimited,
            message: '수집 한도',
          ),
          seconds: 15,
        ),
      ]) {
        final client = MockBgmsApiClient()
          ..collectionRateLimited = scenario.limited
          ..collectionError = scenario.error;
        final repository = PlayerStatsRepository(client: client);
        final before = DateTime.now();
        final bundle = await repository.fetchPlayerStats(
          nickname: 'Player',
          platform: 'steam',
          refresh: true,
        );
        final after = DateTime.now();
        final duration = Duration(seconds: scenario.seconds);
        expect(bundle.collectionAvailableAt, isNotNull);
        expect(
          bundle.collectionAvailableAt!.isBefore(before.add(duration)),
          isFalse,
        );
        expect(
          bundle.collectionAvailableAt!.isAfter(after.add(duration)),
          isFalse,
        );
        expect(bundle.profile.nickname, 'Player');
        final cached = await repository.fetchPlayerStats(
          nickname: 'Player',
          platform: 'steam',
        );
        expect(cached.collectionAvailableAt, isNull);
      }
    });

    test('새 저장과 수동 갱신만 수집 한 번 후 collect:false 요약을 읽는다', () async {
      for (final scenario in [
        (status: 'saved', refresh: false, summaries: true, collects: 1),
        (status: 'cached', refresh: true, summaries: true, collects: 1),
        (status: 'cached', refresh: false, summaries: true, collects: 0),
        (status: 'saved', refresh: true, summaries: false, collects: 0),
      ]) {
        final adapter = FakeHttpAdapter()
          ..stub('/api/pubg/player', {
            'nickname': 'Player',
            'platform': 'steam',
            'syncStatus': scenario.status,
            'recentMatches': ['m1'],
          })
          ..stub('/api/pubg/player/matches', {
            'collection': {'claimed': 3, 'saved': 2, 'alreadyStored': 1},
            'historyIngest': {'pendingCount': 1, 'unavailableCount': 0},
          })
          ..stub('/api/pubg/matches-summary', {
            'summaries': {
              'm1': {'mapName': 'Baltic_Main', 'kills': 0},
            },
          });
        final repository = PlayerStatsRepository(
          client: BgmsApiClient(
            baseUrl: 'https://bgms.kr',
            dio: createFakeDio(adapter),
          ),
        );
        final bundle = await repository.fetchPlayerStats(
          nickname: 'Player',
          platform: 'steam',
          refresh: scenario.refresh,
          includeSummaries: scenario.summaries,
        );
        expect(
          adapter.recordedRequests
              .where((r) => r.uri.path == '/api/pubg/player/matches')
              .length,
          scenario.collects,
        );
        if (scenario.summaries) {
          expect(
            adapter.recordedRequests.last.uri.path,
            '/api/pubg/matches-summary',
          );
          expect((adapter.recordedRequests.last.data as Map)['collect'], false);
          expect(bundle.matches.single.kills, 0);
        }
        if (scenario.collects == 1) {
          expect(bundle.collectionMessage, contains('신규 1경기'));
          expect(bundle.collectionAvailableAt, isNotNull);
        } else {
          expect(bundle.collectionAvailableAt, isNull);
        }
      }
    });

    test('경기 수집 429에도 저장된 전적과 요약을 유지하고 별도 안내한다', () async {
      final adapter = FakeHttpAdapter()
        ..stub('/api/pubg/player', {
          'nickname': 'Player',
          'platform': 'steam',
          'syncStatus': 'saved',
          'recentMatches': ['m1'],
        })
        ..stub('/api/pubg/player/matches', {
          'error': '수집 호출 한도',
        }, statusCode: 429)
        ..stub('/api/pubg/matches-summary', {
          'summaries': {
            'm1': {'mapName': 'Baltic_Main', 'kills': 2},
          },
        });
      final bundle = await PlayerStatsRepository(
        client: BgmsApiClient(
          baseUrl: 'https://bgms.kr',
          dio: createFakeDio(adapter),
        ),
      ).fetchPlayerStats(nickname: 'Player', platform: 'steam');
      expect(bundle.profile.syncStatus, PlayerSyncStatus.saved);
      expect(bundle.matches.single.kills, 2);
      expect(bundle.collectionMessage, contains('경기 수집 실패'));
      expect(bundle.collectionMessage, contains('DB 전체 경기 이력'));
    });

    test('요약 API 503은 시즌 전적을 유지하고 상세 자동 조회 없이 fallback을 표시한다', () async {
      final playerJson = Map<String, dynamic>.from(
        jsonDecode(
              File('test/fixtures/player_response.json').readAsStringSync(),
            )
            as Map,
      );
      final expectedProfile = PlayerStatsProfile.fromJson(playerJson);
      final adapter = FakeHttpAdapter()
        ..stub('/api/pubg/player', playerJson)
        ..stub('/api/pubg/matches-summary', {
          'error': '요약 서버가 일시적으로 응답하지 않습니다.',
          'diagnostic': 'internal server trace',
        }, statusCode: 503);
      final repository = PlayerStatsRepository(
        client: BgmsApiClient(
          baseUrl: 'https://bgms.kr',
          dio: createFakeDio(adapter),
        ),
      );

      final bundle = await repository.fetchPlayerStats(
        nickname: 'TGLTN',
        platform: 'steam',
      );

      expect(bundle.profile.nickname, expectedProfile.nickname);
      expect(bundle.profile.roundsPlayed, expectedProfile.roundsPlayed);
      expect(bundle.profile.adr, expectedProfile.adr);
      expect(bundle.profile.seasonId, expectedProfile.seasonId);
      expect(
        bundle.matches.map((match) => match.matchId),
        expectedProfile.recentMatches.take(20),
      );
      expect(bundle.matches, isNotEmpty);
      expect(bundle.matches.every((match) => match.isFallback), isTrue);
      expect(bundle.summaryFallback, isTrue);
      expect(bundle.summaryError, '요약 서버가 일시적으로 응답하지 않습니다.');
      expect(adapter.requestedPaths.map((path) => Uri.parse(path).path), [
        '/api/pubg/player',
        '/api/pubg/matches-summary',
      ]);
    });
  });
}
