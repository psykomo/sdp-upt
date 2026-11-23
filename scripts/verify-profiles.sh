#!/usr/bin/env bash
# Pre-cutover verification gate: API unit suite, multi-profile API feature suite, and SPA typecheck/build.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"

echo "=== 1/3 API unit tests ==="
(cd "$ROOT_DIR/sdp-upt-api" && ./vendor/bin/phpunit --no-coverage --testsuite unit)

echo ""
echo "=== 2/3 API multi-profile feature tests ==="
(cd "$ROOT_DIR/sdp-upt-api" && ./vendor/bin/phpunit --no-coverage --testsuite feature)

echo ""
echo "=== 3/3 Frontend typecheck & static SPA build ==="
(cd "$ROOT_DIR/sdp-upt-frontend" && npm run typecheck && npm run build)

echo ""
echo "All verification checks passed."
