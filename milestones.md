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
