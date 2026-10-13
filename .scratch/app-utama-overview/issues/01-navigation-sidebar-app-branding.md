# 01: Navigation sidebar and app branding

**What to build:** Update `NavigationStore` and `RootView` sidebar navigation with complete macOS native styling: App icon badge with blue gradient, "Ultimate Mac Monitor" title, standard sidebar sections (Overview, Processes, Incidents with red badge "2", History, Settings), and selection state management.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `AppSection` enum in `NavigationStore.swift` includes `overview`, `processes`, `incidents`, `history`, `settings`, with backward-compatible aliases for legacy callers (`.dashboard`, `.investigation`)
- [ ] Sidebar renders an app header with rounded gradient icon and "Ultimate Mac Monitor" title
- [ ] Sidebar navigation list includes Overview (`house.fill`), Processes (`list.bullet`), Incidents (with red badge "2"), History (`clock`), and Settings (`gearshape`)
- [ ] Selected item displays with high-contrast active styling matching Apple HIG
- [ ] Detail view cleanly routes to the corresponding section view based on selection

## Comments
