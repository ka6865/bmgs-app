import '../../core/config/app_config.dart';
import '../../core/network/bgms_api_client.dart';
import 'ban_watch_models.dart';

class BanWatchRepository {
  BanWatchRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<BanWatchList> fetch({required String accessToken}) async {
    final json = await _client.fetchBanWatches(accessToken: accessToken);
    return BanWatchList.fromJson(json);
  }

  Future<void> remove({
    required String watchId,
    required String accessToken,
  }) async {
    await _client.removeBanWatch(watchId: watchId, accessToken: accessToken);
  }
}
