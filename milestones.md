# Milestones

A running log of every distinct change made for the Sales KPI Dashboard exercise
(Parts A–D): what changed and why. Newest entries go at the bottom, and each entry is
committed together with the change it describes.

Entry format:

- **What changed:** files / functions touched
- **Why:** root cause or reasoning (wrong vs. correct behaviour, before/after numbers for bugs)
- **Verification:** commands run and key output

---

## A1 · fix(kpi): apply discount_pct as a percentage in `_line_net`
- **What changed:** `backend/db.py` `_line_net()` now returns `qty × unit_price × (1 − discount_pct / 100)`.
- **Why:** `discount_pct` is stored as a percentage (schema and form both say "Discount %"), but the old code did `qty × unit_price − discount_pct`, so a 20% discount on a RM 480 line took off only RM 20 instead of RM 96. Every revenue KPI (total, AOV, attainment, breakdowns) goes through this helper, so all of them were overstated whenever a discount applied.
- **Verification:** `py_compile` OK. `/api/summary?month=2026-11` total went from **6309.00 → 6265.70**, which matches Postgres `SUM(quantity*unit_price*(1-discount_pct/100))` = `6265.70`. (Refunds are still counted at this point; they're fixed in A2.)

## A2 · fix(kpi): exclude refunded sales from revenue, orders and breakdowns
- **What changed:** `backend/db.py` `summary()` adds `status = 'completed'` to the filtered query, whether or not other filters are set. `list_sales()` is unchanged, so refunded rows still show (struck through) in the table.
- **Why:** The brief defines revenue as "net revenue from **completed** sales", but `summary()` selected every row. Refunded sales were counted as revenue and as orders, which inflated the total, the order count, AOV and both breakdowns. Orders and AOV now count completed sales only, so AOV = net revenue ÷ orders that actually earned it.
- **Verification:** `py_compile` OK. `/api/summary?month=2026-11`: total **6265.70 → 6058.70**, orders **46 → 43**, AOV **136.21 → 140.90**, which matches Postgres `… WHERE status='completed'` = `6058.70 | 43` and the hand-computed seed value. "All months" (no filters) also works, because the `WHERE` is built correctly when no other clause exists. (The breakdowns and attainment are still wrong at this point; they're fixed in A3–A5.)

## A3 · fix(kpi): accumulate revenue per category
- **What changed:** `backend/db.py` `summary()`. The category loop is now `by_category[cat] = by_category.get(cat, 0.0) + _line_net(r)`.
- **Why:** The old loop read the running subtotal and then overwrote it with `subtotal = _line_net(r)`, so each category ended up showing only its **last** sale rather than the sum. The bars therefore didn't add up to Total Net Revenue (880 vs 6058.70 for 2026-11).
- **Verification:** `py_compile` OK. `/api/summary?month=2026-11` by category, before → after:
  - Cafe 36.00 → **289.50**
  - Coaching 255.00 → **1915.20**
  - Court Booking 480.00 → **3170.00**
  - Pro Shop 120.00 → **684.00**

  These match Postgres `GROUP BY category` exactly and sum to the 6058.70 total.

## A4 · fix(kpi): bucket channels by exact match
- **What changed:** `backend/db.py` `summary()`. The channel loop now does `if ch in by_channel: by_channel[ch] += _line_net(r)`, an exact key match against `online` / `in_store`.
- **Why:** The old code checked `if "in" in ch` first. That's a substring test, and `"online"` contains `"in"` (o-n-l-**i-n**-e), so every online sale fell into `in_store` and the `elif "online"` branch could never run. Online always showed RM 0.00.
- **Verification:** `py_compile` OK. `/api/summary?month=2026-11` by channel:
  - online 0.00 → **2204.70**
  - in_store 6058.70 → **3854.00**

  These match Postgres `GROUP BY channel`. With `&channel=online` the result is online 2204.70 and in_store 0.00. The only channel values in the DB are `online` and `in_store`, so the exact match drops nothing.
