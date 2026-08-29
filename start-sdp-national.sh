#!/usr/bin/env zsh
# Start legacy PHP on :9080 against sdp_pusat (national simulation).
# UPT legacy stays on :8080 / db_sdp.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
source "$ROOT_DIR/sdp-dev-common.sh"

LEGACY_NATIONAL_PORT="${LEGACY_NATIONAL_PORT:-9080}"
LEGACY_CONFIG_DIR="$LEGACY_DIR/system/application/config"

if [[ ! -x "$LEGACY_PHP" ]]; then
	echo "PHP 7.4 was not found at: $LEGACY_PHP" >&2
	exit 1
fi

for f in database_national.local.php config_national.local.php; do
	if [[ ! -f "$LEGACY_CONFIG_DIR/$f" ]]; then
		echo "Missing $LEGACY_CONFIG_DIR/$f" >&2
		echo "Copy from scripts/legacy-national/*.example" >&2
		exit 1
	fi
done

mkdir -p "$RUN_DIR"

if ! port_free "$LEGACY_NATIONAL_PORT"; then
	echo "Port $LEGACY_NATIONAL_PORT is in use." >&2
	describe_port "$LEGACY_NATIONAL_PORT" >&2
	exit 1
fi

echo "Starting national legacy on $OFFICER_BIND:$LEGACY_NATIONAL_PORT (sdp_pusat)"
export SDP_LEGACY_PROFILE=national
(
	cd "$LEGACY_DIR"
	exec "$LEGACY_PHP" -S "$OFFICER_BIND:$LEGACY_NATIONAL_PORT" -t "$LEGACY_DIR/sdp" "$LEGACY_DIR/sdp/index.php"
) >"$RUN_DIR/legacy-national.log" 2>&1 &
write_pid legacy-national $!

sleep 0.5
if curl -fsS -m 2 "http://$HOST:$LEGACY_NATIONAL_PORT/" >/dev/null 2>&1; then
	echo "National legacy is up at http://$HOST:$LEGACY_NATIONAL_PORT/"
else
	echo "Started pid $(read_pid legacy-national); check $RUN_DIR/legacy-national.log"
fi
