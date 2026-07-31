#!/usr/bin/env bash
# 실기기 실행 헬퍼. 웹 프로젝트의 .env.local에서 Supabase 공개 값만 읽어 dart-define으로 전달한다.
# 사용법: scripts/run_device.sh [flutter run 추가 인자...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${BGMS_ENV_FILE:-${APP_ROOT}/../pubg-map-app-local/.env.local}"

read_env() {
  local key="$1"
  [ -f "${ENV_FILE}" ] || return 0
  # 마지막 정의를 사용하고 따옴표와 CR을 제거한다.
  grep -E "^${key}=" "${ENV_FILE}" | tail -1 | cut -d= -f2- \
    | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

SUPABASE_URL="${BGMS_SUPABASE_URL:-$(read_env NEXT_PUBLIC_SUPABASE_URL)}"
SUPABASE_ANON_KEY="${BGMS_SUPABASE_ANON_KEY:-$(read_env NEXT_PUBLIC_SUPABASE_ANON_KEY)}"

# 기본은 운영 도메인이다. 특정 배포 별칭이나 로컬 서버로 붙일 때만
# BGMS_API_BASE_URL 환경 변수로 덮어쓴다.
API_BASE_URL="${BGMS_API_BASE_URL:-https://bgms.kr}"

if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_ANON_KEY}" ]; then
  echo "경고: Supabase 공개 값을 찾지 못했다. 로그인, AI 코칭, 게시판 작성은 비활성 상태로 실행된다." >&2
  echo "확인 경로: ${ENV_FILE}" >&2
fi

cd "${APP_ROOT}"
exec flutter run \
  --dart-define=BGMS_API_BASE_URL="${API_BASE_URL}" \
  --dart-define=BGMS_SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=BGMS_SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  "$@"
