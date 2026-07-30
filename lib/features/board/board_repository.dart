import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'board_models.dart';

class BoardRepository {
  BoardRepository({BgmsApiClient? client})
    : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);

  final BgmsApiClient _client;

  Future<BoardPostPage> fetchPosts({
    String category = 'all',
    String? cursor,
    String? query,
  }) async {
    try {
      final json = await _client.fetchBoardPosts(
        category: category,
        cursor: cursor,
        query: query,
      );
      return BoardPostPage.fromJson(json);
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<BoardPostDetail> fetchPost(int postId) async {
    try {
      final json = await _client.fetchBoardPost(postId: postId);
      return BoardPostDetail.fromJson(json);
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<int> createPost({
    required String title,
    required String content,
    required String category,
  }) async {
    final token = _accessTokenOrNull();
    if (token == null) throw const BoardException('카카오 로그인 후 글을 작성할 수 있습니다.');

    try {
      final json = await _client.createBoardPost(
        title: title,
        content: content,
        category: category,
        accessToken: token,
      );
      return int.tryParse(json['id']?.toString() ?? '') ?? 0;
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<void> createComment({
    required int postId,
    required String content,
  }) async {
    final token = _accessTokenOrNull();
    if (token == null) throw const BoardException('카카오 로그인 후 댓글을 작성할 수 있습니다.');

    try {
      await _client.createBoardComment(
        postId: postId,
        content: content,
        accessToken: token,
      );
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  bool get canWrite => _accessTokenOrNull() != null;

  String? _accessTokenOrNull() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}

class BoardException implements Exception {
  const BoardException(this.message);

  final String message;

  @override
  String toString() => message;
}
