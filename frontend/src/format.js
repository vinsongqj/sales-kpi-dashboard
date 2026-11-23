// Any value that isn't a real, finite number (null, undefined, NaN, ±Infinity)
// renders as "N/A" so the dashboard never shows "NaN" or "Infinity".
const finite = (n) => n != null && n !== "" && Number.isFinite(Number(n));

export const rm = (n) =>
  !finite(n)
    ? "N/A"
    : "RM " +
      Number(n).toLocaleString("en-MY", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });

export const pct = (n) =>
  !finite(n) ? "N/A" : Number(n).toLocaleString("en-MY", { maximumFractionDigits: 1 }) + "%";

// Display names for channel values. The API and database keep the raw values
// ("online", "in_store"); only what's shown on screen changes. Unknown values
// are shown as-is.
const CHANNEL_LABELS = { online: "Online", in_store: "In store" };
export const channelLabel = (c) => CHANNEL_LABELS[c] ?? c;
