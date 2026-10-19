# Faelis Still Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faelis, the elf queen, exists as a selectable third character that stands/hovers, breathes, blinks and can be dragged. No special moves yet.

**Architecture:** Same recipe as Wizzy: a Python tool draws separate part PNGs on the 72x96 grid (`elf_*.png`), `Elf.swift` draws them with the shared Brain pose (a trimmed copy of `Mage.drawBody`: no constellation, dust, sentinel marks). The flower and greenery moves are separate plans, each started only after the user approves the still.

**Tech Stack:** Python 3 + Pillow (sprites), SwiftUI/Swift Testing, XcodeGen (`project.yml`, do not hand-edit `.pbxproj`).

**Spec:** `docs/superpowers/specs/2026-10-19-elf-queen-design.md`

## Global Constraints

- Work in a new worktree/branch `elf/still` off `main`. Do not touch the untracked `Tools/make_lady.py` or `previews/lady/`.
- Never launch, quit or relaunch Glitch. Build, test and `Glitch --snapshot out.png` are fine.
- Never change signing teams, provisioning or bundle IDs.
- All UI text and docs in English. Copyright/author is "ka-fa1500".
- Look (from the user): long blonde hair, flower crown, green eyes, cream dress with green accents, slim, pointed ears, noble and quiet, nothing cute, nothing dark. Green is the dominant colour.
- Sprite part names and the 72x96 grid are the same as Wizzy's (`cape, tunic, cloak, sash, thighL…, armFarUpper…, head, eyes_*`), prefix `elf_`, plus `elf_branch.png` (the blooming branch, takes the role of `mage_staff.png`) and `elf_shadow.png`.
- No sentinel reactions, no moves, no sound design, no menu-bar icon (it keeps the default one) in this plan.

## Review Focus

- Entrance and farewell must not show blood, black hole or star rain (those are Vorn's and Wizzy's). Expected: a plain fade-in/out.
- Knight sounds (`.clang`, `.scrape`, `.swish`) must stay silent for Faelis, as they are for Wizzy.
- Clicks must hit only Faelis herself (hair, dress, branch), not the transparent area.
- Switching Vorn → Faelis → Wizzy → Faelis in the picker must not crash (missing sprite = `fatalError`).
- Reset in Customize must leave the chosen character alone (existing rule; keep it).

---

### Task 1: Faelis sprites and the still preview

**Files:**
- Create: `Tools/make_elf.py`, `Glitch/Sprites/elf_*.png` (generated), `previews/elf/still.png` (generated)
- Reference only: `Tools/make_mage.py` (copy its `rgb`, `tl`, `disc`, `Layer`, `combine` helpers and the `__main__` preview block; do not import from it)

**Interfaces:**
- Produces: PNGs in `Glitch/Sprites/` named `elf_<part>.png`, each 72x96 RGBA, for every part in the list below, and `elf_eyes_{open,closed,half,happy,angry,wide}.png`. Task 2 loads them through `SpriteSet(prefix: "elf_")`, so **all** names `SpriteSet` reads must exist, including `thighL/shinL/footL/thighR/shinR/footR/sash/pauldronFar/pauldronNear`; the ones Faelis does not use (legs hidden under the dress, no pauldrons) are fully transparent images.
- Also produces: `elf_branch.png`, `elf_shadow.png`.

- [ ] **Step 1: Write the failing check.** At the bottom of `make_elf.py`, a `check()` function (run by `python3 Tools/make_elf.py --check`) that opens every expected PNG and asserts: size == (72, 96), mode RGBA, and for the visible parts (`cape, tunic, cloak, head, armFarUpper, armFarFore, armNearUpper, armNearFore, branch, eyes_open`) at least one non-transparent pixel. Also asserts the head has at least 20 pixels where green dominates (flower-crown leaves, `g > r and g > b`), and the tunic's most common non-transparent colour is cream-ish (`r > 200, g > 190, b > 150`).
- [ ] **Step 2: Run it to see it fail.** `python3 Tools/make_elf.py --check` → fails with a missing-file error.
- [ ] **Step 3: Draw the parts.** Palette ramps (outline, shadow, base, light, highlight) for `dress` (cream), `leaf` (greens, also the accents on hem/belt/cape), `skin`, `hair` (golden blonde), `crown` (a few flower colours: white, soft pink, pale yellow, plus leaf green), `branch` (brown wood with a green sprout and tiny blossoms). Eyes are green (`EYE`), pupil dark green. Long hair falls behind the shoulders to about the waist (draw it in `cape`, the back layer, so the existing cape-row ripple moves it). The dress goes in `tunic` (rippled by rows, like Wizzy's robe) down to the ground; the green cape/shawl goes in `cloak`. Ears: pointed, on `head`, sticking out of the hair. Hand holding the branch: the far arm, same hand position as Wizzy's (`hand = (21.5, 51)` in `Mage.swift`) so the branch pivots correctly. Silhouette is slim and tall, same height class as Wizzy.
- [ ] **Step 4: Preview.** Keep the `__main__` block from `make_mage.py` (light and dark desktop, 6x) writing `previews/elf/still.png`; layer order as in Wizzy with `branch` in place of `staff`.
- [ ] **Step 5: Run and look.** `python3 Tools/make_elf.py --check` → prints OK. Run the tool without `--check`, open `previews/elf/still.png`.
- [ ] **Step 6: Stop for the user.** Send the still to the user with `SendUserFile` and wait for approval or change requests. Redraw until approved (memory rule: every look change comes from the user). Do not start Task 2 before approval.
- [ ] **Step 7: Commit** `Tools/make_elf.py`, `Glitch/Sprites/elf_*.png`, `previews/elf/still.png`: "[Elf] Faelis sprites and still preview".

### Task 2: Make Faelis selectable and drawn

**Files:**
- Create: `Glitch/Elf.swift`
- Modify: `Glitch/Prefs.swift:81-83` (character list), `Glitch/RobotView.swift:201` (dispatch to `Elf.draw`), `Glitch/Sprite.swift:79-80` (hit mask), `Glitch/SoundBank.swift:45`, `Glitch/Brain.swift` (arrival/farewell around lines 368-415)
- Test: `GlitchTests/ElfCharacterTests.swift`

**Interfaces:**
- Consumes: `elf_*.png` from Task 1; `SpriteSet(prefix:)`, `Sprite.coverage/bounds`, `Brain.Pose`.
- Produces: `enum Elf { static let id = "elf"; static var isSelected: Bool; static let hitMask: [Bool]; static let hitBounds: CGRect; static func draw(_ outer: inout GraphicsContext, unit: CGFloat, size: CGSize, t: Double, pose: Brain.Pose) }` (same shape as `Mage`).

- [ ] **Step 1: Write the failing test** `ElfCharacterTests` (`@MainActor @Suite(.serialized)`): `#expect(CharacterInfo.all.contains { $0.id == Elf.id && $0.name == "Faelis" && $0.available })`; `#expect(CharacterInfo.all.count == 4)` (Vorn, Wizzy, Faelis, and the locked "Character 4" with id `slot4`) and that the four ids are unique.
- [ ] **Step 2: Run it, expect FAIL.** `xcodegen && xcodebuild -scheme Glitch -destination 'platform=macOS' test 2>&1 | xcbeautify --quiet` (macOS app; the iOS destination in the global notes does not apply). Expected: compile error, `Elf` not defined.
- [ ] **Step 3: Register the character.** In `CharacterInfo.all`, add `CharacterInfo(id: Elf.id, name: "Faelis", theme: "Elf queen", available: true)` and change the locked placeholder to id `slot4`, name "Character 4". Add `Elf.swift` with `id`, `isSelected` (same preference check as `Mage.isSelected`) and the hit mask built from `[cape, tunic, cloak, armFarUpper, armFarFore, armNearUpper, armNearFore, head, branch]` shifted by `(0, -2)`.
- [ ] **Step 4: Draw.** `Elf.draw` = `Mage.draw` minus dust, constellation, shooting-star cast and all sentinel marks; keep: opacity from `pose.reveal`, vortex handling removed (no black hole), hover bob, squash, hang, cape rows (hair + cape ripple), dress rows, branch at the far hand pivoted by `pose.castAngle`-free rest angle 0, arms, cloak, head with `headRot`, eyes. In `RobotView.swift:201` add `if Elf.isSelected { return Elf.draw(...) }` before the Mage line; in `Sprite.hitMask/hitBounds` switch on the three ids.
- [ ] **Step 5: Arrival, farewell, sounds.** In `Brain.swift` around the `Mage.isSelected` checks at lines 368-415, make Faelis use a plain fade: no `beginBlackHole`, no `MageCosmos.openStarRain`, no blood effects; the pose's `reveal` goes 0→1 over about 1.2 s on arrival and 1→0 on farewell, with `farewellLength` 2.0. In `SoundBank.swift:45` also return early for Faelis on `[.clang, .scrape, .swish]`. Wherever Brain calls `teleportAt`/`beginStarGlide`/mage-only moves, guard with `Mage.isSelected` only (already the case), so Faelis walks/idles as the shared Brain does; if a code path draws legs for non-Mage characters, route Faelis through the Mage-like hover path (no legs) instead.
- [ ] **Step 6: Run tests, expect PASS.** Same command as Step 2, expect all green including existing suites.
- [ ] **Step 7: Build and look.** `xcodebuild -scheme Glitch -destination 'platform=macOS' build 2>&1 | xcbeautify --quiet`, then set `character` to `elf` (via `defaults write` on the app's domain, then `build/…/Glitch --snapshot /tmp/elf.png`, no window). Check the snapshot shows Faelis, breathing pose, no blood or stars. Send it to the user.
- [ ] **Step 8: Commit** "[Elf] Faelis is selectable and drawn" and tell the orchestrator session that a build is ready (the user installs and opens it; never launch Glitch).

---

## Self-review

- Spec coverage: look → Task 1; build approach hooks → Task 2; non-goals respected (no moves/sentinel/sound/icon). The two moves (flowers, greenery) are intentionally later plans, per the spec's "show a still first, then add moves one at a time".
- Type consistency: `Elf` mirrors `Mage` (`id`, `isSelected`, `hitMask`, `hitBounds`, `draw`); sprite prefix `elf_` everywhere.
- Review Focus lines map to Task 2 steps 3-5 (picker uniqueness test, hit mask, sounds, plain fade); the picker-switch crash risk is covered by Task 1's check that every name `SpriteSet` reads exists.
- Not verified by tests: the look itself and the entrance/farewell feel; both need the user's eyes (Task 1 step 6, Task 2 step 7).
