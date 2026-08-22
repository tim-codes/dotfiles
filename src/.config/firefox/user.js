// Firefox preferences, codified.
//
// Symlinked into each installation's active profile by scripts/firefox-prefs.
// Firefox applies user.js on every startup, so anything set here is authoritative:
// changing it in about:config will hold for the session and be reset on restart.
// To change a pref for good, change it HERE, not in about:config.

// Pinned tabs are restored EAGERLY by default (unlike normal tabs, which are
// lazy via browser.sessionstore.restore_on_demand=true). A pinned heavy SPA
// therefore starts executing its JS at every launch before you touch it —
// observed 2026-08-22 with a pinned GanttPRO pinning a full core for ~1 min
// after every browser start. Make pinned tabs lazy like everything else.
user_pref("browser.sessionstore.restore_pinned_tabs_on_demand", true);

// Already the Firefox default (firefox.js:365) — pinned here so the intent is
// explicit and survives an upstream default change, given this machine runs
// with heavy long-lived tabs and has hit swap exhaustion.
user_pref("browser.tabs.unloadOnLowMemory", true);

// Idle time before an inactive tab is eligible for unloading. Firefox default
// is 600000 (10 min). Uncomment to unload more aggressively.
// user_pref("browser.tabs.min_inactive_duration_before_unload", 300000);

// Deliberately NOT set: dom.ipc.processCount. Under Fission, process count is
// managed per-origin for site isolation; capping it trades away a security
// boundary for memory, which is the wrong trade on this machine.
