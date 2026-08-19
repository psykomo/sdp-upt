#!/bin/zsh
# Start the local SDP 4.0 stack, or one app:
#   legacy   :8080  (all interfaces, like UPT)
#   api      :8081  (127.0.0.1 only)
#   frontend :8082  (all interfaces; /api → localhost :8081)
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
DEV_MODE=0
ACTION="start"
typeset -a APP_ARGS=()
typeset -a STOP_ARGS=()

usage() {
	cat <<'EOF'
Start the local SDP 4.0 stack (legacy 8080, API 8081, frontend 8082).

Usage:
  ./start-sdp.sh                     Start all three (Caddy serves a built SPA)
  ./start-sdp.sh --dev               Same, but Vite HMR on :8082 (no build)
  ./start-sdp.sh all                 Same as ./start-sdp.sh
  ./start-sdp.sh legacy              Start only http://127.0.0.1:8080
  ./start-sdp.sh api                 Start only http://127.0.0.1:8081
  ./start-sdp.sh frontend            Start only http://127.0.0.1:8082
  ./start-sdp.sh --dev frontend      Vite only (legacy/API already running)
  ./start-sdp.sh api frontend        Start more than one
  ./start-sdp.sh --kill [app]        Kill leftover SDP process on that port, then start
  ./start-sdp.sh stop [app]          Stop all, or legacy / api / frontend
  ./start-sdp.sh status              Show port and pid status

--dev is for porting slices (HMR). Omit it to check the UPT-shaped static SPA.

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
		--dev) DEV_MODE=1 ;;
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

docker_ready() {
	docker info >/dev/null 2>&1
}

ensure_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "docker was not found on PATH (OrbStack or Docker Desktop)." >&2
		return 1
	fi
	if docker_ready; then
		return 0
	fi

	echo "Docker is not running. Starting OrbStack..."
	if [[ -d /Applications/OrbStack.app ]]; then
		open -a OrbStack
	elif command -v orbctl >/dev/null 2>&1; then
		orbctl start >/dev/null 2>&1 || true
	else
		echo "Start OrbStack (or Docker Desktop), then retry." >&2
		return 1
	fi

	local i
	for i in {1..90}; do
		if docker_ready; then
			return 0
		fi
		sleep 0.5
	done
	echo "Docker/OrbStack did not become ready. Open OrbStack and retry." >&2
	return 1
}

ensure_db() {
	ensure_docker || return 1

	local state
	if ! state="$(docker inspect --format '{{.State.Status}}' "$DB_CONTAINER" 2>/dev/null)"; then
		echo "Docker container '$DB_CONTAINER' was not found." >&2
		echo "Check: docker ps -a" >&2
		return 1
	fi

	if [[ "$state" != "running" ]]; then
		echo "Starting $DB_CONTAINER..."
		docker start "$DB_CONTAINER" >/dev/null
	fi

	local i
	for i in {1..40}; do
		if ! port_free "$DB_PORT"; then
			return 0
		fi
		sleep 0.25
	done
	echo "$DB_CONTAINER started but nothing is listening on $HOST:$DB_PORT." >&2
	return 1
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
	echo "Starting legacy on $OFFICER_BIND:$LEGACY_PORT"
	(
		cd "$LEGACY_DIR"
		exec "$LEGACY_PHP" -S "$OFFICER_BIND:$LEGACY_PORT" -t "$LEGACY_DIR/sdp" "$LEGACY_DIR/sdp/index.php"
	) >"$RUN_DIR/legacy.log" 2>&1 &
	write_pid legacy $!
}

start_api() {
	if ! command -v php >/dev/null 2>&1; then
		echo "php was not found on PATH (needed for the CI4 API)." >&2
		return 1
	fi
	echo "Starting API on $API_BIND:$API_PORT (localhost only)"
	(
		cd "$API_DIR"
		exec php spark serve --host "$API_BIND" --port "$API_PORT"
	) >"$RUN_DIR/api.log" 2>&1 &
	write_pid api $!
}

start_frontend() {
	if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
		echo "Frontend dependencies are missing. Run npm install in $FRONTEND_DIR" >&2
		return 1
	fi

	if (( DEV_MODE )); then
		echo "Starting frontend (Vite HMR) on $OFFICER_BIND:$FRONTEND_PORT"
		(
			cd "$FRONTEND_DIR"
			exec npm run dev -- --host "$OFFICER_BIND" --port "$FRONTEND_PORT" --strictPort
		) >"$RUN_DIR/frontend.log" 2>&1 &
		write_pid frontend $!
		return 0
	fi

	if ! command -v caddy >/dev/null 2>&1; then
		echo "caddy was not found on PATH (needed to serve the SPA on :$FRONTEND_PORT)." >&2
		echo "Install it, e.g. brew install caddy — or use ./start-sdp.sh --dev" >&2
		return 1
	fi
	echo "Building frontend (static SPA)"
	if ! (cd "$FRONTEND_DIR" && npm run build >"$RUN_DIR/frontend-build.log" 2>&1); then
		echo "Frontend build failed. See $RUN_DIR/frontend-build.log" >&2
		return 1
	fi
	if [[ ! -f "$FRONTEND_DIR/build/client/index.html" ]]; then
		echo "Frontend build did not produce build/client/index.html" >&2
		return 1
	fi
	echo "Starting frontend (Caddy) on $OFFICER_BIND:$FRONTEND_PORT"
	(
		export FRONTEND_CLIENT="$FRONTEND_DIR/build/client"
		export FRONTEND_PORT
		export API_PORT
		export OFFICER_BIND
		exec caddy run --config "$ROOT_DIR/deploy/Caddyfile" --adapter caddyfile
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
		if [[ -n "$(sdp_pids_on_port "$port")" ]]; then
			busy_names+=("$name")
			busy_ports+=("$port")
		elif ! port_free "$port"; then
			echo "Port $port ($name) is in use by something else (not SDP). Not killing it." >&2
			describe_port "$port" >&2
			if [[ "$port" == "$LEGACY_PORT" ]]; then
				echo "If that is OrbStack Adminer, stop or remap that container off :$LEGACY_PORT, then retry." >&2
			fi
			exit 1
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
	local lan
	lan="$(lan_ip)"
	for name in "${APP_ORDER[@]}"; do
		if (( ${targets[(Ie)$name]} )); then
			if [[ "$name" == api ]]; then
				echo "  $name    $(url_for_app "$name")  (not on the LAN — like UPT)"
			elif [[ -n "$lan" ]]; then
				echo "  $name    $(url_for_app "$name")"
				echo "           LAN  http://$lan:$(port_for_app "$name")/"
			else
				echo "  $name    $(url_for_app "$name")"
			fi
		fi
	done
	if [[ -n "$lan" ]]; then
		echo
		echo "Other devices: use this Mac's LAN address (not :8081)."
		echo "macOS may prompt to allow php/node/caddy on the network."
	fi
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
