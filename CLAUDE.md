# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

작업 규칙(한국어 보고, 작업 루트, 보안 금지 키, 출시 목표, 인수인계 순서)은 `AGENTS.md`가 기준이다. 먼저 읽고 따른다. 이 파일은 명령과 구조만 보충한다.

## 명령

```bash
flutter pub get
flutter test                                   # 전체 테스트
flutter test test/core/network/api_exception_test.dart   # 파일 단위
flutter test --plain-name '프로필 기본 정보를 읽는다'      # 이름으로 단일 테스트
dart analyze                                   # 정적 분석 기준 (flutter analyze는 로컬에서 도구 오류가 날 수 있음)
scripts/run_device.sh [-d <deviceId>]          # 실기기 실행. ../pubg-map-app-local/.env.local에서 Supabase 공개 값만 읽어 dart-define 전달
flutter drive --driver test_driver/integration_test.dart \
  --target integration_test/app_walkthrough_test.dart -d <deviceId>   # 운영 API(bgms.kr)에 실제로 붙는 워크스루
dart run flutter_launcher_icons                # 런처 아이콘 재생성
dart run flutter_native_splash:create          # 스플래시 재생성
```

dart-define: `BGMS_API_BASE_URL`(기본 `https://bgms.kr`), `BGMS_SUPABASE_URL`, `BGMS_SUPABASE_ANON_KEY`, `BGMS_AUTH_REDIRECT_URL`(기본 `bgms://auth-callback`). Supabase 값이 없으면 `main.dart`에서 Supabase를 초기화하지 않고 로그인/게시판 작성/AI 코칭이 비활성 상태가 된다.

## 구조

- 백엔드는 별도 Next.js 프로젝트 `../pubg-map-app-local`이다. 앱은 그 서버의 `/api/...` 라우트만 호출한다. API 계약 확인용으로만 읽고 수정하지 않는다.
- `lib/core/config/app_config.dart`: `AppConfig.local`이 `String.fromEnvironment`로 dart-define 값을 읽는다. 티어 아이콘 URL, 지도 타일 URL(`/tiles/{map}/{z}/{x}/{y}.jpg`, y는 음수 규칙)도 여기서 만든다. 지도 이미지는 앱 번들이 아니라 서버 타일에서 받는다.
- `lib/core/network/bgms_api_client.dart`: dio 기반 단일 API 클라이언트. 모든 실패를 `ApiException`(`api_exception.dart`, `ApiErrorKind`로 분류)으로 정규화한다. 인증 API는 `AuthTokenProvider`로 Supabase access token을 `Authorization: Bearer`에 붙인다.
- `lib/core/providers.dart`: Riverpod 루트 provider(`appConfigProvider`, `dioProvider`, `apiClientProvider`, `supabaseClientProvider`, `authSessionProvider`, 로컬 플레이어 저장소 등). 테스트는 이 provider들을 override한다.
- `lib/features/<기능>/`: 기능별로 `*_models.dart`(`fromJson` 파서) → `*_repository.dart`(`BgmsApiClient` 호출) → `*_screen.dart` 계층을 따른다. 리포지토리는 생성자에서 client를 주입받고, 없으면 `AppConfig.local`로 기본 client를 만든다.
- `lib/navigation/app_router.dart`: go_router. `StatefulShellRoute.indexedStack`의 5개 탭(`/` 홈, `/stats` 전적, `/maps` 지도, `/codex` 도감, `/board` 커뮤니티) + 탭 밖 화면(`/rankings`, `/my`, `/tools/weapons`, `/meta`, `/hotdrop`, `/crates`, `/replay/:matchId`, `/support`, `/notifications`). `createAppRouter()`는 테스트용 의존성 주입 인자를 받는다.
- `lib/app.dart`: `BgmsApp`이 `ProviderScope`를 스스로 포함한다. `enableSuggestions: false`로 위젯 테스트에서 자동완성 네트워크 호출을 끈다. 앱 resume 시 알림 검사를 다시 돈다.
- API 실패 시 가짜 성공 데이터를 보여주지 않고 HTTP 상태/서버 메시지를 화면에 표시하는 것이 원칙이다(README "실패 상태 처리").

- 화면 방향: `lib/core/platform/orientation_policy.dart`. 휴대폰은 세로 고정이고 리플레이 화면과 넓은 화면(짧은 변 600 이상)만 회전한다.
- 디자인 기준: `PRODUCT.md`(제품), `DESIGN.md`(토큰·규칙). 서버 이미지는 `core/widgets/cached_image.dart`로 디스크 캐시한다.

## 테스트 패턴

- `test/support/fake_http_adapter.dart`: 경로별 고정 응답을 주는 Dio 어댑터. `dioProvider`를 이 어댑터가 붙은 Dio로 override해서 네트워크 없이 위젯/계약 테스트를 한다. `requestedPaths`로 호출 경로를 검증한다.
- `test/fixtures/*.json`: 운영 API에서 받아 저장한 실제 응답. `test/live_contract_test.dart`가 파서 계약을 검증하므로 서버 응답 구조가 바뀌면 여기서 먼저 깨진다.
- 테스트 디렉터리는 `lib/` 구조를 따른다(`test/core/...`, `test/features/...`).

## 참고 문서

- `docs/mobile-production-roadmap.md`: 출시 로드맵(AGENTS.md 지정 기준 문서)
- `docs/mobile-design.md`: 모바일 디자인 기준
- `docs/mobile-server-contract-followups-*.md`, `docs/web-mobile-comparison-*.md`: 서버 계약 후속 작업과 웹 대비 차이
