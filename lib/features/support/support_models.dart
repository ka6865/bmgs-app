const supportCategories = <String, String>{
  'account': '계정',
  'community': '커뮤니티',
  'bug': '오류 제보',
  'other': '기타',
  'privacy': '전적 비공개',
};

const supportFaqCategories = <String, String>{
  '': '전체',
  'stats': '전적',
  'account': '계정',
  'community': '커뮤니티',
  'feature': '기능',
};

class SupportFaq {
  const SupportFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });
  final String id;
  final String category;
  final String question;
  final String answer;
  factory SupportFaq.fromJson(Map<String, dynamic> json) => SupportFaq(
    id: _text(json['id']),
    category: _text(json['category']),
    question: _text(json['question']),
    answer: _text(json['answer']),
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.updatedAt,
    this.unread = false,
    this.messages = const [],
    this.attachments = const [],
  });
  final String id;
  final String category;
  final String subject;
  final String status;
  final String updatedAt;
  final bool unread;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;
  String get statusLabel => switch (status) {
    'new' => '접수',
    'in_progress' => '처리 중',
    'awaiting_user' => '추가 정보 요청',
    'answered' => '답변 완료',
    'resolved' => '해결됨',
    'rejected' => '반려',
    _ => '상태 확인 필요',
  };
  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: _text(json['id']),
    category: _text(json['category']),
    subject: _text(json['subject']),
    status: _text(json['status']),
    updatedAt: _text(
      json['updated_at'] ?? json['last_message_at'] ?? json['created_at'],
    ),
    unread: json['unread'] == true,
    messages: _rows(json['messages']).map(SupportMessage.fromJson).toList(),
    attachments: _rows(
      json['attachments'],
    ).map(SupportAttachment.fromJson).toList(),
  );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.body,
    required this.senderType,
    required this.createdAt,
  });
  final String id;
  final String body;
  final String senderType;
  final String createdAt;
  bool get fromAdmin => senderType == 'admin';
  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: _text(json['id']),
    body: _text(json['body']),
    senderType: _text(json['sender_type']),
    createdAt: _text(json['created_at']),
  );
}

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.name,
    required this.status,
  });
  final String id;
  final String name;
  final String status;
  factory SupportAttachment.fromJson(Map<String, dynamic> json) =>
      SupportAttachment(
        id: _text(json['id']),
        name: _text(json['original_name']),
        status: _text(json['status']),
      );
}

List<Map<String, dynamic>> supportRows(Object? json) => _rows(json);
List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : [];
String _text(Object? value) => value is String
    ? value
    : value is num
    ? value.toString()
    : '';
