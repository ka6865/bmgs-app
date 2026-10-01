import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/core/network/bgms_api_client.dart';
import 'package:bgms_mobile_app/features/support/support_repository.dart';
import 'package:bgms_mobile_app/features/support/support_models.dart';
import 'package:bgms_mobile_app/features/support/support_screen.dart';
import '../../support/fake_http_adapter.dart';

class RecordingAdapter extends FakeHttpAdapter {
  RecordingAdapter({super.responses});
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  SupportRepository repository(
    RecordingAdapter adapter, {
    String? Function()? user,
  }) => SupportRepository(
    client: BgmsApiClient(
      baseUrl: 'https://example.test',
      dio: createFakeDio(adapter),
    ),
    tokenProvider: () => 'token',
    userIdProvider: user ?? () => 'user-1',
  );
  test('FAQ는 공개, 문의 읽기·작성·메시지는 Bearer와 정확한 계약을 사용한다', () async {
    final adapter = RecordingAdapter(
      responses: {
        '/api/support/faqs': {
          'faqs': [
            {'id': 1, 'question': '질문', 'answer': '답변', 'category': 'stats'},
          ],
        },
        '/api/support/tickets': {
          'ticket': {'id': 'ticket-1'},
          'tickets': [
            {
              'id': 'ticket-1',
              'subject': '문의',
              'status': 'answered',
              'unread': true,
            },
          ],
        },
        '/api/support/tickets/ticket-1': {
          'ticket': {
            'id': 'ticket-1',
            'messages': [
              {'id': 'm1', 'sender_type': 'admin', 'body': '답변'},
            ],
            'attachments': [
              {'id': 'a1', 'original_name': '증빙.png', 'status': 'ready'},
            ],
          },
        },
        '/api/support/tickets/ticket-1/messages': {
          'message': {'id': 'm2'},
        },
        '/api/support/attachments/a1/url': {
          'signedUrl': 'https://storage.example.test/file?token=temporary',
          'expiresIn': 300,
        },
      },
    );
    final repo = repository(adapter);
    expect(
      (await repo.fetchFaqs(category: 'stats', query: '검색')).single.answer,
      '답변',
    );
    expect(adapter.requests.last.headers['Authorization'], isNull);
    expect(adapter.requests.last.uri.queryParameters['q'], '검색');
    expect((await repo.fetchTickets()).single.unread, isTrue);
    final detail = await repo.fetchTicket('ticket-1');
    expect(detail.messages.single.fromAdmin, isTrue);
    expect(detail.attachments.single.name, '증빙.png');
    await repo.createTicket(category: 'bug', subject: ' 제목 ', body: ' 내용 ');
    expect(adapter.requests.last.data, {
      'category': 'bug',
      'subject': '제목',
      'body': '내용',
      'attachmentIds': [],
    });
    await repo.sendMessage(
      ticketId: 'ticket-1',
      body: ' 추가 ',
      idempotencyKey: '123e4567-e89b-42d3-a456-426614174000',
    );
    expect(adapter.requests.last.data, {'body': '추가'});
    expect(
      adapter.requests.last.headers['Idempotency-Key'],
      '123e4567-e89b-42d3-a456-426614174000',
    );
    await repo.attachmentUrl('a1');
    await repo.attachmentUrl('a1');
    expect(
      adapter.requests.where((r) => r.uri.path.endsWith('/a1/url')).length,
      2,
    );
    expect(
      adapter.requests
          .skip(1)
          .every((r) => r.headers['Authorization'] == 'Bearer token'),
      isTrue,
    );
  });
  test('증빙 없는 개인정보 신규 문의는 전송하지 않는다', () async {
    final adapter = RecordingAdapter();
    await expectLater(
      repository(
        adapter,
      ).createTicket(category: 'privacy', subject: '비공개', body: '문의'),
      throwsA(isA<SupportException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test('로그인하지 않은 문의 요청은 네트워크에 보내지 않는다', () async {
    final adapter = RecordingAdapter();
    await expectLater(
      repository(adapter, user: () => null).fetchTickets(),
      throwsA(isA<SupportException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test('계정이 변경되면 이전 문의 응답을 반환하지 않는다', () async {
    var user = 'user-1';
    final response = Completer<Map<String, dynamic>>();
    final client = _PendingClient(response);
    final repo = SupportRepository(
      client: client,
      tokenProvider: () => 'token',
      userIdProvider: () => user,
    );
    final future = repo.fetchTickets();
    final expectation = expectLater(future, throwsA(isA<SupportException>()));
    await Future<void>.delayed(Duration.zero);
    user = 'user-2';
    response.complete({
      'tickets': [
        {'id': 'private-ticket'},
      ],
    });
    await expectation;
  });
  testWidgets('로그인 없이 공개 FAQ와 로그인 안내를 표시한다', (tester) async {
    final adapter = RecordingAdapter(
      responses: {
        '/api/support/faqs': {
          'faqs': [
            {'id': 'faq', 'question': '전적 갱신 방법', 'answer': '새로고침을 눌러주세요'},
          ],
        },
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportScreen(
            repository: repository(adapter, user: () => null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('전적 갱신 방법'), findsOneWidget);
    expect(find.text('로그인 후 문의하기'), findsOneWidget);
    expect(adapter.requests.map((request) => request.uri.path), [
      '/api/support/faqs',
    ]);
  });
  test('문의 상태와 작성자, 증빙 상태를 별도로 보존한다', () {
    final ticket = SupportTicket.fromJson({
      'id': 't',
      'status': 'awaiting_user',
      'messages': [
        {'sender_type': 'admin', 'body': '증빙 요청'},
      ],
      'attachments': [
        {'id': 'a', 'status': 'deleted'},
      ],
    });
    expect(ticket.statusLabel, '추가 정보 요청');
    expect(ticket.messages.single.fromAdmin, isTrue);
    expect(ticket.attachments.single.status, 'deleted');
  });
}

class _PendingClient extends BgmsApiClient {
  _PendingClient(this.response) : super(baseUrl: 'https://example.test');
  final Completer<Map<String, dynamic>> response;
  @override
  Future<Map<String, dynamic>> fetchSupportTickets({
    required String accessToken,
  }) => response.future;
}
