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

## C2 · Target editor: the form on the dashboard
- **What changed:** A new "Monthly Target" panel above "Add Sale" (`frontend/src/components/TargetEditor.jsx`), with `getTargets()` / `putTarget()` added to `api.js` and wiring in `App.jsx`.
  - Pick a month (any month, including future ones) and enter a target in RM.
  - It shows the month's **current target**, or "No target set for this month yet", and pre-fills the amount.
  - The button reads **Set Target** or **Update Target**. It's disabled until the amount is a positive number that differs from the current target.
  - It follows the dashboard's month filter. With "All months" selected it defaults to the current month (Malaysia time).
  - After saving, the month list refreshes and the dashboard **jumps to that month**, so the new target, attainment and pace show straight away.
- **Why:** C1 made saving a target possible, but only through the API. This puts it where a manager would use it. The form blocks zero, negative and empty amounts before sending, and the API rejects them again anyway (C1).
- **How we checked:**
  - Frontend builds (`✓ built`).
  - The form's first render shows Month [2026-11], an empty Target field, the "No target set…" note and **Set Target**, before the saved targets load in.
  - A bug was caught while reviewing: after saving, reloading the target list wiped the "Saved" message straight away. Clearing the message now only happens when you switch month.
  - The API calls the form makes were tested in C1.
- **Follow-up (your feedback): arrows move by RM 100, typing stays exact.** The Target box's up/down arrows used to change the amount by **RM 0.01**, which is pointless for targets in the thousands.
  - They now move by **RM 100**.
  - You can still type any amount with sen, e.g. **RM 12,345.67**.
  - Normally the browser treats the step size as a rule and would reject 12,345.67 ("nearest valid values are 12,300 and 12,400"). So the form switches off the browser's own checks and uses its own instead: the month must be a real month, and the amount must be a number above 0. The API checks again (C1).
  - Checked: frontend builds, and saving **12,345.67** through the API stored exactly **12,345.67** (the test target was removed afterwards).

## C3 · Dark mode
- **What changed:**
  - A **System / Light / Dark** switch in the top-right of the header (`frontend/src/components/ThemeToggle.jsx`).
    - **System** (the default) follows the computer's own light/dark setting.
    - **Light** and **Dark** override it, and the choice is remembered on that browser.
  - `styles.css` now has a full dark colour set.
  - Seven colours were hard-coded and would have stayed light in dark mode. They've all been turned into theme colours: the error box, the On track / At risk badges, button text, table row hover, and the green/red status dots.
  - `color-scheme` is set, so the browser's own controls match the theme: dropdown lists, date and month pickers, number arrows and scrollbars.
  - A tiny script in `frontend/index.html` applies a saved choice **before the page draws**, so a dark-mode user doesn't see a white flash on load.
- **Why:** Part C asked for a second improvement, and dark mode is easier on the eyes for a dashboard that's left open all day. It was built on the colour variables the app already used, so every panel (including the new Pace and Target panels) switches together without per-component changes. If the browser blocks saved settings (e.g. private mode), the app quietly falls back to "System" instead of crashing.
- **How we checked ("no UI broken"):**
  - Frontend builds (`✓ built`).
  - No hard-coded colours are left outside the theme definitions, and every colour variable used is defined in both themes. The two copies of the dark theme (OS setting vs manual "Dark") were checked to be identical.
  - **Text contrast** was measured with the standard WCAG formula. 4.5:1 is the accessibility pass mark for normal text; 3:1 for large text and UI parts:

    | Text on background | Light | Dark |
    |---|---|---|
    | Body / card text | 17.6 | 14.6–15.7 |
    | Labels (grey) | 3.2* | 6.7 |
    | Button text | 17.6 | 15.7 |
    | At risk / error badge | 6.0 | 6.1 |
    | On track badge | 5.4 | 7.6 |
    | Bars vs their track | 13.7 | 10.0 |

    \*The light-mode grey labels are the app's original design and weren't changed.
  - The check caught one problem in the new switch: its unselected options were **2.9:1** in light mode, below the 3:1 minimum. They now use the main text colour, with the selected option shown by a raised, bold button.
  - Saved-setting fallbacks: no storage available → **System**; saved "dark" → **Dark**; storage that throws an error → **System**, no crash.

## C3a · Add Sale dropdown labels capitalised
- **What changed:** In the Add Sale form (`AddSaleForm.jsx`), Status now shows **Completed** / **Refunded** and Channel shows **Online** / **In store**, instead of the raw lowercase values (`in_store` with an underscore).
- **Why:** Your feedback: it looked unpolished next to the rest of the form. Only the **visible label** changed. The values sent to the API are still `completed` / `refunded` and `online` / `in_store`, which is what the API accepts (A7) and what's stored. Nothing else is affected, and the sales table already shows the status capitalised.
- **How we checked:** Frontend builds (`✓ built`). The option values are unchanged (`completed`, `refunded`, `online`, `in_store`).

## Parts B & C review · Gaps found and fixed
A full re-read of every Part B/C change, looking for leftover duplicate code and unhandled edge cases. Each suspected problem was reproduced against the live app before it was fixed.

- **1. Future-dated sales inflated the pace forecast** (`backend/db.py`, `pace`)
  - **What was wrong:** Month-to-date counted every sale in the month, including ones dated later than today. Court bookings are naturally made in advance. One RM 5,000 booking dated 30 Nov turned November from **at risk (projected RM 7,573)** into **on track (RM 13,823)**, because the run-rate treated future money as already earned.
  - **Fix:** Pace now only counts sales dated **up to today** (Malaysia time). Total revenue and target attainment still include all of the month's booked sales, because they answer "how much is booked this month", not "how fast are we going".
  - **Checked:** with the same booking added, pace stays **RM 6,058.70 → RM 7,573.38, at risk**. October (past) is unchanged. The test sale was deleted.
- **2. The month dropdown could miss the month it was showing** (`backend/db.py`, `filters`)
  - **What was wrong:** On the 1st of a new month (no sales or target yet), the dashboard opens on that month, but the dropdown only listed months with sales or targets. It would show "All months" while displaying something else.
  - **Fix:** The current month is always in the list.
  - **Checked:** simulating 1 Dec, the dropdown lists **2026-12** first, and pace shows day **1/31**, RM 0, no divide-by-zero.
- **3. Some impossible numbers crashed the API** (`backend/sales/routes.py`, `backend/main.py`)
  - **What was wrong:** A price or target of `Infinity`/`NaN`, a price of RM 100 million or more, or a quantity over 2.1 billion caused a **500 server error** instead of a clean "invalid input". The browser forms can't send these, but any other API client can.
  - The price and quantity limits now match the database columns.
  - `Infinity`/`NaN` are rejected outright.
  - One subtle catch: the standard error reply **repeats the bad value back**, and `Infinity` can't be written in JSON, so even the rejection crashed. A small error handler now writes such values as text.
  - **Checked:** all of these now return **422** with a clear reason, e.g. "Input should be a finite number" or "Input should be less than 100000000". Earlier checks (quantity 0, month 2026-13) still return 422.
- **4. Duplicate code removed** (`backend/db.py`): the "look up this month's target" query was copied in both `summary` and `pace`. It's now one helper, `_month_target`.
- **5. Quick month switching could show stale numbers** (`frontend/src/App.jsx`)
  - **What was wrong:** If an older, slower reply arrived after a newer one, it overwrote the screen. You could see October's pace under a November heading.
  - **Fix:** Each load is numbered, and only the newest one may update the screen.
  - **Checked:** by reading the code only; this timing race is hard to trigger by hand.
- **6. Month box hint for Firefox** (`TargetEditor.jsx`): Firefox shows the target form's Month box as plain text, so it now has a "YYYY-MM" placeholder. The form already rejects badly formatted months.
- **Overall checks:**
  - Backend compiles, and `pyflakes` finds no unused imports or variables. Frontend builds, and no unused imports were found.
  - The **Part A regression** (60 month × category × channel combinations against the database) still has **0 mismatches**.

## C3b · Channel names shown the same everywhere
- **What changed:** A small helper, `channelLabel` in `frontend/src/format.js`, turns the stored channel values into display names: `online` → **Online**, `in_store` → **In store**. It's used in all four places a channel appears:
  - the sales table's Channel column (`SalesTable.jsx`)
  - the Channel filter dropdown (`FilterBar.jsx`)
  - the "Revenue by Channel" bars (`Breakdown.jsx`, via a new optional `formatLabel`)
  - the Add Sale form (`AddSaleForm.jsx`)
- **Why:** Your feedback. After C3a, Add Sale said "In store" but the sales table underneath still showed the raw `in_store`. Using one helper means the names are defined in **one place** and can't drift apart again. Only the on-screen text changes: the API, the database and the filter values all still use `online` / `in_store`. An unexpected channel value is shown as-is rather than hidden.
- **How we checked:**
  - Frontend builds (`✓ built`).
  - The helper gives `online` → "Online", `in_store` → "In store", and leaves unknown values unchanged.
  - A code search finds no remaining spot that shows the raw channel value.

## Full re-sweep · 49 automated checks, plus two more fixes
- **What was run:** One script re-ran every check from Parts A–C together. It leaves the data exactly as it found it.
  - **Code:** backend compiles; `pyflakes` finds nothing unused; frontend builds; no unused imports.
  - **Duplicates:** no hard-coded colours outside the theme; the target query and the month rule each exist once; no raw channel names on screen.
  - **Part A:** 60 month × category × channel combinations against the database. Attainment stays store-wide, and is N/A for "All months" and months with no target.
  - **Part B:** live past / current / future / no-target months, plus 11 calculation edge cases (leap and 28/30/31-day months, day 1, exactly on target, year change).
  - **Validation:** 19 bad inputs, all rejected with 422 and never 500. Rejected requests add no rows.
  - **Part C:** saving a target creates then replaces one row; the new month appears in the dropdown; the current month is listed even on the 1st.
  - **Forecast:** a future-dated sale doesn't change the pace figures.
  - **Screen:** the N/A formatters and channel names behave correctly; the pace panel was rendered 10 ways with no "NaN", "Infinity" or "undefined"; the theme defaults to System.
  - **Clean-up:** the data was unchanged afterwards.
- **Result:** **49 passed, 0 failed.** (The first run showed 4 failures. They were a formatting mistake in the test script's expected values, not app bugs, and the actual values were correct.)
- **Two more gaps found by reading the code, and fixed:**
  - **Filters didn't refresh after adding or deleting a sale** (`App.jsx`). Add a sale in a new category like "Merch" and it wouldn't appear in the Category filter until a page reload. Adding or deleting a sale now refreshes the filter lists too. Checked: after adding a "Merch" sale the API's category list includes Merch, and after deleting it Merch is gone (test sale removed).
  - **A failed delete was silent** (`SalesTable.jsx`). If the API was unreachable, clicking Delete did nothing and gave no message. It now shows "Failed to delete sale: …", matching how Add Sale already reports errors.
- Frontend builds after both fixes, and the full suite still passes **49/49**.
