#!/usr/bin/env bash
# Clone local UPT db_sdp into production-simulation schemas on OrbStack sdp-mariadb.
# See docs/LOCAL-DATABASE.md

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# shellcheck source=sdp-dev-common.sh
source "$ROOT_DIR/sdp-dev-common.sh"

SOURCE_DB="${SOURCE_DB:-db_sdp}"
SCHEMAS=(db093 db001 sdp_pusat)
MYSQL_USER="${MYSQL_USER:-sdp}"
MYSQL_PASS="${MYSQL_PASS:-sdp_local}"
LEGACY_DEFINER_USER="${LEGACY_DEFINER_USER:-SdP3UsEr1214}"
LEGACY_DEFINER_PASS="${LEGACY_DEFINER_PASS:-fe91c800e41835f81b76435d603eaca8}"
ROOT_USER="${MARIADB_ROOT_USER:-root}"
ROOT_PASS="${MARIADB_ROOT_PASSWORD:-}"

if [[ -z "$ROOT_PASS" && -f "$ROOT_DIR/.run/mariadb-root.env" ]]; then
	# shellcheck source=/dev/null
	source "$ROOT_DIR/.run/mariadb-root.env"
	ROOT_PASS="${MARIADB_ROOT_PASSWORD:-}"
fi

SKIP_CLONE=0
ONLY_VERIFY=0

usage() {
	cat <<'EOF'
Usage: ./scripts/dev-mariadb-prod-sim.sh [options]

Create db093, db001, sdp_pusat from db_sdp (UPT 093). Requires MariaDB root once for CREATE DATABASE.

Options:
  --skip-clone   Create DBs + grants only; skip mysqldump clone
  --only-verify  Print daftar_referensi 001 for all schemas
  -h, --help     Show this help

Env:
  MARIADB_ROOT_PASSWORD   Root password (if empty, tries root with no password)
  SOURCE_DB               Default db_sdp
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-clone) SKIP_CLONE=1 ;;
		--only-verify) ONLY_VERIFY=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
	esac
	shift
done

mysql_root() {
	if [[ -n "$ROOT_PASS" ]]; then
		docker exec -i "$DB_CONTAINER" mariadb -u"$ROOT_USER" -p"$ROOT_PASS" "$@"
	else
		docker exec -i "$DB_CONTAINER" mariadb -u"$ROOT_USER" "$@"
	fi
}

mysql_app() {
	docker exec -i "$DB_CONTAINER" mariadb -u"$MYSQL_USER" -p"$MYSQL_PASS" "$@"
}

mysqldump_source() {
	if [[ -n "$ROOT_PASS" ]]; then
		docker exec "$DB_CONTAINER" mysqldump -u"$ROOT_USER" -p"$ROOT_PASS" \
			--single-transaction --routines --triggers "$SOURCE_DB"
	else
		docker exec "$DB_CONTAINER" mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASS" \
			--single-transaction --routines --triggers "$SOURCE_DB"
	fi
}

mysql_import_target() {
	local target="$1"
	if [[ -n "$ROOT_PASS" ]]; then
		docker exec -i "$DB_CONTAINER" mariadb -u"$ROOT_USER" -p"$ROOT_PASS" "$target"
	else
		docker exec -i "$DB_CONTAINER" mariadb -u"$MYSQL_USER" -p"$MYSQL_PASS" "$target"
	fi
}

ensure_legacy_definer() {
	# Views/functions in dump use DEFINER=`SdP3UsEr1214`@`localhost` (see sdp/102sdp/scripts/restore-db.sh)
	mysql_root <<SQL
CREATE USER IF NOT EXISTS '${LEGACY_DEFINER_USER}'@'localhost' IDENTIFIED BY '${LEGACY_DEFINER_PASS}';
CREATE USER IF NOT EXISTS '${LEGACY_DEFINER_USER}'@'%' IDENTIFIED BY '${LEGACY_DEFINER_PASS}';
SQL
}

grant_target_access() {
	local target="$1"
	mysql_root <<SQL
GRANT ALL PRIVILEGES ON ${target}.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON ${target}.* TO '${LEGACY_DEFINER_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${target}.* TO '${LEGACY_DEFINER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
}

verify_boot_flags() {
	echo "=== daftar_referensi 001 (site boot) ==="
	for db in "$SOURCE_DB" db093 db001 sdp_pusat; do
		mysql_app -N -e \
			"SELECT '$db', DESKRIPSI FROM ${db}.daftar_referensi WHERE ID_LOOKUP='001';" 2>/dev/null \
			|| echo "$db: (missing or no access)"
	done
	echo "=== identitas row counts ==="
	for db in "$SOURCE_DB" db093 db001 sdp_pusat; do
		mysql_app -N -e \
			"SELECT '$db', COUNT(*) FROM ${db}.identitas;" 2>/dev/null \
			|| echo "$db: (missing)"
	done
}

if (( ONLY_VERIFY )); then
	verify_boot_flags
	exit 0
fi

if ! docker inspect --format '{{.State.Status}}' "$DB_CONTAINER" 2>/dev/null | grep -q running; then
	echo "Start $DB_CONTAINER first (./start-sdp.sh or docker start $DB_CONTAINER)." >&2
	exit 1
fi

echo "Creating schemas and grants (root)..."
if ! mysql_root <<'SQL'
CREATE DATABASE IF NOT EXISTS db093 CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS db001 CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE DATABASE IF NOT EXISTS sdp_pusat CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON db093.* TO 'sdp'@'%';
GRANT ALL PRIVILEGES ON db001.* TO 'sdp'@'%';
GRANT ALL PRIVILEGES ON sdp_pusat.* TO 'sdp'@'%';
FLUSH PRIVILEGES;
SQL
then
	echo "Failed. Set MARIADB_ROOT_PASSWORD or .run/mariadb-root.env (see docs/LOCAL-DATABASE.md)." >&2
	exit 1
fi

if (( SKIP_CLONE )); then
	echo "Skipped clone (--skip-clone)."
	verify_boot_flags
	exit 0
fi

echo "Cloning $SOURCE_DB into ${SCHEMAS[*]} (this may take a few minutes)..."
ensure_legacy_definer
for target in "${SCHEMAS[@]}"; do
	echo "  → $target"
	mysql_root <<SQL
DROP DATABASE IF EXISTS ${target};
CREATE DATABASE ${target} CHARACTER SET utf8 COLLATE utf8_general_ci;
SQL
	grant_target_access "$target"
	mysqldump_source | mysql_import_target "$target"
done

echo "Post-clone patches..."
mysql_app <<'SQL'
UPDATE sdp_pusat.daftar_referensi SET DESKRIPSI = '' WHERE ID_LOOKUP = '001';
UPDATE db001.daftar_referensi SET DESKRIPSI = '001' WHERE ID_LOOKUP = '001';
SQL

echo "Seeding Kanwil test user on sdp_pusat (kanwil_jambi / admin, KANWIL=05)..."
mysql_app sdp_pusat <<'SQL'
DELETE FROM pengguna WHERE ID_USER = 'kanwil_jambi';
INSERT INTO pengguna (
  ID_USER, ID_ROLE, LEVEL, PASSWORD, NAMA, IS_APPROVE, IS_DELETE, KANWIL
) VALUES (
  'kanwil_jambi', 'admin', '4', '21232f297a57a5a743894a0e4a801fc3',
  'Kanwil Jambi Test', 1, 0, '05'
);
SQL

verify_boot_flags

cat <<'EOF'

Done. Quick reference:
  UPT legacy     :8080  → db_sdp     (single)
  National legacy:9080  → sdp_pusat  (shared_database) — ./start-sdp-national.sh
  API national   :8081  → cp sdp-upt-api/env.national sdp-upt-api/.env
  Tenant 093     login tenantId "093" → db093
  Tenant 001     login tenantId "001" → db001
  Pusat login    sdp_pusat — admin / admin
  Kanwil login   sdp_pusat — kanwil_jambi / admin
EOF
