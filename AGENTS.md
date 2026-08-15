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

## Rules

- Pemasyarakatan domain modules use Indonesian names (`Identitas`, not `Identity`). Keep `Auth`, `Lookup`, and `Shared` as technical modules.
- One action per slice (search, lihat, ubah, hapus, tambah, cetak). Not a whole controller. Not a whole menu.
- Same MariaDB as legacy. Do not redesign tables while PHP still uses them. Schema changes are additive CI4 migrations only; never rename or drop a column PHP still reads.
- Browser never calls the API. Node loaders/actions fetch the local API.
- Do not invent a second auth. JWT handover already exists. Use it.
- Reuse RBAC, dates, lookups, origins, envelope. Do not reimplement `cekSecurity` or `getDeskripsi`.
- Persistence is a repository (query builder), not a CodeIgniter `Model`. SQL does not live in services.
- JSON is camelCase. Port behavior and field meaning, not PHP HTML.
- Cut over only the finished action. Unported buttons stay on 8080.
- Distinct `?legacy=1` key per cut-over URL. Empty frontend base URL means skip redirect.
- Extend the existing UI tokens. Do not restyle the shell.
- Do not edit tracked `__config.php` / `__database.php`. Local wrappers and `.env` are fine.
- Fewest files. Deletion over addition. No new dependency if it can be avoided.
- Commit only when asked.

Not lazy about: understanding the legacy page, input validation at trust boundaries, permission checks, anything that can lose or leak data.

## Where things live

| What | Where |
|---|---|
| Why | `Project Statements.md` |
| How to port a slice | `docs/PORTING.md` |
| What is already cut over | `docs/PORTING-PROGRESS.md` |
| Last slice to copy | whatever `docs/PORTING-PROGRESS.md` lists as done |

When the user pastes a `127.0.0.1:8080` URL, that is the next slice. Follow `docs/PORTING.md`. Update `docs/PORTING-PROGRESS.md` when it is done.
