### Project Statements

Standing agent rules: [`AGENTS.md`](AGENTS.md).  
Porting playbook (one slice at a time): [`docs/PORTING.md`](docs/PORTING.md).  
What is already cut over: [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md).  
UPT runtime and the 8081 rule: [`docs/UPT-RUNTIME.md`](docs/UPT-RUNTIME.md).

We will port **two** production legacy trees into **one** API + SPA:

| Tree | Folder | Focus paths |
|---|---|---|
| UPT | `102sdp/` | `102sdp/sdp/`, `102sdp/system/` |
| Kanwil/Pusat | `sdp-pusat-legacy/` | `sdp-pusat-legacy/www/sdp_pusat/`, `sdp-pusat-legacy/system/` |

Local UPT legacy (cutover / click-through) is at:
http://127.0.0.1:8080
username: admin
password: admin
use ego-browser skill to browse the dev server.

When porting a slice, read the matching action in **both** trees and merge into one codebase (profile branches). Playbook: [`docs/PORTING.md`](docs/PORTING.md) §2.


The new codebases will be in form of API (API-fication), and will be built in this folder:
`sdp-upt-api/`

The API will use the exact database engine and database structure as the legacy codebases.

The database is currently running in orbstack sdp-mariadb.

The API will support (see [`docs/TENANCY.md`](docs/TENANCY.md)):

- 1 tenant 1 database in 1 db server (`single` — current UPT box)

- Multi tenants, each tenant has its own database inside one shared db server (`database_per_tenant` — UPT 093 → `db093`, UPT 001 → `db001`)

- Multi tenants single database single db server (`shared_database`)


The API will have modular monolith architecture. It should be easy to maintain, easy to develop and easy to extend.  We could adopt DDD architecture but it should be alot more relax and more pragmatic.

All the legacy codebases features will be ported in parity.

The port will be done per module (strangler fig pattern).

I do not have yet a good porting strategy, but maybe we could start porting one page or one menu at a time from the legacy app.

For every page/menu that we are porting, we build the same structure but in more modern UI inside this folder:
`sdp-upt-frontend/`

When one whole page/menu including all its features has been finished developed, we cutover the old page/menu by redirecting to the new page/menu in the new frontend.

Threse apps run together side by side for UPT strangler cutover: UPT legacy (`102sdp`), API, and modern frontend. National legacy (`sdp-pusat-legacy`) is the second behavior reference until national cutover is wired the same way.

The authentication should be seamless betweeen these 3 apps. User will just login in the legacy app, and the user will be automatically also logged in the the new frontend and the API.

The API will use the latest PHP and latest CodeIgniter.

The API will employs unit of work when it needs to execute services from different modules in one atomic transaction. Also each module can perform its own atomic transaction scoped inside its own module and will not break if it becomes part of larger transaction inside the parent or orchestrator.

API will use the same authentication including RBAC or ABAC as the legacy codebases. We may adjust it as JWT token. The auth flow could be like this, but can be improved: user logs in using legacy app, the app will then somehow also get the jwt token to be able to use the API. Using this flow, the user is authenticated in legacy, frontend and API.
