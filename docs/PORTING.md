# Porting a slice

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
What is already cut over, and which files to copy: [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md).

This is the procedure for one action. It is not Identitas-specific. Copy the last finished slice listed in progress.

## Stack

| App | Folder | Local URL |
|---|---|---|
| Legacy (CI2, PHP 7.4) | `102sdp/` | http://127.0.0.1:8080 |
| API (CI4, latest PHP) | `sdp-api-ci4/` | http://127.0.0.1:8081 |
| Frontend (React Router 8) | `sdp-frontend-reactrouter8/` | http://127.0.0.1:8082 |

```bash
./start-sdp.sh              # all three
./start-sdp.sh api          # one of: legacy | api | frontend
./start-sdp.sh status
./stop-sdp.sh [app]
```

DB: OrbStack `sdp-mariadb`, `127.0.0.1:3307`, `sdp` / `sdp_local`, `db_sdp`.  
Login: `admin` / `admin`. Logs: `.run/`.

`php spark serve` hops port if you only kill the child `php -S`. Use `./stop-sdp.sh api`.

Node `API_BASE_URL` stays `http://127.0.0.1:8081` even when the browser is on a public host.

## 1. Name the slice

From the live URL:

- Controller and method
- Menu id (`cekSecurity("…")` or `$id_menu`)
- Views, models, helpers, tables
- What this slice will **not** include

Map: URL → PHP → SQL → UI → leftover actions.

## 2. Inspect the live page

Log in on 8080. Use `?legacy=1` if that URL already cut over.

Note fields, lookups and “lain-lain” overrides, buttons, files under `upload/…`, empty/404/permission behavior, Pusat vs UPT differences.

## 3. API

Thin controller. Service owns mapping, validation, RBAC, and transactions.
Repository owns SQL for that module’s tables. Create it on the first slice that touches those tables — not only when the query looks “hard”.

Do not add CodeIgniter `Model` classes. Query builder in a repository is the persistence layer — during the port and after PHP is gone.

CI `Model` is Active Record on one table (`id`, `$allowedFields`, timestamps, `find($id)`). Pemasyarakatan tables are keyed by `NOMOR_INDUK` (or similar), columns are legacy uppercase, and one write spans several tables. A Model would still need a service to orchestrate that. We already use CodeIgniter: the query builder, behind the repository.

New API-only tables use the same pattern. Do not split “legacy = repository, new = Model”.

- One repository per module aggregate (`IdentitasRepository` for `identitas` plus its sidik jari / kemiripan / log writes). A dedicated search repository is fine when the list query is a different shape.
- Lookups stay in `DeskripsiLookup` / the Lookup module. Do not re-query `daftar_referensi` inside a domain service.
- Module under `sdp-api-ci4/app/Modules/<Domain>/` (Indonesian name for a pemasyarakatan process: `Identitas`, not `Identity`)
- Route in `api/v1`, behind `jwt` and `menu:<id>`
- Static paths before `(:segment)`
- Envelope `{ ok, data }` / `{ ok, false, message }`
- `RbacService::accessFor` on the payload
- `DeskripsiLookup`, `DateFormat`, `PublicOrigins` for labels, dates, `links.*`
- Ported `links` → `frontendBase()`. Unported `links` → `legacyBase()`.
- Media: prefix stored paths with `legacyBase()`
- Writes: `UnitOfWork::transactional()` (and `nested()` inside a parent)

## 4. Frontend

- Route inside `app-layout` in `app/routes.ts`
- Loader: `requireToken` then `apiGet` (pass `request`)
- `<Link>` to ported screens. `<a href>` to leftover legacy (cetak: `target="_blank"`)
- Reuse `app.css` tokens. Add CSS only for a missing pattern
- `meta({ loaderData })` in React Router 8
- `npm run typecheck` in `sdp-frontend-reactrouter8`
- Update already-ported lists so the new action no longer points at 8080

## 5. Cut over

After `cekSecurity`:

```php
$this->load->library('sdp_sso');
if ($this->sdp_sso->frontend_base_url()
	&& ! $this->sdp_sso->prefer_legacy('YourPageKey'))
{
	$handover = $this->sdp_sso->handover_url('/new/path');
	if ($handover) redirect($handover);
}
```

Copy the last cutover helper rather than rewriting it.

- `?legacy=1` sticky per page key; `?legacy=0` clears it
- New key per URL so one flag does not pin the whole menu to PHP
- Empty frontend base URL: skip redirect
- Add the new key to `Sdp_sso::cutover_slices()` so UPT rollback can see it

`prefer_legacy` check order: config `sdp_frontend_force_legacy` → Pusat file → local file → session `?legacy=1`. See [Rollback](#9-rollback).

Public hosts (`sdp.caripasal.com`, `sdp-api…`, `sdp-front…`) already flow through `PublicOrigins` / `Sdp_sso` / `session.server.ts`. Never hard-code `127.0.0.1` into `links`.

## 6. Verify

- Real row from this DB
- Old URL without `legacy=1` lands on the new page, still logged in
- `?legacy=1` still shows PHP
- 404 and no permission
- Unported buttons still open 8080
- If tunnels are up, cutover goes to the public frontend host

Then update `PORTING-PROGRESS.md`.

## 7. Schema

The API and PHP share one MariaDB. Porting a slice does **not** mean a migration.

When the new API later needs storage PHP never had:

1. Additive only while any PHP path still reads or writes that table: `CREATE TABLE`, `ADD COLUMN` nullable (or with a default). No rename, no drop, no type change that would break CI2.
2. Put the change in `sdp-api-ci4/app/Database/Migrations`. Run `php spark migrate`. Do not `ALTER` inside a controller (legacy does that; we will not).
3. Expand / contract if meaning must change: add the new column, dual-write, switch reads, drop the old column only after that table is fully off 8080.
4. `database_per_tenant`: run the same migration set on each tenant database. `shared_database` / `single`: once.

A new table owned only by the API is fine (prefix or a clearly new name). Do not invent `tenant_id` on legacy tables until PHP is gone from them.

## 8. Sidik jari (desktop)

Leave `SDP-Biometrik` as it is. Do not port capture into 8082. Do not convert the WinForms host to Linux/macOS.

Officers enroll in `SDP.Registration.exe` (IE WebBrowser + Neurotec + `window.external`), which loads PHP `/biometricregistrasi`. Ubah on 8082 may keep daktil text and show existing photos. After a scan, reload the React page.

The Java applet on `viewEdit` is dead. Do not revive it.

## 9. Rollback

No MariaDB change. PHP owns the switch so rollback still works when Node and CI4 are down.

Files next to the local config wrapper (`102sdp/system/application/config/`), gitignored:

| File | Who writes | Effect |
|---|---|---|
| `sdp_cutover.local.php` | UPT admin on 8080 `/CutoverRollback` | Per-slice stay on PHP |
| `sdp_cutover.pusat.php` | Pusat patch / installer only | Same, and UPT cannot clear it |
| `sdp_cutover.example.php` | tracked template | Copy-paste for Pusat |

Shape (missing key = stay cut over):

```php
<?php
return array(
	'ManajemenIdentitasUbah' => true, // true = use PHP
);
```

All Identitas slices: copy the example and uncomment `PencarianIdentitas` and `ManajemenIdentitas`. One slice: only that key. Drop or replace `sdp_cutover.pusat.php` through the same installer channel as other UPT updates. Do not edit tracked `__config.php`.

Nuclear still works: empty `sdp_frontend_base_url`, or `sdp_frontend_force_legacy = true` in the local wrapper.

UPT UI: http://127.0.0.1:8080/CutoverRollback (levels `1` / `4` / `99` / `103`, or Pusat / Kanwil). Toggles the local file only. Pusat lock shows as read-only (“dikunci Pusat”). Officers still enter cut-over pages from the 8080 menu; there is no 8082→8080 bounce.

`?legacy=1` / `?legacy=0` stay as the officer-level hatch when neither file forces that key.
