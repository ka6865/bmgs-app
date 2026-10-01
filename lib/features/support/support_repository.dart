import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/bgms_api_client.dart';
import 'support_models.dart';

class SupportRepository {
  SupportRepository({
    BgmsApiClient? client,
    this._tokenProvider,
    this._userIdProvider,
  }) : _client = client ?? BgmsApiClient(baseUrl: AppConfig.local.apiBaseUrl);
  final BgmsApiClient _client;
  final String? Function()? _tokenProvider;
  final String? Function()? _userIdProvider;

  String? get userId {
    if (_userIdProvider != null) return _userIdProvider();
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get canReadPrivate => userId != null;
  Stream<String?> get authChanges {
    try {
      return Supabase.instance.client.auth.onAuthStateChange
          .map((state) => state.session?.user.id)
          .distinct();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<String> _token() async {
    if (_tokenProvider != null) {
      final token = _tokenProvider();
      if (token != null && token.isNotEmpty) return token;
      throw const SupportException('로그인 후 문의를 이용할 수 있습니다.');
    }
    try {
      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      if (session?.isExpired == true) {
        session = (await client.auth.refreshSession()).session;
      }
      if (session != null && session.accessToken.isNotEmpty) {
        return session.accessToken;
      }
    } catch (_) {
      /* 세션 갱신 실패도 로그인 안내로 처리한다. */
    }
    throw const SupportException('로그인 후 문의를 이용할 수 있습니다.');
  }

  Future<List<SupportFaq>> fetchFaqs({
    String category = '',
    String query = '',
  }) async {
    try {
      final json = await _client.fetchSupportFaqs(
        category: category.isEmpty ? null : category,
        query: query,
      );
      return supportRows(json['faqs']).map(SupportFaq.fromJson).toList();
    } catch (error) {
      throw SupportException(ApiException.from(error).message);
    }
  }

  Future<T> _private<T>(Future<T> Function(String token) request) async {
    final expectedUser = userId;
    final token = await _token();
    if (expectedUser == null || expectedUser != userId) {
      throw const SupportException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
    }
    try {
      final result = await request(token);
      if (expectedUser != userId) {
        throw const SupportException('로그인 상태가 변경되었습니다. 다시 확인해 주세요.');
      }
      return result;
    } on SupportException {
      rethrow;
    } catch (error) {
      throw SupportException(ApiException.from(error).message);
    }
  }

  Future<List<SupportTicket>> fetchTickets() => _private((token) async {
    final json = await _client.fetchSupportTickets(accessToken: token);
    return supportRows(json['tickets']).map(SupportTicket.fromJson).toList();
  });
  Future<SupportTicket> fetchTicket(String ticketId) => _private((token) async {
    final json = await _client.fetchSupportTicket(
      ticketId: ticketId,
      accessToken: token,
    );
    return _ticket(json);
  });
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String body,
  }) async {
    if (category == 'privacy') {
      throw const SupportException(
        '전적 비공개 요청에는 증빙 첨부가 필요합니다. 웹 고객센터를 이용해 주세요.',
      );
    }
    if (!supportCategories.containsKey(category) ||
        subject.trim().isEmpty ||
        subject.trim().length > 120 ||
        body.trim().isEmpty ||
        body.trim().length > 5000) {
      throw const SupportException('제목은 1~120자, 내용은 1~5000자로 입력해 주세요.');
    }
    return _private((token) async {
      final json = await _client.createSupportTicket(
        body: {
          'category': category,
          'subject': subject.trim(),
          'body': body.trim(),
          'attachmentIds': <String>[],
        },
        accessToken: token,
      );
      return _ticket(json);
    });
  }

  Future<void> sendMessage({
    required String ticketId,
    required String body,
    required String idempotencyKey,
  }) async {
    if (body.trim().isEmpty || body.trim().length > 5000) {
      throw const SupportException('내용은 1~5000자로 입력해 주세요.');
    }
    await _private(
      (token) => _client.createSupportMessage(
        ticketId: ticketId,
        body: body.trim(),
        idempotencyKey: idempotencyKey,
        accessToken: token,
      ),
    );
  }

  Future<Uri> attachmentUrl(String attachmentId) => _private((token) async {
    final json = await _client.fetchSupportAttachmentUrl(
      attachmentId: attachmentId,
      accessToken: token,
    );
    final uri = Uri.tryParse(json['signedUrl']?.toString() ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const SupportException('첨부파일 주소를 확인하지 못했습니다.');
    }
    return uri;
  });
  SupportTicket _ticket(Map<String, dynamic> json) {
    if (json['ticket'] is! Map) {
      throw const SupportException('문의 응답을 확인하지 못했습니다.');
    }
    final ticket = SupportTicket.fromJson(
      Map<String, dynamic>.from(json['ticket'] as Map),
    );
    if (ticket.id.isEmpty) throw const SupportException('문의 응답을 확인하지 못했습니다.');
    return ticket;
  }
}

class SupportException implements Exception {
  const SupportException(this.message);
  final String message;
  @override
  String toString() => message;
}
