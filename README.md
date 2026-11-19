# SDP UPT

Strangler-fig port of legacy SDP into a CI4 API and a React Router 8 UI. Production still has **two** legacy trees (`102sdp` UPT, `sdp-pusat-legacy` Kanwil/Pusat); the ported end state is **one** API + SPA with two deploy targets.

This repo holds workspace docs and run scripts only. Clone the apps into `102sdp/`, `sdp-pusat-legacy/`, `sdp-upt-api/`, and `sdp-upt-frontend/` — each has its own remote.

- Goals: [`Project Statements.md`](Project%20Statements.md)
- Standing agent rules: [`AGENTS.md`](AGENTS.md)
- How to port one slice: [`docs/PORTING.md`](docs/PORTING.md)
- What is already ported: [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md)
- UPT runtime and the 8081 rule: [`docs/UPT-RUNTIME.md`](docs/UPT-RUNTIME.md)
- Tenancy / one MariaDB, many UPT schemas: [`docs/TENANCY.md`](docs/TENANCY.md)
- Local DB production simulation: [`docs/LOCAL-DATABASE.md`](docs/LOCAL-DATABASE.md)
- Legacy sync & triage: [`docs/LEGACY-SYNC.md`](docs/LEGACY-SYNC.md)
- SPA + proxy: [`docs/SPA-PROXY.md`](docs/SPA-PROXY.md)

```bash
./start-sdp.sh --dev     # porting: Vite HMR on :8082
./start-sdp.sh           # UPT-shaped: built SPA + Caddy on :8082
./start-sdp.sh status
./stop-sdp.sh
```

Login: `admin` / `admin`. Database: OrbStack `sdp-mariadb` on `127.0.0.1:3307`.
