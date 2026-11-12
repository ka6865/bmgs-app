/// 웹 분류와 기존 앱 작성글을 같은 목록에서 찾기 위한 별칭.
/// 서버의 분류별 별칭 조회를 사용하고 응답 분류도 확인한다.
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

  static const writable = <MapEntry<String, String>>[
    MapEntry('배그 소식', '배그 소식'),
    MapEntry('자유', '자유'),
    MapEntry('듀오/스쿼드 모집', '듀오·스쿼드 모집'),
    MapEntry('클랜홍보', '클랜홍보'),
    MapEntry('제보/문의', '제보·문의'),
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
