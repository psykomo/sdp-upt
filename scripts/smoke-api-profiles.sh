#!/usr/bin/env bash
# Smoke API profiles after dev-mariadb-prod-sim.sh. Requires API on :8081 with matching .env.
set -euo pipefail

API="${API_BASE:-http://127.0.0.1:8081}"
JSON_HEADER=(-H "Content-Type: application/json")

login() {
	local body="$1"
	curl -fsS "${JSON_HEADER[@]}" -d "$body" "$API/api/v1/auth/login"
}

me() {
	local token="$1"
	curl -fsS -H "Authorization: Bearer $token" "$API/api/v1/auth/me"
}

echo "=== UPT (env.upt / single) ==="
echo "Expect: uptId=093, not Pusat/Kanwil — restart API with env.upt first."
TOKEN="$(login '{"username":"admin","password":"admin"}' | php -r 'echo json_decode(stream_get_contents(STDIN))->data->token ?? "";')"
if [[ -n "$TOKEN" ]]; then
	me "$TOKEN" | php -r '$j=json_decode(stream_get_contents(STDIN)); echo json_encode($j->data->user??$j, JSON_PRETTY_PRINT);'
fi

echo ""
echo "=== Tenant 093 (env.tenant + tenantId) ==="
TOKEN="$(login '{"username":"admin","password":"admin","tenantId":"093"}' | php -r 'echo json_decode(stream_get_contents(STDIN))->data->token ?? "";')"
if [[ -n "$TOKEN" ]]; then
	me "$TOKEN" | php -r '$j=json_decode(stream_get_contents(STDIN)); echo json_encode($j->data->user??$j, JSON_PRETTY_PRINT);'
fi

echo ""
echo "=== Pusat (env.national) ==="
TOKEN="$(login '{"username":"admin","password":"admin"}' | php -r 'echo json_decode(stream_get_contents(STDIN))->data->token ?? "";')"
if [[ -n "$TOKEN" ]]; then
	me "$TOKEN" | php -r '$j=json_decode(stream_get_contents(STDIN)); $u=$j->data->user??null; echo "isPusat=".($u->isPusat??"?")." isKanwil=".($u->isKanwil??"?")."\n";'
fi

echo ""
echo "=== UPT officer (env.national + tenantId 093) ==="
TOKEN="$(login '{"username":"supervisor","password":"admin","tenantId":"093"}' | php -r 'echo json_decode(stream_get_contents(STDIN))->data->token ?? "";')"
if [[ -n "$TOKEN" ]]; then
	me "$TOKEN" | php -r '$j=json_decode(stream_get_contents(STDIN)); $u=$j->data->user??null; echo "isPusat=".($u->isPusat??"?")." isKanwil=".($u->isKanwil??"?")." uptId=".($u->uptId??"?")."\n";'
fi
