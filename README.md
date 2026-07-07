# BGMS Mobile App

BGMS Flutter 모바일 앱 MVP입니다. 기존 Next.js 웹 프로젝트와 분리된 앱으로 만들며, 전적/AI/랭킹/지도 데이터는 모바일 앱용 API 계약을 통해 연결합니다.

## 실행

```bash
flutter pub get
flutter run \
  --dart-define=BGMS_API_BASE_URL=http://localhost:3000 \
  --dart-define=BGMS_SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=BGMS_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=BGMS_AUTH_REDIRECT_URL=bgms://auth-callback
```

실기기에서는 `localhost`가 기기 자신을 가리키므로 `BGMS_API_BASE_URL`을 Mac의 LAN IP 또는 배포 HTTPS 주소로 지정해야 합니다.

## 네트워크 설정 주의사항

- Android release 빌드에서도 BGMS API 호출이 필요하므로 `android.permission.INTERNET` 권한이 필요합니다.
- Android 에뮬레이터에서 호스트 Mac의 개발 서버를 호출할 때 `localhost` 대신 `10.0.2.2`를 사용해야 할 수 있습니다.
- iOS는 ATS(App Transport Security) 정책 때문에 HTTP 개발 서버 또는 localhost 접근이 환경에 따라 제한될 수 있습니다.
- 실사용 API는 Android/iOS 모두 HTTPS 엔드포인트 사용을 권장합니다.

## API/키 설정

모바일 앱에 넣는 값:

- `BGMS_API_BASE_URL`: BGMS Next.js 서버 주소. 전적/매치/AI/랭킹/지도 API 호출 대상입니다.
- `BGMS_SUPABASE_URL`: Supabase 프로젝트 URL. 로그인 초기화용 public 값입니다.
- `BGMS_SUPABASE_ANON_KEY`: Supabase anon key. 모바일에 넣을 수 있는 public key입니다.
- `BGMS_AUTH_REDIRECT_URL`: OAuth 콜백 딥링크입니다. 기본값은 `bgms://auth-callback`입니다.

모바일 앱에 넣으면 안 되는 값:

- `SUPABASE_SERVICE_ROLE_KEY`
- `PUBG_API_KEY`
- `GOOGLE_GEMINI_API_KEY`
- `CLOUDFLARE_R2_ACCESS_KEY_ID`
- `CLOUDFLARE_R2_SECRET_ACCESS_KEY`
- `ADMIN_REVALIDATE_TOKEN`

위 비밀키는 `pubg-map-app-local` Next.js 서버 환경변수에만 둡니다. 모바일은 서버 API만 호출합니다.

현재 확인된 주의사항:

- `/api/pubg/player`, `/api/pubg/matches-summary`, `/api/pubg/match`, `/api/pubg/ai-summary`는 웹 프로젝트에 있습니다.
- `/api/rankings`는 웹 프로젝트의 `actions/rankings.ts`를 route로 노출해 모바일에서 호출합니다.
- `/api/maps/{mapId}/markers`는 웹 프로젝트의 `map_markers` 테이블 조회를 route로 노출해 모바일에서 호출합니다.
- `/api/pubg/ai-summary` 호출 시 모바일은 `Authorization: Bearer <access_token>` 헤더를 보냅니다. 웹 서버 `withAuthGuard()`도 쿠키 세션과 Bearer 토큰을 모두 확인해야 합니다.
- 카카오 로그인은 Supabase OAuth provider 설정과 Redirect URL `bgms://auth-callback` 등록이 필요합니다.

## Android Studio 설정

이 프로젝트는 Flutter 3.44.4 / Dart 3.12.2 환경에서 생성 및 테스트되었습니다. Android Studio에서 Flutter 버전이 낮다는 오류가 나오면 코드보다 먼저 Flutter SDK Path를 확인하세요.

- Settings 또는 Preferences > Languages & Frameworks > Flutter > Flutter SDK path
- Homebrew 설치 기준 후보:
  - `/opt/homebrew/share/flutter`
  - `/opt/homebrew/bin/flutter`

터미널 기준 확인:

```bash
flutter --version
```

## 검증

```bash
flutter test
dart analyze
```

현재 코드 기준:

- `flutter test`: 22개 테스트 통과
- `dart analyze`: `No issues found!`

참고: 현재 로컬 환경에서 `flutter analyze`는 Flutter analysis server JSON parsing 예외가 발생할 수 있습니다. 코드 정적 분석은 `dart analyze` 통과 여부를 우선 기준으로 봅니다.

## Android/iOS 로컬 빌드 환경

현재 앱 코드는 Flutter 3.44.4 / Dart 3.12.2에서 테스트와 정적 분석을 통과했습니다. 다만 이 Mac의 네이티브 빌드 환경은 아래 항목이 준비되어야 Android/iOS 빌드까지 확인할 수 있습니다.

- Android: `flutter doctor -v` 기준 Android SDK가 감지되지 않습니다. Android Studio 설치 후 SDK 경로를 `flutter config --android-sdk`로 연결해야 합니다.
- iOS: Xcode는 감지되지만 CocoaPods가 설치되어 있지 않습니다. 현재 시뮬레이터 런타임은 iOS 26.2/26.4만 설치되어 있고, Xcode 빌드는 iOS 26.5 런타임을 요구하므로 Xcode > Settings > Components에서 iOS 26.5 플랫폼/런타임을 추가 설치해야 합니다.

## 현재 MVP 범위

- 홈: 플랫폼 선택, 닉네임 검색, 최근 검색/즐겨찾기 UI
- 전적: K/D, ADR, 승률, 평균 순위, 최근 매치 요약, AI 코칭 상태 카드
- 랭킹: 앱용 `/api/rankings` 계약용 화면, damage/kills/tier 필터, API 실패 원인 표시
- 지도: 읽기 전용 지도 이미지, 맵 선택, 레이어 토글, 마커 API 실패 원인 표시
- 마이: 최근 검색/즐겨찾기 로컬 저장소 관리, Supabase Auth 연결 준비 상태

## 실패 상태 처리

- API가 실패하면 임의 데이터로 성공처럼 보이지 않게 하고, 화면에 HTTP 상태/서버 메시지/미구현 라우트 안내를 표시합니다.
- 랭킹 데이터는 `/api/rankings`가 없으면 빈 목록과 에러 메시지만 표시합니다.
- 지도 마커는 `/api/maps/{mapId}/markers`가 없으면 지도 이미지는 보여주되 마커를 만들지 않고 에러 메시지를 표시합니다.
- AI 코칭은 서버 로그인/비용/인증 오류를 화면 메시지로 표시합니다.
- Supabase Auth는 `BGMS_SUPABASE_URL`, `BGMS_SUPABASE_ANON_KEY` 설정 전까지 초기화하지 않습니다.
