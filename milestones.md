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
