import React, { useCallback, useEffect, useState } from "react";
import * as api from "./api.js";
import FilterBar from "./components/FilterBar.jsx";
import KpiCards from "./components/KpiCards.jsx";
import Breakdown from "./components/Breakdown.jsx";
import AddSaleForm from "./components/AddSaleForm.jsx";
import SalesTable from "./components/SalesTable.jsx";
import PaceCard from "./components/PaceCard.jsx";
import TargetEditor from "./components/TargetEditor.jsx";
import { currentMonthMYT } from "./dates.js";

export default function App() {
  const [filters, setFilters] = useState({ month: currentMonthMYT(), category: "", channel: "" });
  const [options, setOptions] = useState({ categories: [], channels: [], months: [] });
  const [summary, setSummary] = useState(null);
  const [sales, setSales] = useState([]);
  const [pace, setPace] = useState(null);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const [s, list, p] = await Promise.all([
        api.getSummary(filters),
        api.getSales(filters),
        // Pace is per month and store-wide; nothing to show for "All months".
        filters.month ? api.getPace(filters.month) : null,
      ]);
      setSummary(s);
      setSales(list);
      setPace(p);
    } catch (e) {
      setError(String(e.message || e));
    }
  }, [filters]);

  useEffect(() => {
    load();
  }, [load]);

  const loadOptions = useCallback(() => api.getFilters().then(setOptions).catch(() => {}), []);

  useEffect(() => {
    loadOptions();
  }, [loadOptions]);

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
        <h1>Sales KPI Dashboard</h1>
        <p className="subtitle">Ops finance overview · all amounts in RM</p>
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
          <Breakdown title="Revenue by Channel" rows={summary.by_channel} labelKey="channel" />
        </div>
      )}

      <TargetEditor selectedMonth={filters.month} onSaved={onTargetSaved} />

      <AddSaleForm options={options} onCreated={load} />

      <SalesTable sales={sales} onDeleted={load} />
    </div>
  );
}
