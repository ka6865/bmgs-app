import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'ranking_models.dart';

class RankingsRepository {
  RankingsRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<RankingBoard> fetchBoard(RankingQuery query) async {
    try {
      final json = await _client.fetchRankings(
        tab: query.tab,
        mode: query.mode,
        perspective: query.perspective,
        matchType: query.matchType,
      );
      return RankingBoard.fromJson(json, query: query);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return RankingBoard.unavailable(
        query: query,
        message: status == 404
            ? '/api/rankings API가 없습니다. 현재 웹 프로젝트에는 server action만 있고 모바일용 route가 필요합니다.'
            : '랭킹 API 실패: ${_dioMessage(error)}',
      );
    } catch (error) {
      return RankingBoard.unavailable(
        query: query,
        message: '랭킹 응답 파싱 실패: $error',
      );
    }
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return [
      if (error.response?.statusCode != null)
        'HTTP ${error.response!.statusCode}',
      if (error.message != null) error.message!,
    ].join(' · ');
  }
}
