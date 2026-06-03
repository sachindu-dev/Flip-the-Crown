# 👑 The Royal Swap

A tight, snappy single-screen **2D puzzle-platformer** built in **Godot 4**. Instantly swap between two characters with complementary abilities to clear each level: collect the diamond keys, reach the exit, and don't die.

> Swap on the fly — the **King** smashes through boxes and pigs, the **Ninja Frog** double-jumps and wall-jumps to places the King can't reach. Two crowns, one path.

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
- **Swap** instantly teleports the inactive character to the active one's feet, with a dust burst, freeze-frame and screen flash. The bottom-left HUD chip always shows who you can swap *to*.
- **Diamonds** are mandatory keys — collect them all to unlock the exit door. **Fruit** is bonus score.
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
  Levels.gd            # the three level grids
  SheetUtil.gd         # slices sprite sheets into SpriteFrames
assets/                # art (see credits)
```

The game uses a custom tile-grid physics engine (coyote time, jump buffering, variable jump height, wall-slide/jump) rather than Godot's built-in physics, ported faithfully from a browser prototype of the same game.

## 🎨 Credits

Art by **Pixel Frog** — used under their terms:
- [Kings and Pigs](https://pixelfrog-assets.itch.io/kings-and-pigs)
- [Pixel Adventure 1](https://pixelfrog-assets.itch.io/pixel-adventure-1)

Game design & code: **The Royal Swap**.
