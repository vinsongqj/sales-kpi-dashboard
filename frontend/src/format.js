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
