# Changelog

## 1.0.0 — Release (Phase 5)

### Added
- Main menu (continue / new game / settings / quit) with animated ember
  backdrop; the project now boots to the title screen.
- Pause menu with resume, save, load, settings, controls reference, and
  quit-to-title; replaces the static pause overlay.
- Reusable settings panel (mouse sensitivity, FOV, invert Y, view bob,
  and four audio volumes) shared by the main menu and pause menu.
- Full audio layer: procedural ambient tavern bed, day/night music with
  crossfades, footsteps timed to gait, and cues for interaction, doors,
  coins, brawls, quests, events, upgrades, and critical tension. All
  assets are synthesized by `tools/generate_audio.py` (CC0).
- Audio buses (Master/Music/Ambient/Sfx) driven by persisted settings.
- Hearth spark particles that intensify when the fire is stoked.

### Changed
- Saves are now atomic: written to a temp file, previous save rotated to
  `.bak`, then renamed into place. Loading falls back to the backup when
  the primary file is corrupt.
- Starting a new game resets all service state through a baseline
  payload, so replays never inherit the previous session.
- Quest and inventory managers fully reset before applying loaded data.
- HUD tension bar reuses cached styles instead of allocating per tick.
- Lantern shadows disabled (seven shadow casters -> hearth-only), cutting
  lighting cost with no visible loss.
- Seated NPCs drop out of the avoidance simulation.
- Story characters re-sync after a load that rewinds flags.

### Fixed
- Esc during a story dialogue no longer opens the pause menu underneath.
- Mouse could be recaptured while a dialogue held the tree paused.
- Failed loads from the pause menu now report instead of silently doing
  nothing.

## 0.4.0 — Story, quests, events, onboarding (Phase 4)
- Three-act story, 22 data-driven quests, 15 random events, recurring
  characters (Maren, Fenwick, Vess), dialogue panel with the Accord
  choice, skippable intro, learn-by-doing tutorial, HUD quest tracker.

## 0.3.0 — Management (Phase 3)
- Tension system, economy ledger with wages/rent, per-race reputation,
  brawl escalation/damage/interventions, menu pricing and stock,
  11-upgrade tree, Keeper's Ledger UI, SaveData v2.

## 0.2.0 — NPC life (Phase 2)
- NPC base with navmesh locomotion and timer-driven thinking, seven
  races, seat claiming, patron lifecycle, staff roles, spawner with
  daily traffic patterns, speech bubbles and race dialogue.

## 0.1.0 — Foundation (Phase 1)
- Godot 4.4 project, autoload services, first/third-person controller,
  procedural tavern interior, interaction framework, HUD, save system.
