---
version: 1
slug: "lib-app-dart"
primary_target: "lib/app.dart"
related_targets: ["lib/navigation/shell_scaffold.dart"]
---

# BGMS 앱 셸 (전 화면)

범위: 앱 전체 셸과 공통 부품. 모드: Operate. 사용자: 가볍게 자주 여는 배그 유저(게임 중/판 사이, 한 손, 어두운 방).
작업: 검색 → 내 기록 → 매치/AI, 지도·도감·커뮤니티를 몇 탭 안에.
제약: 5탭(홈·전적·지도·도감·커뮤니티), 마이는 홈 우상단 프로필, 랭킹은 홈 섹션·전적 안. 네이티브 컨트롤 유지. 이름 BGMS·골드 #F2A900 고정.
미결: 라이트 모드 여부(현재 다크 단일, 사용 장면 근거).

## Direction contract

THESIS: 전적 앱의 "둥근 카드 더미" 대신 배그 인게임 화면의 문법(각진 모서리, 압축된 숫자, 페이즈 단위의 시간)으로 기록을 읽게 한다. 카드 테두리가 아니라 숫자와 생존 페이즈가 주인공.

OWN-WORLD: 올리브 기운이 도는 숯색 바탕(#0E100F)과 3단 표면, 신호색은 배그 골드 #F2A900 하나, 데이터 전용 색은 치킨(골드), 탑10(그린), 킬(레드), 기절(오렌지). 모서리는 둥글림 대신 4~6px 사선 커팅. 큰 숫자는 Barlow Condensed(탭룰러 숫자), 본문은 시스템 한글 서체. 1px 헤어라인과 촘촘한 밀도.

STORY: 앱을 열면 내 계정의 최근 경기가 먼저 보이고, 한 번 탭으로 매치·AI 분석에 들어가며, 정보(지도·도감)와 커뮤니티는 탭 하나 거리에 있다고 믿게 된다.

FIRST VIEWPORT: 홈. 상단 BGMS 워드마크와 우측 프로필·알림, 그 아래 플랫폼이 붙은 검색 한 줄. 이어 "내 계정" 패널: 닉네임·티어·시즌 핵심 숫자 3개(Barlow 큰 숫자)와 최근 경기 5개의 페이즈 스트립. 그 아래 최근 검색·즐겨찾기 가로 목록, 커뮤니티 인기글, 주간 랭킹 상위 3. 주요 행동은 검색과 내 계정 탭.

FORM: 시그니처 무브 = 생존 페이즈 스트립(매치마다 자기장 페이즈 수만큼 칸을 나누고 사망 페이즈까지 채움, 치킨은 골드로 전부). 전적·매치 목록·홈에서 같은 문법으로 반복. 사용자가 "전술 HUD"를 지정해 고정한 방향이라 롤은 생략. seed: none (unavailable)

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
