# Porting progress

Update this file at the end of every finished slice. Rules: [`../AGENTS.md`](../AGENTS.md). Procedure: [`PORTING.md`](PORTING.md). Tenancy / schema: [`TENANCY.md`](TENANCY.md). Local sim: [`LOCAL-DATABASE.md`](LOCAL-DATABASE.md). Legacy sync: [`LEGACY-SYNC.md`](LEGACY-SYNC.md).

Copy the last **Done** row. Do not rebuild auth, origins, lookups, or the UI shell.

Every slice: read matching PHP in **`102sdp`** (UPT) and **`sdp-pusat-legacy`** (Kanwil/Pusat), merge into one API/SPA. Note tree-vs-tree diffs under national notes.

When a slice is cut over, add its key to `Sdp_sso::cutover_slices()` in `102sdp/system/application/libraries/Sdp_sso.php` so `/CutoverRollback` can toggle it.

Per-slice rollback (no DB): UPT admin at http://127.0.0.1:8080/CutoverRollback writes `sdp_cutover.local.php`. Pusat drops `sdp_cutover.pusat.php` via installer. Missing key = stay cut over. See `docs/PORTING.md` §10.

## Profile tags (UPT / Pusat / Kanwil)

Standalone Kanwil **deploy** is out of scope. Tag **behavior** on each finished slice:

```text
Profiles: UPT ✅ | Pusat ⬜ | Kanwil ⬜
Row scope: … (or N/A — no perkara/upt join)
National notes: …
```

- **Row scope** — how UPT / Kanwil / Pusat filtering is implemented (`perkara.ID_UPT`, `upt.KANWIL`, session keys, or N/A). Required for perkara-bound slices; see [`PORTING.md`](PORTING.md) §2 Row scope.

- **UPT ✅** — verified on local `db_sdp` (required before cutover).
- **Pusat ⬜** — verified on `sdp_pusat` with Pusat context when available.
- **Kanwil ⬜** — verified on `sdp_pusat` with Kanwil context when available (Kanwil officer on national app, not standalone install).
- **National notes** — which legacy branches apply (`isPusat` only, `isKanwil` only, `isPusat \|\| isKanwil`, `upt_session`, `kanwil_session`, columns, joins, media). Cite **`102sdp` vs `sdp-pusat-legacy`** when they disagree. If Pusat and Kanwil share one branch, say so. List gaps explicitly.

Put profile lines in the **Notes** column or as bullets under the table row.

## Done

| Slice | Legacy URL | New UI | API | Cutover key | Notes |
|---|---|---|---|---|---|
| Pencarian identitas | `/PencarianIdentitas` | `/identitas` | `GET /api/v1/identitas`, `GET /api/v1/identitas/export` | `PencarianIdentitas` | Grid + analisa. Menu `10`. Profiles: UPT ✅ \| Pusat ✅ \| Kanwil ✅ (`IdentitasProfilesFeatureTest`). Row scope: UPT `perkara.ID_UPT`; Kanwil `upt.KANWIL` (stricter than legacy unscoped search — intentional); Pusat open. National: `upt` join for Asal UPT (`isHq()`); grid columns from API `columns`; `canPrint` gates cetak menu; HQ working-scope picker (`POST /auth/working-scope`, JWT `sessionFilterUptId` / `sessionFilterKanwilId`) in app shell. Mode analisa: legacy `catatKunjungan` deep link to Kunjungan menu. |
| Lihat identitas | `/ManajemenIdentitas/lihat/{noin}` | `/identitas/:nomorInduk` | `GET /api/v1/identitas/{noin}`, `GET /api/v1/identitas/{noin}/documents`, `GET /api/v1/documents/{id}/download`, `GET /api/v1/documents/{id}/view` | `ManajemenIdentitas` | Read-only. Dukcapil / KTP panels skipped. Profiles: UPT ✅ \| Pusat ✅ \| Kanwil ✅ (`IdentitasProfilesFeatureTest`). Row scope on all paths; 403 cross-scope. National: mutasi photo path fallback via `IdentitasPhotoResolver` (`isHq()`). Dokumen lampiran tab on lihat (`Modules/Dokumen`). |
| Ubah identitas | `/ManajemenIdentitas/viewEdit/{noin}` | `/identitas/:nomorInduk/ubah` | `GET /api/v1/identitas/{noin}/form`, `PUT /api/v1/identitas/{noin}`, `POST/PUT/DELETE /api/v1/identitas/{noin}/documents` + `/api/v1/documents/{id}` | `ManajemenIdentitasUbah` | Writes biodata/alamat/pekerjaan/keluarga/fisik/foto. Ambil Foto is `getUserMedia` on the ubah form (same PUT). Dual password stays on PHP before redirect. Scanner sidik jari, Dukcapil/KTP still legacy. Profiles: UPT ✅ \| Pusat ✅ \| Kanwil ✅ (`IdentitasProfilesFeatureTest`: HQ 403 write-guard + cross-scope 403). Row scope; AKSES002 locks tanggal lahir / kewarganegaraan / agama on form + PUT (`IdentitasSensitiveFieldService`). PDF dokumen upload/delete on dedicated tab; kemiripan add/remove UI wired to existing PUT `nomorIndukSimilar`. |
| Hapus identitas | `/ManajemenIdentitas/viewDelete/{noin}` | `/identitas/:nomorInduk/hapus` | `POST /api/v1/auth/supervisor`, `DELETE /api/v1/identitas/{noin}` | `ManajemenIdentitasHapus` | Supervisor dual password on 8082 (always, like PHP `viewDelete`). Grant required on DELETE. Refuses if open `perkara`. `?legacy=1` still uses PHP `LoginDP`. Profiles: UPT ✅ \| Pusat ✅ \| Kanwil ✅ (`IdentitasProfilesFeatureTest` + `AuthHandoverFeatureTest`). Row scope on DELETE. |
| Tambah identitas | `/AddIdentitas` | `/identitas/baru` | `GET /api/v1/identitas/form`, `POST /api/v1/identitas` | `AddIdentitas` | Create only. Menu `10` write; HQ cannot create (`isHq()` + RBAC). `NOMOR_INDUK` = JWT `uptId`+Ymd+seq4 (not daftar_referensi `001` on national). Duplicate `validasiLokal` → 409 (NM_IBU matched to posted ayah — legacy quirk). BIN/BINTI on insert only. `KONSOLIDASI=0`. Shared `IdentitasWriteMapper` with ubah. Sidik jari capture / Dukcapil / dokumen-on-create / Registrasi session stay 8080. Profiles: UPT ✅ \| Pusat ✅ \| Kanwil ✅ (`IdentitasProfilesFeatureTest`: HQ 403 write-guard). Row scope: create prefix = JWT uptId. |

Auth, JWT handover, public-host origins, lookups (`agama`, `pendidikan`, `kelamin`, `kewarganegaraan`), and the Identitas chrome are in place. Do not rebuild them.

Frontend runtime: static SPA on :8082 behind Caddy (local) / Apache or nginx (UPT). CI4 sets httpOnly `sdp_token`. Hapus supervisor grant is `sessionStorage` for 10 minutes. Copy `clientLoader` / `clientAction` from the last Identitas route.

## Identitas — known gaps (tracked)

Reviewed against legacy after the national Identitas slice. Remaining items stay on 8080 until ported.

| Gap | Legacy | Port status | Profile | Notes |
|---|---|---|---|---|
| Pusat verification workflow | `verifikasi_identitas_pusat` — `view_detail_verifikasi`, `verification_copy`, `verification_copy_to`, `verification_set_identitas_mirip` | **Deferred** | **UPT-only** (`V02`, not menu `10`; hidden from Pusat/Kanwil in legacy menu) | Separate national menu from Manajemen Identitas. Confirm officer usage on UPT boxes before porting as its own epic (`Modules/VerifikasiIdentitas`). |
| Identitas Foto listing | `Identitas_foto` (`ID_MENU` `IFO`) — `index`, `_get_list`, `_perkara_pasal` | **Deferred** | Pusat only (`isPusat`; 404 otherwise) | Mutasi photo path logic ported as `IdentitasPhotoResolver`; standalone Pusat photo browser — confirm menu `IFO` usage before porting. |

**Closed in gap-fill (2026-08):** document attachments (lihat list + stream; ubah upload/delete via `Modules/Dokumen`); kemiripan manage UI on ubah (search modal + remove, PUT `nomorIndukSimilar`); `catatKunjungan` legacy link on mode analisa.

Suggested port order for remaining gaps: **verifikasi_identitas_pusat** (separate menu slice, UPT-only) → **Identitas_foto** (after usage check).

## Identitas — still legacy

These still open `http://127.0.0.1:8080`. Port next unless the user names a different menu.

| Slice | Legacy URL | Suggested new UI | Suggested API |
|---|---|---|---|
| Cetak identitas | `/LaporanIdentitas/cetak_identitas_napi/{noin}` | keep PDF on legacy until print is ported | — |
| Cetak tahanan | `/LaporanIdentitas/cetak_identitas_tahanan/{noin}` | same | — |
| Cetak sidik jari | `/DaftarSidikJari/cetak_sidikjari/{noin}` | same | — |
| Rekam sidik jari | `SDP.Registration.exe` → `/biometricregistrasi` | **keep desktop app** | — |
| Dukcapil / KTP | panels on ManajemenIdentitas | skip until needed | — |
| Verifikasi identitas ke Pusat | `/verifikasi_identitas_pusat` (menu `V02`) | separate menu; UPT-only; deferred | see known gaps |
| Identitas Foto (Pusat listing) | `/Identitas_foto` (menu `IFO`) | keep on 8080 until usage confirmed | see known gaps |

Cetak / biometrik / Dukcapil remain on 8080. Next Identitas work is optional (verifikasi / Identitas_foto) or the next live sidebar menu.

## After Identitas

Pick the next **menu** from the live legacy sidebar (logged in on 8080), then one action inside it. Record the `cekSecurity` / `$id_menu` value here when you start.

| Menu | ID_MENU | Status |
|---|---|---|
| Manajemen Identitas | `10` | Search + lihat + ubah + hapus + tambah done |

## Do not regress

- Frontend is a static SPA on :8082. `/api` is proxied to :8081. Do not open 8081 to officer PCs.
- Identitas visual language in `sdp-upt-frontend/app/app.css`
- Local-only `102sdp/system/application/config/config.php` (leave `__config.php` alone)
- `?legacy=1` escape hatch on every cut-over URL
- Per-slice rollback files `sdp_cutover.local.php` / `sdp_cutover.pusat.php` (not MariaDB); admin at `/CutoverRollback`
- Do not port or rewrite `SDP-Biometrik` (Windows Neurotec host). Capture stays in that exe.
