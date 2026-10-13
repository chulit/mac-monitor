# 02: Processes table with tree hierarchy toggle

**What to build:** The main process table with "Show Process Tree" toggle, column headers, row rendering with app icons, expandable parent-child rows, CPU progress bars, and footer counter.

**Blocked by:** 01 (header & summary foundation).

**Status:** ready-for-agent

- [ ] "Show Process Tree" toggle switch switching between flat list and parent-child tree hierarchy
- [ ] Table columns: `Process`, `PID`, `CPU`, `Memory`, `Parent Process`, and actions `···`
- [ ] Process column renders app/system icon, process name, and expandable disclosure chevron for parent processes
- [ ] CPU column renders exact percentage (e.g. 24.3%) and proportional horizontal blue progress bar
- [ ] Clicking any row selects and navigates to the Process Detail screen
- [ ] Footer counter showing total processes count and live update status (e.g. "184 processes · Updated just now")

## Comments
