import React from "react";
import { rm } from "../format.js";

// Bar width as a 0–100% share of the largest bar; never NaN or > 100%.
const barWidth = (value, max) =>
  Number.isFinite(value) ? Math.min(100, Math.max(0, (value / max) * 100)) : 0;

export default function Breakdown({ title, rows, labelKey }) {
  // At least 1 so an all-zero breakdown never divides by zero.
  const max = Math.max(1, ...rows.map((r) => r.revenue).filter(Number.isFinite));

  return (
    <div className="panel">
      <h2>{title}</h2>
      {rows.length === 0 && <p className="muted">No data.</p>}
      {rows.map((r) => (
        <div className="bar-row" key={r[labelKey]}>
          <div className="bar-label">{r[labelKey]}</div>
          <div className="bar-track">
            <div className="bar-fill" style={{ width: `${barWidth(r.revenue, max)}%` }} />
          </div>
          <div className="bar-value">{rm(r.revenue)}</div>
        </div>
      ))}
    </div>
  );
}
