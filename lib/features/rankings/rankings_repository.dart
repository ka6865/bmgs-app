import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
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
    } catch (error) {
      final apiError = ApiException.from(error);
      return RankingBoard.unavailable(
        query: query,
        message: apiError.isMissingEndpoint
            ? '랭킹 데이터를 준비하고 있습니다.'
            : '랭킹 데이터를 불러오지 못했습니다. ${apiError.message}',
      );
    }
  }
}
