import React, { useEffect, useState } from "react";

const OPTIONS = [
  ["system", "System"],
  ["light", "Light"],
  ["dark", "Dark"],
];

// localStorage can throw (private mode, blocked storage), so every access is
// guarded and the app falls back to following the OS setting.
const readTheme = () => {
  try {
    const t = localStorage.getItem("theme");
    return t === "light" || t === "dark" ? t : "system";
  } catch {
    return "system";
  }
};

/**
 * System / Light / Dark switch. "System" follows the OS (prefers-color-scheme);
 * Light/Dark set data-theme on <html>, which styles.css keys its colours on.
 * index.html applies a saved choice before first paint to avoid a flash.
 */
export default function ThemeToggle() {
  const [theme, setTheme] = useState(readTheme);

  useEffect(() => {
    const root = document.documentElement;
    if (theme === "system") delete root.dataset.theme;
    else root.dataset.theme = theme;
    try {
      if (theme === "system") localStorage.removeItem("theme");
      else localStorage.setItem("theme", theme);
    } catch {
      /* not persisted; still applied for this visit */
    }
  }, [theme]);

  return (
    <div className="theme-toggle" role="group" aria-label="Colour theme">
      {OPTIONS.map(([value, label]) => (
        <button
          key={value}
          type="button"
          className={theme === value ? "active" : ""}
          aria-pressed={theme === value}
          onClick={() => setTheme(value)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
