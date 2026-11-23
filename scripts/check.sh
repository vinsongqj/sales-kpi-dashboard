#!/bin/bash
# End-to-end correctness checks for Parts A–C of the Sales KPI Dashboard.
#
#   bash scripts/check.sh
#
# Needs the stack running (`docker compose up`) and python3 on the host.
# Months are worked out from today's date in Malaysia (UTC+8), and expected
# numbers come from the database itself, so the script keeps working after a
# reseed or when the month changes. Any test rows it adds are removed again,
# and the final section confirms the data is exactly as it was found.
#
# "Permission denied" on the Docker socket means this terminal was opened
# before your user joined the `docker` group: run `newgrp docker` (or open a
# new terminal), check with `docker ps`, then re-run.

cd "$(dirname "$0")/.." || exit 1
API=http://localhost:8010
PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
skip() { SKIP=$((SKIP+1)); printf "  \033[33mSKIP\033[0m %s\n" "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
sql()  { docker compose exec -T db psql -U sales -tAc "$1" </dev/null; }  # </dev/null: never eat a loop's input
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
jget() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
apy()  { docker compose exec -T api python -c "$1"; }

# --- Preflight: stop early with a clear reason instead of running every
# check against empty answers (which gives misleading FAILs *and* PASSes).
die() { printf "\033[31mCannot run checks:\033[0m %s\n" "$1" >&2; exit 2; }
command -v python3 >/dev/null || die "python3 is not installed on this machine."
command -v curl >/dev/null    || die "curl is not installed on this machine."
if ! err=$(docker compose exec -T db true 2>&1 </dev/null); then
  case "$err" in
    *"permission denied"*)
      die "this terminal can't talk to Docker (permission denied on the Docker socket).
  Your user is probably in the 'docker' group, but this terminal was opened before that.
  Fix: run 'newgrp docker' (or open a new terminal), check with 'docker ps', then re-run." ;;
    *) die "can't reach the database container. Is the stack running? Try: docker compose up
  Docker said: $err" ;;
  esac
fi
[ "$(code $API/api/health)" = "200" ] || die "API not reachable at $API. Start the stack: docker compose up"

# Reference months, relative to today in Malaysia.
read -r TODAY CUR PREV NEXT OLD LASTDAY NEXT1 <<<"$(apy "
import db, calendar
t = db.today_myt()
def shift(n):
    y, m = divmod(t.year * 12 + t.month - 1 + n, 12)
    return f'{y}-{m + 1:02d}'
last = calendar.monthrange(t.year, t.month)[1]
print(t, shift(0), shift(-1), shift(1), shift(-4), f'{shift(0)}-{last:02d}', f'{shift(1)}-01')")"
[[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && -n "$NEXT1" ]] || die "couldn't work out today's date from the API container."
echo "Today (MYT): $TODAY | current $CUR | previous $PREV | next $NEXT | old (likely no target) $OLD"

SALES0=$(sql "select count(*) from sales")
TGT0=$(sql "select coalesce(string_agg(month||'='||target_amount, ',' order by month), '') from monthly_targets")
[[ "$SALES0" =~ ^[0-9]+$ ]] || die "couldn't read the sales table from the database."
NET="sum(quantity*unit_price*(1-discount_pct/100))"

echo "== 1. Build & static checks"
apy "import py_compile; [py_compile.compile(f, doraise=True) for f in ('main.py','db.py','sales/routes.py')]" \
  && ok "backend compiles" || bad "backend compiles"
if docker compose exec -T api python -m pyflakes --version >/dev/null 2>&1 \
   || docker compose exec -T api pip install -q pyflakes >/dev/null 2>&1; then
  check "pyflakes: no unused imports/variables" "$(docker compose exec -T api python -m pyflakes main.py db.py sales/routes.py)" ""
else
  skip "pyflakes not available in the api container"
fi
docker compose exec -T web npm run build >/dev/null 2>&1 && ok "frontend builds" || bad "frontend builds"
unused=""
for f in frontend/src/*.js frontend/src/*.jsx frontend/src/components/*.jsx; do
  for name in $(grep -oE '^import \{[^}]*\}|^import [A-Za-z]+ from' "$f" | sed -E 's/import|from|[{},]//g'); do
    [ "$name" = React ] && continue
    [ "$(grep -cw "$name" "$f")" -lt 2 ] && unused="$unused $f:$name"
  done
done
check "frontend: no unused imports" "$unused" ""
check "styles: no hard-coded colours outside theme tokens" \
  "$(grep -nE '#[0-9a-fA-F]{3,6}\b' frontend/src/styles.css | grep -vE '^\s*[0-9]+:\s*--')" ""
check "target lookup SQL defined once" "$(grep -c 'SELECT target_amount FROM monthly_targets' backend/db.py)" "1"
check "no raw channel value rendered in UI" "$(grep -rnE '\{(s|r|c)\.channel\}' frontend/src)" ""

echo "== 2. Part A: dashboard totals vs the database"
# "" in each list means "no filter" (All months / All categories / All channels).
mapfile -t months < <(echo; sql "select distinct to_char(sale_date,'YYYY-MM') from sales order by 1")
mapfile -t cats < <(echo; sql "select distinct category from sales order by 1")
n=0; mism=0
for m in "${months[@]}"; do
  for cat in "${cats[@]}"; do
    for ch in "" online in_store; do
      n=$((n+1)); w="status='completed'"; q=""
      [ -n "$m" ]   && w="$w and to_char(sale_date,'YYYY-MM')='$m'" && q="$q&month=$m"
      [ -n "$cat" ] && w="$w and category='$cat'" && q="$q&category=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$cat")"
      [ -n "$ch" ]  && w="$w and channel='$ch'" && q="$q&channel=$ch"
      exp=$(sql "select coalesce(round($NET,2),0)::float8 ||' '|| count(*) ||' '|| coalesce(round($NET/nullif(count(*),0),2),0)::float8 from sales where $w")
      got=$(curl -s "$API/api/summary?${q#&}" | jget "f\"{float(d['total_revenue'])} {d['order_count']} {float(d['avg_order_value'])} {round(sum(x['revenue'] for x in d['by_category']),2)} {round(sum(x['revenue'] for x in d['by_channel']),2)}\"")
      same=$(python3 -c "e=list(map(float,'$exp'.split())); g=list(map(float,'$got'.split())); print(abs(e[0]-g[0])<0.01 and e[1]==g[1] and abs(e[2]-g[2])<0.01 and abs(g[0]-g[3])<0.01 and abs(g[0]-g[4])<0.01)")
      [ "$same" = True ] || { mism=$((mism+1)); echo "    mismatch ?$q expected=[$exp] got=[$got]"; }
    done
  done
done
expected_n=$(( ${#months[@]} * ${#cats[@]} * 3 ))
check "covered every combination ($n of ${#months[@]} months x ${#cats[@]} categories x 3 channels)" "$n" "$expected_n"
check "revenue, orders, AOV and bar totals match SQL in all $n combinations" "$mism" "0"
exp_att=$(sql "select round(($NET)/nullif((select target_amount from monthly_targets where month='$CUR'),0)*100,1)::float8 from sales where status='completed' and to_char(sale_date,'YYYY-MM')='$CUR'")
check "current-month attainment = store-wide revenue / target" "$(curl -s "$API/api/summary?month=$CUR" | jget 'd["attainment_pct"]')" "${exp_att:-None}"
first_cat=${cats[1]}
check "attainment ignores category filter (store-wide)" "$(curl -s "$API/api/summary?month=$CUR&category=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$first_cat")" | jget 'd["attainment_pct"]')" "${exp_att:-None}"
check "All months: attainment N/A" "$(curl -s "$API/api/summary" | jget 'd["attainment_pct"]')" "None"
if [ -z "$(sql "select 1 from monthly_targets where month='$OLD'")" ]; then
  check "month with no target ($OLD): attainment N/A" "$(curl -s "$API/api/summary?month=$OLD" | jget 'd["attainment_pct"]')" "None"
else skip "$OLD has a target; no-target attainment case not available"; fi

echo "== 3. Part B: Pace to Target (live)"
p=$(curl -s "$API/api/pace")
check "defaults to the current month in MYT" "$(echo "$p" | jget 'd["month"], d["as_of"], d["period"]')" "$CUR $TODAY current"
check "days elapsed = today's day of month" "$(echo "$p" | jget 'd["days_elapsed"]')" "$((10#${TODAY:8:2}))"
check "previous month: past, full month elapsed, projected = actual" \
  "$(curl -s "$API/api/pace?month=$PREV" | jget 'd["period"], d["days_elapsed"]==d["days_in_month"], d["projected_revenue"]==d["mtd_revenue"]')" "past True True"
check "next month: future, 0 days, projection/pace N/A" \
  "$(curl -s "$API/api/pace?month=$NEXT" | jget 'd["period"], d["days_elapsed"], d["projected_revenue"], d["pace_pct"], d["status"]')" "future 0 None None None"
if [ -z "$(sql "select 1 from monthly_targets where month='$OLD'")" ]; then
  check "month with no target: pace N/A" "$(curl -s "$API/api/pace?month=$OLD" | jget 'd["pace_pct"], d["status"]')" "None None"
else skip "$OLD has a target; no-target pace case not available"; fi

echo "== 4. Part B: pace calculation edge cases"
out=$(apy "
from datetime import date; from db import _pace
C = [((1000,5000,2024,2,date(2024,2,10)), (29,2900.0,58.0,'at_risk')),     # leap February
     ((1000,5000,2026,2,date(2026,2,10)), (28,2800.0,56.0,'at_risk')),     # normal February
     ((1000,5000,2026,4,date(2026,4,10)), (30,3000.0,60.0,'at_risk')),     # 30-day month
     ((1000,5000,2026,1,date(2026,1,10)), (31,3100.0,62.0,'at_risk')),     # 31-day month
     ((300,5000,2026,3,date(2026,3,1)),   (31,9300.0,186.0,'on_track')),   # day 1: no divide-by-zero
     ((4800,5000,2024,2,date(2024,3,1)),  (29,4800,96.0,'at_risk')),       # past: projected = actual
     ((0,5000,2026,12,date(2026,11,24)),  (31,None,None,None)),            # future: N/A
     ((1000,None,2026,11,date(2026,11,24)),(30,1250.0,None,None)),         # no target
     ((1000,0,2026,11,date(2026,11,24)),  (30,1250.0,None,None)),          # zero target
     ((2500,5000,2026,4,date(2026,4,15)), (30,5000.0,100.0,'on_track')),   # exactly on target
     ((900,5000,2025,12,date(2026,1,1)),  (31,900,18.0,'at_risk'))]        # year boundary
key = lambda r: (r['days_in_month'], r['projected_revenue'], r['pace_pct'], r['status'])
print(len(C), sum(key(_pace(*a)) != e for a, e in C))")
check "11 cases: leap/28/30/31-day months, day 1, past, future, no/zero target, exact, year change" "$out" "11 0"

echo "== 5. Input validation (bad input gets 422, never a 500)"
B="\"sale_date\":\"$TODAY\",\"product\":\"T\",\"category\":\"Cafe\",\"channel\":\"online\""
for c in "quantity 0|{$B,\"quantity\":0,\"unit_price\":1}" \
         "discount 150%|{$B,\"quantity\":1,\"unit_price\":1,\"discount_pct\":150}" \
         "unknown channel|{\"sale_date\":\"$TODAY\",\"product\":\"T\",\"category\":\"Cafe\",\"channel\":\"web\",\"quantity\":1,\"unit_price\":1}" \
         "unknown status|{$B,\"quantity\":1,\"unit_price\":1,\"status\":\"void\"}" \
         "negative price|{$B,\"quantity\":1,\"unit_price\":-5}" \
         "blank product name|{\"sale_date\":\"$TODAY\",\"product\":\"  \",\"category\":\"Cafe\",\"channel\":\"online\",\"quantity\":1,\"unit_price\":1}" \
         "price Infinity|{$B,\"quantity\":1,\"unit_price\":Infinity}" \
         "price NaN|{$B,\"quantity\":1,\"unit_price\":NaN}" \
         "price too big for DB|{$B,\"quantity\":1,\"unit_price\":1e9}" \
         "quantity too big for DB|{$B,\"quantity\":3000000000,\"unit_price\":1}"; do
  check "new sale, ${c%%|*}" "$(code -X POST -H 'Content-Type: application/json' -d "${c#*|}" $API/api/sales)" "422"
done
for c in "month 13|2026-13|{\"target_amount\":5000}" "target 0|$NEXT|{\"target_amount\":0}" \
         "negative target|$NEXT|{\"target_amount\":-1}" "target too big|$NEXT|{\"target_amount\":1e12}" \
         "target Infinity|$NEXT|{\"target_amount\":Infinity}" "missing target|$NEXT|{}"; do
  IFS='|' read -r label m body <<<"$c"
  check "set target, $label" "$(code -X PUT -H 'Content-Type: application/json' -d "$body" $API/api/targets/$m)" "422"
done
for q in "summary?month=2026-13" "sales?month=abc" "pace?month=2026-00"; do check "GET /api/$q" "$(code "$API/api/$q")" "422"; done
check "rejected requests added no rows" "$(sql "select count(*) from sales")" "$SALES0"

echo "== 6. Part C: target editor"
had_next=$(sql "select target_amount from monthly_targets where month='$NEXT'")
check "set $NEXT target to 12345.67 (sen kept)" "$(curl -s -X PUT -H 'Content-Type: application/json' -d '{"target_amount":12345.67}' $API/api/targets/$NEXT | jget 'd["target_amount"]')" "12345.67"
curl -s -X PUT -H 'Content-Type: application/json' -d '{"target_amount":11000}' $API/api/targets/$NEXT >/dev/null
check "setting again replaces it (still one row)" "$(sql "select count(*)||'/'||max(target_amount) from monthly_targets where month='$NEXT'")" "1/11000.00"
check "$NEXT now selectable in the month dropdown" "$(curl -s $API/api/filters | jget "'$NEXT' in d['months']")" "True"
check "$NEXT pace shows the target but stays N/A (not started)" "$(curl -s "$API/api/pace?month=$NEXT" | jget 'd["target"], d["status"]')" "11000.0 None"
if [ -n "$had_next" ]; then sql "update monthly_targets set target_amount=$had_next where month='$NEXT'" >/dev/null
else sql "delete from monthly_targets where month='$NEXT'" >/dev/null; fi
check "current month listed even on the 1st (simulated $NEXT1)" "$(apy "
import asyncio, datetime, db
async def main():
    await db.init_db(); db.today_myt = lambda: datetime.date.fromisoformat('$NEXT1')
    async with db.pool.acquire() as c: print((await db.filters(c))['months'][0])
    await db.close_db()
asyncio.run(main())")" "$NEXT"

echo "== 7. Future-dated sales don't inflate the forecast"
if [ "$TODAY" != "$LASTDAY" ]; then
  before=$(curl -s "$API/api/pace" | jget 'd["mtd_revenue"], d["projected_revenue"]')
  id=$(curl -s -X POST -H 'Content-Type: application/json' -d "{\"sale_date\":\"$LASTDAY\",\"product\":\"Check\",\"category\":\"Court Booking\",\"channel\":\"online\",\"quantity\":1,\"unit_price\":5000}" $API/api/sales | jget 'd["id"]')
  check "RM 5,000 sale dated $LASTDAY leaves pace unchanged" "$(curl -s "$API/api/pace" | jget 'd["mtd_revenue"], d["projected_revenue"]')" "$before"
  curl -s -X DELETE "$API/api/sales/$id" >/dev/null
else skip "today is the last day of the month; no later date to test with"; fi

echo "== 8. Frontend helpers and rendering"
check "N/A for empty/NaN/Infinity, normal numbers formatted, channel names" "$(docker compose exec -T web node --input-type=module -e '
const f = await import("/app/src/format.js");
const na = [null, undefined, NaN, Infinity, -Infinity, "", "abc"].every(v => f.rm(v) === "N/A" && f.pct(v) === "N/A");
const num = f.rm(6058.7) === "RM 6,058.70" && f.pct(60.6) === "60.6%";
const ch = f.channelLabel("online") === "Online" && f.channelLabel("in_store") === "In store" && f.channelLabel("web") === "web";
console.log(na, num, ch);')" "true true true"
echo 'import React from "react"; import {renderToStaticMarkup} from "react-dom/server"; import P from "./src/components/PaceCard.jsx"; import T from "./src/components/ThemeToggle.jsx"; export {React, renderToStaticMarkup, P, T};' \
  | docker compose exec -T -w /app web sh -c 'npx esbuild --bundle --format=cjs --platform=node --outfile=/tmp/check.cjs --sourcefile=entry.jsx --loader=jsx --log-level=error'
check "Pace panel never shows NaN/Infinity/undefined; theme defaults to System" "$(docker compose exec -T web node -e '
const { React, renderToStaticMarkup: r, P, T } = require("/tmp/check.cjs");
(async () => {
  let bad = 0;
  for (const m of process.argv.slice(1)) {
    const pace = await (await fetch("http://api:8000/api/pace?month=" + m)).json();
    for (const filtered of [false, true]) if (/NaN|Infinity|undefined/.test(r(React.createElement(P, { pace, month: m, filtered })))) bad++;
  }
  console.log(bad, /class="active"[^>]*>System/.test(r(React.createElement(T))));
})();' "$OLD" "$PREV" "$CUR" "$NEXT")" "0 true"
docker compose exec -T web rm -f /tmp/check.cjs

echo "== 9. Data left as found"
check "sales unchanged" "$(sql "select count(*) from sales")" "$SALES0"
check "targets unchanged" "$(sql "select coalesce(string_agg(month||'='||target_amount, ',' order by month), '') from monthly_targets")" "$TGT0"

echo; echo "RESULT: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ]
