# Porting progress

Update this file at the end of every finished slice. Rules: [`../AGENTS.md`](../AGENTS.md). Procedure: [`PORTING.md`](PORTING.md).

Copy the last **Done** row. Do not rebuild auth, origins, lookups, or the UI shell.

## Done

| Slice | Legacy URL | New UI | API | Cutover key | Notes |
|---|---|---|---|---|---|
| Pencarian identitas | `/PencarianIdentitas` | `/identitas` | `GET /api/v1/identitas`, `GET /api/v1/identitas/export` | `PencarianIdentitas` | Grid + analisa. Menu `10`. |
| Lihat identitas | `/ManajemenIdentitas/lihat/{noin}` | `/identitas/:nomorInduk` | `GET /api/v1/identitas/{noin}` | `ManajemenIdentitas` | Read-only. Dukcapil / KTP panels skipped. |
| Ubah identitas | `/ManajemenIdentitas/viewEdit/{noin}` | `/identitas/:nomorInduk/ubah` | `GET /api/v1/identitas/{noin}/form`, `PUT /api/v1/identitas/{noin}` | `ManajemenIdentitasUbah` | Writes biodata/alamat/pekerjaan/keluarga/fisik/foto. Ambil Foto is `getUserMedia` on the ubah form (same PUT). Dual password stays on PHP before redirect. Scanner sidik jari, dokumen, Dukcapil/KTP still legacy. |

Auth, JWT handover, public-host origins, lookups (`agama`, `pendidikan`, `kelamin`, `kewarganegaraan`), and the Identitas chrome are in place. Do not rebuild them.

## Identitas — still legacy

These still open `http://127.0.0.1:8080`. Port next unless the user names a different menu.

| Slice | Legacy URL | Suggested new UI | Suggested API |
|---|---|---|---|
| Hapus | `/ManajemenIdentitas/viewDelete/{noin}` | `/identitas/:nomorInduk/hapus` | `POST` or `DELETE /api/v1/identitas/{noin}` |
| Tambah | `/AddIdentitas` | `/identitas/baru` | `POST /api/v1/identitas` |
| Cetak identitas | `/LaporanIdentitas/cetak_identitas_napi/{noin}` | keep PDF on legacy until print is ported | — |
| Cetak tahanan | `/LaporanIdentitas/cetak_identitas_tahanan/{noin}` | same | — |
| Cetak sidik jari | `/DaftarSidikJari/cetak_sidikjari/{noin}` | same | — |
| Rekam sidik jari | `SDP.Registration.exe` → `/biometricregistrasi` | **keep desktop app** | — |
| Dukcapil / KTP | panels on ManajemenIdentitas | skip until needed | — |

Hapus is the natural next Identitas slice: confirm + soft-delete, dual password on PHP.

## After Identitas

Pick the next **menu** from the live legacy sidebar (logged in on 8080), then one action inside it. Record the `cekSecurity` / `$id_menu` value here when you start.

| Menu | ID_MENU | Status |
|---|---|---|
| Manajemen Identitas | `10` | Search + lihat + ubah done |

## Do not regress

- Frontend Node must keep `API_BASE_URL=http://127.0.0.1:8081`
- Identitas visual language in `sdp-frontend-reactrouter8/app/app.css`
- Local-only `102sdp/system/application/config/config.php` (leave `__config.php` alone)
- `?legacy=1` escape hatch on every cut-over URL
- Do not port or rewrite `SDP-Biometrik` (Windows Neurotec host). Capture stays in that exe.
