# Legacy Sync & Triage

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
How to port a slice: [`PORTING.md`](PORTING.md).  
What is already cut over: [`PORTING-PROGRESS.md`](PORTING-PROGRESS.md).  
Local MariaDB setup: [`LOCAL-DATABASE.md`](LOCAL-DATABASE.md).

Both legacy trees (`102sdp` and `sdp-pusat-legacy`) keep receiving updates while porting runs. This protocol isolates schema, auth, and ported-slice changes from unported menu churn.

## Tracked upstream streams

| Repo | Directory | Upstream ref | Local branch | Merge rule |
|---|---|---|---|---|
| `102sdp` (UPT) | `102sdp/` | `origin/staging` | `feat/modernisasi_sdp` | **Merge (`git merge origin/staging`), never rebase** |
| `pusat` (Kanwil/Pusat) | `sdp-pusat-legacy/` | `origin/production` | `production` | Fast-forward `production` to `origin/production` until national cutover hooks exist |

Single source of truth for watermarks, watched paths, owned tables, and cutover URLs: [`scripts/legacy-watch.conf`](../scripts/legacy-watch.conf).

### Merge discipline (`102sdp`)

- **Always `git merge origin/staging` into `feat/modernisasi_sdp` — never rebase.** Branch history is shared on `origin` with the team, and merging scales cleanly as cutover hooks accumulate. `git diff origin/staging...feat/modernisasi_sdp` always shows pure cutover glue.
- Keep `feat/modernisasi_sdp` pure cutover glue (`Sdp_sso`, `CutoverRollback`, 5-line redirect hooks right after `cekSecurity()`). Do not mix legacy business-logic edits into `feat/modernisasi_sdp`.
- Upstream `102sdp` intentionally omits `.gitignore`, so keep local runtime/config excludes in `102sdp/.git/info/exclude` rather than committing a `.gitignore`.
- Once national cutover hooks are wired in `sdp-pusat-legacy`, follow the same `feat/modernisasi_sdp` + periodic `git merge origin/production` rule.

## Sync & triage procedure (periodic drops)

1. **Fetch & inspect deltas**
   ```bash
   ./scripts/triage-legacy.sh --fetch
   ```
   (Omit `--fetch` to inspect already-fetched refs read-only.)

2. **Review Buckets 1–5**
   Run `./scripts/triage-legacy.sh --diff` (or `--repo 102sdp --diff`) to inspect whitespace-clean hunks for flagged items. Skip the remaining unported module files unless a table/URL hit surfaced them in Bucket 4.

   | Bucket | Meaning |
   |---|---|
   | **1. Schema / SQL** | `querybox/*` and `*.sql` changes (`CREATE`/`ALTER`/`DROP`, `daftar_referensi`, `menu`) |
   | **2. Shared Core** | Auth, RBAC, `Login`, `MY_Controller`, `Menu`, shell layouts |
   | **3. Ported / In-Progress Slices** | Watched controllers, models, libraries, and views per slice |
   | **4. Indirect Hits** | Unported files whose diff queries an owned table or links to a cutover URL |
   | **5. Cutover Conflict Preview** | Files touched by both `feat/modernisasi_sdp` and the incoming upstream drop |

3. **Disposition every Bucket 1–4 hit**
   - **Backport now** — business rule, validation, filter, field, or bugfix that affects parity on `:8082`.
   - **Defer** — change belongs to an unported sub-feature left on `:8080` (e.g., Dukcapil, Cetak, Biometrik) or deferred menu (`V02`, `IFO`); record under notes/gaps in `PORTING-PROGRESS.md` or the Triage Log below.
   - **No-op** — legacy-only HTML/PHP fix or code path not used by the ported slice.
   - **Temp rollback** — urgent production change in a cut-over slice before parity is ready; flip that single slice key back to PHP via `sdp_cutover.pusat.php` or `http://127.0.0.1:8080/CutoverRollback`.

4. **Sync repos, local DB, and backports**
   - Merge `origin/staging` into `102sdp` `feat/modernisasi_sdp`; fast-forward `sdp-pusat-legacy` `production` to `origin/production`.
   - For `querybox/*.sql` updates on local `db_sdp`: prepend `SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';` when piping legacy SQL into OrbStack `sdp-mariadb` (local MariaDB runs `STRICT_TRANS_TABLES` while legacy scripts assume non-strict MariaDB 10.1). Apply new standalone idempotent files directly; for cumulative `*_dari_3.6.1...sql` files, extract and apply **only the incremental delta** after `db_sdp`'s current `VER2` (skipping `DROP/CREATE USER` and `mysql.proc` blocks). Re-run `./scripts/dev-mariadb-prod-sim.sh` when prod-sim schemas (`db093`, `db001`, `sdp_pusat`) also need the schema update.
   - Implement any **Backport now** items in `sdp-upt-api` / `sdp-upt-frontend`.

5. **Advance watermark & log**
   Update the `watermark_sha` in [`scripts/legacy-watch.conf`](../scripts/legacy-watch.conf) **only after** Buckets 1–4 are dispositioned, and append a row to the **Triage Log** below.

## In-progress slice rule

- Check `./scripts/triage-legacy.sh` when starting a slice ([`PORTING.md`](PORTING.md) §1) and again right before cutover (§6).
- When a slice finishes (§7), append its legacy controllers, models, libraries, views, owned tables, and cutover URLs to [`scripts/legacy-watch.conf`](../scripts/legacy-watch.conf).

## Triage Log

| Date | Repo | Range | Backport now | Defer / Notes | DB SQL applied |
|---|---|---|---|---|---|
| 2026-11-19 | `102sdp` | `3381353a..7948a022` | none | Defer: Dukcapil JS parser (`views/ManajemenIdentitas.php`), Pusat broadcast popup (`HeaderNavigation.php`/`Default.php`). No-op: `Login.php`, `identitas_perkara_model.php` (`get_identitas_perkara` MAP widget). Note: `integrasi2.php` + `Integrasi_lib.php` require `9999` + `*_LAIN` contract on `identitas`; `Asesmen_rehab_model.php` writes `dokumen` under `JENIS_DOKUMEN='asesmen_rehab'`. | `17_query_asesmen_rehab.sql`, `18_query_patch_online.sql`, `query_monitoring_pk.sql`, incremental delta of `19_dari_...20261022.sql` (`VER2=2026-10-22`) |
