# DESIGN.md — Dinosaur Fossil Digging Incremental Game

This is the reference document for the full game. Individual task prompts define what to build at each point. **Don't build anything from this file unless the current task asks for it.**

## Pitch

An incremental game about excavating dinosaur fossils. The player digs a timed pit, earns money, uncovers fossils, and upgrades their tools to dig deeper and find rarer dinosaurs. Found fossils automatically assemble into skeletons in a museum, and the museum generates passive income.

Target player reaction: **"One more dig."**

## Constraints

- Solo developer, Godot 4.x + GDScript, heavy AI-assisted development
- About 10 hrs/week, with a **20–30 hour budget** for v1
- Priorities, in order: fun → game feel → replayability → fast implementation → easy content expansion
- If a simple 30-minute solution and a "perfect" 3-hour solution both exist, take the 30-minute one unless it blocks a planned expansion.
- Few systems, lots of data-driven content.

**Design filter:** every feature must improve DIGGING, DISCOVERY, PROGRESSION, or THE MUSEUM, and should reuse an existing system where possible.

## Core loop

Dig (60 s round) → earn money + find fossils → fossils auto-install in the museum → museum income rises → buy upgrades → dig faster/deeper → find rarer fossils → complete dinosaurs → big bonus → repeat.

Active digging must always earn clearly more than waiting.

## Excavation (the most important system)

**Perspective (decided):** a top-down layered grid with a slight tilt. Each cell is a column of stacked layers, and digging removes the top layer. South-facing wall faces sell the pit illusion. Depth = the deepest layer removed this round.

**Materials** get harder and more valuable with depth: loose dirt → packed dirt → clay → soft rock → hard rock → ancient bedrock. Depth bands also gate fossil rarity. It's a single dig site whose content changes by depth, with no separate maps.

| Depth | Band | Content |
|---|---|---|
| 0–5 m | Surface soil | Common fossils, soft terrain |
| 5–15 m | Packed earth | Better fossils |
| 15–30 m | Sedimentary rock | Rare fossils, drill useful |
| 30 m+ | Ancient bedrock | Rarest dinosaurs |

Reaching deeper bands is gated by upgrades. Early rounds physically can't reach 30 m.

**Tools** (select with 1–4 or the scroll wheel):
- **Shovel:** hold + drag, area damage, best on dirt
- **Pickaxe:** click, heavy single-cell damage, best on rock
- **Brush:** scrub motion, damage scales with cursor movement, only works next to exposed fossils, never harms fossils
- **Drill** (unlocked later): hold, rapid continuous damage, best on hard rock

**Fossils** are physically embedded multi-cell shapes at specific layers. The intended sequence is: notice one bone-colored cell → expose more → recognize the shape → brush it out → extraction celebration.

**Risk:** the design uses no "push your luck" gambling. Instead, tension comes from two rules:
1. **Integrity:** shovel/pickaxe hits on exposed fossil cells reduce integrity (with a floor), and value scales with integrity. Rushing costs value.
2. **Timeout:** a fossil that isn't fully exposed when time runs out is lost.

These produce the key moment: 15 seconds left, with a half-exposed fossil, a valuable deposit, and a route deeper. Only one is achievable.

**Round placement:** each round rolls 1–N fossils from a depth-band loot table. The count is upgradeable.

## Fossil collection

Each dinosaur has about 5–7 major pieces (skull, spine, ribs, pelvis, forelimbs, hindlimbs, tail). Individual bones aren't simulated.

- **New piece:** added to the collection, attached to the museum skeleton, museum income increases.
- **Duplicate:** converted to money plus a small amount of research.
- **Duplicate protection:** when rolling which piece a fossil is, missing pieces get 3× weight (tunable).

**Dinosaur completion** is the biggest reward moment. It triggers a large exhibit income multiplier, a research reward, a strong celebration (sound, animation, skeleton reveal), and optionally a small global bonus.

## Museum

- One static scene, with no walking, NPCs, construction, or management.
- A row or grid of exhibit plinths, one per dinosaur.
- **Art approach (to keep art cheap):** each dinosaur skeleton is drawn in **side view**, with each piece as a separate sprite positioned on a shared canvas. Missing pieces render as faint outlines or silhouettes. Adding a piece = showing its sprite with an install animation. One drawing per dinosaur, sliced into pieces.
- Each installed piece adds exhibit income. A completed skeleton applies an exhibit multiplier.
- Offline income: only if it's trivial (timestamp difference × rate, capped).

## Economy

**Money** (common): comes from terrain, deposits, fossil value, duplicates, and museum income. Spent on equipment upgrades.

**Research** (rare): comes from new fossils, completions, and duplicates. Spent on a *small* set of major upgrades. v1 caps research upgrades at 3–4. Add no other currencies.

**Upgrades:** about 12 for v1, each one noticeable (no +1% steps). Categories:
- **Excavation:** shovel radius, pickaxe damage, hard-material damage, drill unlock (research)
- **Efficiency:** round duration, money multiplier
- **Paleontology:** fossils per round, rare-fossil chance, fossil integrity protection (research)
- **Museum:** exhibit income, completion bonus (research)

Each upgrade is a data Resource with name, category, currency, cost curve, max level, and effect key/value. Adding one should mean adding data, not code.

## Data-driven content

Adding any of the following should require zero new gameplay code:
- **DinosaurData:** name, piece list (FossilData refs), depth band, rarity weight, museum sprite canvas, completion rewards
- **FossilData:** name, shape bitmask, base value, sprite, owning dinosaur
- **MaterialData:** name, HP, value, color/texture, particle color, depth range
- **UpgradeData:** as described above

v1 content: **3 dinosaurs** (Triceratops, Stegosaurus, Velociraptor). T. rex is the stretch fourth. The system should support 15–25 later.

## Engagement timescales

- **Every second:** hit feedback, particles, sound, destruction
- **Every 10–30 s:** fossil hint, valuable layer, depth milestone
- **Every 60 s:** round summary + money
- **Every few rounds:** a meaningful upgrade
- **Every 10–30 min:** a completed dinosaur or major unlock
- **Long term:** a full museum

The player should almost always be close to *something*.

## Game feel

Polish beats feature count.
- **Digging:** impact sounds, material-colored particles, rock fragments, crack overlays, small shake on heavy hits, floating money
- **Fossils:** a distinct reveal ping, extraction pop, and a museum-install moment
- **Upgrades:** instant sound, visible stat change, and an effect felt next round
- **Completion:** a much bigger celebration than anything else

## UI

- Three screens: **Dig Site / Museum / Upgrades**
- **Top bar:** money, research, museum income/sec
- **Dig HUD:** timer, depth, tool, round money
- **Round summary:** depth, money, fossils (new/duplicate, integrity), with a huge **DIG AGAIN** (Enter/Space) and smaller Upgrades/Museum buttons. Back to digging in under 2 s.

## Save

Autosave after every round and every purchase. One slot, stored as JSON in `user://`. It holds money, research, upgrade levels, owned fossils, completed dinosaurs, and a last-seen timestamp. The museum state is derived from owned fossils rather than saved separately.

## Architecture guidance

Use autoloads only where state must persist across scenes (roughly: game state/economy, save, sfx). Everything else lives in plain scenes and scripts. There should be no interfaces, event buses, or abstraction layers unless a concrete duplication problem shows up. Keep all tuning numbers in one tuning file or Resource.

## Scope

**v1 must-have:** the dig site with 4–6 material bands, shovel/pickaxe/brush, integrity + timeout, 3 dinosaurs, ~12 upgrades, money + research, the museum with auto-assembling skeletons, passive income, completion bonus, autosave, and a juice pass.

**Stretch (only if under budget):** drill, 4th/5th dinosaur, museum upgrades beyond the two listed, offline income, artifacts/deposits as special cells.

**Never in v1:** player character, NPCs, museum walking or building, quests, dialogue, story, crafting, inventory, procedural overworld, multiplayer, settings beyond volume.

## Milestones (rough budget)

1. **Dig prototype**, ~8 h: is digging fun? (See `TASK_milestone1.md`.)
2. **Collection + upgrades**, ~6 h: FossilData/DinosaurData, loot tables, collection, duplicates, upgrade screen
3. **Museum + income**, ~6 h: museum scene, piece install, passive income, completion celebration
4. **Save + polish + balance**, ~6 h: autosave, juice pass, pacing tuning to hit the timescales above

Target first-completion time for v1 content: **about 60–90 minutes.** All balancing aims at that number.

## Success criteria

The player catches themselves thinking:
- "One more dig."
- "I can almost afford that upgrade."
- "What's under there?"
- "One more piece and the Triceratops is done."
- "I want to see the museum when this is finished."
- "I think I can hit the next layer this time."
