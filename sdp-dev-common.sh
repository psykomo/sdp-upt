# Shared helpers for start-sdp.sh and stop-sdp.sh.
# Expects ROOT_DIR to be set by the caller.

RUN_DIR="$ROOT_DIR/.run"
LEGACY_DIR="$ROOT_DIR/102sdp"
API_DIR="$ROOT_DIR/sdp-api-ci4"
FRONTEND_DIR="$ROOT_DIR/sdp-frontend-reactrouter8"

LEGACY_PHP="/opt/homebrew/opt/php@7.4/bin/php"
HOST="127.0.0.1"
# Officer-facing bind (legacy + SPA). API stays on loopback, like UPT.
OFFICER_BIND="${OFFICER_BIND:-0.0.0.0}"
API_BIND="${API_BIND:-127.0.0.1}"
DB_CONTAINER="sdp-mariadb"
DB_PORT=3307

LEGACY_PORT=8080
API_PORT=8081
FRONTEND_PORT=8082

APP_ORDER=(legacy api frontend)

lan_ip() {
	ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

port_for_app() {
	case "$1" in
		legacy) print -r -- "$LEGACY_PORT" ;;
		api) print -r -- "$API_PORT" ;;
		frontend) print -r -- "$FRONTEND_PORT" ;;
		*) return 1 ;;
	esac
}

normalize_app() {
	case "$1" in
		all) print -r -- all ;;
		legacy|old|8080) print -r -- legacy ;;
		api|8081) print -r -- api ;;
		frontend|ui|8082) print -r -- frontend ;;
		*) return 1 ;;
	esac
}

port_pids() {
	lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | sort -u
}

port_free() {
	[[ -z "$(port_pids "$1")" ]]
}

describe_port() {
	local port="$1"
	lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==1 || NR>1 {print}'
}

pid_command() {
	ps -o command= -p "$1" 2>/dev/null || true
}

# Only php/spark/caddy/npm that we started. Never OrbStack, docker-proxy, or Adminer.
is_sdp_process() {
	local pid="$1"
	local cmd
	cmd="$(pid_command "$pid")"
	[[ -n "$cmd" ]] || return 1

	case "$cmd" in
		*[Oo]rb[Ss]tack*|*"docker-proxy"*|*"com.docker"*|*"Docker Desktop"*|*adminer*)
			return 1
			;;
	esac

	[[ "$cmd" == *'php -S '* ]] && return 0
	[[ "$cmd" == *'spark serve'* ]] && return 0
	[[ "$cmd" == *php* && "$cmd" == *"$API_DIR"* ]] && return 0
	[[ "$cmd" == *php* && "$cmd" == *"$LEGACY_DIR"* ]] && return 0
	[[ "$cmd" == *caddy*'--config'* ]] && return 0
	[[ "$cmd" == *caddy*' run'* ]] && return 0
	[[ "$cmd" == *'react-router'* ]] && return 0
	[[ "$cmd" == 'npm run'* || "$cmd" == npm\ * ]] && return 0
	return 1
}

sdp_pids_on_port() {
	local port="$1"
	local pid
	for pid in $(port_pids "$port"); do
		if is_sdp_process "$pid"; then
			print -r -- "$pid"
		fi
	done
}

# Kill SDP listeners and the spark/npm wrapper that would hop to the next port.
collect_kill_pids() {
	local port="$1"
	local pid ppid
	local -a pids=()
	for pid in $(sdp_pids_on_port "$port"); do
		pids+=("$pid")
		ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
		if [[ -n "$ppid" && "$ppid" != 0 && "$ppid" != 1 ]] && is_sdp_process "$ppid"; then
			pids+=("$ppid")
		fi
	done
	printf '%s\n' "${pids[@]}" | awk 'NF && !seen[$0]++'
}

wait_port_free() {
	local port="$1"
	local i
	for i in {1..20}; do
		port_free "$port" && return 0
		sleep 0.15
	done
	return 1
}

kill_port() {
	local port="$1"
	local -a pids=()
	pids=("${(@f)$(collect_kill_pids "$port")}")
	if (( ${#pids} == 0 )); then
		return 0
	fi
	kill "${pids[@]}" 2>/dev/null || true
	if ! wait_port_free "$port"; then
		kill -9 "${pids[@]}" 2>/dev/null || true
		wait_port_free "$port" || true
	fi
	if ! port_free "$port"; then
		echo "Could not free port $port." >&2
		describe_port "$port" >&2
		return 1
	fi
}

write_pid() {
	print -r -- "$2" >"$RUN_DIR/$1.pid"
}

read_pid() {
	local file="$RUN_DIR/$1.pid"
	[[ -f "$file" ]] || return 1
	local pid
	pid="$(<"$file")"
	[[ -n "$pid" ]] || return 1
	print -r -- "$pid"
}

pid_alive() {
	kill -0 "$1" 2>/dev/null
}

stop_named() {
	local name="$1"
	local port="$2"
	local pid
	local stopped=0
	local leftover

	if pid="$(read_pid "$name" 2>/dev/null)"; then
		if pid_alive "$pid" && is_sdp_process "$pid"; then
			kill "$pid" 2>/dev/null || true
			sleep 0.2
			pid_alive "$pid" && kill -9 "$pid" 2>/dev/null || true
			stopped=1
		fi
		rm -f "$RUN_DIR/$name.pid"
	fi

	leftover="$(sdp_pids_on_port "$port")"
	if [[ -n "$leftover" ]]; then
		kill_port "$port"
		stopped=1
	fi

	if (( stopped )); then
		echo "Stopped $name (port $port)."
	else
		echo "$name (port $port) was already stopped."
	fi

	if ! port_free "$port"; then
		echo "Port $port is still in use (not an SDP process — left running):" >&2
		describe_port "$port" >&2
	fi
}

resolve_app_targets() {
	local arg name
	local -a targets=()

	if (( $# == 0 )); then
		print -l -- "${APP_ORDER[@]}"
		return 0
	fi

	for arg in "$@"; do
		if ! name="$(normalize_app "$arg")"; then
			echo "Unknown app: $arg (use all, legacy, api, or frontend)" >&2
			return 1
		fi
		if [[ "$name" == all ]]; then
			print -l -- "${APP_ORDER[@]}"
			return 0
		fi
		targets+=("$name")
	done

	print -l -- "${targets[@]}"
}

do_stop() {
	local -a targets=()
	local name
	targets=("${(@f)$(resolve_app_targets "$@")}")
	if (( ${#targets} == 0 )); then
		return 1
	fi

	# Stop frontend first so it does not keep calling a dying API.
	for name in frontend api legacy; do
		if (( ${targets[(Ie)$name]} )); then
			stop_named "$name" "$(port_for_app "$name")"
		fi
	done
}

do_status() {
	local name port pid extra
	for name in "${APP_ORDER[@]}"; do
		port="$(port_for_app "$name")"
		if port_free "$port"; then
			extra="free"
		else
			extra="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {printf "%s pid %s %s", $1,$2,$9; exit}')"
		fi
		pid="$(read_pid "$name" 2>/dev/null || true)"
		if [[ -n "$pid" ]]; then
			echo "$name  :$port  pid-file=$pid  ($extra)"
		else
			echo "$name  :$port  ($extra)"
		fi
	done
}
