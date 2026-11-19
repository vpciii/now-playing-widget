# Tasks: Now Playing desktop widget

- **Status:** In progress
- **Spec:** ./spec.md
- **Plan:** ./plan.md

Each task is one small change to `main` (a PR once the repository has a
remote). Mark tasks as you go: `[ ]` → `[~]` (in progress) → `[x]` (done).

---

## Task 1 — Scaffold the project and the snapshot model `[~]`

- **Depends on:** —
- **PR:** —

**What:** Core package with the *snapshot* model and builder, the app and
widget targets generated from `project.yml`, and a widget that renders a
*snapshot* from the shared container.

**Acceptance criteria:**
- [x] `swift test` passes in `Packages/NowPlayingCore` (11 tests)
- [x] Tests cite SC-1, SC-2, SC-4, SC-5, SC-6, SC-7, SC-8
- [x] App and widget build from the generated project
- [x] Signing situation verified and recorded (plan risk 1): ad hoc works; see plan Decisions
- [ ] Widget appears in the widget gallery in the large size only (extension is registered; gallery and placement need the owner)
- [ ] Relay notification from the sandboxed widget reaches the host app (needs a placed widget showing controls; checked in task 2)
- [x] `docs/architecture.md` written
- [x] Traceability table updated

---

## Task 2 — Show the current song from the supported route `[~]`

- **Depends on:** Task 1
- **PR:** —

**What:** The host app observes Music, reads the *current song* and
artwork, writes the *snapshot* and reloads the widget.

**Acceptance criteria:**
- [ ] Widget shows title, artist, album and artwork of the *current song* (host app writes them: verified against real Music; on-desktop rendering needs the owner to place the widget)
- [ ] "Not playing" and paused states shown (SC-7, SC-8 end to end)
- [x] Stale protection entry at `expectedEndAt` (`staleProtection` test)
- [ ] Refresh latency measured over at least 10 track changes and
      reported to the owner (spec open question). First 3 samples,
      reload request to widget timeline request: 28 ms, 11 ms, 10 ms;
      Music's notification to reload request: about 150 ms.
- [x] Tests cite SC-3

---

## Task 3 — Add the upcoming song from the queue source `[~]`

- **Depends on:** Task 2
- **PR:** —

**What:** Bundle and run the *queue source* script, parse it, fetch the
upcoming artwork, fall back to "unavailable".

**Acceptance criteria:**
- [x] Widget shows the *upcoming song* for a streamed playlist (host app published "Rippling Reveries" with artwork after "Fields of Dusk"; on-desktop look to be confirmed by the owner)
- [x] Tests cite SC-4, SC-10 (and SC-5 for each script failure mode)
- [ ] Manual matrix recorded: shuffle, local playlist, radio/Autoplay
      (spec open question)

---

## Task 4 — Overlay layout and controls `[~]`

> 2026-11-19: pulled ahead of task 3 at the owner's request (artwork
> should fill the widget and stay visible when the desktop mutes it).

- **Depends on:** Task 3
- **PR:** —

**What:** Full-artwork layout with overlaid text and scrim; skip, back
and play/pause controls through the relay.

**Acceptance criteria:**
- [x] Tests cite SC-11, SC-12, SC-13, SC-14, SC-15, SC-16, SC-17
- [ ] Each control checked against real Music
- [ ] Clicking outside the controls brings Music forward (R-13)

---

## Task 5 — Login item, menu bar item, and close-out

- **Depends on:** Task 4
- **PR:** —

**What:** Start at login, Quit from the menu bar, logging, README.

**Acceptance criteria:**
- [ ] Tests cite SC-9
- [ ] `scripts/check-traceability.sh` passes with every SC covered
- [ ] README with build, install and undo steps
- [ ] Spec open questions resolved; spec marked `Implemented`
