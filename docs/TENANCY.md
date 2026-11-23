# Tenancy and MariaDB

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
Runtime profiles (UPT / Pusat / Kanwil **behavior**) and **row scope**: [`PORTING.md`](PORTING.md) §2.  
UPT process layout and the 8081 rule: [`UPT-RUNTIME.md`](UPT-RUNTIME.md).  
Schema while PHP still shares tables: [`PORTING.md`](PORTING.md) §8.  
Local multi-schema setup: [`LOCAL-DATABASE.md`](LOCAL-DATABASE.md).

The SPA does not know tenancy. One artifact. The API picks the MariaDB schema.

**Legacy source (production):** two trees — `102sdp` (UPT) and `sdp-pusat-legacy` (Kanwil/Pusat). **Ported deploy:** still two targets below, but **one** codebase. Porting procedure for merging both trees: [`PORTING.md`](PORTING.md) §2.

## Two layers (do not confuse them)

Porting touches **two independent axes**. [`PORTING.md`](PORTING.md) §2 covers behavior; this file covers MariaDB.

| Layer | Question | Mechanism | Examples |
|---|---|---|---|
| **Tenancy** | Which **schema** does this request connect to? | `tenancy.mode`, `TenantContext`, JWT `uptId` | `db_sdp`, `db093`, `sdp_pusat` |
| **Site profile** | Is this officer **UPT**, **Pusat**, or **Kanwil**? | `daftar_referensi` `001`, `SiteContextService`, JWT `isPusat` / `isKanwil` | Asal UPT column, `kanwil_session` filters, blocked menus |

- **Tenancy** = which MariaDB **schema** the API connects to, and whether one schema is shared by all officers or split per UPT.
- **Site profile** = flags and session scoping **inside** whatever schema is connected.
- In **`shared_database`**, UPT, Kanwil, and Pusat officers all use the **same** database (e.g. `sdp_pusat`). They differ by **site profile** (`isPusat`, `isKanwil`, UPT), not by schema.
- **Row scope** (which rows inside the schema): wire on every perkara-bound ported slice from day one — procedure in [`PORTING.md`](PORTING.md) §2 Row scope; Identitas reference: `IdentitasAccessService`.
- Standalone Kanwil (own install and DB) is **not** used or planned. Kanwil in this repo means **Kanwil officer on the national / shared database**.

Code references:

- Tenancy: `App\Modules\Shared\Tenancy\TenantContext`
- Site profile: `App\Modules\Auth\Services\SiteContextService`, `CurrentUser` (`isPusat`, `isKanwil`, `isHq()` only when legacy combines both)

## Deploy targets (tenancy mapping)

| Deploy | Typical `tenancy.mode` | MariaDB schema | Who connects | Site profile at login |
|---|---|---|---|---|
| **UPT box** (local) | `single` | Local DB on the box (e.g. `db_sdp`) | That UPT only | UPT |
| **National / consolidated** | `shared_database` | One shared schema (e.g. `sdp_pusat`) | UPT, Kanwil, and Pusat officers | UPT, Kanwil, or Pusat |
| **Central MariaDB, one schema per UPT** | `database_per_tenant` | `db001`, `db093`, … on one host | UPT (per schema) | UPT (officer picks tenant at login) |

National **Pusat** and **Kanwil** verification for a ported slice: same shared schema, different logins or roles — tag separately in [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md). That is site profile, not a second database.

## Modes

`tenancy.mode` in the API `.env` (default `single`):

| Mode | MariaDB | Who uses it |
|---|---|---|
| `single` | One server, **one database**, one UPT-shaped dataset | **UPT box** — local install; schema holds that prison’s data only (e.g. `db_sdp`). |
| `database_per_tenant` | One server, **one database per UPT** | Central host with `db001`, `db093`, … — legacy replica name `db` + `ID_UPT`; API switches schema per JWT `uptId`. |
| `shared_database` | One server, **one database for everyone** | **UPT, Kanwil, and Pusat** officers all connect to the **same** schema (e.g. `sdp_pusat`). Rows from many UPTs live in one DB; scope in SQL/session (`perkara.ID_UPT`, `upt_session`, `kanwil_session`, `isPusat` / `isKanwil`). |

Summary:

```
single              → one DB, one UPT’s world (local box)
database_per_tenant → many DBs on one server, one UPT per schema
shared_database     → one DB, all profiles (UPT + Kanwil + Pusat)
```

Project Statements called the middle row “multi tenants, each tenant has its own database inside one shared db server.” That is `database_per_tenant`. The third row is “multi tenants single database single db server” — everyone on the same MariaDB schema.

## `database_per_tenant` (central MariaDB)

```
officer / proxy
    → CI4 API  (one process)
         → MariaDB host
              ├─ db001
              ├─ db093
              └─ db…
```

Each schema is a full SDP copy (same tables as legacy). PHP at a UPT, if still running, points at **that UPT’s** schema on this server — not at a second engine.

This is **not** the national consolidated model (`sdp_pusat`). It is many isolated UPT-shaped schemas on one MariaDB host.

Env:

```
tenancy.mode = database_per_tenant
tenancy.databasePrefix = db

database.default.hostname = <central MariaDB>
database.default.database = db093
database.default.username = …
database.default.password = …
```

`database.default.database` is only the **connect** schema (MariaDB wants one). Every authenticated request, and login, switches with:

```
database = tenancy.databasePrefix + tenantId
```

Default prefix `db` (legacy-aligned). Tenant `093` → `db093`. Tenant id is the UPT key sealed in the JWT (`uptId`, same meaning as `daftar_referensi` `ID_LOOKUP=001` on that schema). If real `ID_UPT` is `0501`, the schema is `db0501`.

The app user must be granted on every `db*` tenant schema it may select.

Local simulation: [`LOCAL-DATABASE.md`](LOCAL-DATABASE.md).

### Who chooses the schema

| When | Source | Not |
|---|---|---|
| `POST /auth/login` | JSON `tenantId` (or `uptId`), or header `X-Tenant-Id` | Guessing from username against the connect schema |
| After login | JWT `uptId` only | `X-Tenant-Id` — a client must not hop to another UPT’s database |

No tenant id in this mode → fail closed (do not stay on `database.default.database`). Tenant id must match `^[A-Za-z0-9_]+$`.

Login looks up `pengguna` **after** the switch, so username/password live in that UPT’s schema. Failed-login rows in `log_login` do too.

### Connection

Repositories and `UnitOfWork` use `db_connect()` (shared default connection). `TenantContext::apply()` calls `setDatabase` on that same object. Do not open `db_connect(null, false)` for ordinary writes — that session would miss the switch and the transaction.

One request = one schema. A Pusat report that must read every UPT in one query is **not** this mode — use `shared_database` (one national schema).

### Migrations

Same set on each tenant database (`php spark migrate` per schema). See [`PORTING.md`](PORTING.md) §8.

## `single` (UPT box)

One install, one MariaDB schema, one UPT’s local dataset.

| | |
|---|---|
| Typical deploy | UPT box |
| `database.default.database` | Local schema (e.g. `db_sdp`) |
| `001` in schema | That UPT’s `ID_UPT` |
| Site profile | UPT |

Leave `tenancy.mode` unset or `single`. Login does not need `tenantId`.

This mode is **not** the national consolidated database. National / all-profile deploy uses `shared_database`.

## `shared_database` (national — one DB for everyone)

**One MariaDB schema** shared by **UPT, Kanwil, and Pusat** officers. No schema switch per profile — everyone hits `database.default.database` (typically `sdp_pusat` on the national server).

| | |
|---|---|
| Typical deploy | National app (after or alongside legacy on same DB) |
| Officers | UPT, Kanwil, Pusat — same database |
| `001` in schema | Empty → Pusat boot; Kanwil `KODE` → Kanwil; UPT id on rows from konsolidasi |
| Scoping | Application layer — `perkara.ID_UPT`, `upt_session`, `kanwil_session`, `isPusat` / `isKanwil` (see [`PORTING.md`](PORTING.md) §2) |

Env:

```
tenancy.mode = shared_database

database.default.hostname = <national MariaDB>
database.default.database = sdp_pusat
database.default.username = …
database.default.password = …
```

`TenantContext::apply()` does **not** switch schemas in this mode. JWT `uptId` scopes **which rows** an UPT officer may see inside the shared schema. Kanwil scoping uses `upt.KANWIL` on JWT `uptId` (Kanwil code). Shared row-scope primitives live in `App\Modules\Shared\Access\RowScope` and `PerkaraScopeRepository` (used by `IdentitasAccessService`).

Row-level scoping beyond tenancy mode: `Shared\Access\RowScope` + `PerkaraScopeRepository` (`perkara.ID_UPT` / `upt.KANWIL`). `TenantContext::sharedDatabaseUptId()` remains a stub for generic reuse. Do not add `tenant_id` on legacy tables while PHP still reads them.

`SiteContextService::resolve()` still reads `001` after connect — empty → `isPusat`, Kanwil code → `isKanwil`. On national `shared_database`, optional login `tenantId` / `uptId` sets UPT officer context (`isPusat=false`, JWT `uptId`) without switching schema — mirrors legacy `upt_session`. Those flags go on the JWT; porting branches on them per [`PORTING.md`](PORTING.md) §2.

## Porting and tenancy

1. **Tenancy** — `single` on UPT box first; national target is `shared_database` on `sdp_pusat`.
2. **Site profile** — grep legacy `isPusat`, `isKanwil`, `upt_session`, `kanwil_session`; mirror exact branches ([`PORTING.md`](PORTING.md) §2).
3. **Verify** — UPT on `db_sdp` (`single`) before cutover; Pusat and Kanwil on `sdp_pusat` (`shared_database`) when available.
4. **Repositories** — `database_per_tenant`: never assume `database.default.database` after login; `shared_database`: same schema for all profiles, apply row/session scoping like legacy; Kanwil lists may use `kanwil_session` rather than JWT `uptId` alone.
