# Claude Code Nöbetçisi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Glitch watches every Claude Code session on the Mac through global hooks and shows "permission / question / finished / error" with new knight moves and red/gold shoulder sparks.

**Architecture:** A tiny shell hook (installed into `~/.claude/settings.json` with the user's consent) drops each hook payload as its own JSON file into a spool folder. Glitch watches that folder, turns payloads into `SentinelEvent`s, and a pure `SessionStore` decides priority, sparks and click target. `Brain` gets a small sentinel API with four new moves; `RobotView` draws the sparks.

**Tech Stack:** Swift 6, SwiftUI + AppKit, macOS 15, XcodeGen, Swift Testing, POSIX sh.

**Spec:** `docs/superpowers/specs/2026-10-17-claude-code-nobetci-design.md`

## Who does what

| Owner | Tasks | Files they own |
|---|---|---|
| **Main** | 0, 1, 2, 3, 4, 5, 7, 8 | `Glitch/Sentinel/*`, `GlitchTests/*`, `GlitchApp.swift`, `project.yml`, `Tools/glitch-hook.sh` |
| **Animations** | 6 | `Brain.swift`, `RobotView.swift`, `SoundBank.swift` |

Task 6 can start right after Task 0 and runs in parallel with 1–5. Task 7 needs 2 and 6. Task 8 is last. Neither session edits the other's files; the only shared surface is the Brain API in Task 6's Interfaces block.

## Global Constraints

- Hooks go to the **global** `~/.claude/settings.json`; existing hooks and settings are never removed or overwritten; there is an uninstall.
- Before installing hooks, show the user exactly what will be added and get consent.
- Event data never leaves the Mac. No network.
- Glitch closed or crashed must never slow down or break Claude Code (hook always exits 0, fast).
- One 3/4 rig only, no new views. Every new move is new: it must not look like salute, kneel, stances, Ochs/Pflug/Vom Tag, landing, blood storm, or the idle random glitch flicker.
- Snapshot first, user approval, then continue, for every new move and for the sparks.
- `git status` before touching a file; commit only your own files (`git add <file>`, never `-A`), prefix `[Main]` / `[Animations]`.
- Don't hand-edit `.pbxproj`; run `xcodegen` after `project.yml` changes. Don't touch signing/bundle IDs.
- Build: `xcodebuild -scheme Glitch -destination 'platform=macOS' -derivedDataPath build build 2>&1 | xcbeautify --quiet`. Test: same with `test`.
- Priorities: permission (1) > question (2) > error (3) > finished (4). Red spark = permission/question, gold spark = finished, error = no spark, red ✕ in the list.
- Permission reminder: once, after 5 minutes unanswered.
- "Question" = Claude explicitly asked (e.g. AskUserQuestion). A normal end of turn = "finished".
- "Error" = only session-stopping failures (API error, crash), never ordinary tool failures.

## Review Focus

1. **Stale events from when Glitch was closed** → on launch Glitch deletes the spool and starts empty; no ghost sparks from yesterday. (Task 3 test)
2. **A session that dies without an end event** (app force-quit) → its entry is dropped after 24 h without events, so sparks can't pile up forever. *(Plan call; the spec's "no timeout" refers to gold sparks of live sessions.)* (Task 2 test)
3. **Parallel sessions writing at the same time / half-written or malformed payloads** → one file per event written via temp + rename; bad files are skipped and deleted, never crash. (Task 1 + Task 3 tests)
4. **`settings.json` missing, empty, invalid JSON, or already containing user hooks** → missing/empty is created/filled; invalid JSON refuses with a message and changes nothing; user hooks stay byte-for-byte in place; installing twice doesn't duplicate. (Task 4 tests)
5. **Turning a project's filter off while it has sparks** → its sparks vanish at once and come back when turned on; events keep being recorded meanwhile. (Task 2 test)

---

### Task 0: Verify the hook assumptions (Main, needs the user)

**Files:**
- Create: `GlitchTests/Fixtures/*.json` (captured real payloads, secrets/paths you consider private trimmed)
- Modify: spec, append a `## Bulgular (Task 0)` section

- [ ] **Step 1:** Show the user the temporary logging hook you want to add to `~/.claude/settings.json` (every hook event → `cat > /tmp/glitch-probe/$(date +%s).$$.json`) and **wait for consent**. Back up the file first (`settings.json.glitch-backup`).
- [ ] **Step 2:** Ask the user to: (a) run a short task in a Claude **desktop** Code session, (b) trigger a permission prompt, (c) trigger an AskUserQuestion, (d) let a turn finish, (e) do the same in a terminal `claude` session.
- [ ] **Step 3:** From the captured files answer the spec's four assumptions and write them in the spec: which `hook_event_name` (and which fields, e.g. `notification_type`, `message`, `tool_name`) map to permission / question / finished / error / user-acted / ended; whether desktop sessions fire hooks; whether a session's desktop `local_…` id or title can be derived; how to bring that session forward.
- [ ] **Step 4:** Remove the probe hook (restore from backup, diff to confirm identical). Save 1 payload per event type as fixtures.
- [ ] **Step 5:** If an assumption fails (e.g. desktop sessions don't fire hooks), **stop and tell the user** before continuing. Otherwise commit fixtures + spec: `[Main] Hook probe findings`.

---

### Task 1: Test target + event parsing (Main)

**Files:**
- Modify: `project.yml` (add `GlitchTests` target: `type: bundle.unit-test`, `platform: macOS`, `sources: [GlitchTests]`, `dependencies: [{target: Glitch}]`; add `scheme: {testTargets: [GlitchTests]}` to the `Glitch` target)
- Create: `Glitch/Sentinel/SentinelEvent.swift`
- Test: `GlitchTests/SentinelEventTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct SentinelEvent: Equatable, Sendable {
      enum Kind: Equatable, Sendable { case permission, question, finished, error, userActed, ended }
      let sessionID: String
      let cwd: String
      let kind: Kind
      let date: Date
      static func parse(_ data: Data, date: Date) -> SentinelEvent?   // nil = ignore (unknown event, ordinary tool error, malformed)
  }
  ```

- [ ] **Step 1: Write failing tests**, one per fixture from Task 0: `parsesPermission`, `parsesQuestion`, `parsesFinished`, `parsesError`, `parsesUserActed`, `parsesEnded` — each `#expect(SentinelEvent.parse(fixture, date: d)?.kind == .X)` and checks `sessionID`/`cwd` equal the fixture's. Plus `ignoresOrdinaryToolFailure`, `ignoresUnknownEvent`, `ignoresMalformedJSON` (`Data("{\"hook_event".utf8)`), `ignoresMissingSessionID` → all `nil`.
- [ ] **Step 2:** `xcodegen && xcodebuild … test` → FAIL (type missing).
- [ ] **Step 3:** Implement `parse` with `JSONSerialization`, using the mapping written in the spec in Task 0.
- [ ] **Step 4:** Run tests → PASS. Build app → succeeds.
- [ ] **Step 5:** Commit `project.yml GlitchTests/SentinelEventTests.swift Glitch/Sentinel/SentinelEvent.swift`: `[Main] Sentinel event parsing + test target`.

---

### Task 2: SessionStore (Main)

**Files:**
- Create: `Glitch/Sentinel/SessionStore.swift`
- Test: `GlitchTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `SentinelEvent` (Task 1)
- Produces:
  ```swift
  enum SessionState: Int, Comparable, Sendable { case permission = 1, question, error, finished }  // lower = more urgent
  struct SessionStatus: Equatable, Sendable { let id: String; let cwd: String; let state: SessionState; let since: Date }
  @MainActor final class SessionStore {
      var isIncluded: (String) -> Bool = { _ in true }       // cwd -> project filter
      var onChange: (() -> Void)?
      func apply(_ event: SentinelEvent)
      func markOpened(_ id: String)                          // clears finished/error for that session
      func expire(now: Date)                                 // drops sessions with no event for 24 h
      func refilter()                                        // call after the filter changes
      var visible: [SessionStatus] { get }                   // filtered, sorted: state, then oldest since
      var mostUrgent: SessionStatus? { get }                 // visible.first
      var redSparks: Int { get }                             // permission + question
      var goldSparks: Int { get }                            // finished
      func reminderDue(now: Date) -> [String]                // permission ids unanswered ≥ 300 s, each returned once
  }
  ```

- [ ] **Step 1: Write failing tests:**
  - `permissionBeatsQuestionBeatsFinished`: apply finished(A), question(B), permission(C) → `visible.map(\.id) == ["C","B","A"]`, `redSparks == 2`, `goldSparks == 1`.
  - `samePriorityOldestFirst`: two permissions at t0, t1 → older first.
  - `userActedClearsSpark`: permission(A) then userActed(A) → `visible.isEmpty`.
  - `markOpenedClearsGold`: finished(A), `markOpened("A")` → empty.
  - `endedRemovesSession`.
  - `errorHasNoSparkButIsListed`: error(A) → `visible.count == 1`, `redSparks == 0`, `goldSparks == 0`.
  - `deadSessionExpiresAfter24h`: finished at t0, `expire(now: t0+86_401)` → empty; `expire(now: t0+86_399)` → still there.
  - `filterHidesAndRestores`: `isIncluded = { $0 != "/x" }`, events in `/x` and `/y`, `refilter()` → only `/y`; set to all, `refilter()` → both.
  - `reminderOnceAfterFiveMinutes`: permission at t0 → `reminderDue(t0+299) == []`, `reminderDue(t0+300) == ["A"]`, `reminderDue(t0+400) == []`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement with a `[String: SessionStatus]` plus last-event dates; call `onChange` after every mutation.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit: `[Main] Sentinel session store`.

---

### Task 3: Hook script + spool feed (Main)

**Files:**
- Create: `Tools/glitch-hook.sh` (copied into the app bundle as a resource; add `Tools/glitch-hook.sh` under the Glitch target's `sources` with `buildPhase: resources` in `project.yml`)
- Create: `Glitch/Sentinel/EventFeed.swift`
- Test: `GlitchTests/EventFeedTests.swift`

**Interfaces:**
- Consumes: `SentinelEvent.parse`, `SessionStore.apply`
- Produces:
  ```swift
  @MainActor final class EventFeed {
      static let defaultSpool: URL   // ~/Library/Application Support/Glitch/events
      init(spool: URL, store: SessionStore)
      func start()                   // empties the spool, then watches it (DispatchSource on the folder)
      func drain()                   // reads *.json oldest first, applies, deletes each (bad files deleted too)
      func stop()
  }
  ```

- [ ] **Step 1: The hook script** (exact; the temp+rename keeps readers from seeing half files, `|| true` keeps Claude unaffected):
  ```sh
  #!/bin/sh
  d="$HOME/Library/Application Support/Glitch/events"
  mkdir -p "$d" 2>/dev/null
  f="$d/$(date +%s).$$"
  cat > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f.json" 2>/dev/null
  exit 0
  ```
- [ ] **Step 2: Write failing tests** (temp spool dir):
  - `startClearsOldFiles`: put 3 files in spool, `start()` → spool empty, store empty.
  - `drainAppliesInOrderAndDeletes`: write permission(A) then userActed(A) files with increasing names, `drain()` → store empty, spool empty.
  - `badFileSkippedAndDeleted`: one garbage file + one valid → store has 1, spool empty.
  - `ignoresTmpFiles`: a `*.tmp` file stays untouched.
  - `hookScriptWritesOneFile`: run `/bin/sh Tools/glitch-hook.sh` with `HOME` set to a temp dir and stdin `{"x":1}` → exactly one `*.json` with that content, exit status 0; with an unwritable HOME → exit status 0.
- [ ] **Step 3:** Run → FAIL. **Step 4:** Implement. **Step 5:** Run → PASS.
- [ ] **Step 6:** Commit: `[Main] Hook script and spool feed`.

---

### Task 4: Hook installer with consent (Main)

**Files:**
- Create: `Glitch/Sentinel/HookInstaller.swift`
- Modify: `Glitch/GlitchApp.swift` (menu item, see Step 6)
- Test: `GlitchTests/HookInstallerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum HookInstaller {
      enum Failure: Error, Equatable { case invalidJSON }
      static let events: [String]                         // exactly the hook events Task 0 found necessary
      static func merged(settings: Data?, scriptPath: String) throws -> Data   // adds ours, keeps everything else
      static func removed(settings: Data, scriptPath: String) throws -> Data   // removes only entries whose command == scriptPath
      static func isInstalled(settings: Data?, scriptPath: String) -> Bool
      static func preview(scriptPath: String) -> String    // human-readable list shown in the consent alert
  }
  ```
  Our entry per event: `{"hooks":[{"type":"command","command":"<scriptPath>"}]}` appended to that event's array. `scriptPath` = `~/Library/Application Support/Glitch/glitch-hook.sh` (installer copies the bundled script there, `chmod 755`).

- [ ] **Step 1: Write failing tests:** `mergeIntoNil`, `mergeIntoEmptyObject`, `mergeKeepsUserHooks` (fixture with a user `PreToolUse` hook + `"model"` key → both still present and unchanged after merge), `mergeTwiceNoDuplicates`, `invalidJSONThrows` (`#expect(throws: HookInstaller.Failure.invalidJSON)`), `removeLeavesUserHooks` (after merge+remove the parsed object equals the original), `isInstalledTrueAfterMerge`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement with `JSONSerialization` (`.prettyPrinted`, `.sortedKeys` off). **Step 4:** Run → PASS.
- [ ] **Step 5:** Writing to disk: back up to `settings.json.glitch-backup` first, write atomically.
- [ ] **Step 6:** Menu item in `MenuBarExtra`: `"Claude Code nöbetçisi: Kur…"` / `"Claude Code nöbetçisi: Kaldır"`. "Kur…" opens an `NSAlert` whose informative text is `preview(...)` with buttons `"Kur"` / `"Vazgeç"`; invalid JSON shows `"settings.json okunamadı, hiçbir şey değiştirilmedi."`.
- [ ] **Step 7:** Build → succeeds. Commit: `[Main] Hook installer with consent`.

---

### Task 5: Project names + filter menu (Main)

**Files:**
- Create: `Glitch/Sentinel/ProjectMap.swift`
- Modify: `Glitch/GlitchApp.swift` (submenu)
- Test: `GlitchTests/ProjectMapTests.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor final class ProjectMap {
      init(defaults: UserDefaults = .standard)
      func name(for cwd: String) -> String            // user override, else last path component ("PET", "Obsidian Vault")
      func rename(_ cwd: String, to name: String)
      func isIncluded(_ cwd: String) -> Bool          // default true
      func setIncluded(_ cwd: String, _ on: Bool)
      var known: [String] { get }                     // cwds seen so far, persisted
      func noteSeen(_ cwd: String)
  }
  ```
  Subdirectories map to the nearest known/project root is **not** needed; match on exact cwd.

- [ ] **Step 1: Tests** (`UserDefaults(suiteName: UUID().uuidString)!`): `defaultNameIsLastComponent` (`"/Users/x/Documents/PET"` → `"PET"`), `renameOverrides`, `includedByDefault`, `exclusionPersists` (new `ProjectMap` on same defaults keeps it), `knownPersists`.
- [ ] **Step 2–4:** FAIL → implement → PASS.
- [ ] **Step 5:** Submenu `"İzlenen projeler"` with one toggle per `known` cwd (label = `name(for:)`); toggling calls `setIncluded` then `store.refilter()`.
- [ ] **Step 6:** Commit: `[Main] Project names and filter`.

---

### Task 6: Sentinel moves, sparks and sounds (Animations)

**Files:**
- Modify: `Glitch/Brain.swift`, `Glitch/RobotView.swift`, `Glitch/SoundBank.swift`, `Glitch/GlitchApp.swift` **only** the snapshot `mood` switch (coordinate with Main via `git status`; it's a few lines)

**Interfaces:**
- Produces (Main calls exactly these from Task 7):
  ```swift
  extension Brain {
      enum SentinelHold: Equatable { case none, barrier, attend }   // barrier = permission, attend = question
      func setSentinel(hold: SentinelHold, redSparks: Int, goldSparks: Int, at now: Double = CACurrentMediaTime())
      func playFinished(at now: Double = CACurrentMediaTime())       // flick + scrape, ~2 s, ends with one gold spark flying to the shoulder
      func playError(at now: Double = CACurrentMediaTime())          // sword slips and is caught, one-shot
      func remindPermission(at now: Double = CACurrentMediaTime())   // small sword shake + clang, once
  }
  ```
  New `Pose` fields: `redSparks: Int`, `goldSparks: Int`, `scrapeAge: Double` (< 0 = none, drives the scrape spark burst).
  New `SoundEffect` cases: `.clang` (barrier raise + reminder), `.scrape` (metal on stone). The flick reuses `.swish`.
  Snapshot moods: `barrier`, `attend`, `flick`, `scrape`, `fumble`, `sparks` (2 red + 1 gold).

- [ ] **Step 1: Barrier (held):** sword horizontal at chest height, eyes flare once with `.clang` on raise; while `hold == .barrier` the scheduler runs no idle actions, stance changes, guards or wandering (blink stays). Snapshot `barrier` → **show user, wait for approval.**
- [ ] **Step 2: Attend (held):** head turned toward the viewer, near hand on the hilt; same idle suspension. Snapshot `attend` → **approval.**
- [ ] **Step 3: Finished one-shot:** 0.8 s blood flick (blood ribbon allowed: it's a swing) with `.swish`, then ~1.0 s scrape along the ground with `.scrape` and a gold spark burst (`scrapeAge`); most sparks die, one rises to the shoulder. Snapshots `flick`, `scrape` → **approval.**
- [ ] **Step 4: Error one-shot:** sword slips from the hand and is caught back; must not look like the idle `.glitch` flicker. Snapshot `fumble` → **approval.**
- [ ] **Step 5: Sparks:** `RobotView` draws `redSparks` crimson and `goldSparks` gold pixel sparks floating by the near shoulder (start from the mockup: 8 px, gentle float, staggered); palette colours only. Snapshot `sparks` → **approval.**
- [ ] **Step 6: Reminder:** `remindPermission` = one short sword shake + `.clang`, only valid during `barrier`.
- [ ] **Step 7:** Build → succeeds; run the app and watch idle behaviour is unchanged when `hold == .none` and sparks are 0.
- [ ] **Step 8:** Commit each approved move separately: `[Animations] Sentinel barrier pose`, etc.

---

### Task 7: Wiring, hover list and click (Main)

**Files:**
- Create: `Glitch/Sentinel/SentinelController.swift`, `Glitch/Sentinel/SessionListPanel.swift`
- Modify: `Glitch/GlitchApp.swift` (create controller in `applicationDidFinishLaunching`, hover in `handle(_:)`/mouse-moved, click routing)

**Interfaces:**
- Consumes: `SessionStore`, `EventFeed`, `ProjectMap`, Brain API from Task 6.
- Produces:
  ```swift
  @MainActor final class SentinelController {
      init(brain: Brain, store: SessionStore, feed: EventFeed, projects: ProjectMap)
      func start()                         // feed.start(); 1 s timer: expire + reminders
      func handleClick() -> Bool           // true = consumed (opened mostUrgent); false = let Brain.clicked() run
      func hover(_ inside: Bool, near frame: CGRect)
  }
  ```

- [ ] **Step 1:** On `store.onChange`: hold = `.barrier` if any visible permission, else `.attend` if any question, else `.none`; call `setSentinel`. On a newly applied `finished` event call `playFinished`, on `error` call `playError` (only for included projects). Each reminder id → `remindPermission`. New cwds → `projects.noteSeen`.
- [ ] **Step 2:** `SessionListPanel`: borderless non-activating `NSPanel` beside the character, dark (`rgba(14,12,14,.92)`), thin crimson border, monospaced 11 pt, one row per `visible` status: `⚔`/`◆`/`✕` + `"\(projectName) · \(sessionTitle)"` + state text (`izin bekliyor`, `cevap bekliyor`, `bitti`, `hata`) + age (`2 dk`). Last row `— tıkla: <title> açılır`. `sessionTitle` = the title source Task 0 found; if none, the first 6 characters of the session id. Shown only while the mouse is over character pixels (reuse `isOverCharacter`) **and** `visible` is non-empty.
- [ ] **Step 3:** Click: if `mostUrgent != nil`, open it the way Task 0 found (desktop link or bring app/terminal forward), call `store.markOpened(id)`, return `true`. Else return `false` and the existing `brain.clicked()` runs. Drag and double-click "✕ Kapat" unchanged.
- [ ] **Step 4:** Build. Manually feed spool files (copy fixtures into the spool) and check: barrier + 1 red spark; add a finished → flick/scrape plays, 1 gold spark; hover shows 2 rows; click opens permission session first.
- [ ] **Step 5:** Commit: `[Main] Sentinel wiring, list and click`.

---

### Task 8: End-to-end with real sessions (Main + user)

- [ ] **Step 1:** Install hooks from the menu (user consents). Ask the user to run three real sessions (one desktop permission, one AskUserQuestion, one plain finish).
- [ ] **Step 2:** Screenshot each state; confirm priorities, spark counts and colours, hover text, click target, reminder after 5 min, filter on/off, quit Glitch → Claude Code still works, relaunch → no ghost sparks.
- [ ] **Step 3:** Uninstall from the menu → `settings.json` equals the backup apart from formatting.
- [ ] **Step 4:** Report results (with any failures) to the user. Commit any fixes with `[Main]`.
