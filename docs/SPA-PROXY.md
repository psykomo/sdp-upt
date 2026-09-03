# SPA + swappable proxy

Status: **implemented.** See [`UPT-RUNTIME.md`](UPT-RUNTIME.md) for what runs at the UPT.

---

# SPA + swappable proxy: drop Node at the UPT

## Why

UPT boxes cannot afford a fourth always-on runtime. 8082 stays **on the UPT**, not Pusat. Node SSR is the RAM we can drop. Officers must still never dial **port 8081**.

## Target shape

The **app** only knows same-origin `/api/v1`. It does not know Caddy, Apache, or nginx.

```
officer PC
    │
    ▼
:8082  (any reverse proxy that implements the contract)
    ├─ /api/*  →  127.0.0.1:8081  (CI4, prefix kept)
    └─ /*      →  static build/client + SPA fallback to index.html
```

**Local/dev** uses Caddy (`./start-sdp.sh frontend`).  
**UPT** uses whatever they already run — Apache or nginx — with a config that implements the same contract. We ship example snippets for all three; we do not couple install to Caddy.

Legacy :8080 and MariaDB stay. Handover URL stays `http://127.0.0.1:8082/auth/legacy?token=…`. `sdp_frontend_base_url` does not change.

CI4 keeps listening on localhost 8081 only. The proxy does not expose 8081.

## Auth (no second login)

CI4 owns the session cookie. The SPA never signs cookies and does not need `SESSION_SECRET` / `API_BASE_URL`.

Do **not** put the JWT in `localStorage`.

Flow:

1. CI4 `POST /auth/login` (and `POST /auth/cookie` for PHP handover) sets  
   `Set-Cookie: sdp_token=<raw JWT>; HttpOnly; Path=/; SameSite=Lax; Max-Age=28800`  
   (`Secure` only on HTTPS).
2. The proxy forwards `Set-Cookie` as-is (default on Caddy / Apache / nginx). The cookie is stored for the **8082 host**.
3. SPA `fetch('/api/v1/…', { credentials: 'same-origin' })`. The browser attaches the cookie. JS never reads the token.
4. `JwtAuthFilter` accepts `Authorization: Bearer` **or** cookie `sdp_token`.
5. Logout: SPA calls `POST /auth/logout`, which expires the cookie.

Hapus supervisor grant is a header (`X-SDP-Supervisor-Grant`), held in `sessionStorage` for 10 minutes — not a signed cookie.

PHP `Sdp_sso` handover is unchanged (token still in the query). `/auth/legacy` is a `clientLoader` that POSTs the token to `/api/v1/auth/cookie` then redirects.

## Frontend (Framework SPA)

Follow `sdp-upt-frontend/.agents/skills/react-router/SKILL.md` and installed `docs/how-to/spa.md`.

- `react-router.config.ts`: `ssr: false`.
- Root: `HydrateFallback` (existing empty-state tokens). No auth/DB in a root loader.
- Data routes use `clientLoader` / `clientAction` (SPA mode forbids server loaders).
- `app/lib/session.ts`: `apiBase()` is `''` so calls are same-origin `/api/v1/…`. Public tunnel hosts are constants in that file, not `.env`.
- `requireToken` / `hasSession`: `GET /api/v1/auth/me` with credentials; 401 → `/login`. Do not parse the cookie in JS.
- Export CSV: `clientLoader` fetches `/api/v1/identitas/export` and returns a `Response` download from the browser.

`@react-router/serve` stays a **dev/build** dependency only. UPT does not run Node.

## Proxy contract (vendor-neutral)

1. Listen on the officer frontend port (**8082** locally).
2. `/api/*` → `127.0.0.1:8081` with the path unchanged (`/api/v1/identitas` stays `/api/v1/identitas` on CI4).
3. Forward `Cookie`, `Authorization`, `X-SDP-Public-Host`, `X-SDP-Supervisor-Grant`, `Content-Type`.
4. Forward upstream `Set-Cookie` to the browser without rewriting `Path` or `Domain`.
5. All other paths: files from `sdp-upt-frontend/build/client`; missing path → `index.html` (SPA).
6. Do not listen on 8081 for officer PCs.

Ship **examples**, not one blessed binary:

| File | Who uses it |
|---|---|
| `deploy/Caddyfile` | Local `./start-sdp.sh frontend` (API is still `spark serve`) |
| `deploy/nginx.conf.example` | UPT: :8080 PHP 7.4, localhost :8081 PHP 8.x, :8082 SPA |
| `deploy/apache.conf.example` | Same split |
| `deploy/php-fpm-pools.conf.example` | Two FPM pools / two sockets |

No Caddy-only headers, modules, or `handle_path` tricks the others cannot copy.

Local `./start-sdp.sh frontend` runs Caddy after `npm run build`. Vite HMR is optional later. `./stop-sdp.sh frontend` stops Caddy on 8082.

## Docs / rules

Standing rules live in `AGENTS.md` and [`UPT-RUNTIME.md`](UPT-RUNTIME.md): browsers never reach port 8081; same-origin `/api` through the UPT proxy; Node SSR is not used at the UPT. Porting stack: static SPA on :8082 behind the proxy ([`PORTING.md`](PORTING.md)).

## Blast radius (already cut over)

| Surface | Behavior |
|---|---|
| Frontend route modules | `clientLoader` / `clientAction` |
| Login, logout, auth-legacy | Cookie via CI4 |
| Hapus grant | `sessionStorage` + header |
| CI4 Auth + JwtAuthFilter | Set-Cookie + cookie fallback + logout |
| `start-sdp.sh` / `stop-sdp.sh` | Caddy locally |
| `deploy/*.example` | Apache / nginx copies of the same contract |

Verify after changes: login, 8080→8082 handover still logged in, search/lihat/ubah/hapus (including supervisor grant), logout, `?legacy=1`, cetak still 8080, 8081 not reachable from the browser origin (only `/api` on 8082).

## Out of scope

- Opening 8081 on the LAN or adding CORS for officer PCs.
- Hosting 8082 at Pusat.
- Docker-only UPT install.
- Re-styling the shell.
