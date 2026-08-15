#!/bin/zsh
# Start the local SDP 4.0 stack, or one app:
#   legacy   http://127.0.0.1:8080
#   api      http://127.0.0.1:8081
#   frontend http://127.0.0.1:8082
#
# Usage:
#   ./start-sdp.sh                # all three
#   ./start-sdp.sh api            # one app
#   ./start-sdp.sh api frontend   # more than one
#   ./start-sdp.sh --kill api     # kill that port, then start
#   ./start-sdp.sh stop [app]
#   ./start-sdp.sh status

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "$ROOT_DIR/sdp-dev-common.sh"

AUTO_KILL=0
ACTION="start"
typeset -a APP_ARGS=()
typeset -a STOP_ARGS=()

usage() {
	cat <<'EOF'
Start the local SDP 4.0 stack (legacy 8080, API 8081, frontend 8082).

Usage:
  ./start-sdp.sh                     Start all three
  ./start-sdp.sh all                 Same as above
  ./start-sdp.sh legacy              Start only http://127.0.0.1:8080
  ./start-sdp.sh api                 Start only http://127.0.0.1:8081
  ./start-sdp.sh frontend            Start only http://127.0.0.1:8082
  ./start-sdp.sh api frontend        Start more than one
  ./start-sdp.sh --kill [app]        Kill busy port(s), then start
  ./start-sdp.sh stop [app]          Stop all, or legacy / api / frontend
  ./start-sdp.sh status              Show port and pid status

Stop is also available as ./stop-sdp.sh [app]
EOF
}

url_for_app() {
	case "$1" in
		legacy) print -r -- "http://$HOST:$LEGACY_PORT/" ;;
		api) print -r -- "http://$HOST:$API_PORT/" ;;
		frontend) print -r -- "http://$HOST:$FRONTEND_PORT/identitas" ;;
		*) return 1 ;;
	esac
}

wait_url_for_app() {
	case "$1" in
		legacy|api|frontend) print -r -- "http://$HOST:$(port_for_app "$1")/" ;;
		*) return 1 ;;
	esac
}

label_for_app() {
	case "$1" in
		legacy) print -r -- Legacy ;;
		api) print -r -- API ;;
		frontend) print -r -- Frontend ;;
		*) print -r -- "$1" ;;
	esac
}

while (( $# > 0 )); do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--kill) AUTO_KILL=1 ;;
		start) ACTION="start" ;;
		stop)
			ACTION="stop"
			shift
			STOP_ARGS=("$@")
			break
			;;
		status) ACTION="status" ;;
		all|legacy|old|8080|api|8081|frontend|ui|8082)
			if [[ "$ACTION" == stop ]]; then
				STOP_ARGS+=("$1")
			else
				APP_ARGS+=("$1")
			fi
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

mkdir -p "$RUN_DIR"

ask_kill() {
	local name="$1"
	local port="$2"
	local answer
	if (( AUTO_KILL )); then
		return 0
	fi
	if [[ ! -t 0 ]]; then
		echo "Port $port ($name) is busy. Re-run with --kill, or free it first." >&2
		return 1
	fi
	echo
	echo "Port $port ($name) is in use:"
	describe_port "$port"
	echo -n "Kill it so $name can start? [y/N] "
	read -r answer
	[[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

ensure_db() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "Docker/OrbStack is required but was not found." >&2
		return 1
	fi
	local state
	state="$(docker inspect --format '{{.State.Status}}' "$DB_CONTAINER" 2>/dev/null || true)"
	if [[ -z "$state" ]]; then
		echo "OrbStack container '$DB_CONTAINER' was not found." >&2
		return 1
	fi
	if [[ "$state" != "running" ]]; then
		echo "Starting $DB_CONTAINER..."
		docker start "$DB_CONTAINER" >/dev/null
	fi
}

wait_http() {
	local url="$1"
	local label="$2"
	local i
	for i in {1..60}; do
		if curl -fsS -m 1 "$url" >/dev/null 2>&1; then
			echo "$label is up at $url"
			return 0
		fi
		sleep 0.5
	done
	echo "$label did not become ready at $url" >&2
	return 1
}

start_legacy() {
	if [[ ! -x "$LEGACY_PHP" ]]; then
		echo "PHP 7.4 was not found at: $LEGACY_PHP" >&2
		return 1
	fi
	echo "Starting legacy on $HOST:$LEGACY_PORT"
	(
		cd "$LEGACY_DIR"
		exec "$LEGACY_PHP" -S "$HOST:$LEGACY_PORT" -t "$LEGACY_DIR/sdp" "$LEGACY_DIR/sdp/index.php"
	) >"$RUN_DIR/legacy.log" 2>&1 &
	write_pid legacy $!
}

start_api() {
	if ! command -v php >/dev/null 2>&1; then
		echo "php was not found on PATH (needed for the CI4 API)." >&2
		return 1
	fi
	echo "Starting API on $HOST:$API_PORT"
	(
		cd "$API_DIR"
		exec php spark serve --host "$HOST" --port "$API_PORT"
	) >"$RUN_DIR/api.log" 2>&1 &
	write_pid api $!
}

start_frontend() {
	if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
		echo "Frontend dependencies are missing. Run npm install in $FRONTEND_DIR" >&2
		return 1
	fi
	echo "Starting frontend on $HOST:$FRONTEND_PORT"
	(
		cd "$FRONTEND_DIR"
		export API_BASE_URL="http://$HOST:$API_PORT"
		export LEGACY_BASE_URL="http://$HOST:$LEGACY_PORT"
		exec npm run dev -- --host "$HOST" --port "$FRONTEND_PORT" --strictPort
	) >"$RUN_DIR/frontend.log" 2>&1 &
	write_pid frontend $!
}

start_named() {
	case "$1" in
		legacy) start_legacy ;;
		api) start_api ;;
		frontend) start_frontend ;;
		*) return 1 ;;
	esac
}

do_start() {
	local -a targets busy_names busy_ports
	local name port needs_db=0

	targets=("${(@f)$(resolve_app_targets "$@")}")
	if (( ${#targets} == 0 )); then
		return 1
	fi

	for name in "${targets[@]}"; do
		if [[ "$name" == legacy || "$name" == api ]]; then
			needs_db=1
		fi
	done
	if (( needs_db )); then
		ensure_db
	fi

	for name in "${targets[@]}"; do
		port="$(port_for_app "$name")"
		if ! port_free "$port"; then
			busy_names+=("$name")
			busy_ports+=("$port")
		fi
	done

	if (( ${#busy_ports} > 0 )); then
		local i
		for i in {1..${#busy_ports}}; do
			if ! ask_kill "${busy_names[$i]}" "${busy_ports[$i]}"; then
				echo "Aborted. No processes were killed." >&2
				exit 1
			fi
		done
		for port in "${busy_ports[@]}"; do
			kill_port "$port"
		done
	fi

	for name in "${APP_ORDER[@]}"; do
		if (( ${targets[(Ie)$name]} )); then
			start_named "$name"
		fi
	done

	for name in "${APP_ORDER[@]}"; do
		if (( ${targets[(Ie)$name]} )); then
			wait_http "$(wait_url_for_app "$name")" "$(label_for_app "$name")" || {
				echo "See $RUN_DIR/$name.log" >&2
				exit 1
			}
		fi
	done

	echo
	echo "Started:"
	for name in "${APP_ORDER[@]}"; do
		if (( ${targets[(Ie)$name]} )); then
			echo "  $name    $(url_for_app "$name")"
		fi
	done
	echo
	echo "Stack status:"
	do_status
	echo
	echo "Logs: $RUN_DIR/*.log"
	echo "Stop with: $ROOT_DIR/stop-sdp.sh ${*:-}"
}

case "$ACTION" in
	start) do_start "${APP_ARGS[@]}" ;;
	stop) do_stop "${STOP_ARGS[@]}" ;;
	status) do_status ;;
esac
