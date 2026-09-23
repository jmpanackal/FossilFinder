# Task: First Playable Excavation Prototype (Milestone 1)

`DESIGN.md` in the repo root describes the full game. Read it for context, but **build only what this file asks for.** Don't create stubs, managers, or data structures for the museum, upgrades, research, saving, or multiple dinosaurs. Those come in later milestones.

The single question this milestone answers: **is digging fun?**

## Project setup

- Godot 4.x, GDScript
- Desktop target, 1280×720 base resolution with stretch mode `canvas_items`
- Placeholder art only: colored shapes, `_draw()` calls, and built-in particles
- Existing project: none. Start from an empty Godot project.

## Locked decisions (don't revisit without asking)

**1. Perspective: top-down layered grid with a slight tilt.**
- The dig site is a 2D grid of cells. Each cell is a column of stacked layers.
- Digging damages the cell's top remaining layer. When a layer's HP hits 0, it's removed and the next layer is exposed.
- Render each cell as a slightly squashed square, and draw a visible "wall" face on its south edge wherever a neighbor is higher. This creates a pit illusion without real 3D.
- Top-layer color comes from material and darkens with depth.
- Store terrain data in plain arrays and render with a custom node's `_draw()`. Only use TileMap or per-cell nodes if they're clearly simpler, and explain why in the plan.

**2. Grid and depth**
- 16×10 cells, 24 layers per cell, 0.5 m per layer (12 m max this milestone)
- Displayed depth = the deepest layer removed anywhere in the grid this round

**3. Materials by layer index** (all numbers go in the tuning file):

| Layers | Material | HP | $ per layer cleared |
|---|---|---|---|
| 0–5 | Loose dirt | 1 | 1 |
| 6–11 | Packed dirt | 3 | 3 |
| 12–17 | Clay | 6 | 6 |
| 18–23 | Soft rock | 12 | 12 |

**4. Tools.** Select with keys 1–3 or the scroll wheel. The cursor always shows the current tool.
- **Shovel (1):** Hold and drag. Damages every cell in a small radius under the cursor at a fixed tick rate. Strong against dirt, weak against clay, near-useless against rock.
- **Pickaxe (2):** Click. Heavy damage to one cell. Strong against rock and clay, overkill on dirt.
- **Brush (3):** Hold and move. Damage scales with the distance the cursor travels, so scrubbing matters and holding still does nothing. It **only affects cells adjacent to an exposed fossil cell**. It never damages the fossil.
- Tool-vs-material damage lives in a single matrix in the tuning file.

**5. Fossil (exactly one per round)**
- Defined as a minimal `FossilData` Resource with fields `name`, `shape` (small 2D bitmask, e.g. 3×2 to 4×3), `min_layer`, `max_layer`, and `base_value`. Create exactly one instance: "Triceratops Skull". This is the only data Resource allowed in this milestone.
- At round start, place it at a random grid position and a random layer within its range.
- A fossil cell becomes visible as bone color once all layers above it in that cell are removed. Cells occupied by the fossil can't be dug below the fossil's layer.
- **Integrity:** The fossil starts at 100%. Each shovel or pickaxe hit on an exposed fossil cell costs 10% (tunable), with a floor of 25%. The fossil cracks visually as integrity drops. Brush hits cost nothing.
- **Extraction:** When every fossil cell is exposed, extraction happens automatically with a celebration. Reward = `base_value × integrity`.
- **Timeout:** If the round ends before extraction, the fossil is lost. The summary shows "Fossil left behind — X% exposed." This rule is what makes the end-of-round tradeoff matter.

**6. Round flow**
- 60 s timer. HUD shows the timer, current depth, current tool, and money earned this round.
- When time expires, show a summary: depth reached, money earned, and the fossil result (extracted with integrity %, or left behind with exposure %).
- The **DIG AGAIN** button dominates the summary. Enter and Space also trigger it. A new round must start in under 1 second, with a fresh grid and a newly placed fossil.
- Money persists across rounds in memory only. There's no saving yet.

## Tuning and debug

- Put every number above (HP, damage matrix, tick rates, radii, timer, grid size, layers, money values, integrity costs) in one place: a `tuning.gd` autoload or a single `.tres` with `@export` vars. I will tune game feel myself.
- **F1:** debug overlay showing the fossil's location/layer, FPS, and the damage matrix
- **F2:** end the round immediately

## Minimum juice (required in this milestone, not polish for later)

- Particles on every hit, colored by material. Rock gets chunkier fragments than dirt.
- A crack overlay on each cell, scaled to how damaged its top layer is
- Small screen shake on pickaxe hits, tunable, with an option to disable
- Floating "+$N" text when layers clear
- A distinct "ping" effect the first time any fossil cell becomes exposed
- A pop/flash on extraction, with the fossil name and value
- Sound: route everything through `Sfx.play("hit_dirt")`-style calls. Silent stubs or generated placeholder beeps are fine. The point is to have the hook points in place.

## Acceptance criteria

Milestone 1 is done when all of these hold:
1. The pit reads as depth: after 20 seconds of digging, you can see which areas are deeper.
2. The shovel is clearly the right tool for dirt, and the pickaxe for rock. You can feel the difference within a few seconds.
3. The fossil is noticed from a single exposed cell, and its shape becomes recognizable as more cells are exposed.
4. The brush is the obviously correct way to finish exposing the fossil, and it feels like scrubbing, not clicking.
5. The timer creates a real choice between finishing the fossil and digging deeper for money.
6. Summary → DIG AGAIN → digging again takes under 2 seconds.
7. It runs with no errors or warnings in the output panel.

## Process

1. Inspect the repo.
2. Write a short plan (one page max) covering the file list, scene tree, data layout, and any deviation from the locked decisions with a reason. **Stop and wait for my approval.**
3. Implement in this order. Run the project after each step and fix errors before moving on:
   1. Grid rendering + shovel
   2. Materials + pickaxe + damage matrix
   3. Depth, timer, money, HUD
   4. Fossil placement, reveal, brush, integrity, extraction
   5. Summary + DIG AGAIN loop
   6. Juice pass
4. After each step, tell me in one or two lines what to test.

## Out of scope for this milestone

Museum, upgrades, research, save/load, multiple fossils or dinosaurs, the drill, menus, settings screens, real audio assets, and any "manager" classes for future systems. If something seems necessary that isn't listed here, ask before building it.
