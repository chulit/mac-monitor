# 08: Engine integration, verification, and polish pass

**What to build:** Integrate live metrics, samples, process deltas, and incidents from `EngineController` into the Overview screen, test state transitions, verify dark and light mode appearance, and ensure clean compilation and test verification.

**Blocked by:** 05, 07.

**Status:** ready-for-agent

- [ ] Overview screen correctly updates with live readings from `EngineController` without unnecessary view re-renders
- [ ] Toggling "Start Investigation" triggers real high-detail sampling via `pipeline.requestHighDetail`
- [ ] View smoothly transitions between normal monitoring mode (`a. overview.png`) and high-detail investigation mode (`b. overview - start-investigating.png`)
- [ ] Dynamic colors adapt seamlessly between macOS Light and Dark appearances
- [ ] Full project builds cleanly with `swift build` and passes unit tests

## Comments
