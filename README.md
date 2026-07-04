# BGMS Mobile App

BGMS Flutter 모바일 앱 MVP입니다. 기존 Next.js 웹 프로젝트와 분리된 앱으로 만들며, 전적/AI/랭킹/지도 데이터는 모바일 앱용 API 계약을 통해 연결합니다.

## 실행

```bash
flutter pub get
flutter run --dart-define=BGMS_API_BASE_URL=http://localhost:3000
```

## 검증

```bash
flutter analyze
flutter test
```

## 현재 MVP 범위

- 홈: 플랫폼 선택, 닉네임 검색, 최근 검색/즐겨찾기 UI
- 전적: 기존 Next API 연결을 위한 화면 골격
- 랭킹: 앱용 `/api/rankings` 계약용 화면 골격
- 지도: 읽기 전용 지도/마커 레이어 골격
- 마이: Supabase Auth 연결 준비 상태

## Mock/Fallback

- 랭킹 데이터는 `/api/rankings`가 추가되기 전까지 mock/fallback UI입니다.
- 지도 데이터는 `/api/maps/{mapId}/markers`가 추가되기 전까지 정적 마커 UI입니다.
- Supabase Auth는 `BGMS_SUPABASE_URL`, `BGMS_SUPABASE_ANON_KEY` 설정 전까지 초기화하지 않습니다.
