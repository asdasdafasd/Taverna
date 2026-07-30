# The Wandering Flagon

A cozy 3D tavern-management game built with **Godot 4.4** (Forward+).

You inherit The Wandering Flagon from your grandfather Aldous — a roadside
tavern with a longer memory than its regulars. Pour ale for seven fantasy
races, balance the books, keep tempers below a boil, and uncover what
really sleeps beneath the cellar across a three-act story with two endings.

## Running the game

1. Install [Godot 4.4.x](https://godotengine.org/download) (standard build,
   no .NET required).
2. Clone this repository.
3. Open `project.godot` in the Godot editor (first open imports assets;
   give it a moment).
4. Press **F5** / *Run Project*. The game boots to the title screen.

### Building a release

1. In the editor: *Editor → Manage Export Templates* and install the
   templates for 4.4.x.
2. *Project → Export…*, add a preset for your platform
   (Windows Desktop / Linux / macOS), keep default settings.
3. Export. All content is procedural or text data — no external asset
   packs are needed.

## Controls

| Input | Action |
| --- | --- |
| Mouse | Look (raw input, capture-mode) |
| `W` `A` `S` `D` | Move |
| `Space` | Jump (with coyote time and jump buffering) |
| `Shift` (hold) / `W` double-tap | Sprint |
| `Ctrl` / `C` | Crouch |
| `V` | Toggle first / third person |
| `E` | Interact, talk, advance dialogue |
| `Q` | Drop carried item |
| `Tab` | Keeper's Ledger (management) |
| `F` | Break up the nearest brawl by force |
| `G` | Stand a round on the house (may end a fight peacefully) |
| `H` | Skip the tutorial (first run) |
| `F5` / `F8` | Quick save / quick load |
| `Esc` | Pause menu (settings, save/load, quit to title) |

## What is implemented

- **Player**: first/third-person controller with sprint, crouch, coyote
  time, jump buffer, view bob, interaction ray, carry/drop, footsteps.
- **Tavern**: procedurally assembled interior (hall, bar, kitchen, cellar,
  porch), animated hearth with sparks, candles, lanterns, dust motes,
  volumetric fog, day/night mood.
- **NPCs**: seven races (human, orc, elf, dwarf, halfling, goblin, undead)
  with distinct patience, aggression, menus, relations, and one unique
  trait each; patrons enter, claim seats (no double-seating), order, eat,
  gossip, brawl, pay, and leave; staff (bartender, cook, bouncer, bard)
  work order queues, break up fights, and play verses.
- **Management**: economy ledger with wages/rent, room tension with
  warning/critical bands, per-race reputation that shifts the crowd, menu
  pricing and restocking, furniture damage and repairs, an 11-upgrade tree
  with real effects.
- **Story**: three acts, 22 data-driven quests (completable and failable),
  three recurring characters, a final choice with two endings, 15 random
  tavern events, skippable intro, learn-by-doing tutorial.
- **Systems**: atomic saves with backup rotation and version migration,
  full settings (mouse, camera, audio buses), procedural audio (ambient
  bed, day/night music crossfade, 12 event cues), main menu and pause menu.

## Project layout

```
autoload/       16 global services (event bus, time, saves, economy,
                tension, reputation, inventory, upgrades, brawls, story,
                quests, events, audio, settings, session, startup)
assets/audio/   Procedurally generated WAVs (see tools/generate_audio.py)
assets/materials/  Shared PBR + shader materials
data/           Typed resources and JSON content (items, recipes, races,
                upgrades, quests, events, dialogue)
game/main/      The playable scene: world + player + NPCs + UI
interaction/    Interactable contract, ray, highlight, carryable props
npc/            Patron/staff/story NPCs, seats, spawner, dialogue data
player/         Controller, footsteps, brawl intervention
shaders/        Flame, embers, dust, focus outline
tools/          Asset generation scripts (Python, stdlib only)
ui/             Menu, HUD, ledger, dialogue panel, onboarding
utils/          Math and string helpers
world/          Tavern architecture, furniture, props
```

## Architecture notes

- Typed GDScript throughout; signals over references; `EventBus` is the
  only cross-system wiring surface.
- Autoloads are true services registered in dependency order. Gameplay
  data (quests, events, dialogue, upgrades, races, items) is external —
  JSON or `.tres` — and loaded at boot.
- Persistence: nodes join `save_participants` and implement
  `write_save_data` / `read_save_data` against a versioned `SaveData`
  (v3, reads v2). Saves are written atomically (`.tmp` → rotate `.bak` →
  rename) and loads fall back to the backup on corruption.
- Physics layers: 1 world, 2 player, 3 interactable, 4 carryable, 5 npc.

## Known limitations

- One quicksave slot (plus automatic backup); no manual slot picker.
- NPC bodies are stylized capsule figures; no skeletal animation.
- The tutorial and intro replay only for fresh profiles
  (`user://profile.cfg`); delete that file to see them again.
- Navigation assumes the shipped tavern layout; moving walls at runtime
  would require a re-bake.

## Credits

- Design, code, art direction, audio synthesis: the Wandering Flagon team.
- Built with [Godot Engine](https://godotengine.org) (MIT license).
- All sounds and music are generated by `tools/generate_audio.py`
  (Python stdlib) and are CC0, like everything else in this repository.

## License

CC0 1.0 Universal — see [LICENSE](LICENSE).
