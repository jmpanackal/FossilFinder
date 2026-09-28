# Fossil Finder — Priority Plan

> **For agentic workers:** implement **one slice at a time**. Do not start P1+ until the player picks it. Economy retune is later — keep numbers fast for testing.

**Goal:** Turn the listed feel bugs into shippable slices, smallest first.

**Architecture:** Isolated UI/camera first (sky, museum zoom). Then rewrite unveil as a stackable rate+timer. Then purchasable spotlight ranks. Then dig-footer art. Shop numbers and a paleo chrome pass last.

**Tech stack:** Godot 4 / GDScript. Headless tests: `godot --headless --path <project> -s res://tests/<suite>.gd`

**Spec:** this file. Player list from 2026-09-25 playtest.

## How to work this

One slice at a time. Each slice is independently playable. Do **not** implement all at once.

**Out of scope until later:** economy / tool power retune. Fast scaling stays for testing.

---

## P0 — Kill the sky strip (minutes)

The dig still paints a 32px blue-gray wash across the top (`SiteBackdrop.horizon_y()` / `_draw_sky`). That reads as a letterbox, not a field. Extend the tan ground (`GROUND`) to `y = 0` and drop the sky bands. Keep the pit cutout, props, and survey string as they are.

**Files:** `site_backdrop.gd` (`horizon_y`, `_draw_sky`, `_draw_ground`). `tests/test_field_site.gd` currently *requires* an 8–48px sky wash — rewrite those asserts so ground fills the window and `clear_color` stays dirt-family, not void.

**Success:** Open a dig. No blue/gray strip at the top. Ground color meets the HUD. `test_field_site.gd` passes.

---

## P1 — Museum wheel zooms (isolated)

Wheel currently pans the hall (`WHEEL_PAN` in `museum.gd`). Change wheel to zoom. Zoom out until the full 2000×1480 hall fits; zoom in and drag to pan. Clicks must still hit the same stand after zoom (hall pos = pad pos transformed by scale + pan). Do not change unveil or spotlight behavior here.

**Files:** `museum.gd` (`_on_hall_gui_input`, `_apply_pan`, `_clamp_pan`, `_click_hall`). `museum_exhibit.gd` only if click-hit / draw scale needs a helper. New or extend `tests/test_hall_spotlight.gd` / `tests/test_museum_management.gd` for zoom→click mapping.

**Success:** Wheel in/out. Fully zoomed out shows every stand. Zoomed in, drag pans; wheel no longer scrolls the aisle. Click still unveils / features the stand under the cursor.

---

## P2 — Unveil rewrite (core feel)

Today a stand ribbons **once** (first piece only). Later bones on that dino do not re-ribbon (`install_find` + `test_fossil_sets.gd` “later feet do not re-ribbon”). A new *piece type* on that stand should ribbon again. Copy names the new bone(s) — “Stegosaurus plate waiting” — not “the Stegosaurus.”

Drop the toast/float `+$40` as the headline. Show **`+$X.XX/sec from unveiling rush`** plus a countdown. Duration longer than `Tuning.unveil_spike_seconds` (5s). If another unveil happens while a rush is live, **stack**: add the extra $/sec and extend (or refresh) the timer. Keep the cash burst in the bank if tests still need it, but do not lead with it.

Add better Exhibit upgrades for rush duration / strength (do not retune tools).

**Files:** `game_state.gd` (`pending_unveils`, `install_find`, `unveil_stand`, `museum_income`, save/load). `tuning.gd` (duration, stack rules). `museum.gd` (`_unveil_stand`, `_exhibit_income_line`, `_toast`). Catalog rows in `game_state.gd` `catalog`. Tests: `tests/test_hall_spotlight.gd`, `tests/test_museum_management.gd`, `tests/test_fossil_sets.gd`, `tests/test_save_game.gd`, `tests/test_fossil_roster.gd`.

**Success:** Dig a second *new* bone for a dino already unveiled → ribbon returns, names that bone. Unveil shows rate + timer. Second unveil mid-rush increases $/sec and keeps the timer alive. Old saves without the new stack fields still load.

---

## P3 — Spotlight is a shop rank (2x / 3x / 4x)

Featuring a stand is free today and always 2x (`Tuning.spotlight_mult`, plaque `·  2x`). Click should still *pick* the featured stand. The multiplier is a purchased Exhibit upgrade: rank 1 = 2x, 2 = 3x, 3 = 4x (scale the cone / glow in `_draw_spotlight` to match). No ranks bought → click features but does not multiply (or the first rank *is* unlocking 2x — pick one and test it).

**Files:** `game_state.gd` (`catalog`, `apply_upgrades`, `stand_income`, `museum_income`). `tuning.gd` (`spotlight_mult`). `museum_exhibit.gd` (cone + plaque). `shop.gd` / `shop_icon.gd` for the row. Tests: `tests/test_hall_spotlight.gd`, `tests/test_museum_management.gd` (today assert “adds one extra copy”). `tests/test_shop_layout.gd` if a new row appears.

**Success:** Unbought: light can sit on a stand, income is 1x. Buy 2x → that stand doubles and the cone looks like 2x. 3x / 4x scale income and the beam. Other stands stay 1x.

---

## P4 — Multi-find footer + fly-to-footer

Footer is text-only (`status_dock.gd` “THIS FIND”, `hud.gd` `_find_box` names). A pit can already hide extra bones (`extra_find_slots`). Show **image + label + status** for every live fossil. Reuse `ArtCatalog` (`art/final` PNGs) with the existing silhouette fallback.

When a bone is fully uncovered, fly it like matrix scraps (`loot_fly.gd`) into its footer slot — not the wallet.

**Files:** `status_dock.gd` or a new find-tray control. `hud.gd` (`_find_box`, `_layout_footer`). `loot_fly.gd` (or a fossil variant). `main.gd` (`_on_fossil_exposed` / extract). `art_catalog.gd`, `fossil_data.gd`. Tests: `tests/test_early_game_scaling.gd` (footer layout), `tests/test_fossil_silhouettes.gd`, `tests/test_matrix_finds.gd` if fly reuse changes.

**Success:** Two bones in the pit → two footer chips with art + name + “underground / uncovering / brush / bagged.” Full uncover plays a fly into that chip. Extra scraps do not steal the only slot.

---

## P5 — Shop effect tooltips

Rows already show flavor (`upgrade_node.gd` `desc` / `shop_item_desc`). Hover should add a **number**: “200% mining speed”, “+6s per shift”, “+20% exhibit income.” Hover tooltip is the intended modality — keep flavor on the row.

One helper (e.g. `GameState.shop_effect_line(id)`) so HUD NEXT and the shop stay in sync. Do not invent fake percents — read `apply_upgrades` / `Tuning`.

**Files:** `game_state.gd` (effect-line helper). `upgrade_node.gd`, `shop.gd`. Optional tooltip control. `tests/test_shop_layout.gd`, `tests/test_matrix_finds.gd` (copy), `tests/test_shop_goal.gd` if NEXT shows the same number.

**Success:** Hover Calloused Fingers / Heavy Swings / Longer Shift / Warm Lights. Tooltip states the next rank’s real delta. Flavor text still visible without hover.

---

## P6 — Paleo UI pass

Last, because P0–P5 change the same surfaces. Same dirt / bone / brass language across HUD, shop, museum, summary, settings. Cleaner hierarchy (wallet, clock, tools, footer tray). No gameplay numbers.

**Files:** `ui_style.gd`, `hud.gd`, `shop.gd`, `museum.gd`, `status_dock.gd`, `summary.gd`, `settings.gd`, `toast_layer.gd`. Visual pass — no new economy tests unless a control moves.

**Success:** Dig / shop / museum / summary look like one field catalog, not three mockups. Nothing important clipped. Existing layout tests still pass.

---

## Later — Economy retune (do not start)

Tools feel OP and income ramps too fast. **Leave it.** Fast numbers help test unveils, spotlights, and shop ranks. Retune `tuning.gd` / `apply_upgrades` only after P0–P6 are in.

---

## Suggested first ask

**Start P0** (sky strip). Then P1 or P2.

Reply with a slice: `P0` / `P1` / `P2` / …
