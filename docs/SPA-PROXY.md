# SPA + swappable proxy (proposed)

Status: **proposed — not implemented.** Current UPT still uses Node SSR on 8082. See [`UPT-RUNTIME.md`](UPT-RUNTIME.md) for what runs today.

To continue: implement this file. Do not start from a session `plan.md`.

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

Today Node signs an httpOnly `sdp_token` cookie (React Router `createCookie`, not the raw JWT). The browser cannot send that to CI4, and SPA loaders cannot read httpOnly cookies to set `Authorization`.

Do **not** put the JWT in `localStorage`.

Do this instead:

1. CI4 `POST /auth/login` (and a small `POST /auth/cookie` for PHP handover) sets  
   `Set-Cookie: sdp_token=<raw JWT>; HttpOnly; Path=/; SameSite=Lax; Max-Age=28800`  
   (`Secure` only on HTTPS).
2. The proxy forwards `Set-Cookie` as-is (default on Caddy / Apache / nginx). The cookie is stored for the **8082 host**.
3. SPA `fetch('/api/v1/…', { credentials: 'same-origin' })`. The browser attaches the cookie. JS never reads the token.
4. `JwtAuthFilter` accepts `Authorization: Bearer` **or** cookie `sdp_token`.
5. Logout: SPA calls `POST /auth/logout` (new, tiny) that expires the cookie.

Hapus supervisor grant stays a header (`X-SDP-Supervisor-Grant`), held in `sessionStorage` for 10 minutes — not a Node-signed cookie.

PHP `Sdp_sso` handover is unchanged (token still in the query). `/auth/legacy` becomes a `clientLoader` that POSTs the token to `/api/v1/auth/cookie` then redirects.

## Frontend (Framework SPA)

Follow `sdp-frontend-reactrouter8/.agents/skills/react-router/SKILL.md` and installed `docs/how-to/spa.md`.

- `react-router.config.ts`: `ssr: false`.
- Root: `HydrateFallback` (existing empty-state tokens). Root `loader` only if needed at **build** time — no auth/DB there.
- Every current `loader` / `action` becomes `clientLoader` / `clientAction` (SPA mode forbids other server loaders).
- `session.server.ts` → `app/lib/session.ts`: `apiBase()` is `''` + `/api/v1`; no `process.env.API_BASE_URL` at runtime; `fileToPayload` without Node `Buffer`.
- `requireToken`: `GET /api/v1/auth/me` with credentials; 401 → `/login`. Do not parse the cookie in JS.
- Export CSV: `clientLoader` fetches `/api/v1/identitas/export` and returns a `Response` download (same as now, from the browser).

`@react-router/serve` stays a **dev/build** dependency only. UPT does not run Node.

## Proxy contract (vendor-neutral)

1. Listen on the officer frontend port (**8082** locally).
2. `/api/*` → `127.0.0.1:8081` with the path unchanged (`/api/v1/identitas` stays `/api/v1/identitas` on CI4).
3. Forward `Cookie`, `Authorization`, `X-SDP-Public-Host`, `X-SDP-Supervisor-Grant`, `Content-Type`.
4. Forward upstream `Set-Cookie` to the browser without rewriting `Path` or `Domain`.
5. All other paths: files from `sdp-frontend-reactrouter8/build/client`; missing path → `index.html` (SPA).
6. Do not listen on 8081 for officer PCs.

Ship **examples**, not one blessed binary:

| File | Who uses it |
|---|---|
| `deploy/Caddyfile` | Local `./start-sdp.sh frontend` |
| `deploy/nginx.conf.example` | UPT nginx |
| `deploy/apache.conf.example` | UPT Apache |

No Caddy-only headers, modules, or `handle_path` tricks the others cannot copy.

Local `./start-sdp.sh frontend` runs Caddy after `npm run build`. Vite HMR is optional later. `./stop-sdp.sh frontend` stops Caddy on 8082.

## Docs / rules (when implementing)

- `AGENTS.md`: replace “browser never calls the API” with: **browsers never reach port 8081**. Same-origin `/api` through the UPT proxy is required. Node SSR is not used at the UPT.
- `docs/UPT-RUNTIME.md`: chosen path is SPA + proxy contract; Caddy locally; Apache/nginx at UPT. Keep “do not open 8081 + CORS”.
- `docs/PORTING.md` stack table: frontend = static SPA on :8082 behind the proxy.

## Blast radius

| Surface | Change |
|---|---|
| All frontend route modules | `loader`/`action` → `client*` |
| Login, logout, auth-legacy | Cookie via CI4, not `tokenCookie.serialize` |
| Hapus grant | `sessionStorage` instead of signed cookie |
| CI4 Auth + JwtAuthFilter | Set-Cookie + cookie fallback + logout |
| `start-sdp.sh` / `stop-sdp.sh` | Caddy locally |
| `deploy/*.example` | Apache / nginx copies of the same contract |
| Cutover PHP | None (still handover to 8082) |
| MariaDB / Identitas SQL | None |

Verify after: login, 8080→8082 handover still logged in, search/lihat/ubah/hapus (including supervisor grant), logout, `?legacy=1`, cetak still 8080, 8081 not reachable from the browser origin (only `/api` on 8082).

## Out of scope

- Opening 8081 on the LAN or adding CORS for officer PCs.
- Hosting 8082 at Pusat.
- Docker-only UPT install.
- Re-styling the shell.
