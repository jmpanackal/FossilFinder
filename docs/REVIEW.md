# Fossil Finder — UI/UX & Game Feel Review (2026-09-28)

A full pass over the game: the code, the headless suites, and rendered screenshots at 1280×720 and 1920×1080. The core loop is solid: dig, uncover, brush, mount, earn, upgrade. Most problems come from how things are **presented**, **how they are paced**, and **how much each purchase is felt**, not from the concept itself.

Items marked **✅ done** shipped on branch `claude/confident-fermi-93sro2`. Everything else is a recommendation, ordered by impact per hour of work.

---

## 1. Performance ✅ done (biggest single problem)

At the 16×10 claim with upgrades bought, a CPU frame took **~45 ms** (≈20 FPS before any rendering). Now it is **< 7 ms**.

| Cause | Cost / frame | Fix |
|---|---|---|
| Every `money_changed` (museum income ticks almost every frame) rebuilt the **hidden** Upgrades screen | ~32 ms | Shop marks dirty while hidden and refreshes at most ~8×/s while open |
| HUD `refresh()` recreated 6 StyleBoxes + a Theme per tool button and re-laid out the rail 3× | ~5 ms | Styling, layout and find-cards are cached by a signature and rebuilt only when it changes |
| `ArtCatalog.texture()` hit the filesystem for every cell draw (and would decode and scan the PNG once art lands) | scales with art | Textures cached under the default art root |
| Dig draw allocated a `RandomNumberGenerator` per cracked/dusty/inclusion cell and duplicated a Dictionary per cell | ~1–2 ms on redraw | Stable hash noise; reads the pending grid directly |
| Strata walls: 2 draw calls per layer per column (~900 commands) | GPU / web | One textured rect per wall |

**Still worth doing:**
- `museum.gd` calls `queue_redraw()` on the whole 2000×1480 hall every frame. Redraw only while guests or tweens are animating, or split the static hall into its own `CanvasItem`.
- Add a tiny perf test (in the style of `test_hold_dig_perf`) that fails if `GameState._process` + `hud.refresh` exceed a budget, so the regression can't return silently.

## 2. Text clipping and small UI bugs

- ✅ Pickaxe/Shovel role lines overflowed their tool cards. They're shorter now ("Break stone · chips bone").
- ✅ At 1080p the shop row's effect line collided with the rank pips. Rows are 8 px taller.
- ✅ The empty-hall line rendered as "Nothing   on display   yet". It's tight now, and it adds "click a ribbon to unveil" when finds are waiting.
- ✅ The cursor tool tag used the engine fallback font. It now uses Libre Baskerville with an outline.
- ✅ The wallet `$/s` disagreed with the hall header after mounting a find (it was stale until the next money tick).
- ☐ The museum can't zoom out far enough to see every stand (`_zoom_min` fits width only; bottom stands are cut). `test_hall_spotlight` locks this, so it needs your call. **Recommend:** min zoom = fit both axes, default = fit width.
- ☐ Unveil ribbons cross the whole stand art and cover the skeleton you're meant to admire. Use a corner sash or a small "Unveil" tag instead.
- ☐ The shop's locked "Hands II" card takes about 40% of the page to say one sentence. Collapse locked tiers into a one-line gate row.
- ☐ 3 stale assertions in `test_catalog_chrome` (bright wallet plate) predate this pass and fail on `main`. Either restore the bright plate or delete those asserts.

## 3. Dig perspective (the core screen)

What reads poorly today (see the mid-game screenshot): columns step down **independently per cell**, so a partly dug pit looks like a jagged bar chart of tan tiles rather than a hole. The north/west/east faces are blue-grey bands, and there is a big blank border between the backdrop cutout and the pit.

Recommendations, cheapest first:
1. **Depth shading on tops.** Darken each cell's top by `depth × k` *and* add an inner shadow on the edges that border a shallower neighbour (all four sides, not only south). This alone makes dug areas read as holes.
2. **Shared walls instead of per-cell drops.** Where a cell is deeper than its north neighbour, draw the exposed wall in that neighbour's strata colours. The textured strata helper that now exists makes this cheap.
3. **Occlusion awareness.** A sunken bone cell is partly hidden by the row in front, and clicks go to the front row. Either cap the visual sink harder for exposed bone, or aim-assist: prefer an exposed fossil cell when the cursor is inside its rect.
4. Make the backdrop cutout hug the pit (the tan margin reads as a second, misaligned frame).
5. Particles: add 2–3 larger "chunk" particles that bounce once on the pit floor for rock breaks.

## 4. Tools

**Hands ✅ now the survey tool.** Every hand strike feels for bone within `hands_sense_radius` and marks it with ivory corner ticks, a bone glyph, a ping and a "Bone below!" float. The radius grows from 1.0 to about 5.2 cells through Calloused Fingers and Fieldcraft, so hands are the way to scout big claims instead of blind shovelling. Next ideas:
- "Sure Grip": clicking a fully exposed but unbrushed bone with Hands extracts it at once for a quick bank, trading value for time.
- Show the sense radius as a faint ring around the hands cursor, like the shovel's.

**Brush ✅ now has a skill loop.** Back-and-forth scrubbing builds a combo (×1.2 per reversal, up to ×2). Dust pitch rises and a `SCRUB ×N` tag appears at the cursor; the combo fades if you stop. Brush upgrades widen the bristles to dust neighbouring bone cells (shown as a second ring). Next ideas:
- A visible dust layer that wipes away where the cursor passes (a per-cell mask texture), which is far more tactile than a colour lerp.
- A "Pristine" bonus (+25% value, a sparkle) for a bone brushed to 100% without a single chip.

**Shovel / Pickaxe:** add per-tool **tier looks** (rusty → steel → Super → Titan) in both the toolbar icon and the cursor so upgrades are *seen*, not only read.

## 5. Upgrade scaling (why ranks feel small)

Almost every rank is **additive** (+0.20 click power, +6 s, +6% money) while costs are **exponential** (×1.65–×2.6 per rank). So each purchase is a smaller share of your power, while its price keeps climbing. Recommendations:
1. **Milestones on max rank.** Maxing any upgrade grants a one-off ×2 to that stat, with a gold "MASTERED" pip. This creates spikes to chase.
2. **Multiplicative where it's felt.** For click power and `money_mult`, use ×1.25 per rank instead of +0.2 or +6%. Keep additive for time and radius, where the numbers are already concrete.
3. **Before → after on purchase.** You already have `shop_effect_line`. Flash "Dig power 1.4 → 1.75 (+25%)" on buy, and for pit upgrades show the new footprint on the next dig start.
4. The first shift after a purchase should *prove* it: e.g. auto-select the upgraded tool and pulse its cursor ring (the `boosted_tools` path exists; extend it to all tools).

`docs/PRIORITY.md` parks the economy retune until later. Items 1 and 3 are feel-only and safe to do now. Item 2 is the retune.

## 6. Cooler upgrades (reuse existing systems)

| Upgrade | Hook it reuses | Why it's fun |
|---|---|---|
| **Seismic Tap** (Hands T3) | `_sense_bone` on shift start, radius 2 around a random bone | "What's under there?" answered by skill, not luck |
| **Dynamite** (Pickaxe T3, 1 charge/shift) | `_apply_pickaxe` with radius 3, ignores HP on rock | Big, loud, once per shift |
| **Air Scribe** (Brush T3) | brush reach plus auto-scrub while held still | The late-game brush feels mechanised |
| **Field Crew** (existing `passive_miner` stub) | `_strike_current` on a timer at a placed cell | The listed "placement comes later" item |
| **Golden Hour** (Site) | Lucky Strike spawns ×2 in the last 10 s | Puts a climax at the end of every shift |
| **Curator's Eye** (Museum) | featured stand; unveil rush | Completed skeletons unlock a second spotlight |

## 7. Progression: building full skeletons

✅ **Done:** finishing a stand now pays its full bone value ×2, **doubles that stand's visitors permanently**, and fires a toast, fanfare, shake and big float. Before this, completing a dinosaur was silent even though DESIGN.md names it "the biggest reward moment".

Next:
- A **collection strip** on the dig HUD and the summary: "T. rex 4/6 · Triceratops 6/7". The player should always know how close they are ("one more piece and the Triceratops is done").
- **Weighted spawns toward near-complete stands** (e.g. ×2 weight on the missing pieces of a stand at ≥ 70%). `_choose_main_find` already prefers missing pieces; add the near-complete bias.
- **Hall completion moment:** the skeleton lights up, and a short camera move to the stand runs the next time the museum opens.
- **Summary callout:** "Stegosaurus: 1 piece left" under Dig again.

## 8. Screens and hierarchy

- **Title:** flat brown with three buttons. Show the actual pit, or the museum's best skeleton, behind a darker scrim, with a subtitle ("Dig. Brush. Build a museum.") and "Continue — Day N / $X" when a save exists.
- **Summary:** good structure. Make the money counter tick up, put new pieces first with their set progress, and drop "Back" from this context (Dig again / Museum / Upgrades covers it).
- **Shop:** add a "Best next buy" highlight across tabs, and show the rank pips' *next* effect on hover (P5 in PRIORITY.md).
- **Museum:** header stats are great. Add per-stand completion bars on the plaques and make the featured stand obvious from zoomed out.

## 9. Suggested order

1. ✅ Performance, clipping, wallet sync (this pass)
2. ✅ Hands survey, brush combo, skeleton completion (this pass)
3. Dig depth shading + shared walls (§3.1–3.2): the biggest visual upgrade to the core screen
4. Collection strip + near-complete spawn bias (§7)
5. Max-rank mastery + before→after purchase flash (§5.1, §5.3)
6. Two new T3 upgrades (Seismic Tap, Dynamite)
7. Title/summary polish; museum zoom decision
8. Economy retune (§5.2) last, per `PRIORITY.md`

---

## 10. Bone condition system (built after playtest)

Replaces bone breaking, which never really happened (hold-dig skipped bone).

- **Condition** (Poor / Fair / Good / Great / Perfect) is rolled when the pit is made and revealed when the bone is fully dug out. It sets value (0.5x-2x) and museum visitors (0.5x-2x). Gentle Digging / Gentle Picking improve the odds. Tools never damage bone.
- **Brushing:** 2-4 layers of dirt (by depth) wipe away where the brush passes. A starter brush lifts half a layer per pass.
- **Museum:** a better copy upgrades the exhibit (the old one is sold). Stands show average condition stars.
- **Fragile bones** (~20%) and **Opal bones** (~6%, worth 2.5x) crumble one condition step at a time once in open air. A countdown ring over the bone and the find card show the time left.
- **Plaster Cast** (Hands upgrade, 3 ranks): hold Hands on a dug-out bone to wrap it, like a cast on a broken arm. It stops crumbling and is collected at once.
- **Feedback:** reveals, upgrades and finished skeletons pop a ribbon on the Finds tray border. It's louder for better finds and never covers the dig cells. First-time explanations appear as its second line.

Next (phase 3): a museum repair upgrade that restores a crumbled piece one step for money, and *Masterpiece* skeletons (complete, all Fine or better) with a gold plaque and a big bonus.
