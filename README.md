# SDP UPT

Strangler-fig port of legacy SDP (`102sdp`) into a CI4 API and a React Router 8 UI. They run together.

This repo holds workspace docs and run scripts only. Clone the three apps into `102sdp/`, `sdp-upt-api/`, and `sdp-upt-frontend/` — each has its own remote.

- Goals: [`Project Statements.md`](Project%20Statements.md)
- Standing agent rules: [`AGENTS.md`](AGENTS.md)
- How to port one slice: [`docs/PORTING.md`](docs/PORTING.md)
- What is already ported: [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md)
- UPT runtime and the 8081 rule: [`docs/UPT-RUNTIME.md`](docs/UPT-RUNTIME.md)
- Tenancy / one MariaDB, many UPT schemas: [`docs/TENANCY.md`](docs/TENANCY.md)
- SPA + proxy: [`docs/SPA-PROXY.md`](docs/SPA-PROXY.md)

```bash
./start-sdp.sh --dev     # porting: Vite HMR on :8082
./start-sdp.sh           # UPT-shaped: built SPA + Caddy on :8082
./start-sdp.sh status
./stop-sdp.sh
```

Login: `admin` / `admin`. Database: OrbStack `sdp-mariadb` on `127.0.0.1:3307`.
