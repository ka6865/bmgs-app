# BGMS 웹 코드 기준 모바일 앱 기능 비교와 개선 우선순위

실제 웹 화면, 서버 API, 데이터 조회 코드와 Flutter 앱을 비교했다. 모바일의 지도·랭킹·기본 전적·게시판은 서버에 연결하는 코드가 이미 있다. 가장 먼저 보완할 부분은 전적의 갱신 상태, 게시판 분류, 상자 추첨 분류처럼 웹과 앱이 같은 데이터를 다르게 해석하는 부분이다. 그다음 기존 API로 제공할 수 있는 경기 이력·비교·고객센터를 연결하는 순서가 적절하다.

검토일은 2026-10-02다. 웹은 `pubg-map-app-local`의 현재 작업트리와 HEAD `984f305`, 모바일은 `main`의 `97bb4d2`를 기준으로 했다. 웹의 학습·일일 경기 콘텐츠에는 기존 미커밋 변경이 포함되어 있어 운영 배포 여부를 별도로 확인해야 한다. 이 문서는 코드 검토 결과이며 실제 운영 DB·OAuth·작성 성공을 보증하지 않는다.

아래 앱 상태는 **수정 전 기준**이다. 이후 사용자 승인에 따라 진행한 단계별 반영과 검증 결과는 [모바일 적용 보고서](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/docs/mobile-implementation-2026-10-02.md)에 기록한다.

## 먼저 바로잡아야 할 구현 차이

### 전적의 오래된 캐시와 부분 갱신을 구분해야 한다

웹 플레이어 API는 일반 조회에서 저장된 전적이 있으면 DB 전적을 반환한다. 응답 캐시의 3분 TTL이 DB 전적 자체를 3분마다 새로 수집한다는 뜻은 아니다. 저장된 전적의 강제 갱신은 `refresh=true`로 요청하며 플레이어별 60초 제한을 적용한다. 외부 전적 조회 경로는 모드별 `statsAvailability`의 `ready/stale/unavailable`을 제공한다. 완전 갱신이 실패하면 이전 `updatedAt`을 유지하고 `retryAfterSeconds`도 반환한다. 일반 DB 캐시 응답에는 이 상태 필드가 없을 수도 있다. [웹 캐시 반환](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/player/route.ts:169), [부분 갱신 상태](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/player/route.ts:416)

앱에는 시즌 선택과 `refresh=true` 호출이 이미 있지만 모드별 상태·재시도 시각을 모델에 저장하지 않는다. 따라서 일부 항목만 새로 갱신된 상태와 이전 캐시를 구분하기 어렵다. 상태 필드는 선택적으로 파싱하고, 누락 시에는 마지막 동기화 시간만 표시해야 한다. 429 응답의 `Retry-After`도 갱신 버튼에 반영할 필요가 있다. [앱 갱신 호출](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/stats_detail_screen.dart:171), [앱 전적 모델](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/player_stats_models.dart:106)

앞선 실기기 조회에서 `TGLTN`의 동기화 시간이 7월 30일이었던 현상은 이 캐시 반환 경로로 설명할 수 있다. 실제 DB가 갱신되지 않은 이유가 일반 조회만 발생했기 때문인지, 강제 갱신의 부분 실패인지, 저장 실패인지는 운영 로그와 DB 이력을 보지 않아 확정하지 않았다.

### 미제공 경기 정보를 실제 기록처럼 표시하지 않아야 한다

웹 요약 API는 분석 데이터→기본 경기 DB→원본 DB→최대 5건의 경량 수집 순서로 보완하고, 남은 `missingMatchIds`와 경기별 성과 상태를 반환한다. 웹 목록도 계산 대기·계산 불가 등을 구분한다. [요약 API](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/matches-summary/route.ts:100), [웹 경기 상태](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/stat/matches/CompactMatchRow.tsx:94)

앱은 누락 경기에 `kills: 0`, `damage: 0`, `createdAt: DateTime.now()`를 넣는다. 실제 카드가 이 값을 표시해 `분석 대기 / 방금 전 / 0킬·0딜량`이 된다. 이 경로는 코드와 [10월 2일 실기기 캡처](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/screenshots/10_stats_matches.png) 모두에서 확인했다. 없는 값은 `-`, 시각은 `경기 시간 확인 전`으로 표시하고, 기본 기록·전술 분석·성과 계산의 상태를 분리하는 것이 우선이다. [앱 fallback 생성](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/player_stats_models.dart:258), [앱 카드 표시](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/widgets/match_card.dart:16)

### 게시판 분류 계약이 서로 다르다

웹 작성 분류는 `배그 소식 / 자유 / 듀오·스쿼드 모집 / 클랜홍보 / 제보·문의`다. 앱은 `free / strategy / question`을 사용한다. 모바일 서버 목록은 요청 분류를 DB의 `category`와 그대로 비교하므로 `free` 요청에 웹의 `자유` 글이 포함되지 않는다. 전체 목록에서는 보일 수 있다. 모바일 작성 API도 영어 분류를 저장하므로 앱 키만 한글로 바꾸면 기존 앱 작성글을 놓칠 수 있다. 웹·앱의 공통 분류와 기존 값의 별칭을 함께 정리해야 한다. [웹 분류](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/BoardWrite.tsx:18), [서버 필터](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/route.ts:125), [앱 분류](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/board/board_screen.dart:29)

### 상자 추첨 그룹을 웹과 같게 분리해야 한다

웹은 관계의 `drop_type`으로 `base / prime / bonus`를 나눈다. 기본 풀에도 프라임 소포 자체가 들어갈 수 있으며, 당첨된 소포의 추가 개봉은 별도 동작이다. 앱은 `drop_type`을 조회하지 않고 `isPrimeParcel`이 아닌 모든 행을 기본 풀로 사용한다. 따라서 기본 풀의 소포를 제외하거나 prime·bonus의 일반 아이템을 기본 추첨에 섞을 수 있다. 풀을 다시 가중 정규화하므로 해당 템플릿에서는 웹과 확률이 달라질 수 있다. [웹 그룹 분리](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/actions/crates.ts:65), [웹 기본 추첨](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/crates/useCratesState.ts:569), [앱 조회 필드](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/crates/crates_repository.dart:28), [앱 기본 풀](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/crates/crate_models.dart:113)

우선 `drop_type=base` 관계를 기본 풀로 사용하고 아직 제공하지 않는 프라임 개봉·보너스 처리를 명확히 표시해야 한다. 현재 활성 템플릿의 실제 관계 구성은 DB를 조회하지 않아 미확인이다. 코드 분류 차이는 확인했지만 모든 활성 상자의 확률이 현재 잘못됐다고 단정하지 않는다.

### 랭킹의 티어 의미와 경기 정보를 보완해야 한다

웹의 `tier`는 최근 7일의 BGMS 전술 분석 최고 경기 점수 순위다. PUBG 시즌 RP 순위로 설명하면 안 된다. 앱은 label이 있으면 숫자 점수를 숨기며, 맵·모드·경기 시각·보조 기록도 모델에 보존하지 않는다. `BGMS 최고 경기` 같은 명확한 설명과 티어·점수·경기 정보를 함께 제공할 필요가 있다. [웹 랭킹 설명](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/rankings/RankingsClient.tsx:376), [앱 모델](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/rankings/ranking_models.dart:17), [앱 점수 표시](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/rankings/rankings_screen.dart:347)

### AI 코칭의 이름과 응답 계약을 맞춰야 한다

앱의 `AI 스쿼드 분석 및 코칭 받기` 버튼은 최근 플레이어 경기의 `/api/pubg/ai-summary`를 호출한다. 웹의 팀 구성별 분석은 `groupKey`를 받는 `/api/pubg/ai-squad`라는 별도 경로다. 현재 앱의 동작은 `최근 경기 AI 코칭`으로 설명하는 것이 정확하다. [앱 버튼](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/ai_coaching_card.dart:84), [앱 실제 요청](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/core/network/bgms_api_client.dart:183), [웹 스쿼드 계약](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/ai-squad/route.ts:128)

웹은 `summaryContractVersion: 2`를 보내며 검증된 `cards`와 AI 해석을 분리한다. 해석에 실패해도 서버가 만든 사실 카드는 유지한다. 앱은 버전을 보내지 않아 서버의 기존 계약을 사용하고, 응답 전체를 받은 뒤 일부 요약 항목만 표시한다. `cards` 레코드와 경기 표본·추세·근거 표시는 지원하지 않는다. 기존 계약이 서버에 남아 있으므로 앱 요청이 무조건 실패한다는 뜻은 아니다. v2 이식 시에는 요청 필드와 모델·화면을 함께 바꾸고 실패 시 사실 카드 보존도 검증해야 한다. [웹 v2 요청](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/stat/RecentAISummary.tsx:678), [서버 버전 분기](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/ai-summary/route.ts:1942), [웹 사실 카드 처리](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/stat/RecentAISummary.tsx:804), [앱 파서](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/ai_coaching_models.dart:160)

## 웹 기능과 앱 구현 비교

아래의 API 존재는 로컬 코드 기준이다. 운영 배포·데이터량·권한 검증 완료와는 별개다.

| 영역 | 실제 웹 기능 | 앱 현재 상태 | 연결에 필요한 작업 |
|---|---|---|---|
| 첫 화면 | 루트에서 에란겔 지도로 이동 | 검색·최근 조회·즐겨찾기 중심의 앱 전용 홈 | 홈 개인화는 UX 제안이며 웹에서 빠진 기능을 복제하는 작업은 아님 |
| 전적 | 시즌·모드 전적, 갱신 상태, 기본·전술·성과 상태 | 기본 지표·시즌·모드·매치 상세 연결 | 갱신/미제공 상태와 세부 정보를 먼저 반영 |
| 경기 이력 | 페이지·일반/경쟁 필터가 있는 저장 경기 목록 | 최근 20개 중심, 전체 보기도 해당 범위 | `/api/pubg/player/matches` 클라이언트·페이지 모델·더 보기 추가 |
| 전적 비교 | 두 플레이어의 딜·킬·교전·팀 지표 비교 | 화면·호출 없음 | `/api/pubg/battle` 활용, 기본 전적과 분석 가능 여부부터 표시 |
| 상대 기록 | 최근 90일 만난 상대, 제재 추적 | 없음 | encounters·ban-watch 연결과 인증 GET 지원 |
| 무기 숙련도 | 플레이어별 무기 숙련도, 캐시·수동 갱신 | 없음 | `/api/pubg/player/weapon-mastery` 모델·화면, 호출 제한 표시 |
| AI 코칭 | 경기 요약 v2, 단일 경기·스쿼드별 분석 | 최근 경기 요약 일부만 표시 | v2 카드와 근거·실패 상태를 먼저 대응, 팀 분석은 별도 기능 |
| 지도 | 6맵·마커·필터, 텔레메트리 재생·핫드랍·자기장 연습 | 6맵·타일·마커·필터·전체화면 | 매치→2D 지도 흐름, 줌에 맞는 타일·밀집 마커 처리 |
| 랭킹 | 딜·킬·BGMS 최고 경기, 필터·경기 정보·자동 갱신 | API·필터·플레이어 이동 연결 | 의미·점수·보조 정보 표시 보완 |
| 게시판 | 서식·이미지·모집/클랜 정보, 답글·추천·수정·삭제·신고 | 목록·상세·이미지 열람·텍스트 작성·일반 댓글 | 분류 일치 후 답글, 회원 작업·첨부 계약 추가 |
| 마이 | 프로필·PUBG 연결 정보·활동 통계·미니 전적·탈퇴 | 프로필/플랫폼 수정·통계·로그아웃·탈퇴 구조 | 실기기 인증 검증, 필요 시 미니 전적·문의 진입 추가 |
| 로그인 | Kakao·Google 진입 | Kakao 진입 | OAuth 복귀·세션 유지 검증, Google 추가는 운영 설정 확인 후 결정 |
| 고객센터 | FAQ, 내 문의·답변·추가 메시지, 개인정보 문의, 증빙 첨부 | 없음 | 기존 support API와 인증 GET을 앱에 연결 |
| 무기 도감 | 총기·파츠 DB, 조합 효과·비교·시뮬레이션 | 없음 | 공개 읽기 데이터 계약과 네이티브 도감·비교 화면 |
| 가방 계산 | 용량·무게·탄약·투척물·파츠·차량 적재 계산 | 없음 | 공개 데이터 전달과 Dart 계산·수량 조작 화면 |
| 상자 | base·prime·bonus, 가상 구매·토큰·보관함 | 기본 1/10회 뽑기·통계·확률 목록 | 그룹 계약부터 일치, 추가 개봉·보너스·보관함은 이후 확장 |
| 학습 콘텐츠 | 일일 랭커 경기·장면·지도 근거, 정적 레슨 | 없음 | 공개 목록/상세 계약과 네이티브 장면 카드, 미커밋 웹 변경 범위 확인 |
| 총기 메타 | 경기 유형·패치별 메타 대시보드 | 없음 | `/api/pubg/meta` 모델·필터·충분한 표본 안내 |
| 리플레이 | 텔레메트리 기반 3D 재생, 지원 맵·보존 기간 제약 | 없음 | 2D 타임라인/장면을 먼저 검토, 3D는 모바일 렌더링·성능 별도 설계 |

대표 코드 근거: [웹 첫 화면](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/page.tsx:35), [앱 전체 라우트](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/navigation/app_router.dart:50), [경기 이력 API](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/player/matches/route.ts:51), [비교 API](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/battle/route.ts:145), [상대 기록](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/encounters/route.ts:14), [무기 숙련도](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/pubg/player/weapon-mastery/route.ts:54).

부가 도구 근거: [웹 무기 데이터와 비교](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/weapons/WeaponsClient.tsx:179), [가방 데이터](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/backpack/BackpackClient.tsx:154), [가방 계산](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/backpackUtils.ts:6), [일일 학습 데이터](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/learn/dailyStories.ts:137), [총기 메타 호출](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/meta/WeaponMetaDashboard.tsx:70), [고급 지도](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/map/MapShell.tsx:387).

무기·가방은 웹 클라이언트가 Supabase 데이터를 직접 읽고, 일일 학습은 서버 조회 함수로 가져온다. 웹 페이지가 존재한다고 해서 앱이 호출할 공개 JSON API도 이미 있다는 뜻은 아니다. 공개 읽기 정책 또는 소비자용 API를 확정해야 하며 `/api/admin/*`를 앱의 데이터 API로 재사용하면 안 된다.

## 게시판과 고객센터의 인증 연결 상태

`withAuthGuard`는 Bearer 토큰을 먼저 검증하고 쿠키 세션도 지원한다. `withOptionalAuth`는 현재 쿠키 세션만 읽는다. 따라서 모든 웹 API에 앱의 Bearer 토큰을 보내면 회원 기능을 사용할 수 있다고 가정하면 안 된다. [필수 인증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/utils/supabase/guard.ts:35), [선택 인증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/utils/supabase/guard.ts:127)

| 기능 | 서버 코드의 현재 계약 | 앱 연결 판단 |
|---|---|---|
| 모바일 글·댓글 작성 | `/api/mobile/board/*`, Bearer 지원 | 이미 연결, 실제 작성 성공은 미검증 |
| 회원 작성·수정 | `/api/posts/write`, 쿠키 회원 인증·revision 충돌 처리 | 회원 수정에 Bearer 지원과 앱 소유 여부/revision 모델 필요 |
| 웹 댓글·신고 | 선택적 쿠키 인증, 비회원 경로 별도 | Bearer만으로 회원 댓글/신고자로 인식되지 않음 |
| 글·댓글 삭제 API | 비회원 비밀번호 검증용, 회원 데이터 삭제는 거절 | 회원 삭제 API로 재사용 불가. 웹은 회원 삭제·추천을 Supabase 직접 호출 |
| 게시판 이미지 | reserve→서명 업로드→complete/release, Bearer 지원 | 업로드 계약은 있으나 모바일 글 저장은 이미지 payload를 400으로 거절 |
| 고객센터 FAQ | 공개 검색·분류 | 앱 화면·모델로 연결 가능 |
| 내 문의·상세·추가 메시지 | support API, Bearer·본인 문의 권한 확인 | 앱 호출과 인증 GET 지원을 추가하면 재사용 가능 |
| 문의 증빙 첨부 | 예약·완료·URL API, Bearer 지원 | 첨부 모델·업로드 연결 필요, 조회 URL은 300초 유효 |
| 계정 삭제 | 쿠키·Bearer 직접 처리 | 앱에 연결됨, 실제 삭제·세션 처리 검증은 별도 |

댓글 답글은 모바일 API가 이미 `parent_id`를 받고 상세가 `parentId`를 반환하지만 앱 모델은 이를 저장하지 않고 작성 요청에도 보내지 않는다. 웹 댓글 경로에는 수신자 알림 생성이 있지만 모바일 댓글 경로에는 그 처리가 없다. 답글 계층은 앱 중심으로 추가할 수 있고, 댓글 알림의 동일한 동작에는 서버 작업이 필요하다. [모바일 답글 계약](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/[postId]/comments/route.ts:34), [앱 댓글 모델](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/board/board_models.dart:123), [웹 댓글 알림](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/board/comments/route.ts:287)

모바일 상세 API는 댓글을 오래된 순서로 최대 50개만 반환하고 댓글 페이지 조회를 제공하지 않는다. 답글 UI를 추가해도 51번째 이후 댓글·답글은 현재 응답에 포함되지 않으므로 댓글 조회 확장도 함께 필요하다. [서버 댓글 제한](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/[postId]/route.ts:90)

사진 선택기만 추가하면 게시판 사진 작성이 완성되는 구조는 아니다. 업로드 예약과 저장 소유권, 본문 이미지 연결, 서버의 모바일 이미지 거절을 함께 처리해야 한다. 현재 앱의 열람은 이미지를 먼저 보여주고 본문을 일반 텍스트로 표시하므로 웹의 본문 내 이미지 위치·서식·링크도 유지되지 않는다. [모바일 이미지 거절](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/route.ts:177), [앱 본문 표시](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/board/board_detail_screen.dart:127)

고객센터는 새 백엔드를 통째로 만들 필요가 없다. FAQ·문의·메시지·개인정보 대상 확인·첨부 API가 있다. 앱의 공통 GET은 인증 헤더를 붙이지 않으므로 내 문의와 첨부 조회에는 인증 GET을 보완해야 한다. [문의 API](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/support/tickets/route.ts:10), [앱 GET](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/core/network/bgms_api_client.dart:338)

## 모바일 화면과 호출 흐름의 개선 방향

다음은 코드·기존 실기기 관찰을 바탕으로 한 개선 제안이다.

- 홈에는 최근 조회 선수의 요약·변화와 도구 진입을 제공한다. 웹 루트는 지도이므로 개인화 홈은 모바일의 독자적인 UX 선택이다. 하단 탭을 계속 늘리지 않고 홈 또는 마이에 도구 목록을 둔다.
- 전적은 핵심 지표와 최근 경기 결과를 먼저 보여주고 상세 차트·AI 근거는 펼쳐보게 한다. 누락·기본 기록·분석 완료 상태는 시각적으로 구분한다.
- 지도는 기본 활성 레이어를 줄이고 줌에 맞춰 마커를 집계한다. 앱의 고정 z2 타일 16장을 확대하는 방식은 상세 줌을 위한 타일 갱신과 다르므로 후속 개선이 필요하다. 사용자 화면의 `tile z2` 문구도 제거 대상이다. [앱 타일 구성](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/maps/maps_screen.dart:476)
- 검색창 안내 잘림, 게시판 제목의 단어 중간 줄바꿈, 지도 버튼 대비를 보완한다. 큰 글꼴·VoiceOver·Android 보조기술의 실제 검증은 별도다.
- 첫 전적 조회에서 앱은 서버의 경량 요약 보완이 끝난 뒤에도 누락 최대 4건에 상세 분석 API를 호출하며 이를 모두 기다린다. 먼저 프로필·기본 목록을 표시하고 선택한 경기에서 상세 분석을 요청하는 흐름을 검토한다. 실제 지연·호출 수는 측정하지 않았으므로 성능 개선 효과를 수치로 단정하지 않는다. [앱 추가 상세 호출](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/player_stats_repository.dart:71), [전체 결과 대기 화면](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/stats/stats_detail_screen.dart:315)
- 알림 확인도 같은 전적 repository의 일반 조회를 사용한다. 새 경기 감지는 DB 전적의 갱신 주기에 영향을 받으므로 수집 주기·알림 신선도를 먼저 확인하고, 상세 분석을 동반하지 않는 가벼운 확인 경로를 검토한다. 모든 확인을 무조건 `refresh=true`로 바꾸면 호출 제한에 영향을 줄 수 있다. [앱 알림 조회](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/notifications/notification_service.dart:84)

웹 마이의 `PUBG API 정상(Connected)` 문구와 재연동 버튼은 현재 정적 표시이며 재연동 처리 함수가 없다. 이를 실제 연동 확인 기능으로 집계하지 않았다. [웹 마이 표시](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/mypage/MyPage.tsx:354)

## 권장 작업 순서와 완료 기준

| 순서 | 작업 | 서버 변경 범위 | 완료 기준 |
|---|---|---|---|
| 1 | 전적 상태·미제공 값·갱신 제한 표시 | 기존 응답 활용, 운영 갱신 이력 확인 필요 | 부분 성공·오래된 캐시·미제공 경기·429를 실제 값과 구분 |
| 1 | 게시판 분류와 상자 추첨 분류 일치 | 게시판 공통 분류/별칭은 서버와 협의, 상자는 앱 조회·모델 수정 중심 | 웹/앱 작성글이 같은 분류로 검색, base/prime/bonus 혼합 데이터에서도 기본 풀 일치 |
| 1 | 랭킹 의미·AI 버튼 이름 정리 | 앱 중심 | BGMS 경기 점수와 PUBG RP를 구분, 버튼이 실제 제공하는 분석을 설명 |
| 2 | 경기 이력·비교·답글 | 기존 API 재사용 중심 | 페이지/필터·분석 불가 상태·답글 계층과 작성 왕복 확인 |
| 2 | 고객센터 | 기존 Bearer API 재사용, 앱 인증 GET 추가 | 본인 문의 목록·상세·추가 메시지·첨부 만료 처리 확인 |
| 2 | AI v2 카드 | 기존 API 재사용, 요청·모델·UI 함께 수정 | 사실/해석 분리, 표본 표시, AI 실패 시 사실 유지, 인증·비용 제한 확인 |
| 3 | 무기 도감·학습·가방·총기 메타 | 무기/가방/학습의 공개 읽기 계약 확인·추가 | 공개 데이터만 사용, 모바일 조작과 데이터 부재 상태 확인 |
| 3 | 매치 지도·핫드랍·상대 기록·3D | 일부 기존 API, 네이티브 시각화·인증·보존 기간 설계 | 2D 장면부터 검증, 3D는 지원 맵·성능 측정 후 확장 |

Android·iOS OAuth 복귀·세션 유지·쓰기 권한·알림·스토어 내부 테스트는 위 기능 개선과 별도의 출시 확인 항목이다. 한쪽 플랫폼만 공개하는 것으로 완료 처리하지 않는다.

소비자 앱에 그대로 옮길 대상에서 관리자 화면·지도 편집기·좌표 테스트·Overwolf 데스크톱 연동을 제외했다. 서버 수집·AI 생성·발행·관리 로직과 비밀키는 서버에 유지한다. 웹 SEO·광고 배치·브라우저 드래그 방식도 모바일 구현 요구로 집계하지 않았다.

## 검증 범위와 남은 확인

- 웹·앱의 실제 화면 및 데이터 호출 경로를 분담 검토하고 주요 불일치를 원본 코드로 다시 확인했다. 웹 코드는 변경하지 않았다.
- Flutter 3.44.4 / Dart 3.12.2를 확인했고 `flutter pub get`을 완료했다. 이번 요청에서는 앱 코드 변경·빌드·테스트 재실행을 하지 않았다. 앞선 `97bb4d2` 검증의 225개 테스트·정적 분석·iOS 워크스루 결과는 별도 [실기기 점검 기록](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/docs/mobile-audit-2026-10-01.md)에 있다.
- 운영 DB·RLS·Storage·공개 API 배포·OAuth 설정·실제 작성/삭제/신고/문의·유료 AI 호출은 이번 코드 비교에서 확인하지 않았다.
- 기존 AGENTS·로드맵의 “랭킹·지도 API 추가 전 fallback” 설명은 현재 코드와 다르다. 실제 API와 앱 호출이 있으므로 앞으로의 작업을 API 신설로 잘못 분류하지 않아야 한다.
