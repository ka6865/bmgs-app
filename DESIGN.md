---
name: BGMS
description: 배그 인게임 HUD의 문법으로 내 전적을 읽는 다크 전용 모바일 앱
colors:
  pubg-gold: "#F2A900"
  on-gold: "#14110A"
  olive-charcoal: "#0E100F"
  surface: "#161917"
  elevated: "#20241F"
  hairline: "#FFFFFF1F"
  glass-bar: "#121513F2"
  text-primary: "#F4F3EE"
  text-secondary: "#F4F3EEB3"
  text-muted: "#F4F3EE80"
  top10-green: "#57C785"
  kill-red: "#E5484D"
  knock-orange: "#F08A24"
  defeat-gray: "#8B958C"
  item-slot: "#B4B8AC"
  tier-master: "#D8B4FE"
  tier-survivor: "#FDE68A"
  tier-diamond: "#67E8F9"
  tier-crystal: "#7DD3FC"
  tier-platinum: "#5EEAD4"
  tier-gold: "#FCD34D"
  tier-silver: "#CBD5E1"
  tier-bronze: "#FB923C"
typography:
  number-hero:
    fontFamily: "Barlow Condensed"
    fontSize: "56px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  number-lg:
    fontFamily: "Barlow Condensed"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  number-md:
    fontFamily: "Barlow Condensed"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  number-sm:
    fontFamily: "Barlow Condensed"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  number-xs:
    fontFamily: "Barlow Condensed"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1
    fontFeature: "tnum"
  title:
    fontFamily: "system-ui, -apple-system, Roboto, sans-serif"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.27
    letterSpacing: "0em"
  title-sm:
    fontFamily: "system-ui, -apple-system, Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 800
    lineHeight: 1.5
  body:
    fontFamily: "system-ui, -apple-system, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
  body-sm:
    fontFamily: "system-ui, -apple-system, Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
  label:
    fontFamily: "system-ui, -apple-system, Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.33
    letterSpacing: "0em"
rounded:
  cut: "6px"
  cut-sm: "4px"
  sm: "3px"
  md: "4px"
  lg: "6px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
components:
  button-primary:
    backgroundColor: "{colors.pubg-gold}"
    textColor: "{colors.on-gold}"
    rounded: "{rounded.cut}"
    height: "48px"
  button-outlined:
    backgroundColor: "{colors.olive-charcoal}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.cut}"
    height: "48px"
  button-text:
    textColor: "{colors.pubg-gold}"
    height: "44px"
  chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.cut-sm}"
  chip-selected:
    backgroundColor: "{colors.pubg-gold}"
    textColor: "{colors.on-gold}"
    rounded: "{rounded.cut-sm}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
  panel:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.cut}"
    padding: "16px"
  match-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.cut}"
    padding: "12px 14px"
  weapon-slot:
    backgroundColor: "{colors.item-slot}"
    rounded: "{rounded.cut-sm}"
  nav-bar:
    backgroundColor: "{colors.glass-bar}"
    textColor: "{colors.text-secondary}"
  nav-bar-selected:
    textColor: "{colors.pubg-gold}"
  phase-cell-empty:
    backgroundColor: "{colors.elevated}"
    height: "6px"
---

# Design System: BGMS

<!-- 근거: 2026-11-13 iPhone 17 시뮬레이터(iOS 26.5) 캡처 21장과 lib/core/theme/bgms_theme.dart, lib/core/widgets/*. 계획이 아니라 출하된 코드 기준. -->

## Overview

**Creative North Star: "전술 HUD (Operate 모드)"**

BGMS는 전적 앱의 "둥근 카드 더미" 대신 배그 인게임 화면의 문법으로 기록을 읽게 한다. 화면의 주인공은 카드 테두리가 아니라 압축된 숫자와 생존 페이즈다. 올리브 기운이 도는 숯색 바탕 위에 표면 3단을 쌓고, 신호색은 배그 골드 하나만 쓴다. 판과 판 사이에 한 손으로, 어두운 방에서 짧게 확인하는 사용 장면에 맞춰 밀도는 촘촘하고 장식은 없다.

모양 언어는 사선으로 잘린 모서리(베벨)다. 패널·버튼·칩·스낵바가 모두 테마 단계에서 베벨 모양을 받는다. 큰 숫자는 Barlow Condensed 탭룰러 숫자로 자릿수를 맞추고, 그 외 글은 OS 시스템 서체(한국어 기준)를 그대로 쓴다. 깊이는 그림자가 아니라 표면 명도 단계와 1px 헤어라인으로 만든다.

이 체계는 아직 절반만 이식됐다. 홈·전적(요약/매치)·도감 진입·무기 도감·스쿼드 분석·랭킹·공통 패널은 새 문법을 따르지만, 지도·게시판·메타·핫드랍·상자깡 화면과 전적 상세 내부 일부는 이전 웹 이식 스타일(둥근 모서리, 원시 Container 장식)을 그대로 쓴다. 다크 테마 하나만 있다(라이트 모드 미결).

**Key Characteristics:**
- 다크 전용, 올리브 숯색 바탕과 3단 표면(바탕 → 표면 → 상승)
- 신호색은 골드 하나, 데이터 색은 순위 의미가 있을 때만
- 둥글림 대신 4~6px 사선 커팅
- 큰 숫자는 Barlow Condensed 700 탭룰러, 본문은 시스템 서체
- 시그니처: 생존 페이즈 스트립(경기마다 9칸, 탈락 페이즈까지 채움)
- 그림자 없음, 1px 헤어라인과 표면 명도로 깊이 표현

## Colors

올리브 숯색 단색 계열 위에 골드 신호 하나와 순위 전용 데이터 색 몇 개를 얹는 팔레트다.

### Primary
- **배그 골드** (pubg-gold): 브랜드 고정색(PRODUCT.md). 주요 버튼, 선택된 칩·세그먼트·탭·하단 탭, 텍스트 버튼, 치킨(1위) 순위 숫자·페이즈 스트립·카드 테두리, 랭킹 상위 값, 홈 워드마크. 코드 전체에서 가장 많이 쓰이는 색 토큰이다(약 77회).
- **골드 위 글자** (on-gold): 골드 면 위의 글자와 체크 표시. 순흑 대신 따뜻한 검정.

### Secondary (데이터 색)
- **탑10 그린** (top10-green): 2~10위 경기의 순위 숫자, 페이즈 스트립 채움, 매치 카드 테두리(55% 투명도). 성공 상태(success)와 같은 값을 공유한다.
- **기절 오렌지** (knock-orange): 기절 지표용. 현재 스쿼드 분석 화면 한 곳에서만 쓴다.
- **킬 레드** (kill-red): 킬 지표와 오류 상태(ErrorPanel 아이콘, 14% 배경). 테마의 error 역할도 맡는다.
- **탈락 회색** (defeat-gray): 11위 이하 경기의 페이즈 채움과 카드 테두리(25% 투명도). 의미 없는 회색이 아니라 "탈락"을 뜻하는 데이터 색이다.

### Tertiary (티어 색)
- **티어 8색** (tier-master ~ tier-bronze): PUBG 랭크 티어 이름과 엠블럼 강조에만 쓴다. 웹 TIER_STYLE과 대응한다. 티어가 없으면 text-muted로 떨어진다.

### Neutral
- **올리브 숯색 바탕** (olive-charcoal): 스캐폴드와 앱바 배경.
- **표면** (surface): 패널, 카드, 입력창, 미선택 칩.
- **상승 표면** (elevated): 스켈레톤, 페이즈 스트립 빈 칸, 아이콘 받침, 진행 막대 트랙, 스낵바.
- **헤어라인** (hairline): 흰색 12%. 패널 테두리, 구분선, 미선택 칩·버튼 테두리.
- **유리 막대** (glass-bar): 하단 탭 막대 배경(95% 불투명) + 16px 블러.
- **글자 3단** (text-primary / text-secondary 70% / text-muted 50%): 본문 / 보조 설명·라벨 / 메타 정보·이동 화살표.
- **아이템 칸** (item-slot): 무기 렌더 뒤의 밝은 회녹색 칸. 무기 이미지가 투명 배경의 검은 총기라서 어두운 표면 위에서는 보이지 않기 때문에 둔 기능 색이다. 무기 이미지 뒤에만 쓴다.

### Named Rules
**The One Signal Rule.** 신호색은 골드 하나다. 선택·주요 행동·치킨만 골드를 받는다. 새 강조색을 만들지 않는다.

**The Data-Only Color Rule.** 그린·레드·오렌지·탈락 회색은 순위·킬·기절이라는 데이터 의미가 있을 때만 쓴다. 장식이나 섹션 구분용으로 쓰지 않는다.

## Typography

**Display Font:** Barlow Condensed SemiBold/Bold (번들 폰트, OFL)
**Body Font:** OS 시스템 서체(iOS SF/Apple SD 산돌고딕 Neo, Android Roboto/Noto Sans KR), Material 2021 타입 스케일
**Label/Mono Font:** 별도 없음

홈의 BGMS 워드마크는 시스템 서체 900 이탤릭(headlineSmall, 골드)으로 그려진다. 로고 자산이나 전용 서체가 아니라 시스템 서체를 디스플레이로 쓴 임시 상태라 타입 토큰으로 올리지 않는다. 다른 화면에서 이 처리를 따라 쓰지 않는다.

**Character:** 좁고 단단한 Condensed 숫자가 HUD 계기판처럼 자릿수를 맞추고, 한국어 본문은 시스템 서체로 읽기 편하게 둔다. 숫자와 글이 서체로 역할을 나눈다.

### Hierarchy
- **Number hero** (number-hero): 스쿼드 분석 등급(B- 등) 한 곳.
- **Number large** (number-lg): 홈 "내 계정" 패널의 시즌 핵심 숫자 3개(K/D·평균 딜·승률).
- **Number medium** (number-md, 실사용 20~28px): 매치 카드 순위(24), 무기 피해(22), 랭킹 값(20~22), 무기 비교(20·28).
- **Number small** (number-sm / number-xs): 홈 최근 경기 행의 순위(18)와 킬·딜(15), 홈 랭킹 값(18).
- **Title** (title): 화면 제목(ScreenHeader), 닉네임.
- **Title small** (title-sm): 섹션 카드 제목, 패널 제목, 맵 이름.
- **Body / Body small** (body, body-sm): 설명, 오류 메시지, 보조 문구.
- **Label** (label): 섹션 밴드 제목(text-secondary), 지표 이름. 자간 0.

### Named Rules
**The Tabular Number Rule.** 비교되는 숫자(순위, 킬, 딜, K/D, 피해, 점수)는 `BgmsText.number`로 쓴다. 시스템 서체로 큰 숫자를 쓰지 않는다. 기존 `StatCell`은 아직 시스템 서체 titleLarge 900을 쓴다(미이식).

## Layout

세로 한 열 모바일 레이아웃이다. 화면 좌우 여백 16px, 위아래 12px(BgmsSpacing.screen), 패널 안쪽 16px(BgmsSpacing.card). 여백 단계는 4·8·12·16·20px이며 8px(sm)과 12px(md)가 가장 많이 쓰인다. 섹션은 SectionBand(작은 라벨 + 내용, 간격 10px)로 나누고 카드 안에 카드를 넣지 않는다.

하단 탭은 5개(홈·전적·지도·도감·커뮤니티)이고, 랭킹·마이·도구·상세는 탭 밖에서 push되는 화면이다. 탭 화면은 왼쪽 정렬 큰 제목(ScreenHeader), push 화면은 가운데 제목 앱바 + 뒤로가기다. 매치 카드는 너비 352px 미만이거나 글자 크기 확대 시 킬·딜을 아래 줄로 내린다. 태블릿·가로 레이아웃은 없다.

터치 영역은 버튼 최소 48px, 텍스트 버튼 44px, 그룹 목록 행 56px.

## Elevation & Depth

그림자가 없는 평면 체계다. 모든 패널·카드·앱바의 elevation은 0이고, surfaceTint도 끈다. 깊이는 바탕 → 표면 → 상승 표면의 명도 단계와 1px 헤어라인 테두리로만 나타낸다. 하단 탭 막대만 예외로 16px 배경 블러와 상단 헤어라인을 쓴다.

### Named Rules
**The Flat HUD Rule.** 그림자를 쓰지 않는다. 강조가 필요하면 테두리 색(골드·그린·탈락 회색)을 바꾼다. 상자깡 결과 카드의 희귀도 발광 그림자는 이 규칙 밖의 구 스타일이다.

## Shapes

둥근 모서리 대신 사선으로 잘린 모서리(BeveledRectangleBorder)가 기본이다. 큰 표면(패널, 카드, 그룹 목록, 주요·외곽선 버튼, 스낵바)은 6px 커팅, 작은 요소(칩, 세그먼트 버튼, 무기 아이템 칸)는 4px 커팅. 둥근 반경은 입력창(4px), 스켈레톤(3px), 아이콘 받침(4px)에만 남는다. 페이즈 스트립 칸은 반경 없는 직각이다.

**The Cut Corner Rule.** 새 표면은 `BgmsShape.panel()`로 만든다. `BorderRadius.circular`로 새 카드·칩·버튼을 만들지 않는다.

현재 상태: 테마 밖에서 `Radius.circular`가 58곳 남아 있다(매치 상세 13, 전적 상세 9, 홈 대시보드 섹션 7, AI 코칭 4, 지도 4, 검색창 4, 기타). 전적 상세의 모드 칩(20px 알약형)과 경쟁전/일반전 토글이 화면에서 둥글게 보이는 대표 사례다. 이는 미이식 부채이며 규칙이 아니다.

## Components

### Buttons
- **Shape:** 6px 사선 커팅(rounded.cut), 최소 48×48.
- **Primary:** 골드 면, on-gold 글자 800. 검색 실행, 다시 시도, 주요 행동.
- **Outlined:** 투명 면, 헤어라인 테두리, text-primary 글자. 보조 행동(예: 랭킹 "최신 랭킹").
- **Text:** 골드 글자, 최소 44px. 섹션 "전체" 링크, 패널 내부 재시도.
- **Segmented:** 선택 칸 골드 면 + on-gold, 미선택 표면 + text-primary, 4px 커팅(랭킹 딜량/킬/BGMS 점수, 홈 Steam/Kakao).

### Chips
- **Style:** 표면 면, 헤어라인 테두리, 4px 커팅(테마 ChoiceChip).
- **State:** 선택 시 골드 면 + on-gold 체크·글자. 랭킹 필터가 테마를 그대로 따른다. 전적 모드 칩은 아직 20px 둥근 모양으로 덮어쓴다(미이식).

### Cards / Containers
- **BgmsCard / panel:** 표면 면, 6px 커팅, 헤어라인 테두리, 안쪽 16px. 상태는 테두리 색으로만 표시한다(치킨 = 골드 100%, statusColor = 55%).
- **SectionCard / InfoPanel / ErrorPanel / LoadingCard:** 테마 Card(같은 베벨) + 제목 title-sm 800 + 본문. Info/Error는 40px 아이콘 받침(상승 표면 또는 레드 14%)을 왼쪽에 둔다. Error는 서버 메시지를 그대로 보여주고 재시도 가능하면 골드 "다시 시도" 버튼을 붙인다.
- **SectionBand:** 카드 없이 작은 라벨(15px 아이콘 + label, text-secondary)과 내용만 놓는 섹션 틀. 반복 카드가 들어가는 섹션은 이것을 쓴다.
- **GroupedList / GroupedRow:** 베벨 패널 하나에 56px 행을 헤어라인(왼쪽 56px 들여쓰기)으로 나눈다. 행 아이콘은 골드, 오른쪽 화살표는 text-muted. 도감 탭과 마이에서 쓴다.

### Inputs / Fields
- **Style:** 표면 채움, 헤어라인 테두리, 4px 반경(둥근 모서리, 테마 기본값). 힌트 text-muted, 앞 아이콘 text-secondary.
- **Focus:** 테두리가 골드로 바뀐다.

### Navigation
- **하단 탭:** 5개, 유리 막대(glass-bar + 블러 16) + 상단 헤어라인. 아이콘 22px, 라벨 11px. 선택 시 골드 아이콘·라벨 800과 골드 15% 알약형 인디케이터, 미선택은 text-secondary 500. 인디케이터 모양은 Material 기본(알약형)이다.
- **화면 헤더:** 홈만 BgmsBrandHeader(워드마크 + 알림·프로필, 워드마크 서체는 Typography 참고), 그 외 탭은 ScreenHeader(제목 22px 800 + 한 줄 상태 문구).
- **탭 안 하위 탭:** TabBar, 골드 라벨·인디케이터, 헤어라인 구분선(전적 요약/매치/AI 분석).

### Match Card
한 경기 = 한 카드. 왼쪽 순위 블록(#순위, Barlow 24, 치킨 골드 / 탑10 그린 / 그 외 text-secondary), 가운데 맵 이름(title-sm 800)·모드·티어·경과 시간(label-sm, text-muted)과 페이즈 스트립, 오른쪽 킬·딜량(Barlow 20) + 화살표. 테두리는 순위 의미 색. 화면 낭독기는 카드를 한 문장으로 읽는다.

### Weapon Row
베벨 그룹 패널 안의 행. 왼쪽 아이템 칸(item-slot, 4px 커팅) 위에 무기 렌더, 이름(title-sm)·분류·탄약(text-secondary), 오른쪽 피해 숫자(Barlow 22) + 비교 체크박스.

### Survival Phase Strip (시그니처)
경기마다 자기장 페이즈를 가로 칸으로 나누고 탈락 페이즈까지 채운다. 높이 6px, 칸 사이 2px, 직각. 채움 색은 치킨 골드(전 칸) / 탑10 그린 / 탈락 회색, 빈 칸은 상승 표면. 페이즈 정보가 없으면 칸을 비우고 헤어라인 테두리만 그려 "0페이즈"와 구분한다. 홈 내 계정 패널(최근 5경기)과 매치 카드에서 같은 문법으로 반복한다. 화면 낭독기 라벨은 "자기장 N페이즈에서 탈락".

현재 한계: 맵별 실제 페이즈 수 대신 9칸 고정이다(코드에 shortcut 주석). 서버가 맵별 페이즈 수를 주면 바꾼다.

### Loading
SkeletonBox: 상승 표면 블록, 3px 반경, 1.1초 주기로 불투명도 35%↔70% 왕복. LoadingCard는 첫 줄 22px·폭 160, 이후 14px 줄로 실제 레이아웃 높이를 유지한다.

## Do's and Don'ts

### Do:
- **Do** 새 표면은 `BgmsCard` 또는 `BgmsShape.panel()`(6px 커팅, 작은 요소 4px)로 만든다.
- **Do** 비교되는 숫자는 `BgmsText.number`(Barlow Condensed 700, 탭룰러)로 쓴다.
- **Do** 경기 결과는 페이즈 스트립과 순위 의미 색(골드/그린/탈락 회색)으로 같은 문법을 반복한다.
- **Do** 강조는 그림자 대신 테두리 색과 표면 명도 단계로 한다.
- **Do** 무기 렌더는 item-slot 칸 위에 올린다.
- **Do** 로딩·빈 상태·오류는 LoadingCard / InfoPanel / ErrorPanel로 모든 화면에서 같게 다루고, 측정하지 않은 값은 "-"나 "정보 없음"으로 둔다.

### Don't:
- **Don't** 골드 외의 강조색을 새로 만들거나, 브랜드 골드를 다른 노랑(예: 랭킹 1위 #FFD54F)으로 대체하지 않는다.
- **Don't** 그린·레드·오렌지를 데이터 의미 없이 장식으로 쓰지 않는다.
- **Don't** `BorderRadius.circular`로 새 카드·칩·버튼을 만들지 않는다. 남은 58곳은 이식 대상이지 선례가 아니다.
- **Don't** 카드 안에 카드를 넣지 않는다. 반복 항목 섹션은 SectionBand를 쓴다.
- **Don't** 그림자로 깊이를 만들지 않는다.
