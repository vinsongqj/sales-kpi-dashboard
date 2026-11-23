"""HTTP routes for the Sales KPI Dashboard.

Thin handlers — they acquire a connection and delegate to `db`. The KPI math
lives in `db.summary()`.
"""

from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Path, Query
from pydantic import BaseModel, ConfigDict, Field

import db

router = APIRouter()

# 'YYYY-MM' with a real month (01–12). Bad values get a 422 instead of
# silently matching nothing or breaking date math downstream.
MONTH_PATTERN = r"^\d{4}-(0[1-9]|1[0-2])$"
Month = Annotated[str | None, Query(pattern=MONTH_PATTERN)]


class SaleIn(BaseModel):
    # Trim surrounding spaces from text fields before validating, so "   " is
    # rejected as empty and "Cafe " doesn't become a separate category.
    # Reject NaN/Infinity outright (they'd crash the DB insert).
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)

    sale_date: date
    product: str = Field(min_length=1)
    category: str = Field(min_length=1)
    channel: Literal["online", "in_store"]
    # Upper bounds are the DB column limits (INTEGER, NUMERIC(10,2)), so an
    # oversized value gets a 422 instead of a database error (500).
    quantity: int = Field(ge=1, le=2_147_483_647)
    unit_price: float = Field(ge=0, lt=100_000_000)
    discount_pct: float = Field(default=0, ge=0, le=100)
    status: Literal["completed", "refunded"] = "completed"


@router.get("/summary")
async def get_summary(month: Month = None, category: str | None = None, channel: str | None = None):
    async with db.pool.acquire() as conn:
        return await db.summary(conn, month, category, channel)


@router.get("/pace")
async def get_pace(month: Month = None):
    """Pace to Target for a month (defaults to the current month in MYT)."""
    async with db.pool.acquire() as conn:
        return await db.pace(conn, month)


@router.get("/sales")
async def get_sales(month: Month = None, category: str | None = None, channel: str | None = None):
    async with db.pool.acquire() as conn:
        return await db.list_sales(conn, month, category, channel)


@router.post("/sales")
async def post_sale(sale: SaleIn):
    async with db.pool.acquire() as conn:
        return await db.create_sale(conn, sale.model_dump())


@router.delete("/sales/{sale_id}")
async def remove_sale(sale_id: int):
    async with db.pool.acquire() as conn:
        await db.delete_sale(conn, sale_id)
    return {"ok": True}


@router.get("/filters")
async def get_filters():
    async with db.pool.acquire() as conn:
        return await db.filters(conn)


@router.get("/targets")
async def get_targets():
    async with db.pool.acquire() as conn:
        return await db.list_targets(conn)


class TargetIn(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)

    # Must be positive: a zero target would make attainment/pace meaningless.
    # NUMERIC(12,2) holds up to 9,999,999,999.99.
    target_amount: float = Field(gt=0, lt=10_000_000_000)


@router.put("/targets/{month}")
async def put_target(target: TargetIn, month: Annotated[str, Path(pattern=MONTH_PATTERN)]):
    """Set (create or replace) the target for one month."""
    async with db.pool.acquire() as conn:
        return await db.upsert_target(conn, month, target.target_amount)
