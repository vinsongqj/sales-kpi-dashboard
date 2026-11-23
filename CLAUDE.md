# Sales KPI Dashboard — Take-Home Rules

Brief: `Technical-Exercise-Sales-KPI-Dashboard.md` (Parts A–D). Setup/run: `README.md`.

## Stack & Layout
- Frontend: React 18 + Vite 5, **plain JS/JSX** (no TypeScript, no linter) — `frontend/`
  - `src/App.jsx` dashboard shell + data loading; `src/api.js` fetch client; `src/format.js` `rm()`/`pct()` formatters
  - `src/components/` FilterBar, KpiCards, Breakdown, AddSaleForm, SalesTable
- Backend: FastAPI + asyncpg, raw SQL, no ORM/migrations — `backend/`
  - `main.py` app/CORS/lifespan; `sales/routes.py` thin `/api/*` handlers
  - `db.py` schema, seed, all queries **and KPI math** (`summary()`, `_line_net()`)
- Database: PostgreSQL 16 via Docker Compose (`docker-compose.yml`: `db`, `api`, `web`)
- Reference timezone: Asia/Kuala_Lumpur (UTC+8). Containers run in UTC.

## Run
- `docker compose up --build` → web http://localhost:5173, API http://localhost:8010 (`/api/summary`, `/api/health`), Postgres `localhost:5442` (`sales`/`sales`/`sales`)
- Backend (`uvicorn --reload`) and frontend (Vite, polling) hot-reload via bind mounts.
- Reset + reseed: `docker compose down -v && docker compose up --build`
- Docker needs Docker Desktop running with WSL integration (host user currently lacks socket access).

## Data & Seed
- Tables: `sales` (`status` = `completed`|`refunded`, `channel` = `online`|`in_store`, `discount_pct` is a percentage), `monthly_targets` (`month` TEXT `'YYYY-MM'`).
- `db.seed_if_empty()` runs only on an empty DB: 75 days back from `date.today()`, 1–3 sales/day, deterministic by day index; targets RM 10,000 for current + 2 prior months. Seed dates are relative to today, so recompute expected values per run (e.g. `psql` on port 5442 or a script mirroring the seed loop).

## Tests / Verification
- **No test suites or test deps exist yet** (backend `requirements.txt`: fastapi, uvicorn, asyncpg only; frontend scripts: `dev`, `build`, `preview`). Add pytest/vitest explicitly if writing tests.
- Frontend build check: `docker compose exec web npm run build` (host `frontend/node_modules` is empty — deps live in the container volume).
- Backend syntax check: `docker compose exec api python -m py_compile main.py db.py sales/routes.py`
- API smoke check: `curl -s 'http://localhost:8010/api/summary?month=YYYY-MM'`
- Report exact command output after edits.

## Working Principles
- Work incrementally on `feat/kpi-dashboard-exercise`. Commit as you go; never squash or force-push.
- Keep changes scoped to the current task (Part A bugs, Part B Pace to Target, Part C innovation).
- Verify calculations against deterministic seed data before treating a bug fix as done.
- Match existing style: KPI logic in `db.py`, thin routes, small documented functions with explicit edge-case handling.
- Never commit `_interviewer/` (gitignored answer key).

## Key Edge Cases to Guard
- "Today" must be UTC+8 consistently. Current sources of "today": `date.today()` in `db.py` seed (container UTC) and `new Date()` in `App.jsx` / `AddSaleForm.jsx` (browser local).
- Month lengths vary (28/29/30/31, leap years).
- Past months: projected total equals actual total.
- Future months (0 days elapsed) or missing/zero targets: never divide by zero or render NaN/Infinity; show "N/A".
