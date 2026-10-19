# Elf Queen: design (draft, awaiting approval)

Character: **Faelis**, a light, nature-themed elf queen (name chosen by the user, 2026-10-19). Approved by the user 2026-10-19; the "lady" draft is a separate character and stays untouched.

## Why
A third character that is the opposite of Vorn's gothic mood: bright, green, calm. The user wants no dark look and nothing cute or distracting (see memory: ask-before-design).

## Look (all from the user unless marked "my call")
- Female elf queen, long blonde hair.
- Crown woven from flowers (a few green leaves beside them: my call).
- Green eyes.
- Cream dress with green accents: hem, belt, cape (where the green goes: my call).
- Slim, tall, pointed ears, noble and quiet, not chubby (my call, from Wizzy's "keep it fit" feedback).
- Fairy-like, with two pairs of sheer green-tinted wings behind her; no tall staff; a small wand with a blossom tip in her far hand (user, 2026-10-19).
- Green is the dominant colour of the whole figure and its effects.

## Moves
1. Scatters flowers around her. They bloom briefly, then fade.
2. Grows greenery on the ground around her: grass, sprouts, leaves.
Everything else (breathing, blinking, drag, gravity, hover or walk) comes from the shared Brain, as it does for Wizzy.
Which trigger plays which move (click, idle timer, sentinel events) is not decided: my proposal is click = flowers, idle every ~70 s = greenery.

## Non-goals
- No new views (3/4 only, see glitch-character-spec).
- No Claude Code sentinel reactions in v1 (Wizzy's rune, crystal ball and feast). Add later, each reaction approved first.
- No sound design in v1 beyond reusing existing effects.

## Build approach (my call, mirrors Wizzy)
- Sprites: new `Tools/make_elf.py` on the 72x96 grid and Layer shading used by `make_mage.py`; separate part PNGs `elf_*.png`.
- Drawing: new `Glitch/Elf.swift` (like `Mage.swift`) and `ElfNature.swift` for flower and grass effects (like `MageCosmos.swift`).
- Hooks: a new `id` in the `CharacterInfo` list in `Prefs.swift` (fills the "Character 3" slot), `isSelected` branches in `Brain.swift`, menu-bar icon in `GlitchApp.swift`.
- Process: show a still snapshot for approval first, then add moves one at a time.

## Open points
- Untracked `Tools/make_lady.py` and `previews/lady/` belong to a separate character: do not touch.
- Build in a new worktree/branch (`elf/still`), since main has unrelated untracked files.
