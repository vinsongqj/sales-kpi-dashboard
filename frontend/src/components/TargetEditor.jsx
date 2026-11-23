import React, { useEffect, useState } from "react";
import * as api from "../api.js";
import { rm } from "../format.js";
import { currentMonthMYT } from "../dates.js";

/**
 * Set or change the sales target for any month (including future months).
 * Follows the dashboard's selected month; falls back to the current MYT month
 * when "All months" is selected.
 */
export default function TargetEditor({ selectedMonth, onSaved }) {
  const [targets, setTargets] = useState({}); // { 'YYYY-MM': amount }
  const [month, setMonth] = useState(selectedMonth || currentMonthMYT());
  const [amount, setAmount] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(null);

  const loadTargets = () =>
    api
      .getTargets()
      .then((rows) => setTargets(Object.fromEntries(rows.map((t) => [t.month, t.target_amount]))))
      .catch(() => {});

  useEffect(() => {
    loadTargets();
  }, []);

  // Follow the dashboard's month filter.
  useEffect(() => {
    setMonth(selectedMonth || currentMonthMYT());
  }, [selectedMonth]);

  // Pre-fill the amount with the month's existing target (blank if none).
  useEffect(() => {
    setAmount(targets[month] != null ? String(targets[month]) : "");
  }, [month, targets]);

  // Clear any "Saved"/error message only when switching to another month.
  useEffect(() => {
    setMessage(null);
  }, [month]);

  const current = targets[month];
  const value = Number(amount);
  const valid =
    /^[1-9]\d{3}-(0[1-9]|1[0-2])$/.test(month) && amount !== "" && Number.isFinite(value) && value > 0;

  const submit = async (e) => {
    e.preventDefault();
    if (!valid) return;
    setBusy(true);
    try {
      await api.putTarget(month, value);
      await loadTargets();
      setMessage(`Saved: ${month} target is now ${rm(value)}.`);
      onSaved(month);
    } catch (err) {
      setMessage("Failed to save target: " + (err.message || err));
    } finally {
      setBusy(false);
    }
  };

  return (
    // noValidate: the browser would otherwise treat step="100" as a rule and
    // reject amounts like 12,345.67. Our own `valid` check (a number > 0)
    // gates submission instead, and the API re-checks it.
    <form className="panel add-form" onSubmit={submit} noValidate>
      <h2>Monthly Target</h2>
      <div className="form-grid">
        <label>
          Month
          <input
            type="month"
            placeholder="YYYY-MM" /* shown where type=month falls back to text, e.g. Firefox */
            value={month}
            onChange={(e) => setMonth(e.target.value)}
            required
          />
        </label>
        <label>
          Target (RM)
          <input
            type="number"
            step="100"
            min="0"
            inputMode="decimal"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="e.g. 10000"
            required
          />
        </label>
      </div>
      <p className="muted target-note">
        {current != null ? `Current target: ${rm(current)}` : "No target set for this month yet."}
      </p>
      <button type="submit" disabled={busy || !valid || value === current}>
        {busy ? "Saving…" : current != null ? "Update Target" : "Set Target"}
      </button>
      {message && <p className="muted target-note">{message}</p>}
    </form>
  );
}
