# UPT runtime and the 8081 rule

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
How to port a slice: [`PORTING.md`](PORTING.md).  
Proxy contract: [`SPA-PROXY.md`](SPA-PROXY.md).

8082 sits **on the UPT**, not at Pusat, unless a later 100% cut-over deploy puts API+UI at Pusat. Public hosts (`sdp.caripasal.com`, `sdp-api…`, `sdp-front…`) are for tunnels and origin rewriting.

## What runs at the UPT

A cut-over UPT therefore runs:

| Process | Port (local) | Role |
|---|---|---|
| MariaDB | 3307 / socket | Shared by PHP and CI4 (`tenancy.mode=single`) |
| Legacy CI2 (PHP 7.4) | 8080 | Menu, unported screens, cutover switch |
| CI4 API | 8081 | JWT API. Listen on localhost. |
| Apache / nginx (Caddy locally) | 8082 | Static SPA + `/api` → `127.0.0.1:8081` |

There is **no Node process** on the UPT. Pusat (or `./start-sdp.sh frontend`) builds `sdp-upt-frontend/build/client`. The proxy serves those files.

php-fpm for legacy (PHP 7.4, :8080) and CI4 (PHP 8.x, `127.0.0.1:8081`). Do not ship `spark serve` or `php -S` on site. Do not add Redis, Node cluster, or a second frontend process.

Example vhosts: [`../deploy/apache.conf.example`](../deploy/apache.conf.example), [`../deploy/nginx.conf.example`](../deploy/nginx.conf.example). Two FPM sockets: [`../deploy/php-fpm-pools.conf.example`](../deploy/php-fpm-pools.conf.example). PHP 7.4 serves :8080 only. PHP 8.x serves `127.0.0.1:8081` only. :8082 has no PHP.

Officer PCs: the hydrated SPA bundle is heavier than old PHP. Do not add a new UI library.

## Browser never reaches port 8081

Same-origin `/api` through the 8082 proxy is required. Officers must not dial `:8081`.

What that buys:

- JWT is an httpOnly `sdp_token` cookie on the **8082 host**, set by CI4 (`POST /auth/login`, `POST /auth/cookie`). JS cannot read it.
- The SPA calls `/api/v1/…` with `credentials: 'same-origin'`. The proxy forwards the cookie to localhost 8081. `JwtAuthFilter` accepts `Authorization: Bearer` **or** cookie `sdp_token`.
- 8081 stays off the LAN. No CORS on officer PCs. CI4 is not a public app.
- `PublicOrigins` / `X-SDP-Public-Host` stay the rewrite layer for public-host tunnels.

Do **not** open 8081 on the LAN with CORS so the SPA can `fetch('http://upt:8081/…')`. That is a new auth surface and it makes CI4 browser-facing.

## Proxy contract

One listener on the officer frontend port (8082 locally):

- `/api/*` → `127.0.0.1:8081` with the path unchanged
- `/*` → static `build/client`, missing path → `index.html`
- Forward `Cookie`, `Authorization`, `X-SDP-Public-Host`, `X-SDP-Supervisor-Grant`, `Content-Type`
- Forward upstream `Set-Cookie` without rewriting `Path` or `Domain`

Examples: [`../deploy/Caddyfile`](../deploy/Caddyfile) (local), [`../deploy/nginx.conf.example`](../deploy/nginx.conf.example), [`../deploy/apache.conf.example`](../deploy/apache.conf.example).

The **app** only knows same-origin `/api/v1`. It does not know Caddy, Apache, or nginx.

## Other deploys (same artifact)

| Mode | `/api` upstream | Notes |
|---|---|---|
| API on the UPT | `127.0.0.1:8081` | Default while any menu is still on 8080. Local MariaDB, `tenancy.mode=single`. |
| API at Pusat | Pusat private URL | Only after **100%** cutover (no 8080). Officer PCs that can reach Pusat should hit Pusat 8082 instead. |
| Central MariaDB, one schema per UPT | Same API artifact | `tenancy.mode=database_per_tenant`. UPT 093 → `db093`, UPT 001 → `db001` on one server. |

Tenant and MariaDB are API concerns. Do not fork the SPA. Modes: [`TENANCY.md`](TENANCY.md).

## Config without `.env` (IonCube / Windows & Linux)

UPT deploys ship **no `.env` file**. Without `.env`, CI4 defaults `ENVIRONMENT` to `production` and reads IonCube-encoded PHP config classes under `sdp-upt-api/app/Config/` (`App.php`, `Database.php`, `Encryption.php`, `Sdp.php`). Local development can keep using `.env` (`BaseConfig` supports both `sdp.*` and legacy dotted aliases such as `jwt.secret`, `tenancy.mode`, `legacy.root`).

- Keep `Config\Optimize::$configCacheEnabled = false` so CI4 never serializes config secrets into `writable/cache/`.
- Do not obfuscate class or property names in `app/Config/*` during IonCube encoding (`Factories` / `BaseConfig` rely on exact names).
- Keep UPT and Pusat `jwtSecret` / `encryption.key` distinct across build profiles.
- **Per-UPT `legacyRoot` override (Windows & Linux):** Standard UPT installs (`SDP/htdocs/www/sdp` beside `SDP/sdp-upt-api`) work out of the box with no `sdp-local.php` (`StoredUploadPath` auto-detects `../htdocs/www/sdp`, then `../102sdp/sdp` for local dev). Only non-standard folder layouts need an unencoded sibling `../sdp-local.php` returning `['legacyRoot' => '...']` (relative from `sdp-upt-api/` or absolute). Only `legacyRoot` is allowlisted from that file; secrets and tenancy mode stay inside encoded `app/Config/`.
- `legacy.baseURL` does not vary per UPT when UPTs differ only by server IP: `PublicOrigins` rewrites `http://127.0.0.1:8080` from `X-SDP-Public-Host` / `X-Forwarded-Host` / `Host`.
