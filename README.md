# SDP 4.0

Strangler-fig port of legacy SDP (`102sdp`) into a CI4 API and a React Router 8 UI. They run together.

This repo holds workspace docs and run scripts only. Clone the three apps into `102sdp/`, `sdp-api-ci4/`, and `sdp-frontend-reactrouter8/` — each has its own remote.

- Goals: [`Project Statements.md`](Project%20Statements.md)
- Standing agent rules: [`AGENTS.md`](AGENTS.md)
- How to port one slice: [`docs/PORTING.md`](docs/PORTING.md)
- What is already ported: [`docs/PORTING-PROGRESS.md`](docs/PORTING-PROGRESS.md)

```bash
./start-sdp.sh           # legacy :8080  API :8081  frontend :8082
./start-sdp.sh status
./stop-sdp.sh
```

Login: `admin` / `admin`. Database: OrbStack `sdp-mariadb` on `127.0.0.1:3307`.
