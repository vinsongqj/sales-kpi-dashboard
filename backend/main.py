"""Sales KPI Dashboard — FastAPI entrypoint.

Wires shared setup (CORS, DB lifecycle) and mounts the sales router. Business
logic and the DB schema live in `db.py`; HTTP routes live in `sales/routes.py`.
"""

import math
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

import db
from sales.routes import router as sales_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create the pool, ensure the schema, and seed sample data on first boot.
    await db.init_db()
    yield
    await db.close_db()


app = FastAPI(title="Sales KPI Dashboard", lifespan=lifespan)

# Open CORS — this is a local test harness, not a production service.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def _json_safe(value):
    """Replace NaN/Infinity (not valid JSON) with text, recursively."""
    if isinstance(value, float) and not math.isfinite(value):
        return str(value)
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(v) for v in value]
    return value


@app.exception_handler(RequestValidationError)
async def validation_error(request: Request, exc: RequestValidationError):
    # Same 422 body as FastAPI's default, but the echoed bad input is made
    # JSON-safe: a rejected `Infinity` would otherwise crash the error reply
    # itself and turn a clean 422 into a 500.
    return JSONResponse(
        status_code=422,
        content={"detail": jsonable_encoder(_json_safe(exc.errors()))},
    )


app.include_router(sales_router, prefix="/api")


@app.get("/api/health")
async def health():
    return {"ok": True}
