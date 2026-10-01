# 일일 랭커 학습의 모바일 공개 계약 제안

2026-10-02 기준 계약 제안이며 구현된 API가 아니다.

## 확인한 차단 원인

웹 `lib/learn/dailyStories.ts`의 목록·상세 함수는 서버에서 service_role 키를 사용한다. `supabase/migrations/20260927145237_daily_ranker_stories_by_mode.sql`은 `daily_ranker_stories`에 RLS를 켜고 public/anon/authenticated 접근을 회수한다. 루트 담당의 실제 anon REST 읽기는 401 permission denied였다. 모바일에서 서버 키를 사용하거나 테이블 권한을 풀어 우회하지 않는다.

## 필요한 읽기 API

- `GET /api/mobile/learn/daily?day=YYYY-MM-DD&limit=30&cursor=...`: 게시된 이야기 목록. day는 선택, KST 날짜로 정의하며 실제 달력 날짜를 검증한다. limit은 1~100으로 제한하고 같은 날짜 안에서 모드를 정렬한다. 응답은 `{ entries, nextCursor }`. cursor에는 마지막 `(dayKst, mode)`를 사용하고 서버에서 검증한다.
- `GET /api/mobile/learn/daily/{day}/{mode}`: 하나의 게시된 이야기. mode는 solo/duo/squad만 허용한다. 응답은 `{ story }`이며 없거나 비공개면 404, 잘못된 입력은 400, 저장소 실패는 503이다. 빈 목록 200과 실패 503을 구분한다.

목록 entry의 허용 필드: `dayKst, mode, nickname, mapName, leaderboardRank, publishedAt, kills, damage, headline, conclusion, sceneCount, leaderboardObservedAt, leaderboardSeason, leaderboardSource`.

상세 story는 목록 필드에 `matchId, playedAt, teamKills, points[{text,evidenceIds}], facts, weapons, killEvents, teamKillEvents, roster, encounters, route, aircraft, zones, blueZoneSamples, limitations, scenes, schemaVersion, evidenceVersion`를 추가한다. 선택 필드의 누락을 허용하며 좌표계·거리(m)·시간(경기 시작 이후 초)을 계약에 명시해야 한다. scenes 구조와 facts는 웹의 타입을 기반으로 서버에서 버전별 검증해야 하며, 임의 JSON을 검증 없이 그대로 공개하지 않는다.

## API 구현·인수 조건

서버만 privileged DB 읽기를 수행하고 소비자 응답에는 허용한 게시 데이터만 담는다. 원본 evidence 전체, 내부 selection/rejectedReasons, 생성 프롬프트, 운영 정보는 공개하지 않는다. 닉네임·팀원·피해자 등 식별 정보의 공개 동의/비공개 플레이어 정책을 목록·상세·리플레이에 동일 적용한다. 공개 정책 변경의 캐시 무효화와 요청 제한도 서버에서 정의한다.

모바일 인수는 목록→날짜·모드 선택→상세→근거 장면 순서로 구현한다. 현재 차단 상태는 읽기 API 미구현이며, 단순한 anon 권한 오류나 mock 이야기로 성공 상태를 대신하지 않는다. API 공개 정책, 타입·버전, 실패 계약과 개인정보 필터가 통과하면 목록·상세 위젯 테스트를 추가한다. 실기기 지도·장면 제스처와 오래된 schemaVersion QA는 별도 출시 검증이다.
