import React from "react";
import { rm, pct } from "../format.js";

const STATUS_LABEL = { on_track: "On track", at_risk: "At risk" };

// "+RM 1,234.00" / "−RM 1,234.00"; N/A when there's no number.
const signedRm = (n) =>
  Number.isFinite(n) ? `${n < 0 ? "−" : "+"}${rm(Math.abs(n))}` : rm(n);

/**
 * Pace to Target for the selected month. All numbers come from /api/pace;
 * nulls (future month, missing target) render as "N/A".
 */
export default function PaceCard({ pace, month, filtered }) {
  if (!month) {
    return (
      <div className="panel">
        <h2>Pace to Target</h2>
        <p className="muted">Select a month to see its pace to target.</p>
      </div>
    );
  }
  if (!pace) return null;

  const past = pace.period === "past";
  const progress =
    Number.isFinite(pace.mtd_revenue) && pace.target > 0
      ? Math.min(100, Math.max(0, (pace.mtd_revenue / pace.target) * 100))
      : 0;

  const stats = [
    { label: "Month-to-date revenue", value: rm(pace.mtd_revenue) },
    { label: "Days elapsed", value: `${pace.days_elapsed} / ${pace.days_in_month}` },
    { label: past ? "Final month total" : "Projected month-end", value: rm(pace.projected_revenue) },
    { label: "Target", value: rm(pace.target) },
    {
      label: "Pace vs target",
      value: signedRm(pace.pace_rm),
      sub: Number.isFinite(pace.pace_pct) ? `${pct(pace.pace_pct)} of target` : null,
    },
  ];

  const notes = [];
  if (pace.period === "future") notes.push("This month hasn't started yet, so there's nothing to project.");
  if (past) notes.push("This month is over, so the projection is the actual total.");
  if (pace.target == null || pace.target <= 0) notes.push("No target is set for this month.");
  if (filtered) notes.push("Store-wide: category and channel filters don't apply here.");

  return (
    <div className="panel">
      <div className="pace-head">
        <h2>Pace to Target · {pace.month}</h2>
        <span className={`pace-status ${pace.status || "na"}`}>
          {STATUS_LABEL[pace.status] || "N/A"}
        </span>
      </div>

      <div className="pace-grid">
        {stats.map((s) => (
          <div key={s.label}>
            <div className="pace-value">{s.value}</div>
            {s.sub && <div className="pace-sub">{s.sub}</div>}
            <div className="kpi-label">{s.label}</div>
          </div>
        ))}
      </div>

      <div className="bar-track pace-track" title={`${progress.toFixed(1)}% of target so far`}>
        <div className="bar-fill" style={{ width: `${progress}%` }} />
      </div>

      {notes.map((n) => (
        <p className="muted pace-note" key={n}>
          {n}
        </p>
      ))}
    </div>
  );
}
