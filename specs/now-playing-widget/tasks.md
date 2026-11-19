# Tasks: Now Playing desktop widget

- **Status:** In progress
- **Spec:** ./spec.md
- **Plan:** ./plan.md

Each task is one small change to `main` (a PR once the repository has a
remote). Mark tasks as you go: `[ ]` → `[~]` (in progress) → `[x]` (done).

---

## Task 1 — Scaffold the project and the snapshot model `[x]`

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
- [x] Widget appears in the widget gallery in the large size only (owner added it, 2026-11-19)
- [x] Relay notification from the sandboxed widget reaches the host app (logged `relayed command: back / next / playpause`, 2026-11-19)
- [x] `docs/architecture.md` written
- [x] Traceability table updated

---

## Task 2 — Show the current song from the supported route `[~]`

- **Depends on:** Task 1
- **PR:** —

**What:** The host app observes Music, reads the *current song* and
artwork, writes the *snapshot* and reloads the widget.

**Acceptance criteria:**
- [x] Widget shows title, artist, album and artwork of the *current song* (owner confirmed on the desktop, 2026-11-19)
- [ ] "Not playing" and paused states shown (SC-7, SC-8 end to end): paused published and reloaded; "not playing" not yet seen on the desktop
- [x] Stale protection entry at `expectedEndAt` (`staleProtection` test)
- [x] Refresh latency measured and reported to the owner (spec open
      question). 2026-11-19, 12 changes on the full build (queue lookup
      and artwork included): Music's notification to reload request
      0.35 to 0.6 s; reload request to the widget's timeline request
      about 12 ms. A button press reaches the widget in roughly 0.6 to
      0.8 s. Not measured: behaviour over a long listening day, where
      WidgetKit may start throttling reloads.
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
- [x] Each control checked against real Music (owner: back, play/pause and skip all work, 2026-11-19; each press logged once and followed by Music's notification)
- [ ] Clicking outside the controls brings Music forward (R-13)

---

## Task 5 — Login item, menu bar item, and close-out `[~]`

- **Depends on:** Task 4
- **PR:** —

**What:** Start at login, Quit from the menu bar, logging, README.

**Acceptance criteria:**
- [x] Tests cite SC-9 (installed copy logged `login item: registeredNow=true enabled=true`, 2026-11-19; not yet tested across a real logout and login)
- [x] `scripts/check-traceability.sh` passes with every SC covered
- [x] README with build, install and undo steps
- [ ] Spec open questions resolved; spec marked `Implemented` (open: queue correctness under shuffle, local playlists and radio)
