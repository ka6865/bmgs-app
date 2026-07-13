import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'match_detail_models.dart';
import 'player_stats_models.dart';

class MatchDetailRepository {
  MatchDetailRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<MatchDetail> fetchMatchDetail({
    required MatchSummary summary,
    required String nickname,
    required String platform,
  }) async {
    try {
      final json = await _client.fetchMatchDetail(
        matchId: summary.matchId,
        nickname: nickname,
        platform: platform,
      );
      if (json.isEmpty || json['error'] != null) {
        return MatchDetail.fromSummary(
          summary,
          nickname: nickname,
          message: json['error']?.toString(),
        );
      }
      return MatchDetail.fromJson(summary.matchId, json);
    } on DioException catch (error) {
      return MatchDetail.fromSummary(
        summary,
        nickname: nickname,
        message: _dioMessage(error),
      );
    } catch (error) {
      return MatchDetail.fromSummary(
        summary,
        nickname: nickname,
        message: error.toString(),
      );
    }
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (error.response?.statusCode == 429) {
      return 'PUBG API 호출 한도가 일시적으로 초과되었습니다.';
    }
    return error.message ?? '매치 상세를 불러오지 못했습니다.';
  }
}
