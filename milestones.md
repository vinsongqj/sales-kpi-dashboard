# Milestones

A running log of every change made for the Sales KPI Dashboard exercise
(Parts A–D): what changed, why, and how it was checked. Newest entries are at
the bottom.

Each entry answers three questions:

- **What changed** — in plain words, plus the file
- **Why** — what was wrong and what it caused
- **How we checked** — the numbers before and after

---

## A1 · Discounts were taken off as ringgit, not as a percentage
- **What changed:** The price calculation now treats the discount as a percentage (`backend/db.py`, `_line_net`).
- **Why:** A sale with "20% off" should knock 20% off the price. The old code subtracted the number 20 as **RM 20** instead. On a RM 480 sale that took off RM 20 when it should have taken off RM 96. Every revenue figure on the dashboard uses this calculation, so they were all too high.
- **How we checked:** November revenue dropped from **RM 6,309.00 to RM 6,265.70**, which matches the same sum done directly in the database. (Refunds were still counted at this stage; see A2.)

## A2 · Refunded sales were counted as revenue
- **What changed:** The dashboard totals now only count sales marked "completed" (`backend/db.py`, `summary`). Refunded sales still appear in the sales table, struck through.
- **Why:** A refunded sale is money given back, so it isn't revenue and shouldn't count as an order. The brief says revenue means "completed sales". The old code counted everything, which made revenue, order count, average order value and the breakdowns all too high.
- **How we checked:** For November, revenue went from **RM 6,265.70 to RM 6,058.70**, orders from **46 to 43**, and average order value from **RM 136.21 to RM 140.90**. These match a database query of completed sales and our own calculation from the sample data.

## A3 · Each category only showed its last sale
- **What changed:** Each category's total now adds up all of its sales (`backend/db.py`, `summary`).
- **Why:** The old code was meant to keep a running total per category, but on every sale it replaced the total with that one sale's value. So each bar showed just the last sale, and the four bars added up to RM 880 instead of the RM 6,058.70 total.
- **How we checked:** November, before → after:
  - Cafe RM 36.00 → **RM 289.50**
  - Coaching RM 255.00 → **RM 1,915.20**
  - Court Booking RM 480.00 → **RM 3,170.00**
  - Pro Shop RM 120.00 → **RM 684.00**

  These match the database exactly and add up to the RM 6,058.70 total.

## A4 · Online sales were counted as in-store
- **What changed:** Sales are now put in a channel by matching the channel name exactly (`backend/db.py`, `summary`).
- **Why:** The old code asked whether the channel name *contains* the letters "in" and, if so, counted it as in-store. But "onl**in**e" also contains "in", so every online sale went to in-store and online always showed RM 0.
- **How we checked:** For November, online went from **RM 0.00 to RM 2,204.70** and in-store from **RM 6,058.70 to RM 3,854.00**. Both match the database, and they add up to the total.

## A5 · Target attainment was the average sale × 100
- **What changed:** Target attainment is now this month's revenue divided by this month's target (`backend/db.py`, `summary`, plus a new helper `_month_net_revenue` that Part B will reuse).
- **Why:** "Target attainment" should answer "how much of the monthly goal have we reached?". The old code divided revenue by the **number of orders** instead of the target, which gives the average sale (RM 140.90). Multiplying by 100 gave the nonsense figure of 14,090%.
  - **Always store-wide:** the target is for the whole store, so this number ignores the category and channel filters. Otherwise picking "Cafe" would compare café sales alone against the whole store's goal.
  - **No target:** if a month has no target, or a target of 0, the card shows "—" instead of an error or "Infinity".
- **How we checked:**
  - November: **14,090% → 60.6%** (RM 6,058.70 ÷ RM 10,000)
  - October: **70.8%**; September: **57.6%**; all three match the database
  - November with the Cafe filter still shows **60.6%**
  - December (no target) and "All months" show **—**
  - a temporary target of 0 also showed **—**; the test target was removed afterwards

## A6 · "Today" now always means today in Malaysia
- **What changed:** Every place that works out "today" now uses Malaysia time (UTC+8):
  - **Server:** a new `today_myt()` in `backend/db.py`, used when creating the sample data.
  - **Browser:** a new `frontend/src/dates.js` with `todayMYT()` and `currentMonthMYT()`, used for the dashboard's default month (`App.jsx`) and the Add Sale form's default date (`AddSaleForm.jsx`).
- **Why:** The business runs on Malaysia time, but "today" came from two different clocks, and neither was Malaysia's:
  - **The server runs on UTC**, 8 hours behind Malaysia. From midnight to 8 am in Malaysia the server still thinks it's yesterday. If the sample data is created then, it's dated a day early, and on the 1st of a month it lands in the previous month.
  - **The browser uses the viewer's own timezone.** Someone viewing from London or the US could see the wrong month selected by default, or a new sale pre-filled with yesterday's date.

  Malaysia doesn't use daylight saving, so a fixed "+8 hours" is always correct. No extra timezone package is needed.
- **How we checked:**
  - Backend still compiles; frontend builds (`✓ built`).
  - Server, at midnight boundaries:
    - 30 Nov 17:00 UTC → Malaysia date **1 Dec**
    - 30 Nov 15:59 UTC → still **30 Nov**
    - 31 Dec 16:00 UTC → **1 Jan 2027** (year rollover)
  - Browser, simulated in UTC:
    - 30 Nov 17:00 UTC → today **2026-12-01**, month **2026-12**
    - 28 Feb 2028 16:30 UTC → **2028-02-29** (leap day)
  - At the time of this change (23:40 in Malaysia, 15:40 UTC) both clocks happened to agree on 23 Nov. After 16:00 UTC they'd disagree, and the new code would follow Malaysia.
  - The existing sample data isn't regenerated, because seeding only runs on an empty database. The fix applies the next time the data is reset.

## A7 · The API now rejects bad input instead of storing or using it
- **What changed:** The API now checks what it's given (`backend/sales/routes.py`):
  - **Month filter** must look like a real month, `YYYY-MM` with 01–12.
  - **New sales** must have:
    - quantity of at least 1
    - price of 0 or more
    - discount between 0 and 100%
    - channel of `online` or `in_store`
    - status of `completed` or `refunded`
    - a product and category name that aren't empty

  Anything else is turned away with an error (HTTP 422) saying what's wrong.
- **Why:** The browser form has some limits, but the API itself accepted anything. That let bad data reach the numbers:
  - A discount of 150% would make a sale count as **negative** revenue.
  - A channel spelled "web" would be stored but left out of both channel bars, so they'd no longer add up to the total.
  - A typo'd status would quietly drop a sale from revenue.
  - A month like `2026-13` would just show an empty dashboard instead of an error, and it would break the date maths in Part B.
- **How we checked:**
  - Month filter: `2026-13`, `2026-1`, `abc` and `2026-00` → **rejected (422)**; `2026-11` and no month → **OK (200)**.
  - New sales: quantity 0, discount 150, channel "web", status "void", price −5 and an empty product name → all **rejected (422)**.
  - A valid sale still saves (it was deleted again afterwards); the database still holds 150 rows.

## A8 · The dashboard can never show "NaN" or "Infinity"
- **What changed:**
  - The money and percentage formatters (`frontend/src/format.js`) now show **"N/A"** for anything that isn't a real number. That covers empty values, "not a number" and infinity.
  - The breakdown bars (`Breakdown.jsx`) can't have a broken or over-wide width.
- **Why:** The brief says the dashboard must never show `NaN` or `Infinity`. The backend now avoids dividing by zero (A5), but the screen shouldn't depend on that alone:
  - The old formatters only handled an empty value. Anything else invalid would have been printed as "RM NaN" or "Infinity%".
  - The brief asks for a sensible "N/A", so empty values now show "N/A" instead of the old "—". For example, Target Attainment for a month with no target now reads **N/A**.
- **How we checked:**
  - Frontend builds (`✓ built`).
  - Each formatter was fed a list of tricky values:
    - real numbers come out as normal: `6058.7` → **RM 6,058.70**, `0` → **RM 0.00**, `"10.00"` → **RM 10.00**
    - empty, NaN, Infinity, −Infinity, blank text and `"abc"` all come out as **N/A**

## Part A review · Everything re-checked end to end
- **What changed:** Fixed one out-of-date code comment in `backend/db.py`. It still said a missing target shows "—", but since A8 it shows "N/A". No other leftovers were found: no unused imports or helpers, and the old browser-clock date functions were fully removed.
- **Why:** A final pass to make sure Part A is complete and consistent before starting Part B.
- **How we checked:**
  - The dashboard totals were compared with the database for **every combination** of month (all, Sep, Oct, Nov), category (all + 4) and channel (all + 2). That's **60 combinations, 0 mismatches** in revenue, orders and average sale, and in every case the category bars and channel bars added up to the total.
  - Backend compiles; frontend builds.

## A9 · Names made only of spaces are now rejected
- **What changed:** New sales have extra spaces trimmed from the start and end of their text fields before they're checked (`backend/sales/routes.py`, `SaleIn`).
- **Why:** A7 rejected empty product and category names, but a name of just spaces ("   ") still got through, because spaces count as characters. Trimming first means:
  - a blank-looking name is correctly rejected as empty
  - "Cafe " with a stray space is saved as "Cafe", rather than appearing as a separate category in the filter and the breakdown
- **How we checked:**
  - Product "   " → **rejected (422)**; category "  " → **rejected (422)**.
  - Product "  Latte " with category "Cafe " → **saved as "Latte" / "Cafe"** (the test sale was deleted afterwards).
  - The database still has 150 sales in 4 categories.

## B1 · Pace to Target: the calculation and API
- **What changed:**
  - A new `/api/pace?month=YYYY-MM` endpoint (`backend/sales/routes.py`). With no month it uses the current month in Malaysia time.
  - The maths lives in `_pace()` in `backend/db.py`. It's a plain function with no database, so every edge case can be tested directly. `pace()` fetches the month's revenue (reusing A5's `_month_net_revenue`) and target, then calls it.
  - Response fields:
    - month-to-date revenue
    - days elapsed / days in month
    - projected month-end revenue
    - target
    - pace vs target, in RM and %
    - status (`on_track` / `at_risk`)
    - `period` (past / current / future) and `as_of` (today's Malaysia date)
- **Why:** This is the Part B feature. Forecast = revenue so far ÷ days elapsed × days in the month. The brief's tricky cases are handled like this:
  - **Past month:** it's over, so the "projection" is just the actual total.
  - **Current month:** today counts as a day elapsed. On the 1st that's 1 day, not 0, so there's never a divide-by-zero. The trade-off is that early-month forecasts swing a lot (one good sale on the 1st projects a huge month).
  - **Future month:** nothing has happened yet (0 days), so projected and pace are **N/A** rather than a division by zero.
  - **Month lengths:** taken from the calendar, which knows Feb has 29 days in leap years.
  - **No target, or a target of 0:** pace and status are **N/A**. The forecast is still shown, since it doesn't need a target.
  - **Today:** Malaysia time (A6). Store-wide like attainment (A5), so it ignores the category/channel filters.
- **How we checked:**
  - **Live API:**
    - November is "current", day **24 of 30**. Projected **RM 7,573.38** (6,058.70 ÷ 24 × 30, which matches a hand calculation), **75.7%** of target, **at risk**.
    - The server's own clock (UTC) still said 23 Nov at that moment, but the API correctly reported 24 Nov (Malaysia).
    - October is "past" with **31/31** days and projected = actual = **RM 7,082.65**. September is "past" with **30/30** days and **RM 5,764.45**.
    - December is "future" with **0/31** days, and projected, pace and status are all **N/A**. August (no target) has pace **N/A**. `2026-13` is **rejected (422)**.
  - **Edge cases** run straight through the calculation, all correct:

    | Case | Days | Projected | Pace | Status |
    |---|---|---|---|---|
    | Feb 2024, leap year (RM 1,000 by day 10) | 10/29 | 2,900 | 58% | at risk |
    | Feb 2026, not a leap year | 10/28 | 2,800 | 56% | at risk |
    | April (30-day month) | 10/30 | 3,000 | 60% | at risk |
    | January (31-day month) | 10/31 | 3,100 | 62% | at risk |
    | Day 1 of the month | 1/31 | 9,300 | 186% | on track |
    | Last day of the month | 31/31 | 4,500 | 90% | at risk |
    | Past leap-year Feb (actual RM 4,800) | 29/29 | 4,800 | 96% | at risk |
    | Future month | 0/31 | N/A | N/A | N/A |
    | No target / target of 0 | 24/30 | 1,250 | N/A | N/A |
    | No sales yet | 24/30 | 0 | 0% | at risk |
    | Exactly on target | 15/30 | 5,000 | 100% | on track |
    | December viewed on 1 Jan (year change) | 31/31 | 900 (actual) | 18% | at risk |

## B2 · Pace to Target: the dashboard panel
- **What changed:** A new "Pace to Target" panel sits under the KPI cards (`frontend/src/components/PaceCard.jsx`). It's loaded by `App.jsx` through a new `getPace()` in `api.js`, and styled in `styles.css`. It shows:
  - month-to-date revenue
  - days elapsed / days in month
  - projected month-end revenue
  - target
  - pace vs target, in RM (+/−) and as a % of target
  - an **On track** (green) / **At risk** (red) / **N/A** (grey) badge
  - a bar showing how much of the target has been reached so far
- **Why:** This is the visible half of Part B. All the maths happens in the API (B1), so the panel only displays it. Anything the API can't work out arrives empty and is shown as **N/A**, never NaN or Infinity. A short note explains the special cases:
  - **Past month:** the "Projected" label changes to "Final month total", with a note that the month is over.
  - **Future month:** "This month hasn't started yet, so there's nothing to project."
  - **No target:** "No target is set for this month."
  - **A category/channel filter is on:** "Store-wide: category and channel filters don't apply here", so the numbers aren't mistaken for the filtered view.
  - **"All months" selected:** a prompt to pick a month, since pace only makes sense for one month.
- **How we checked:**
  - Frontend builds (`✓ built`).
  - The panel was rendered with real API data for each case:
    - **Nov (current):** At risk · RM 6,058.70 · 24 / 30 · projected RM 7,573.38 · target RM 10,000.00 · **−RM 2,426.62, 75.7% of target**
    - **Oct (past):** 31 / 31 · "Final month total" RM 7,082.65 · 70.8% · "month is over" note
    - **Dec (future):** N/A badge · 0 / 31 · projected, target and pace all **N/A** · "hasn't started" and "no target" notes
    - **Aug (no target):** pace **N/A** · "no target" note
    - **Nov with a Cafe filter:** same store-wide numbers, plus the "store-wide" note
    - **All months:** "Select a month…" prompt
  - None of the rendered months contained "NaN", "Infinity" or "undefined".
  - A small fix along the way: with no pace the panel briefly read "N/A of target", so the "% of target" line now only appears when there is a percentage.
  - Note: December can't be picked from the month dropdown yet, because it only lists months that have sales. Part C fixes that.

## C1 · Target editor: saving a target, and future months in the dropdown
- **What changed:**
  - A new `PUT /api/targets/{month}` endpoint (`backend/sales/routes.py`, `db.upsert_target`). It creates a month's target, or replaces it if one already exists.
  - The month dropdown (`db.filters`) now lists months that have **sales or a target**, rather than only months with sales.
- **Why I picked this for Part C:** The dashboard is built around monthly targets, but there was **no way to set one**. Only three months were ever given a RM 10,000 target, when the sample data was created. In practice:
  - a manager couldn't plan next month's target or correct this month's
  - any month outside those three was stuck on "N/A" forever
  - future months couldn't even be picked from the dropdown, which only listed months with sales

  With this, you can set a target for next month, select it straight away, and see the Part B "future month → N/A" handling live.
- **Safety checks:**
  - The month must be a real month.
  - The target must be **more than 0**. A zero target is exactly the divide-by-zero case Parts A/B guard against, so it isn't allowed in.
  - The target must fit the database column (under 10 billion).
- **How we checked:**
  - Bad input is **rejected (422)**: month `2026-13`, target 0, −100, 1 trillion, or missing.
  - Setting December to RM 12,000 and then RM 11,000 **saved and replaced** it (one row, not two).
  - The dropdown then listed **2026-12** at the top.
  - December's pace showed target RM 11,000 but pace still **N/A**, which is right because it hasn't started.
  - Changing November's target to RM 8,000 immediately updated attainment to **75.7%** and pace to **94.7%** (still at risk).
  - Test data was put back afterwards: November is RM 10,000 again and December's target was removed, so the targets table is back to its 3 original rows.
