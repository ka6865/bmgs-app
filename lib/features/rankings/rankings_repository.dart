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
            ? '랭킹 데이터를 준비하고 있습니다.'
            : '랭킹 데이터를 일시적으로 불러오지 못했습니다. ${_dioMessage(error)}',
      );
    } catch (error) {
      return RankingBoard.unavailable(
        query: query,
        message: '랭킹 데이터를 표시하지 못했습니다. $error',
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
