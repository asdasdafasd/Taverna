# QA Notes — 1.0.0

Walkthrough audit of the release build, following the player's path.
Static verification: GDScript parser + gdlint clean over all 60 scripts;
scene/resource reference check clean; JSON content (quests, events,
dialogue) valid; quest graph fully reachable; save key symmetry verified.

## Boot & menus
- Boots to the main menu; Continue only appears when a save (or backup)
  exists. New Game resets all service state via a baseline payload before
  play, so a second run in the same session starts clean.
- Settings persist immediately (`user://settings.cfg`) and apply live:
  audio buses, FOV, sensitivity, view bob.

## First run
- Intro letter plays over black, any key skips, and it cannot trap input
  (`MOUSE_FILTER_IGNORE` everywhere, input handler only while playing).
- Tutorial waits for the intro, advances only on the real actions, `H`
  skips, completion recorded in profile and save.

## Core loop
- Movement, sprint (both bindings), crouch under the bar, camera toggle,
  carry/drop tankards: verified by code path review; interaction ray
  extends with the third-person boom so reach stays constant.
- Patrons path through the entrance (door auto-opens on layer 5 bodies),
  claim distinct seats (hard claim before walking), order only items in
  stock, and cancellation returns reserved units.
- Ledger opens only from the PLAYING state and never on top of a paused
  dialogue; every button plays UI feedback and refreshes affected tabs.

## Conflict path
- Tension rises from seating enemies/angry exits/brawls; decay ticks skip
  while paused. Brawls: bystander join/flee rolls run once per fight,
  bouncer path checks liveness each tick, both player interventions
  (F shove / G soothe) resolve fights into LEAVING or back to seats —
  no state where a patron stays FIGHTING with no opponent (opponent
  invalidation ends the fight on the next think tick).

## Save / load
- Atomic write path (`.tmp` → `.bak` rotation → rename); load falls back
  to backup on parse/version failure; v2 saves migrate (new fields
  default). Load resets quests and inventory before applying, and the
  story director re-syncs character presence afterwards.
- Quickload with no save posts a hint instead of failing silently.

## Performance review
- NPC decisions are timer-driven (0.4–0.7 s, jittered); per-frame work is
  steering only. Seated NPCs disable avoidance processing.
- Shadow casters reduced to the hearth + player-visible moonlight;
  lanterns and candles are shadowless fills.
- HUD updates are event-driven; the tension bar reuses cached styleboxes.
- Audio uses a fixed 6-voice SFX pool with per-cue cooldowns; music and
  ambient are two looping streams with tween crossfades.
- Save files are ~2–4 KB JSON; writes are single-frame.

## Known non-blocking items
- Godot may print a one-time navmesh bake notice on first load order;
  spawning waits for `navigation_ready`, so behavior is unaffected.
- If the player quits to title mid-brawl, the fight simply despawns with
  the scene — by design (world state is scene-local, persistent state
  lives in services).
