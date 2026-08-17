# UPT runtime and the 8081 rule

Standing rules: [`../AGENTS.md`](../AGENTS.md).  
How to port a slice: [`PORTING.md`](PORTING.md).

This is a deploy decision, not a slice. Do not implement a proxy or open 8081 to browsers unless a later task says so.

Proposed next path (not implemented): [`SPA-PROXY.md`](SPA-PROXY.md) — drop Node SSR, static SPA, same-origin `/api` behind Caddy (dev) or Apache/nginx (UPT).

## What runs at the UPT

8082 sits **on the UPT**, not at Pusat. A cut-over UPT therefore runs:

| Process | Port (local) | Role |
|---|---|---|
| MariaDB | 3307 / socket | Shared by PHP and CI4 |
| Legacy CI2 (PHP 7.4) | 8080 | Menu, unported screens, cutover switch |
| CI4 API | 8081 | JWT API. Listen on localhost. |
| Node `react-router-serve` | 8082 | SSR UI. Officers land here after PHP handover. |

Public hosts (`sdp.caripasal.com`, `sdp-api…`, `sdp-front…`) are for tunnels and origin rewriting. They do not mean 8082 is hosted at Pusat.

## Constrained boxes

UPT servers are short on RAM. The expensive part is **another always-on runtime**, not Identitas React source.

If Node must live on the UPT:

- Production only: `npm run start` on `build/`. Never Vite / `react-router dev` on site.
- One Node process. Cap the heap (start around 128–256MB `max-old-space-size`).
- php-fpm for legacy and CI4. Do not ship `spark serve` or `php -S`.
- Node calls CI4 on `http://127.0.0.1:8081` (`API_BASE_URL`). That hop is local.
- Cut over one action so most clicks stay on 8080. Idle Node still uses RAM; it should not SSR the whole app yet.
- Do not add Redis, Node cluster, or a second frontend process to “help” the UPT.

SSR stays on. Turning it off so the browser talks to 8081 saves little RAM unless you also remove Node, and it breaks the current cookie/auth wiring.

Officer PCs: SSR HTML is light; the hydrated bundle is heavier than old PHP. Do not add a new UI library.

## Browser never calls 8081

Current rule ([`AGENTS.md`](../AGENTS.md)): the browser never calls the API. Node loaders/actions fetch `127.0.0.1:8081`.

That is a **security and origin choice**, not a law of PHP.

What it buys today:

- JWT stays in an httpOnly cookie on 8082. JS cannot read it. A browser `fetch` to :8081 cannot send that cookie (different origin).
- 8081 stays off the LAN. No CORS on officer PCs. CI4 is not a public app.
- Public-host browsers still make Node use localhost 8081. `PublicOrigins` / `X-SDP-Public-Host` stay the rewrite layer.
- Framework SSR already runs loaders on the server.

What it costs: Node must stay on every UPT that serves 8082.

### What must not change casually

Officer browsers must not reach the **CI4 port**. Do not open 8081 on the LAN with CORS so React can `fetch('http://upt:8081/…')`. That is a new auth surface (token in JS, or a second cookie) and it makes CI4 browser-facing.

### What we can change later

Rewrite the spirit of the rule to: **browsers never reach the CI4 port. Only localhost, or a same-origin proxy, may call 8081.**

Then one listener on the UPT (nginx / Apache):

- `/` → Node, or later static `build/client`
- `/api` → CI4 on `127.0.0.1:8081`

The browser calls `/api/v1/…` on the same host. It never dials :8081. The cookie can stay host-only. Node can shrink or go away if RAM cannot take it.

That is the path if a UPT cannot afford Node. It is a deliberate deploy slice: proxy, cookie host, login/handover. Not a one-line delete of the AGENTS.md rule.

Do not implement that slice from this file. Come back here when someone is ready to size a real UPT box or to put a proxy in front.