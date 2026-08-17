### Project Statements

Standing agent rules: [`AGENTS.md`](AGENTS.md).  
Porting playbook (one slice at a time): [`docs/PORTING.md`](docs/PORTING.md).  
What is already cut over: [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md).  
UPT runtime and the 8081 rule: [`docs/UPT-RUNTIME.md`](docs/UPT-RUNTIME.md).

We will port legacy codebases from this project: 

/Users/hap/Documents/dev/sdp-4.0/102sdp

But focus on these 2 folders: 

/Users/hap/Documents/dev/sdp-4.0/102sdp/sdp
/Users/hap/Documents/dev/sdp-4.0/102sdp/system

We can also access the dev server at:
http://127.0.0.1:8080
username: admin
password: admin
use ego-browser skill to browse the dev server.


The new codebases will be in form of API (API-fication), and will be built in this folder:
/Users/hap/Documents/dev/sdp-4.0/sdp-api-ci4

The API will use the exact database engine and database structure as the legacy codebases.

The database is currently running in orbstack sdp-mariadb.

The API will support:

- 1 tenant 1 database in 1 db server

- Multi tenants, each tenant has its own database inside one shared db server. 

- Multi tenants single database single db server.


The API will have modular monolith architecture. It should be easy to maintain, easy to develop and easy to extend.  We could adopt DDD architecture but it should be alot more relax and more pragmatic.

All the legacy codebases features will be ported in parity.

The port will be done per module (strangler fig pattern).

I do not have yet a good porting strategy, but maybe we could start porting one page or one menu at a time from the legacy app.

For every page/menu that we are porting, we build the same structure but in more modern UI inside this folder:
/Users/hap/Documents/dev/sdp-4.0/sdp-frontend-reactrouter8

When one whole page/menu including all its features has been finished developed, we cutover the old page/menu by redirecting to the new page/menu in the new frontend.

Threse 3 codebases, legacy, API and the new modern frontend will run together, side by side.

The authentication should be seamless betweeen these 3 apps. User will just login in the legacy app, and the user will be automatically also logged in the the new frontend and the API.

The API will use the latest PHP and latest CodeIgniter.

The API will employs unit of work when it needs to execute services from different modules in one atomic transaction. Also each module can perform its own atomic transaction scoped inside its own module and will not break if it becomes part of larger transaction inside the parent or orchestrator.

API will use the same authentication including RBAC or ABAC as the legacy codebases. We may adjust it as JWT token. The auth flow could be like this, but can be improved: user logs in using legacy app, the app will then somehow also get the jwt token to be able to use the API. Using this flow, the user is authenticated in legacy, frontend and API.
