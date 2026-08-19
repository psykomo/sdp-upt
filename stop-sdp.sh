#!/bin/zsh
# Stop the local SDP 4.0 stack, or one app.
# Frontend is Caddy on :8082 (not Node). API is spark on :8081.
# Does not stop OrbStack, MariaDB, or other containers (e.g. Adminer on :8080).
#
#   ./stop-sdp.sh              # all three
#   ./stop-sdp.sh all
#   ./stop-sdp.sh legacy
#   ./stop-sdp.sh api
#   ./stop-sdp.sh frontend     # stop Caddy on :8082
#   ./stop-sdp.sh api frontend

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "$ROOT_DIR/sdp-dev-common.sh"
mkdir -p "$RUN_DIR"

usage() {
	cat <<'EOF'
Stop the local SDP 4.0 stack.

Usage:
  ./stop-sdp.sh                 Stop legacy, API, and frontend
  ./stop-sdp.sh all             Same as above
  ./stop-sdp.sh legacy          Stop only http://127.0.0.1:8080
  ./stop-sdp.sh api             Stop only http://127.0.0.1:8081
  ./stop-sdp.sh frontend        Stop Caddy on http://127.0.0.1:8082
  ./stop-sdp.sh api frontend    Stop more than one
  ./stop-sdp.sh status          Show which ports are in use
EOF
}

if (( $# > 0 )); then
	case "$1" in
		-h|--help) usage; exit 0 ;;
		status) do_status; exit 0 ;;
	esac
fi

do_stop "$@"
