# Wizzy sentinel reactions: plan (not started)

The task comes from the orchestrator. The user picked these reactions: rune (permission), crystal ball (question), staff spell + star feast + sweet chime (finished), spell misfire (error).

## Brain (keep the API: setSentinel / playFinished / playError / remindPermission)
- New Pose fields: `rune`, `orb`, `feast`, `misfire`, `nudge` (seconds since start, < 0 = none).
- For the mage:
  - `playFinished` sets feastStart and plays `.chime`. Do not call `start(.finished)`.
  - `playError` sets misfireStart and plays `.fizzle`.
  - `remindPermission` sets remindStart and plays `.nudge`.
  - `setSentinel` plays no `.clang` (optional `.rune` / `.orb` cue).
- `schedule`: `idle = sentinelHold == .none || Mage.isSelected`, so the hold doesn't freeze the mage.
- The `arriving` gold spark count must also cover the feast.
- Expose `actionKind` and `idleLifeRuns` for the tests.

## Mage.draw
- Rune: red glyph in front at about x 4..14, y 32..44 (the mage faces left); eyes look at it (eyeDX -2).
- Orb: small glow above the near hand at about (44, 50).
- Feast: staff raised, stars burst from the tip (tip = Constellation.tip turned about hand (21.5, 51)).
- Misfire: staff jerks, grey puff, a few red sparks, shakeX flinch.
- Red/gold counts: tiny stars in an arc above the staff star.

## Sound
- SoundBank: new effects `.chime` (soft C6-E6-G6-C7 arpeggio), `.nudge`, `.rune`, `.orb`, `.fizzle`.
- In `play`, drop `.clang` / `.scrape` / `.swish` when `Mage.isSelected`.
- Prefs: new SoundGroup "Wizzy's spells" for the new effects.

## Tests (write first)
- GlitchTests compile the app sources minus GlitchApp.swift and SentinelController.swift (project.yml).
- Use a `.serialized` suite: set Prefs character to mage, then glitch.
- Mage hold → idleLifeRuns.
- Mage finished/error → no action, no knight sounds.
- Glitch finished → `.finished` action.

## Then
Snapshot each move (add `--snapshot` moods), get the user's approval, merge, tell the orchestrator.
