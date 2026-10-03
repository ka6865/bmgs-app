import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'board_models.dart';
import 'board_categories.dart';

typedef BoardBinaryUploader =
    Future<void> Function(
      String bucket,
      String key,
      String token,
      Uint8List bytes,
      String mimeType,
    );

class BoardRepository {
  // Provider names form the injectable public contract.
  BoardRepository({
    BgmsApiClient? client,
    String? Function()? tokenProvider,
    String? Function()? userIdProvider,
    Stream<String?>? authChanges,
    BoardBinaryUploader? binaryUploader,
  }) : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl),
       // ignore: prefer_initializing_formals
       _tokenProvider = tokenProvider,
       // ignore: prefer_initializing_formals
       _userIdProvider = userIdProvider,
       // ignore: prefer_initializing_formals
       _authChanges = authChanges,
       // ignore: prefer_initializing_formals
       _binaryUploader = binaryUploader;
  final BgmsApiClient _client;
  final String? Function()? _tokenProvider;
  final String? Function()? _userIdProvider;
  final Stream<String?>? _authChanges;
  final BoardBinaryUploader? _binaryUploader;
  String? get userId {
    if (_userIdProvider != null) return _userIdProvider();
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Stream<String?> get authChanges {
    if (_authChanges != null) return _authChanges;
    try {
      return Supabase.instance.client.auth.onAuthStateChange
          .map((state) => state.session?.user.id)
          .distinct();
    } catch (_) {
      return const Stream.empty();
    }
  }

  bool get canWrite => userId != null;
  Future<String?> _token() async {
    if (_tokenProvider != null) return _tokenProvider();
    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session?.isExpired == true) {
        session = (await auth.refreshSession()).session;
      }
      return session?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final actor = userId;
    final token = await _token();
    if (actor == null || token == null || token.isEmpty) {
      throw const BoardException('로그인 후 이용할 수 있습니다.');
    }
    if (actor != userId) {
      throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
    }
    try {
      final result = await request(token);
      if (actor != userId) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      return result;
    } on BoardException {
      rethrow;
    } catch (error) {
      final api = ApiException.from(error);
      throw BoardException(api.message, statusCode: api.statusCode);
    }
  }

  Future<BoardPostPage> fetchPosts({
    String category = 'all',
    String? cursor,
    String? query,
  }) async {
    try {
      final page = BoardPostPage.fromJson(
        await _client.fetchBoardPosts(
          category: category,
          cursor: cursor,
          query: query,
        ),
      );
      return BoardPostPage(
        items: page.items
            .where((post) => BoardCategories.matches(category, post.category))
            .toList(),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<BoardPostDetail> fetchPost(int postId, {bool refresh = false}) async {
    final actor = userId;
    try {
      final token = actor == null ? null : await _token();
      if (actor != userId) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      final json = await _client.fetchBoardPost(
        postId: postId,
        refresh: refresh,
        accessToken: token?.isNotEmpty == true ? token : null,
      );
      if (actor != userId) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      return BoardPostDetail.fromJson(json);
    } on BoardException {
      rethrow;
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<BoardPostEdit> fetchEdit(int postId) => _authorized(
    (token) async => BoardPostEdit.fromJson(
      await _client.fetchBoardEdit(postId: postId, accessToken: token),
    ),
  );
  Future<BoardCommentPage> fetchComments(int postId, {String? cursor}) async {
    final actor = userId;
    try {
      final token = actor == null ? null : await _token();
      if (actor != userId) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      final json = await _client.fetchBoardComments(
        postId: postId,
        cursor: cursor,
        accessToken: token?.isNotEmpty == true ? token : null,
      );
      if (actor != userId) {
        throw const BoardException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      return BoardCommentPage.fromJson(json);
    } on BoardException {
      rethrow;
    } catch (error) {
      throw BoardException(ApiException.from(error).message);
    }
  }

  Future<int> createPost({
    required String title,
    required String content,
    required String category,
    List<String> contentImageIds = const [],
    String? thumbnailImageId,
  }) => _authorized((token) async {
    final json = await _client.createBoardPost(
      title: title,
      content: content,
      category: category,
      accessToken: token,
      contentImageIds: contentImageIds,
      thumbnailImageId: thumbnailImageId,
    );
    final data = json['data'] is Map ? json['data'] as Map : json;
    final id = int.tryParse(data['id']?.toString() ?? '');
    if (json['success'] != true || id == null || id <= 0) {
      throw const BoardException('게시글 저장 결과를 확인하지 못했습니다. 목록에서 확인해 주세요.');
    }
    return id;
  });
  Future<void> updatePost({
    required BoardPostEdit original,
    required String title,
    required String content,
    required String category,
    required List<String> contentImageIds,
    String? thumbnailImageId,
  }) => _authorized((token) async {
    final result = await _client.updateBoardPost(
      postId: original.id,
      accessToken: token,
      body: {
        'title': title,
        'content': content,
        'category': category,
        'expectedRevision': original.revision,
        'contentImageIds': contentImageIds,
        'thumbnailImageId': thumbnailImageId,
      },
    );
    _requireSuccess(result, '수정');
  });
  Future<void> deletePost(int postId, int revision) =>
      _authorized((token) async {
        final result = await _client.deleteBoardPost(
          postId: postId,
          expectedRevision: revision,
          accessToken: token,
        );
        _requireSuccess(result, '삭제');
      });
  Future<void> createComment({
    required int postId,
    required String content,
    int? parentId,
  }) => _authorized((token) async {
    final result = await _client.createBoardComment(
      postId: postId,
      content: content,
      parentId: parentId,
      accessToken: token,
    );
    _requireSuccess(result, '댓글 등록');
  });

  static void _requireSuccess(Map<String, dynamic> result, String action) {
    if (result['success'] != true) {
      throw BoardException('$action 결과를 확인하지 못했습니다. 새로고침 후 확인해 주세요.');
    }
  }

  Future<int> likePost(int postId) => _authorized((token) async {
    final result = await _client.likeBoardPost(
      postId: postId,
      accessToken: token,
    );
    if (result['success'] != true ||
        result['liked'] != true ||
        result['likes'] is! int ||
        (result['likes'] as int) < 0) {
      throw const BoardException('추천 결과를 확인하지 못했습니다. 새로고침 후 확인해 주세요.');
    }
    return result['likes'] as int;
  });

  Future<void> reportContent({
    required String targetType,
    required int targetId,
    required String reason,
    String? detail,
  }) => _authorized((token) async {
    final result = await _client.reportBoardContent(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      detail: detail,
      accessToken: token,
    );
    if (result['success'] != true) {
      throw const BoardException('신고 접수 결과를 확인하지 못했습니다.');
    }
  });

  static String imageMimeType(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 1572864) {
      throw const BoardException('사진은 파일당 1.5MiB 이하만 첨부할 수 있습니다.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'image/webp';
    }
    throw const BoardException(
      'PNG, JPEG, WebP 사진만 지원합니다. HEIC 사진은 JPEG로 변환해 주세요.',
    );
  }

  Future<BoardUploadedImage> uploadImage(Uint8List bytes) => _authorized((
    token,
  ) async {
    final actor = userId;
    final mime = imageMimeType(bytes);
    final reservation = await _client.reserveBoardImage(
      mimeType: mime,
      byteSize: bytes.length,
      accessToken: token,
    );
    final id = reservation['imageId']?.toString() ?? '';
    bool completed = false;
    try {
      if (!RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            caseSensitive: false,
          ).hasMatch(id) ||
          reservation['bucketId'] != 'board-images-v2' ||
          reservation['storageKey'] != id ||
          reservation['token'] is! String ||
          (reservation['token'] as String).trim().isEmpty) {
        throw const BoardException('사진 업로드 정보를 확인하지 못했습니다.');
      }
      if (actor != userId) throw const BoardException('로그인 상태가 변경되었습니다.');
      if (_binaryUploader != null) {
        await _binaryUploader(
          'board-images-v2',
          id,
          reservation['token'] as String,
          bytes,
          mime,
        );
      } else {
        await Supabase.instance.client.storage
            .from('board-images-v2')
            .uploadBinaryToSignedUrl(
              id,
              reservation['token'] as String,
              bytes,
              FileOptions(contentType: mime, upsert: false),
            );
      }
      if (actor != userId) throw const BoardException('로그인 상태가 변경되었습니다.');
      final result = await _client.completeBoardImage(
        imageId: id,
        accessToken: token,
      );
      final url = Uri.tryParse(result['publicUrl']?.toString() ?? '');
      if (result['imageId'] != id ||
          url == null ||
          url.scheme != 'https' ||
          url.userInfo.isNotEmpty) {
        throw const BoardException('사진 업로드 결과를 확인하지 못했습니다.');
      }
      if (actor != userId) throw const BoardException('로그인 상태가 변경되었습니다.');
      completed = true;
      return BoardUploadedImage(id: id, url: url.toString());
    } finally {
      if (!completed && id.isNotEmpty) {
        try {
          await _client.releaseBoardImages(imageIds: [id], accessToken: token);
        } catch (_) {
          /* 서버 만료 정리가 남는다. */
        }
      }
    }
  });
  Future<bool> releaseImages(List<String> ids) {
    if (ids.isEmpty) return Future.value(true);
    return _authorized((token) async {
      final json = await _client.releaseBoardImages(
        imageIds: ids,
        accessToken: token,
      );
      return json['deferred'] == 0 &&
          json['released'] is int &&
          (json['released'] as int) >= ids.toSet().length;
    });
  }
}

class BoardException implements Exception {
  const BoardException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
