class BoardPostSummary {
  const BoardPostSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.createdAt,
    required this.views,
    required this.likes,
    required this.commentCount,
    required this.isNotice,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String author;
  final String category;
  final String createdAt;
  final int views;
  final int likes;
  final int commentCount;
  final bool isNotice;
  final String? imageUrl;

  factory BoardPostSummary.fromJson(Map<String, dynamic> json) {
    return BoardPostSummary(
      id: _asInt(json['id']),
      title: _asString(json['title'], '제목 없음'),
      author: _asString(json['author'], '알 수 없음'),
      category: _asString(json['category'], 'free'),
      createdAt: _asString(json['createdAt'], ''),
      views: _asInt(json['views']),
      likes: _asInt(json['likes']),
      commentCount: _asInt(json['commentCount']),
      isNotice: json['isNotice'] == true,
      imageUrl: _nullableString(json['imageUrl']),
    );
  }
}

class BoardPostPage {
  const BoardPostPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<BoardPostSummary> items;
  final bool hasMore;
  final String? nextCursor;

  factory BoardPostPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return BoardPostPage(
      items: items is List
          ? items
                .whereType<Map>()
                .map((item) => BoardPostSummary.fromJson(item.cast()))
                .toList()
          : const [],
      hasMore: json['hasMore'] == true,
      nextCursor: _nullableString(json['nextCursor']),
    );
  }
}

class BoardPostDetail {
  const BoardPostDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.contentText,
    required this.imageUrls,
    required this.createdAt,
    required this.views,
    required this.likes,
    required this.comments,
    this.canEdit = false,
    this.revision,
  });

  final int id;
  final String title;
  final String author;
  final String category;
  final String contentText;
  final List<String> imageUrls;
  final String createdAt;
  final int views;
  final int likes;
  final List<BoardComment> comments;
  final bool canEdit;
  final int? revision;

  /// 상세 응답의 초기 댓글은 50개 제한이며 별도 댓글 페이지 API로 이어 읽는다.
  bool get commentsMayBeTruncated => comments.length >= 50;

  factory BoardPostDetail.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] is Map)
        ? (json['post'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final comments = json['comments'];
    return BoardPostDetail(
      id: _asInt(post['id']),
      title: _asString(post['title'], '제목 없음'),
      author: _asString(post['author'], '알 수 없음'),
      category: _asString(post['category'], 'free'),
      contentText: _asString(post['contentText'], ''),
      imageUrls: post['imageUrls'] is List
          ? (post['imageUrls'] as List)
                .map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toList()
          : const [],
      createdAt: _asString(post['createdAt'], ''),
      views: _asInt(post['views']),
      likes: _asInt(post['likes']),
      canEdit:
          post['canEdit'] == true &&
          post['revision'] is int &&
          (post['revision'] as int) >= 0,
      revision: post['revision'] is int && (post['revision'] as int) >= 0
          ? post['revision'] as int
          : null,
      comments: comments is List
          ? comments
                .whereType<Map>()
                .map((item) => BoardComment.fromJson(item.cast()))
                .toList()
          : const [],
    );
  }
}

class BoardComment {
  const BoardComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.canDelete = false,
  });

  final int id;
  final String author;
  final String content;
  final String createdAt;
  final int? parentId;
  final bool canDelete;

  factory BoardComment.fromJson(Map<String, dynamic> json) {
    return BoardComment(
      id: _asInt(json['id']),
      author: _asString(json['author'], '알 수 없음'),
      content: _asString(json['content'], ''),
      createdAt: _asString(json['createdAt'], ''),
      parentId: json['parentId'] == null ? null : _asInt(json['parentId']),
      canDelete: json['canDelete'] == true,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(Object? value, String fallback) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

class BoardCommentPage {
  const BoardCommentPage({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.nextCursor,
  });
  final List<BoardComment> items;
  final int totalCount;
  final bool hasMore;
  final String? nextCursor;
  factory BoardCommentPage.fromJson(Map<String, dynamic> json) =>
      BoardCommentPage(
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((item) => BoardComment.fromJson(item.cast()))
            .toList(),
        totalCount: _asInt(json['totalCount']),
        hasMore: json['hasMore'] == true,
        nextCursor: _nullableString(json['nextCursor']),
      );
}

class BoardPostEdit {
  const BoardPostEdit({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.revision,
    this.contentImageIds = const [],
    this.thumbnailImageId,
  });
  final int id;
  final String title;
  final String content;
  final String category;
  final int revision;
  final List<String> contentImageIds;
  final String? thumbnailImageId;
  factory BoardPostEdit.fromJson(Map<String, dynamic> json) {
    final post = (json['post'] as Map).cast<String, dynamic>();
    if (_asInt(post['id']) <= 0 ||
        post['canEdit'] != true ||
        post['revision'] is! int ||
        (post['revision'] as int) < 0) {
      throw const FormatException('수정 권한 또는 버전을 확인하지 못했습니다.');
    }
    return BoardPostEdit(
      id: _asInt(post['id']),
      title: _asString(post['title'], ''),
      content: _asString(post['content'], ''),
      category: _asString(post['category'], '자유'),
      revision: post['revision'] as int,
      contentImageIds: (post['contentImageIds'] as List? ?? [])
          .whereType<String>()
          .toList(),
      thumbnailImageId: _nullableString(post['thumbnailImageId']),
    );
  }
}

class BoardUploadedImage {
  const BoardUploadedImage({required this.id, required this.url});
  final String id;
  final String url;
}
