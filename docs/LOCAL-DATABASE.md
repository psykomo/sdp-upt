# Local MariaDB (production simulation)

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
Tenancy modes: [`TENANCY.md`](TENANCY.md).  
Runtime profiles: [`PORTING.md`](PORTING.md) §2.

OrbStack container **`sdp-mariadb`**, host **`127.0.0.1:3307`**.

| Account | User | Password | Notes |
|---------|------|----------|--------|
| App | `sdp` | `sdp_local` | Legacy + API |
| Root | `root` | `sdp_root_local` | From `sdp/102sdp/docker-compose.mariadb.yml` |

Copy `.run/mariadb-root.env.example` → `.run/mariadb-root.env` so `./scripts/dev-mariadb-prod-sim.sh` finds root without `export`.

## Schema naming

Legacy replica and API `database_per_tenant` share one rule:

```
schema name = db + ID_UPT     →  db093, db001
JWT tenantId / uptId          →  093, 001   (not the full schema name)
```

## Schemas (after setup)

| Schema | Tenancy mode | Role | `001` boot |
|--------|--------------|------|------------|
| `db_sdp` | `single` | UPT box (local) | `093` |
| `db093` | `database_per_tenant` + legacy replica | UPT 093 tenant / hop-1 replica | `093` |
| `db001` | `database_per_tenant` | Second tenant (switch tests) | `001` |
| `sdp_pusat` | `shared_database` | National — UPT + Kanwil + Pusat | empty (Pusat) |

## Port layout

| Port | App | Database |
|------|-----|----------|
| 8080 | Legacy UPT | `db_sdp` |
| 9080 | Legacy national (optional) | `sdp_pusat` |
| 8081 | CI4 API | from `.env` |
| 8082 | React SPA | (API via proxy) |

## One-time setup

```bash
./scripts/dev-mariadb-prod-sim.sh
```

Requires MariaDB **root** inside the container (for `CREATE DATABASE`). Set password via:

```bash
export MARIADB_ROOT_PASSWORD='…'
./scripts/dev-mariadb-prod-sim.sh
```

Or copy `.run/mariadb-root.env.example` → `.run/mariadb-root.env` (gitignored).

**Manual fallback** (OrbStack → sdp-mariadb → Terminal):

```bash
mariadb -uroot -p < scripts/sql/prod-sim-manual-root.sql
./scripts/dev-mariadb-prod-sim.sh --skip-clone
```

Re-run after large changes to `db_sdp`:

```bash
./scripts/dev-mariadb-prod-sim.sh
```

Options: `--skip-clone`, `--only-verify`.

## API env profiles

Copy a template to `sdp-upt-api/.env` (not committed):

| Template | Mode | `database.default.database` |
|----------|------|-----------------------------|
| `sdp-upt-api/env.upt` | `single` | `db_sdp` |
| `sdp-upt-api/env.national` | `shared_database` | `sdp_pusat` |
| `sdp-upt-api/env.tenant` | `database_per_tenant` | `db093` |

Tenant mode also needs:

```
tenancy.databasePrefix = db
```

Restart API after switching: `./stop-sdp.sh api && ./start-sdp.sh api`.

### Login examples

SPA `/login` calls `GET /api/v1/auth/login-options`; the **ID UPT** field appears only when `tenancy.mode = database_per_tenant`.

**UPT box** (`env.upt`):

```json
POST /api/v1/auth/login
{ "username": "admin", "password": "admin" }
```

**Tenant 093** (`env.tenant`):

```json
{ "username": "admin", "password": "admin", "tenantId": "093" }
```

→ connects to **`db093`**.

**Tenant 001**:

```json
{ "username": "admin", "password": "admin", "tenantId": "001" }
```

→ connects to **`db001`**.

**Pusat** (`env.national`, `sdp_pusat`):

```json
{ "username": "admin", "password": "admin" }
```

→ `isPusat=true`, `isKanwil=false`.

**Kanwil** (same DB, merged Kanwil — `pengguna.KANWIL`):

```json
{ "username": "kanwil_jambi", "password": "admin" }
```

→ `isKanwil=true`, `isPusat=false`, `uptId=05` (Jambi).

**UPT officer** (same DB, optional `tenantId` / `uptId` at login — mirrors legacy `upt_session`):

```json
{ "username": "supervisor", "password": "admin", "tenantId": "093" }
```

→ `isPusat=false`, `isKanwil=false`, `uptId=093`, UPT name from `upt` table. Without `tenantId`, `supervisor` on `sdp_pusat` is treated as Pusat boot (no `uptId`).

SPA `/login` shows optional ID UPT when API is `shared_database` on Pusat boot (`requiresWorkingUptId`).

```bash
./start-sdp-national.sh
```

Uses `SDP_LEGACY_PROFILE=national` and local wrappers under `102sdp/system/application/config/`:

- `database_national.local.php` — `sdp_pusat`
- `config_national.local.php` — base URL `:9080`

Install wrappers once:

```bash
cp scripts/legacy-national/database_national.local.php.example \
  102sdp/system/application/config/database_national.local.php
cp scripts/legacy-national/config_national.local.php.example \
  102sdp/system/application/config/config_national.local.php
```

Pusat vs Kanwil on national: same DB, different login (`admin` vs `kanwil_jambi`).

## Verify

```bash
./scripts/dev-mariadb-prod-sim.sh --only-verify
```

## Smoke (after DB + API)

```bash
# 1. Create schemas (needs root password)
export MARIADB_ROOT_PASSWORD='…'
./scripts/dev-mariadb-prod-sim.sh

# 2. Switch API env and restart
cp sdp-upt-api/env.national sdp-upt-api/.env   # add jwt.secret from backup
./stop-sdp.sh api && ./start-sdp.sh api

# 3. Profile checks
./scripts/smoke-api-profiles.sh
```

PHPUnit: `cd sdp-upt-api && ./vendor/bin/phpunit tests/unit/TenantContextTest.php`

Or SQL:

```sql
SELECT DESKRIPSI FROM sdp_pusat.daftar_referensi WHERE ID_LOOKUP='001';  -- empty
SELECT DESKRIPSI FROM db093.daftar_referensi WHERE ID_LOOKUP='001';      -- 093
SELECT DESKRIPSI FROM db001.daftar_referensi WHERE ID_LOOKUP='001';      -- 001
```

## What this does not simulate

- Konsolidasi FTP / binlog / CSV merge pipeline
- Many UPTs in `sdp_pusat` (only 093’s data until more is merged)
- Standalone Kanwil install
