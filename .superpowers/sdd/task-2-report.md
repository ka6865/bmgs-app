# Task 2: 매치 리스트 아이템 UI에 경과 시간 표시 추가 - 작업 리포트

## 1. 작업 개요
- **목적**: 매치 요약 카드(`_MatchCard`)의 상단 맵/모드 렌더링 영역 옆에 몇 시간 전, 몇 일 전 형식의 경과 시간을 표시하여 플레이어의 매치 생성 시각을 직관적으로 확인할 수 있도록 함.
- **수정 대상 파일**: 
  - `lib/features/stats/stats_detail_screen.dart`
  - `test/features/stats/stats_detail_screen_test.dart`

## 2. TDD (Test-Driven Development) 수행 과정

### 2.1. 실패 테스트 작성 (Red Phase)
- `test/features/stats/stats_detail_screen_test.dart` 내 `MockPlayerStatsRepository`의 매치 데이터 생성 시각(`createdAt`)을 상대 시간으로 수정하였습니다.
  - `match-1`의 생성 시간: 현재 시간 기준 5분 전 (`DateTime.now().subtract(const Duration(minutes: 5))`)
  - `match-2`의 생성 시간: 현재 시간 기준 3시간 전 (`DateTime.now().subtract(const Duration(hours: 3))`)
- 매치 요약 카드 내에 "5분 전", "3시간 전" 텍스트가 올바르게 렌더링되는지 검증하는 신규 테스트 케이스 `StatsDetailScreen - 매치 리스트 아이템 UI 경과 시간 표시 검증`을 추가하였습니다.
- **실패 테스트 실행 결과**:
  ```bash
  flutter test test/features/stats/stats_detail_screen_test.dart
  ```
  **출력**:
  ```text
  ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
  The following TestFailure was thrown running a test:
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "5분 전": []>
     Which: means none were found but one was expected
  ```

### 2.2. 코드 구현 (Green Phase)
- `lib/features/stats/stats_detail_screen.dart` 파일 내 `_MatchCard` 위젯 클래스 내부에 `_formatElapsedTime(DateTime dateTime)` 헬퍼 메서드를 구현하였습니다:
  ```dart
  String _formatElapsedTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
  ```
- `_MatchCard` build 메서드의 상단 `Row`에서 맵 이름과 모드를 렌더링하는 `Expanded` 위젯 우측에 경과 시간을 출력하도록 UI 코드를 업데이트하였습니다:
  ```dart
  Row(
    children: [
      Expanded(
        child: Text(
          '${match.mapName} · ${match.gameMode.toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        _formatElapsedTime(match.createdAt),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 8),
      // ...
  ```

### 2.3. 테스트 통과 확인 (Refactor & Verify Phase)
- 단일 위젯 테스트를 수행하여 구현이 올바름을 검증하였습니다:
  ```bash
  flutter test test/features/stats/stats_detail_screen_test.dart
  ```
  **결과**:
  ```text
  00:00 +0: StatsDetailScreen UI 개편 검증 - 탭 필터링, 레이더 차트, 티어 및 그리드
  00:00 +1: StatsDetailScreen - 매치 리스트 아이템 UI 고도화 검증 (우승 하이라이트 및 티어 뱃지)
  00:00 +2: StatsDetailScreen - 플레이어 변경 시 내부 필터 탭 초기화 검증 (ValueKey 테스트)
  00:00 +3: StatsDetailScreen - 매치 리스트 아이템 UI 경과 시간 표시 검증
  00:00 +4: All tests passed!
  ```

## 3. 최종 통합 및 정적 분석 결과

- **전체 테스트 실행 (`flutter test`)**:
  ```text
  00:03 +40: All tests passed!
  ```
- **정적 분석 (`dart analyze`)**:
  ```text
  Analyzing bgms-mobile-app...
  No issues found!
  ```
