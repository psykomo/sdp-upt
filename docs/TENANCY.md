# Tenancy and MariaDB

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
UPT process layout and the 8081 rule: [`UPT-RUNTIME.md`](UPT-RUNTIME.md).  
Schema while PHP still shares tables: [`PORTING.md`](PORTING.md) §7.

The SPA does not know tenancy. One artifact. The API picks the MariaDB schema.

## Modes

`tenancy.mode` in the API `.env` (default `single`):

| Mode | MariaDB | What a request uses |
|---|---|---|
| `single` | One server, one database | Current UPT box. `database.default.database` is the only schema. |
| `database_per_tenant` | **One server, one database per UPT** | UPT 1 → `upt_1`, UPT 2 → `upt_2`. Same host/user. `db_connect()->setDatabase(...)` per request. |
| `shared_database` | One server, one database, many UPTs | Filter by `perkara.ID_UPT`. Not this deploy. Do not add `tenant_id` on legacy tables while PHP still reads them. |

Project Statements called the middle row “multi tenants, each tenant has its own database inside one shared db server.” That is `database_per_tenant`.

## `database_per_tenant` (central MariaDB)

```
officer / proxy
    → CI4 API  (one process)
         → MariaDB host
              ├─ upt_1
              ├─ upt_2
              └─ upt_…
```

Each schema is a full SDP copy (same tables as legacy). PHP at a UPT, if still running, points at **that UPT’s** schema on this server — not at a second engine.

Env:

```
tenancy.mode = database_per_tenant
tenancy.databasePrefix = upt_

database.default.hostname = <central MariaDB>
database.default.database = upt_1
database.default.username = …
database.default.password = …
```

`database.default.database` is only the **connect** schema (MariaDB wants one). Every authenticated request, and login, switches with:

```
database = tenancy.databasePrefix + tenantId
```

Default prefix `upt_`. Tenant `1` → `upt_1`. Tenant id is the UPT key sealed in the JWT (`uptId`, same meaning as `daftar_referensi` `ID_LOOKUP=001` on that schema). If real `ID_UPT` is `0501`, the schema is `upt_0501`.

The app user must be granted on every `upt_*` schema it may select.

### Who chooses the schema

| When | Source | Not |
|---|---|---|
| `POST /auth/login` | JSON `tenantId` (or `uptId`), or header `X-Tenant-Id` | Guessing from username against the connect schema |
| After login | JWT `uptId` only | `X-Tenant-Id` — a client must not hop to another UPT’s database |

No tenant id in this mode → fail closed (do not stay on `database.default.database`). Tenant id must match `^[A-Za-z0-9_]+$`.

Login looks up `pengguna` **after** the switch, so username/password live in that UPT’s schema. Failed-login rows in `log_login` do too.

### Connection

Repositories and `UnitOfWork` use `db_connect()` (shared default connection). `TenantContext::apply()` calls `setDatabase` on that same object. Do not open `db_connect(null, false)` for ordinary writes — that session would miss the switch and the transaction.

One request = one schema. A Pusat report that must read every UPT is **not** this mode.

### Migrations

Same set on each tenant database (`php spark migrate` per schema). See PORTING.md §7.

## `single` (UPT-local MariaDB)

Unchanged: one box, one MariaDB, one database. Leave `tenancy.mode` unset or `single`. Login does not need `tenantId`.

## `shared_database`

Not implemented beyond a stub (`TenantContext::sharedDatabaseUptId()`). Do not use it for the `upt_1` / `upt_2` deploy.
