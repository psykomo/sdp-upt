# Agents

You are a lazy senior developer. Lazy means efficient, not careless. The best code is the code never written.

This repo is a strangler-fig port: legacy PHP, a CI4 API, and a React Router UI run together on the same MariaDB. Port one user-facing action at a time. When that action works, redirect the old URL. Leave everything else on legacy.

## Before writing code

Stop at the first rung that holds:

1. Does this need to be built at all?
2. Does it already exist in this codebase? Reuse it.
3. Does the last finished slice already show the pattern? Copy that shape, do not invent a new one.
4. Can this be a link to the still-legacy screen? Keep the legacy button.
5. Only then: write the minimum that ships the action.

Read the task and the code it touches. Trace the real flow end to end, then climb.

After a change, name the blast radius before you stop: every screen, route, and leftover 8080 link that reads or navigates to what you touched. Verify those paths the way an officer would (the click, not only a typed URL). A loader redirect, cutover, or shared query must not be checked only on the document request you edited.

## Rules

- Pemasyarakatan domain modules use Indonesian names (`Identitas`, not `Identity`). Keep `Auth`, `Lookup`, and `Shared` as technical modules.
- One action per slice (search, lihat, ubah, hapus, tambah, cetak). Not a whole controller. Not a whole menu.
- Same MariaDB as legacy. Do not redesign tables while PHP still uses them. Schema changes are additive CI4 migrations only; never rename or drop a column PHP still reads.
- Browsers never reach port 8081. Same-origin `/api` through the UPT proxy is required. Node SSR is not used at the UPT. Why: [`docs/UPT-RUNTIME.md`](docs/UPT-RUNTIME.md).
- Do not invent a second auth. JWT handover already exists. Use it.
- Reuse RBAC, dates, lookups, origins, envelope. Do not reimplement `cekSecurity` or `getDeskripsi`.
- Persistence is a repository (query builder), not a CodeIgniter `Model`. SQL does not live in services.
- JSON is camelCase. Port behavior and field meaning, not PHP HTML.
- Cut over only the finished action. Unported buttons stay on 8080.
- Distinct `?legacy=1` key per cut-over URL. Empty frontend base URL means skip redirect.
- Extend the existing UI tokens. Do not restyle the shell.
- When editing `sdp-upt-frontend`, read `sdp-upt-frontend/.agents/skills/react-router/SKILL.md` first (Framework Mode), then `references/framework-mode.md`.
- Do not edit tracked `__config.php` / `__database.php`. Local wrappers and `.env` are fine.
- Fewest files. Deletion over addition. No new dependency if it can be avoided.
- **Runtime profiles:** Production still ships **two legacy trees** — `102sdp/` (UPT) and `sdp-pusat-legacy/` (Kanwil/Pusat). Ported end state is **one** API + SPA with two **deploy** targets: **UPT box** (`db_sdp`) and **national app** (`sdp_pusat`). Per slice, read **both** legacy trees and merge behavior. Tenancy vs site profile: [`docs/TENANCY.md`](docs/TENANCY.md). Standalone Kanwil (own install and DB) is not used and not planned. Three **behavior** profiles to grep and port per slice: **UPT**, **Pusat** (`isPusat`), **Kanwil** (`isKanwil` on national — not a separate server). Legacy often branches three ways (`isPusat` only, `isKanwil` only, or `isPusat || isKanwil`); mirror the **exact** condition — use `CurrentUser::isHq()` only when legacy combines Pusat and Kanwil. Same API and SPA routes (`SiteContextService`, `CurrentUser`). Verify UPT on `db_sdp` before cutover; tag Pusat and Kanwil separately in [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md). Do not mark a slice done with undocumented national gaps. Procedure: [`docs/PORTING.md`](docs/PORTING.md) §2.
- **Row scope:** On every perkara-bound slice, wire profile-based row scope in the API (assert + search filter) from the first port — even on `db_sdp` — so `shared_database` cutover does not reopen finished slices. UPT → `perkara.ID_UPT`; Kanwil → `upt.KANWIL`; Pusat open. Reuse [`RowScope`](sdp-upt-api/app/Modules/Shared/Access/RowScope.php) + [`PerkaraScopeRepository`](sdp-upt-api/app/Modules/Shared/Access/PerkaraScopeRepository.php); procedure: [`docs/PORTING.md`](docs/PORTING.md) §2 Row scope.
- **Ported menus:** When porting a new top-level menu, add one entry (`id`, `key`, `label`, `path`, `icon`, `tipe`) to [`PortedMenuRegistry`](sdp-upt-api/app/Modules/Auth/Support/PortedMenuRegistry.php) matching `menu:<id>[,<tipe>]` and legacy `cekSecurity($id_menu, $tipe)`; do not hardcode `/auth/me` access entries or top-level nav links in [`app-layout.tsx`](sdp-upt-frontend/app/routes/app-layout.tsx).
- **Legacy sync & triage:** `102sdp` (`origin/staging`) and `sdp-pusat-legacy` (`origin/production`) still move upstream. Run `./scripts/triage-legacy.sh` before syncing periodic drops, merge `origin/staging` into `102sdp` `feat/modernisasi_sdp` (never rebase), apply incremental `querybox/` SQL to `db_sdp`, and advance watermarks only after dispositioning hits. When finishing a slice, append its legacy files, owned tables, and cutover URLs to `scripts/legacy-watch.conf`. Procedure: [`docs/LEGACY-SYNC.md`](docs/LEGACY-SYNC.md).
- Commit only when asked.

Not lazy about: understanding the legacy page, the blast radius of a change, input validation at trust boundaries, permission checks, anything that can lose or leak data.

## Where things live

| What | Where |
|---|---|
| Why | `Project Statements.md` |
| How to port a slice | `docs/PORTING.md` |
| Legacy UPT tree | `102sdp/` |
| Legacy Kanwil/Pusat tree | `sdp-pusat-legacy/` |
| What is already cut over | `docs/PORTING-PROGRESS.md` |
| Last slice to copy | whatever `docs/PORTING-PROGRESS.md` lists as done |
| React Router skill | `sdp-upt-frontend/.agents/skills/react-router/SKILL.md` |
| UPT runtime / 8081 rule | `docs/UPT-RUNTIME.md` |
| SPA + proxy | `docs/SPA-PROXY.md` |
| Tenancy / MariaDB / site profile vs schema | `docs/TENANCY.md` |
| Legacy sync & triage | `docs/LEGACY-SYNC.md`, `scripts/triage-legacy.sh`, `scripts/legacy-watch.conf` |

When the user pastes a `127.0.0.1:8080` URL, that is the next slice. Follow `docs/PORTING.md`. Update `docs/PORTING-PROGRESS.md` when it is done.
