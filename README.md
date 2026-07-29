# The Wandering Flagon

A cozy 3D tavern management game built with **Godot 4.4** (Forward+).
You are the keeper of a roadside tavern: pour ale, feed travelers, and keep
the hearth burning.

This repository currently contains **Phase 1** — the playable foundation:
a fully controllable first/third-person player, a believable tavern interior,
the interaction framework, and the core global services every later phase
builds on.

## Getting started

1. Install [Godot 4.4.x](https://godotengine.org/download) (standard build,
   no .NET required).
2. Clone this repository.
3. Open `project.godot` with the Godot editor (first open imports assets).
4. Press **F5** (Run Project). The game boots straight into the tavern.

## Controls

| Input | Action |
| --- | --- |
| Mouse | Look (raw input, capture-mode) |
| `W` `A` `S` `D` | Move |
| `Space` | Jump (with coyote time and jump buffering) |
| `Shift` (hold) | Sprint |
| `W` double-tap | Sprint (Minecraft-style), released with `W` |
| `Ctrl` / `C` | Crouch (smooth height transition, blocked ceilings respected) |
| `V` | Toggle first-person / third-person camera |
| `E` | Interact with the focused object / drop carried item |
| `Q` | Drop carried item |
| `Esc` | Pause / resume |
| `F5` | Quick save |
| `F8` | Quick load |
| Left click | Recapture the mouse after focus loss |

### Things to try

- Stoke the **hearth** on the west wall and watch the fire roar up.
- Snuff and relight the **candles** on the tables.
- Open the **entrance door** and step onto the porch, or take the
  **cellar door** down the stairs to the barrel cellar.
- Pick up a **tankard** from the bar (`E`), carry it around, and toss it (`Q`).

## Project layout

```
autoload/     Global services registered as autoload singletons
  event_bus.gd          Decoupled cross-system signals
  game_manager.gd       Session state, funds, data catalogs
  save_manager.gd       JSON save slots + save-participant group
  settings_manager.gd   User preferences (user://settings.cfg)
  time_manager.gd       In-game calendar/clock
assets/materials/       Shared PBR + shader materials (.tres)
data/
  scripts/              Typed Resource models (items, recipes, races, saves)
  items/ recipes/ races/  Data instances loaded by GameManager at boot
game/main/              Boot scene: main flow, pause, quick save/load
interaction/            Interactable contract, ray, highlight, carryable props
player/                 Player controller scene + script
shaders/                Procedural shaders (flame, embers, dust, outline)
ui/hud/                 Crosshair, prompts, clock, notifications, pause
utils/                  Math and string helpers
world/
  tavern/               Tavern scene + procedural architecture builder
  furniture/            Tables, stools, bar, shelf, barrels, kitchen block
  props/                Doors, fireplace, candles, lanterns, tankards
```

## Architecture notes

- **Typed GDScript everywhere.** Every variable, parameter, signal payload,
  and return type is annotated.
- **Signals over references.** Cross-system communication flows through
  `EventBus`; systems never reach into each other's scene trees.
- **Autoloads are true services** (`EventBus`, `SettingsManager`,
  `TimeManager`, `SaveManager`, `GameManager`) and are registered in
  dependency order.
- **Scenes are self-contained.** Each prop/furniture piece owns its meshes,
  collision, lights, and script; the tavern scene only composes them.
- **Interaction contract.** Anything focusable extends `Interactable`
  (a `CollisionObject3D` script) on the *interactable* physics layer. The
  player's `InteractionRay` drives focus highlight (a pulsing shader outline)
  and HUD prompts; `CarryableProp` extends the contract for pick-up physics.
- **Saving.** Nodes join the `save_participants` group and implement
  `write_save_data` / `read_save_data`; `SaveManager` serializes a versioned
  `SaveData` resource to `user://saves/*.json`.
- **The tavern shell is generated** by `TavernArchitecture` from named layout
  constants (rooms, openings, stairs), so the whole building can be retuned
  from one file while keeping visuals and collision in lockstep. The
  `NavigationRegion3D` bakes at runtime from static colliders, ready for
  patron pathfinding in Phase 2.

## Physics layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | `world` | Architecture, furniture, camera occlusion, navmesh bake |
| 2 | `player` | The player body |
| 3 | `interactable` | Everything the interaction ray can focus |
| 4 | `carryable` | Rigid-body props the player can collide with and carry |

## License

CC0 1.0 Universal — see [LICENSE](LICENSE).
