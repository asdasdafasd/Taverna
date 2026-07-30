# The Wandering Flagon

A cozy 3D tavern management game built with **Godot 4.4** (Forward+).
You are the keeper of a roadside tavern: pour ale, feed travelers, and keep
the hearth burning.

This repository currently contains **Phases 1–4**: the playable foundation
(player controller, tavern interior, interaction framework, core services),
living NPCs (seven fantasy races of patrons who enter, claim seats, order,
gossip, brawl, pay, and leave, served by a staff crew), the management
layer (economy and ledger, room tension, per-race reputation, dangerous
brawls with interventions, menu pricing and stock, and a working upgrade
tree), and the narrative layer — a three-act story about the truce-hall
buried under the Flagon, 22 event-driven quests, recurring named
characters, a random-event library, a skippable letter intro, and a
learn-by-doing tutorial. Everything persists through saves.

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
| `Tab` | Open / close the Keeper's Ledger (management screen) |
| `F` | Break up the nearest brawl by force (raises tension a little) |
| `G` | Stand a round on the house (costs coin, may end a fight peacefully) |
| `H` | Skip the tutorial (first run only) |
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
- Watch **patrons** arrive through the front door: they claim stools, order
  from the bartender and cook, chat, and settle their tab on the way out.
- Wait for an **orc and an elf** to sit near each other at night — the
  bouncer earns his keep.
- Listen for the **bard's** verses; they lift the whole room's mood.
- Open the **Keeper's Ledger** (`Tab`): tune menu prices, restock the
  cellar, review the day's takings, check staff wages, buy upgrades, and
  track your standing with each race.
- Keep an eye on the **tension bar** under your coin count — a rowdy room
  brawls more, and brawls smash furniture you'll have to repair.
- Step into a fight yourself: shove the brawlers apart (`F`) or buy the
  room a calming round (`G`).
- Follow the **story**: Maren the courier carries your grandfather's
  letters, Old Fenwick remembers what this hall used to be, and someone
  pale only visits after the candles gutter. The **quest tracker** at the
  top right follows your current thread, and the **Quests** tab in the
  Ledger tracks every thread across three acts.
- Keep playing through the days — a traveling minstrel, a duke's assessor,
  a white stag in the yard: **random events** keep no two evenings alike.

## Project layout

```
autoload/     Global services registered as autoload singletons
  event_bus.gd          Decoupled cross-system signals
  game_manager.gd       Session state, funds, data catalogs
  save_manager.gd       JSON save slots + save-participant group
  settings_manager.gd   User preferences (user://settings.cfg)
  time_manager.gd       In-game calendar/clock
  tension_manager.gd    Room tension meter with warning/critical bands
  economy_manager.gd    Ledger, daily totals, wages and rent charges
  reputation_manager.gd Per-race standing, spawn/mood/tip modifiers
  upgrade_manager.gd    Upgrade catalog, ownership, summed named effects
  inventory_manager.gd  Stock counts, menu prices, restocking
  brawl_manager.gd      Fight tracking, bystanders, damage, interventions
  story_manager.gd      Story flags, acts, the Accord decision
  quest_manager.gd      Quest loading, event routing, rewards, unlocks
  tavern_events_manager.gd  Random-event table: weights, cooldowns, effects
assets/materials/       Shared PBR + shader materials (.tres)
data/
  scripts/              Typed Resource models (items, recipes, races, saves,
                        upgrades, quests)
  items/ recipes/ races/ upgrades/  Data instances loaded at boot
  quests/               Quest definitions (quests.json)
  events/               Random tavern events (events.json)
  dialogue/             NPC and story line content (JSON)
game/main/              Boot scene: main flow, pause, quick save/load
interaction/            Interactable contract, ray, highlight, carryable props
npc/                    NPC life: base class, patrons, seats, dialogue, spawner
  staff/                Bartender, cook, bouncer, bard roles
  story/                Recurring characters, story director, staged dialogue
player/                 Player controller + brawl intervention component
shaders/                Procedural shaders (flame, embers, dust, outline)
ui/hud/                 Crosshair, prompts, clock, funds, tension bar,
                        quest tracker, pause
ui/management/          The Keeper's Ledger management screen
ui/dialogue/            Paged story conversation panel
ui/onboarding/          Intro letter sequence + learn-by-doing tutorial
utils/                  Math and string helpers
world/
  tavern/               Tavern scene + procedural architecture builder
  furniture/            Tables, stools, bar, shelf, barrels, kitchen block
  props/                Doors, fireplace, candles, lanterns, tankards,
                        story markers
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
- **NPC life (Phase 2).** `NPCBase` provides navmesh locomotion, the
  procedural body, speech bubbles, and a jittered timer-driven think loop —
  no per-frame decision code. `PatronNPC` runs the guest lifecycle
  (enter → claim seat → order → consume → socialize → pay → leave) with a
  strict priority order: danger, needs, service, social, leaving. Seats are
  hard-claimed through `Seat.try_claim` before an NPC walks over, so
  double-seating cannot happen. Seven `RaceData` resources drive patience,
  aggression, tips, menus, ally/enemy relations, body tint/size, and one
  unique trait each (orc war toast, dwarf second round, goblin coin skim,
  elf seat aloofness, halfling second lunch, human gossip, undead grave
  chill). Dialogue lines live in `data/dialogue/*.json` keyed by moment and
  race. Staff (`StaffNPC` roles: bartender, cook, bouncer, bard) prioritize
  work over idling — servers fulfill `PatronOrder`s from the EventBus queue,
  the bouncer breaks up brawls, the bard buffs room mood. `NPCSpawner`
  follows an hourly busyness curve and shifts the race mix across day,
  evening, and night, under a configurable population cap. Doors open
  automatically for NPC bodies and close behind them.
- **Management layer (Phase 3).** Single sources of truth: `TensionManager`
  (0–100 with CALM/UNEASY/CRITICAL bands; feeds patron brawl chance),
  `EconomyManager` (every coin flows through `earn`/`try_spend`/
  `absorb_loss` into a rolling ledger with per-day totals; wages and rent
  charge at midnight and missing them has consequences),
  `ReputationManager` (per-race 0–100 standing that scales spawn weights,
  arrival mood, and tips), `InventoryManager` (stock and player-set menu
  prices — gouging above 2× base value sours moods; orders reserve stock
  and sold-out items cost reputation), `UpgradeManager` (upgrades grant
  summed named effects like `max_patrons_bonus` or `prep_speed_bonus` that
  systems query by key), and `BrawlManager` (tracks fights, rolls bystander
  join/flee reactions by race, books furniture damage over time, and offers
  the intervention API used by the bouncer and the player's shove/soothe
  keys). The Keeper's Ledger (`ui/management/`) is a tabbed pause-screen UI
  over live manager state: overview and ledger, menu and stock, staff and
  wages, the upgrade shop, reputation bars, and a running journal.
- **Story and quests (Phase 4).** A three-act arc: the player inherits the
  Flagon, learns it was the valley's buried truce-hall, and finally chooses
  to renew the old Accord or let it fade — both endings change the game
  state (tension/reputation vs. a coin windfall). `StoryManager` owns flags
  and acts; `QuestManager` loads 22 quests from `data/quests/quests.json`
  and routes 18 gameplay event types (orders delivered, tabs paid, brawls,
  tension recovery, funds and reputation thresholds, dialogue, markers)
  into objective progress, failure triggers, and rewards — no quest logic
  lives outside the data and the router. Recurring characters (Maren the
  courier, Old Fenwick, Vess the witness) are placed by `StoryDirector` on
  schedule windows and story state; their staged dialogue lives in
  `data/dialogue/story_dialogue.json` and plays through a paged panel with
  a real choice at the climax. `TavernEventsManager` rolls a 15-entry
  weighted event table hourly against live tavern state (hours, patrons,
  races present, funds, stock, act) with per-event day cooldowns. First
  runs get a three-beat skippable letter intro and a five-step tutorial
  that only advances when the player performs each action; both remember
  completion per profile and per save.
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
| 5 | `npc` | Patron and staff bodies (door sensors watch this layer) |

## License

CC0 1.0 Universal — see [LICENSE](LICENSE).
