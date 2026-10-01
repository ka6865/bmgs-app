/// 웹 분류와 기존 앱 작성글을 같은 목록에서 찾기 위한 별칭.
/// 서버는 category를 정확히 비교하므로 목록 조회는 all로 받고 분류한다.
class BoardCategories {
  static const filters = <MapEntry<String, String>>[
    MapEntry('all', '전체'),
    MapEntry('배그 소식', '배그 소식'),
    MapEntry('자유', '자유'),
    MapEntry('듀오/스쿼드 모집', '듀오·스쿼드 모집'),
    MapEntry('클랜홍보', '클랜홍보'),
    MapEntry('제보/문의', '제보·문의'),
    MapEntry('공략', '공략'),
    MapEntry('질문', '질문'),
    MapEntry('공지', '공지'),
  ];

  // 현재 모바일 작성 API가 허용하는 값만 사용한다.
  static const writable = <MapEntry<String, String>>[
    MapEntry('자유', '자유'),
    MapEntry('공략', '공략'),
    MapEntry('질문', '질문'),
    MapEntry('클랜', '클랜홍보'),
  ];

  static String canonical(String value) => switch (value.trim()) {
    'free' => '자유',
    'strategy' => '공략',
    'question' => '질문',
    'notice' => '공지',
    'clan' || '클랜' => '클랜홍보',
    '듀오·스쿼드 모집' => '듀오/스쿼드 모집',
    '제보·문의' => '제보/문의',
    final category => category,
  };

  static bool matches(String filter, String category) =>
      filter == 'all' || canonical(filter) == canonical(category);
}
