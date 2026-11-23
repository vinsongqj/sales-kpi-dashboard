import React, { useCallback, useEffect, useRef, useState } from "react";
import * as api from "./api.js";
import FilterBar from "./components/FilterBar.jsx";
import KpiCards from "./components/KpiCards.jsx";
import Breakdown from "./components/Breakdown.jsx";
import AddSaleForm from "./components/AddSaleForm.jsx";
import SalesTable from "./components/SalesTable.jsx";
import PaceCard from "./components/PaceCard.jsx";
import TargetEditor from "./components/TargetEditor.jsx";
import ThemeToggle from "./components/ThemeToggle.jsx";
import { currentMonthMYT } from "./dates.js";
import { channelLabel } from "./format.js";

export default function App() {
  const [filters, setFilters] = useState({ month: currentMonthMYT(), category: "", channel: "" });
  const [options, setOptions] = useState({ categories: [], channels: [], months: [] });
  const [summary, setSummary] = useState(null);
  const [sales, setSales] = useState([]);
  const [pace, setPace] = useState(null);
  const [error, setError] = useState(null);
  // Each load gets a number; only the latest one may update the screen, so a
  // slow reply for a previous month can't overwrite the current month's data.
  const latestLoad = useRef(0);

  const load = useCallback(async () => {
    const id = ++latestLoad.current;
    try {
      setError(null);
      const [s, list, p] = await Promise.all([
        api.getSummary(filters),
        api.getSales(filters),
        // Pace is per month and store-wide; nothing to show for "All months".
        filters.month ? api.getPace(filters.month) : null,
      ]);
      if (id !== latestLoad.current) return; // a newer load has started
      setSummary(s);
      setSales(list);
      setPace(p);
    } catch (e) {
      if (id === latestLoad.current) setError(String(e.message || e));
    }
  }, [filters]);

  useEffect(() => {
    load();
  }, [load]);

  const loadOptions = useCallback(() => api.getFilters().then(setOptions).catch(() => {}), []);

  useEffect(() => {
    loadOptions();
  }, [loadOptions]);

  // After a sale is added or deleted: reload the numbers, and the filter
  // options too, since a new category or month may have appeared (or the last
  // sale of one may have gone).
  const onSalesChanged = () => {
    load();
    loadOptions();
  };

  // After a target is saved: refresh the month list (a new future month may
  // now be selectable) and show that month so the change is visible at once.
  const onTargetSaved = async (month) => {
    await loadOptions();
    if (month === filters.month) load();
    else setFilters((f) => ({ ...f, month }));
  };

  return (
    <div className="app">
      <header className="app-header">
        <div>
          <h1>Sales KPI Dashboard</h1>
          <p className="subtitle">Ops finance overview · all amounts in RM</p>
        </div>
        <ThemeToggle />
      </header>

      {error && <div className="error">API error: {error}</div>}

      <FilterBar filters={filters} options={options} onChange={setFilters} />

      {summary && <KpiCards summary={summary} />}

      <PaceCard
        pace={pace}
        month={filters.month}
        filtered={Boolean(filters.category || filters.channel)}
      />

      {summary && (
        <div className="grid-2">
          <Breakdown title="Revenue by Category" rows={summary.by_category} labelKey="category" />
          <Breakdown
            title="Revenue by Channel"
            rows={summary.by_channel}
            labelKey="channel"
            formatLabel={channelLabel}
          />
        </div>
      )}

      <TargetEditor selectedMonth={filters.month} onSaved={onTargetSaved} />

      <AddSaleForm options={options} onCreated={onSalesChanged} />

      <SalesTable sales={sales} onDeleted={onSalesChanged} />
    </div>
  );
}
