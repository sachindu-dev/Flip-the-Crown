# 👑 The Royal Swap

A tight, snappy single-screen **2D puzzle-platformer** built in **Godot 4**. Instantly swap between two characters with complementary abilities to clear each level: collect the diamond keys, reach the exit, and don't die.

> Swap on the fly — the **King** smashes through boxes and pigs, the **Ninja Frog** double-jumps and wall-jumps to places the King can't reach. Two crowns, one path.

https://github.com/user-attachments/assets/19710b17-ee0d-4236-8127-fbfd2ed8ca40

---

## 🎮 Controls

| Action | Keys |
|--------|------|
| Move   | `←` `→` / `A` `D` |
| Jump   | `Space` / `Z` |
| Swap character | `X` / `Shift` |
| Hammer (King only) | `C` / `J` |
| Pause  | `Esc` |

## 🕹️ Gameplay

- **The King** — slow, single jump. His hammer destroys wooden boxes and defeats Pigs.
- **The Ninja Frog** — fast, double-jump and wall-slide/wall-jump. Can't attack and dies in one hit.
- **Swap** instantly toggles which character you control — each one keeps its own position, so you move the King and the Frog independently and switch between them on the fly (with a dust burst, freeze-frame and screen flash). The bottom-left HUD chip always shows who you can swap *to*, and the inactive character is marked on-screen.
- **Diamonds** are mandatory keys — collect them all to unlock the exit door, then get **both** the King and the Frog to the exit to finish the level. **Fruit** is bonus score.
- **Pigs** patrol their platforms; **spikes** and **spinning saws** are lethal to both characters.
- **3 hearts.** Taking damage respawns both characters at the start of the level (with brief invulnerability). Lose all three and it's game over.

## 🗺️ Levels

Three single-screen levels of rising difficulty, hand-tuned so high diamonds force the Frog and box corridors force the King's hammer:

1. **First Swap** — learn the swap.
2. **Sawmill** — spikes, saws and vertical climbs.
3. **The Vault** — the gauntlet.

## ▶️ Running it

1. Install **Godot 4.6** (or newer 4.x).
2. Open this folder as a project (`project.godot`) and press **Play** (`F5`), or run headless from the CLI:
   ```sh
   godot --path .
   ```

## 🧱 Project structure

```
project.godot          # config; input map is built at runtime in Game.gd
scenes/Main.tscn       # the single scene (root runs Game.gd)
scripts/
  Game.gd              # engine, state machine, world builder, swap/hazard/pickup/door logic
  Character.gd         # King + Ninja Frog — custom tile-grid physics
  Pig.gd               # patrolling enemy
  Particles.gd         # dust / break particle layer
  UI.gd                # HUD, main menu, pause, end screen (built in code)
  Levels.gd            # text grids (fallback / source for the scene generator)
  Pickup/SawEnt/DoorEnt.gd  # entity behaviours
  SheetUtil.gd         # slices sprite sheets into SpriteFrames
entities/              # editable entity scenes (Pig, Diamond, Fruit, Box, Saw, Spike, Door)
levels/Level1-3.tscn   # editable level scenes (TileMapLayer + placed entities)
tilesets/terrain.tres  # terrain TileSet for painting levels
tools/build_level_scenes.gd  # regenerates the tileset + level scenes from Levels.gd
assets/                # art (see credits)
```

The game uses a custom tile-grid physics engine (coyote time, jump buffering, variable jump height, wall-slide/jump) rather than Godot's built-in physics, ported faithfully from a browser prototype of the same game.

### Editing levels visually

`Game.gd` loads a level from `levels/LevelN.tscn` if it exists, otherwise from the text grid in `Levels.gd`. **All three levels are editable scenes** — open any `levels/LevelN.tscn` in Godot and:

- **Paint terrain** on the `Terrain` TileMapLayer using the `tilesets/terrain.tres` palette (any painted cell is solid).
- **Place entities** by dragging the scenes from `entities/` into the level and snapping them to the 32 px grid.
- **Move the `KingSpawn` / `FrogSpawn`** markers to set where each character starts.

The engine reads the TileMap cells as the collision grid and the placed nodes (by group) as entities. The text grids in `Levels.gd` are kept as a fallback and as the source for `tools/build_level_scenes.gd`, which regenerates the tileset and all level scenes (`godot --headless --script res://tools/build_level_scenes.gd`).

## 🎨 Credits

Art by **Pixel Frog** — used under their terms:
- [Kings and Pigs](https://pixelfrog-assets.itch.io/kings-and-pigs)
- [Pixel Adventure 1](https://pixelfrog-assets.itch.io/pixel-adventure-1)

Game design & code: **The Royal Swap**.
