import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bgms_mobile_app/features/support/support_screen.dart';
import 'package:bgms_mobile_app/features/support/support_create_screen.dart';
import 'package:bgms_mobile_app/features/support/support_detail_screen.dart';
import 'package:bgms_mobile_app/features/support/support_models.dart';
import 'package:bgms_mobile_app/features/support/support_repository.dart';

class _SessionRepository extends SupportRepository {
  String? currentUser = 'user-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  final createdDrafts = <({String? user, String subject, String body})>[];
  final pendingCreates = <Completer<SupportTicket>>[];
  @override
  String? get userId => currentUser;
  @override
  Stream<String?> get authChanges => changes.stream;
  void switchUser(String? user) {
    currentUser = user;
    changes.add(user);
  }

  @override
  Future<List<SupportFaq>> fetchFaqs({
    String category = '',
    String query = '',
  }) async => const [
    SupportFaq(
      id: 'faq',
      category: 'stats',
      question: '갱신 방법',
      answer: '새로고침으로 확인합니다.',
    ),
  ];
  @override
  Future<List<SupportTicket>> fetchTickets() async => const [];
  @override
  Future<SupportTicket> fetchTicket(String ticketId) async => SupportTicket(
    id: ticketId,
    category: 'bug',
    subject: '테스트 문의',
    status: 'new',
    updatedAt: '',
    messages: const [
      SupportMessage(
        id: 'm1',
        body: '테스트 내용',
        senderType: 'user',
        createdAt: '',
      ),
    ],
  );
  @override
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String body,
  }) {
    createdDrafts.add((user: currentUser, subject: subject, body: body));
    if (pendingCreates.isNotEmpty) return pendingCreates.removeAt(0).future;
    return Future.error(const SupportException('초안 제출 오류'));
  }
}

void main() {
  Future<void> pumpCreate(
    WidgetTester tester,
    _SessionRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SupportCreateScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterDraft(
    WidgetTester tester,
    String subject,
    String body,
  ) async {
    await tester.enterText(find.byType(TextField).first, subject);
    await tester.enterText(find.byType(TextField).last, body);
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '문의 제출');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('고객센터 세 화면은 외부 Scaffold 없이 Material을 제공한다', (tester) async {
    final repository = _SessionRepository();
    addTearDown(repository.changes.close);
    for (final screen in <Widget>[
      SupportScreen(repository: repository),
      SupportCreateScreen(repository: repository),
      SupportDetailScreen(ticketId: 'ticket-1', repository: repository),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      final textField = find.byType(TextField).first;
      expect(
        find.ancestor(of: textField, matching: find.byType(Material)),
        findsWidgets,
      );
    }
  });
  testWidgets('계정 변경 시 문의 초안과 오류를 지우고 새 계정 내용만 전송한다', (tester) async {
    final repository = _SessionRepository();
    addTearDown(repository.changes.close);
    await pumpCreate(tester, repository);
    await enterDraft(tester, 'A의 제목', 'A의 문의 내용');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('초안 제출 오류'), findsOneWidget);
    repository.switchUser('user-b');
    await tester.pumpAndSettle();
    expect(find.text('초안 제출 오류'), findsNothing);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
      expect(field.enabled, isTrue);
    }
    await enterDraft(tester, 'B의 제목', 'B의 문의 내용');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(repository.createdDrafts.last, (
      user: 'user-b',
      subject: 'B의 제목',
      body: 'B의 문의 내용',
    ));
  });
  testWidgets('인증 이벤트 전달 전 사용자 변경도 기존 초안 제출을 차단한다', (tester) async {
    final repository = _SessionRepository();
    addTearDown(repository.changes.close);
    await pumpCreate(tester, repository);
    await enterDraft(tester, 'A의 제목', 'A의 문의 내용');
    repository.currentUser = 'user-b';
    await submit(tester);
    await tester.pumpAndSettle();
    expect(repository.createdDrafts, isEmpty);
    expect(find.text('로그인 상태가 변경되었습니다. 문의 내용을 다시 작성해 주세요.'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
  });
  testWidgets('계정 변경은 전송 상태를 초기화하고 이전 요청 오류를 무시한다', (tester) async {
    final repository = _SessionRepository();
    final pending = Completer<SupportTicket>();
    repository.pendingCreates.add(pending);
    addTearDown(repository.changes.close);
    await pumpCreate(tester, repository);
    await enterDraft(tester, 'A의 제목', 'A의 문의 내용');
    await submit(tester);
    expect(find.text('제출 중...'), findsOneWidget);
    repository.switchUser('user-b');
    await tester.pumpAndSettle();
    expect(find.text('제출 중...'), findsNothing);
    expect(find.text('문의 제출'), findsOneWidget);
    pending.completeError(const SupportException('이전 계정 요청 오류'));
    await tester.pumpAndSettle();
    expect(find.text('이전 계정 요청 오류'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('로그아웃 후 다시 로그인해도 이전 문의 내용은 남지 않는다', (tester) async {
    final repository = _SessionRepository();
    addTearDown(repository.changes.close);
    await pumpCreate(tester, repository);
    await enterDraft(tester, 'A의 제목', 'A의 문의 내용');
    repository.switchUser(null);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('로그인 후 문의 작성'), findsOneWidget);
    repository.switchUser('user-a');
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
  });
}
