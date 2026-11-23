# Porting a slice

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
What is already cut over, and which files to copy: [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md).

This is the procedure for one action. It is not Identitas-specific. Copy the last finished slice listed in progress.

## Stack

| App | Folder | Local URL / role |
|---|---|---|
| Legacy UPT (CI2, PHP 7.4) | `102sdp/` (`sdp/`, `system/`) | http://127.0.0.1:8080 — production UPT tree |
| Legacy Kanwil/Pusat (CI2) | `sdp-pusat-legacy/` (`www/sdp_pusat/`, `system/`) | Reference only for national behavior (not wired to `start-sdp.sh` yet) |
| API (CI4, latest PHP) | `sdp-upt-api/` | http://127.0.0.1:8081 |
| Frontend (React Router 8 SPA) | `sdp-upt-frontend/` | http://127.0.0.1:8082 and LAN IP (`/api` → localhost :8081) |

**Production today:** two legacy source trees (UPT vs Kanwil/Pusat). **Port target:** one API + one SPA, two deploy targets (`db_sdp` / `sdp_pusat`). Every slice must read **both** trees and merge behavior into that one codebase.

```bash
./start-sdp.sh --dev        # porting: Vite HMR on :8082, no rebuild
./start-sdp.sh              # UPT-shaped: build + Caddy on :8082
./start-sdp.sh api          # one of: legacy | api | frontend
./start-sdp.sh status
./stop-sdp.sh [app]
```

DB: OrbStack `sdp-mariadb`, `127.0.0.1:3307`, `sdp` / `sdp_local`, `db_sdp`.  
Login: `admin` / `admin`. Logs: `.run/`.

`php spark serve` hops port if you only kill the child `php -S`. Use `./stop-sdp.sh api`.

The SPA calls same-origin `/api/v1`. Caddy (local) or Apache/nginx (UPT) forwards `/api` to `127.0.0.1:8081`. The browser never dials port 8081. Why: [UPT-RUNTIME.md](UPT-RUNTIME.md).

This app is React Router Framework Mode, **SPA** (`ssr: false`). Use `clientLoader` / `clientAction`. Do not add a server `loader` except on the root route at build time.

## 1. Name the slice

From the live URL:

- Controller and method
- Menu id (`cekSecurity("…")` or `$id_menu`)
- Views, models, helpers, tables
- What this slice will **not** include

Map: URL → PHP → SQL → UI → leftover actions. For PHP, open the matching controller/method in **both** `102sdp` and `sdp-pusat-legacy` (controller names usually match; bodies may diverge). Check legacy drift (`./scripts/triage-legacy.sh`) at slice kickoff and again right before cutover ([`LEGACY-SYNC.md`](LEGACY-SYNC.md)).

## 2. Runtime profiles (UPT / Pusat / Kanwil)

**Deploy** (where the app runs) and **behavior** (what legacy branches on) are not the same thing.

**Standalone Kanwil** (own server, own DB, `is_transisi_sdp_kanwil=TRUE`) is out of scope — not used and not planned.

### Two legacy trees → one ported codebase

| Tree | Folder | What it is for |
|---|---|---|
| **UPT** | `102sdp/` | Production UPT box; local 8080; verify UPT cutover here |
| **Kanwil/Pusat** | `sdp-pusat-legacy/` | Production national tree; source of truth for Pusat/Kanwil behavior |

Do not port from `102sdp` alone and invent national gaps. Diff the same action in both trees. Controller/URL names are often shared (`PencarianIdentitas`, `ManajemenIdentitas`, …); implementation, SQL, session keys, and media paths may differ. Record meaningful diffs in [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md) national notes. The ported API/SPA must cover **both** trees’ behavior via profile branches — not two modules and not a second SPA.

### Deploy (two targets — ported end state)

| Deploy | DB | `daftar_referensi` `001` |
|---|---|---|
| **UPT box** | Local schema (`db_sdp` on the box) | UPT `ID_UPT` |
| **National app** | `sdp_pusat` | Empty = Pusat boot; Kanwil code = Kanwil officer on the same national app |

Tenancy for each deploy: [`TENANCY.md`](TENANCY.md). National uses `shared_database` — UPT, Kanwil, and Pusat share one schema (e.g. `sdp_pusat`); they differ by **site profile** (`isPusat` / `isKanwil`), not by database.

### Behavior (grep three flags per slice — both trees)

| Behavior | Session flag | Typical runtime | Prefer reading |
|---|---|---|---|
| **UPT** | neither Pusat nor Kanwil | UPT box | `102sdp` |
| **Pusat** | `isPusat` | National app | `sdp-pusat-legacy` |
| **Kanwil** | `isKanwil` | National app (scoped Kanwil; not a separate install) | `sdp-pusat-legacy` |

Within each tree, differences are often PHP branches: extra columns, `upt` joins, session scoping (`upt_session`, `kanwil_session`), blocked actions, upload/photo paths. Across trees, the same branch may disagree — unify into one condition in the port; do not keep two source copies.

Legacy patterns vary by slice — do not assume one “HQ” branch:

- `isPusat` only — Pusat-only screens or blocks
- `isKanwil` only (often `elseif`) — Kanwil-only paths
- `isPusat || isKanwil` — shared national list behavior (e.g. Identitas Asal UPT column)
- `isKanwil && !is_transisi_sdp_kanwil` — merged Kanwil on national (still relevant without standalone Kanwil)

**Before you code**

```bash
rg -n 'isPusat|isKanwil|upt_session|kanwil_session' \
  102sdp/system/application/controllers/<Controller>.php \
  sdp-pusat-legacy/system/application/controllers/<Controller>.php
```

Also check views in both trees if the controller delegates layout. Classify each branch: Pusat-only, Kanwil-only, or combined. Note columns, SQL joins, filters, permission blocks, media paths, and **tree-vs-tree** diffs.

**Implement**

- Same API route and SPA route for every profile. Branch in service or repository — not `/pusat/…` or a second module.
- API: `SiteContextService` (boot from `001`) and `CurrentUser` (`isPusat`, `isKanwil` separately).
- Mirror the **merged** legacy condition (both trees). Use `isHq()` only when both trees (or the national tree for HQ-only paths) use `isPusat || isKanwil` in that branch.
- Frontend: Pusat/Kanwil-only columns and filters only when the API exposes them (e.g. `asalUpt`, filter params).

### Row scope (wire on every perkara-bound slice)

**Tenancy** picks the schema; **row scope** picks which rows inside that schema the officer may see. On `shared_database` (`sdp_pusat`), menu RBAC alone is not enough — officers share one DB. Wire row scope on **every ported slice** that lists or loads data tied to `perkara` / `upt`, even while you still verify on `db_sdp` (`single`). Same code path then survives the move to national; on UPT box the filter is usually redundant but safe.

Branch on `CurrentUser` — **not** on `tenancy.mode`. Profile resolution order matters (JWT `uptId` means different things):

| Profile | Condition | SQL scope |
|---|---|---|
| **Kanwil** | `isKanwil` + `uptId` set | `upt.KANWIL = uptId` (Kanwil **code** — all UPTs in wilayah) |
| **UPT officer** | `!isPusat && !isKanwil` + `uptId` set | `perkara.ID_UPT = uptId` (one prison) |
| **Pusat** | `isPusat` (not Kanwil) | No default row filter |

**Implement (each slice)**

- **By-key routes** (lihat, ubah form, PUT, DELETE): assert scope **before** load/write; out of scope → **403**; missing row → **404**.
- **Search / export**: same scope in the list repository (`WHERE` or `EXISTS` on `perkara` / `upt`).
- Grep legacy `upt_session` / `kanwil_session` — some screens filter in session; others (e.g. Identitas search) never did. On `shared_database` the API still needs scope even when legacy list SQL did not use session keys.
- Entity-specific rules (e.g. Identitas “no active STA parent perkara → allow”) stay in that module — grep legacy before copying.

**Reference implementation:** `sdp-upt-api/app/Modules/Shared/Access/RowScope.php` and `PerkaraScopeRepository.php` (`IdentitasAccessService` is a thin wrapper over them). Reuse `RowScope` + `PerkaraScopeRepository` on every new perkara-bound module — do not copy-paste `EXISTS` SQL into services.

**Verify**

- **UPT:** `db_sdp` — behavior unchanged; scope still runs.
- **National UPT sim:** `sdp_pusat`, login with `tenantId` — own UPT OK; cross-UPT key → **403** on detail/ubah.
- **Kanwil:** `kanwil_jambi` on `sdp_pusat` — rows under that Kanwil OK; other Kanwil → **403**.
- **Pusat:** `admin` without `tenantId` — still sees all rows (no filter).

Record row-scope behavior in [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md) notes (see profile tags).

**Verify** (profiles)

- **UPT:** real row on local `db_sdp` — required before cutover.
- **Pusat / Kanwil:** on `sdp_pusat` when available (separate logins or roles if you have them). If not available locally, ship UPT verify and record Pusat/Kanwil as ⬜ in [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md).

Do not ship UPT-only behavior when legacy has a Pusat or Kanwil branch unless the gap is written in progress notes.

**Slice prompt (paste with a 8080 URL)**

> Port per `docs/PORTING.md`. Read the slice in **both** `102sdp` and `sdp-pusat-legacy`. Grep and port **UPT**, **Pusat** (`isPusat`), and **Kanwil** (`isKanwil`) — mirror each branch exactly (`Pusat only`, `Kanwil only`, or `Pusat \|\| Kanwil`); unify tree diffs into one API/SPA. Standalone Kanwil deploy is out of scope. Same routes; branch in API/services. **Wire row scope** on perkara-bound slices (§2 Row scope). Verify on UPT; tag Pusat and Kanwil in `PORTING-PROGRESS.md`.

## 3. Inspect the live page

Log in on 8080 (UPT tree). Use `?legacy=1` if that URL already cut over.

Note fields, lookups and “lain-lain” overrides, buttons, files under `upload/…`, empty/404/permission behavior, and **UPT vs Pusat vs Kanwil** differences (see §2). For national-only UI you cannot click locally yet, read `sdp-pusat-legacy` views/controllers as the second source of truth.

## 4. API

Thin controller. Service owns mapping, validation, RBAC, and transactions.
Repository owns SQL for that module’s tables. Create it on the first slice that touches those tables — not only when the query looks “hard”.

Do not add CodeIgniter `Model` classes. Query builder in a repository is the persistence layer — during the port and after PHP is gone.

CI `Model` is Active Record on one table (`id`, `$allowedFields`, timestamps, `find($id)`). Pemasyarakatan tables are keyed by `NOMOR_INDUK` (or similar), columns are legacy uppercase, and one write spans several tables. A Model would still need a service to orchestrate that. We already use CodeIgniter: the query builder, behind the repository.

New API-only tables use the same pattern. Do not split “legacy = repository, new = Model”.

- One repository per module aggregate (`IdentitasRepository` for `identitas` plus its sidik jari / kemiripan / log writes). A dedicated search repository is fine when the list query is a different shape.
- Lookups stay in `DeskripsiLookup` / the Lookup module. Do not re-query `daftar_referensi` inside a domain service.
- Module under `sdp-upt-api/app/Modules/<Domain>/` (Indonesian name for a pemasyarakatan process: `Identitas`, not `Identity`)
- Route in `api/v1`, behind `jwt` and `menu:<id>[,<tipe>]` (register new menus in `App\Modules\Auth\Support\PortedMenuRegistry` so `/auth/me` and the SPA nav expose them automatically)
- Dual-password (`LoginDP`) flows: call `POST /api/v1/auth/supervisor` with `menuId`, `resourceKey`, and `action` (`AuthService::issueSupervisorGrant` / `readSupervisorGrant`)
- Envelope `{ ok, data }` / `{ ok, false, message }`
- `RbacService::accessFor` on the payload
- `DeskripsiLookup`, `DateFormat`, `PublicOrigins` for labels, dates, `links.*`
- Ported `links` → `frontendBase()`. Unported `links` → `legacyBase()`.
- Media: prefix stored paths with `legacyBase()`
- Writes: `UnitOfWork::transactional()` (inner calls join the parent; CI4 only commits the outermost)
- Services construct their own collaborators (`new IdentitasUpdateService()`). The controller does HTTP only.
- **Row scope** on perkara-bound slices: assert on by-key routes, filter on search/export — see §2 Row scope. Use `Shared\Access\RowScope` + `PerkaraScopeRepository`.

## 5. Frontend

This app is React Router Framework Mode, SPA (`ssr: false`). Before changing routes, loaders, or actions, read [`../sdp-upt-frontend/.agents/skills/react-router/SKILL.md`](../sdp-upt-frontend/.agents/skills/react-router/SKILL.md), then `references/framework-mode.md` and `how-to/spa.md`.

- Route inside `app-layout` in `app/routes.ts`
- `clientLoader`: `apiGet` (pass `request`; cookie is sent same-origin). 401 → `/login`
- `<Link>` to ported screens. `<a href>` to leftover legacy (cetak: `target="_blank"`)
- Reuse `app.css` tokens. Add CSS only for a missing pattern
- `meta({ loaderData })` in React Router 8
- `npm run typecheck` in `sdp-upt-frontend`
- Update already-ported lists so the new action no longer points at 8080

## 6. Cut over

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

`prefer_legacy` check order: config `sdp_frontend_force_legacy` → Pusat file → local file → session `?legacy=1`. See [Rollback](#10-rollback).

Public hosts (`sdp.caripasal.com`, `sdp-api…`, `sdp-front…`) already flow through `PublicOrigins` / `Sdp_sso` / `session.ts`. Never hard-code `127.0.0.1` into `links`.

## 7. Verify

- Real row from this DB (UPT: `db_sdp`)
- UPT / Pusat / Kanwil / multi-tenant behavior via `tests/feature/<Module>ProfilesFeatureTest.php` and `./scripts/verify-profiles.sh`
- Row scope: cross-profile 403 on national (`sdp_pusat`) verified automatically (§2 Row scope)
- Old URL without `legacy=1` lands on the new page, still logged in
- `?legacy=1` still shows PHP
- 404 and no permission
- Unported buttons still open 8080
- If tunnels are up, cutover goes to the public frontend host

Then update `PORTING-PROGRESS.md` (include profile tags — see progress file) and append this slice's legacy files, owned tables, and cutover URLs to `scripts/legacy-watch.conf` ([`LEGACY-SYNC.md`](LEGACY-SYNC.md)).

## 8. Schema

The API and PHP share one MariaDB. Porting a slice does **not** mean a migration.

When the new API later needs storage PHP never had:

1. Additive only while any PHP path still reads or writes that table: `CREATE TABLE`, `ADD COLUMN` nullable (or with a default). No rename, no drop, no type change that would break CI2.
2. Put the change in `sdp-upt-api/app/Database/Migrations`. Run `php spark migrate`. Do not `ALTER` inside a controller (legacy does that; we will not).
3. Expand / contract if meaning must change: add the new column, dual-write, switch reads, drop the old column only after that table is fully off 8080.
4. `database_per_tenant`: run the same migration set on each tenant database (`db001`, `db093`, …). `shared_database` / `single`: once. See [`TENANCY.md`](TENANCY.md).

A new table owned only by the API is fine (prefix or a clearly new name). Do not invent `tenant_id` on legacy tables until PHP is gone from them.

## 9. Sidik jari (desktop)

Leave `SDP-Biometrik` as it is. Do not port capture into 8082. Do not convert the WinForms host to Linux/macOS.

Officers enroll in `SDP.Registration.exe` (IE WebBrowser + Neurotec + `window.external`), which loads PHP `/biometricregistrasi`. Ubah on 8082 may keep daktil text and show existing photos. After a scan, reload the React page.

The Java applet on `viewEdit` is dead. Do not revive it.

## 10. Rollback

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
