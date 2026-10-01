# PROGRESS — FourSeasons

**Last updated:** 2026-09-30
**Project root:** `C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons`
**Engine:** Godot 4.7.2 stable (`4.7`, GL Compatibility renderer)

> **Read this file at the start of every session before making changes.**
> The actual project files are the source of truth. If this file and the code
> disagree, the code is correct and this file is stale — fix this file.

---

## 1. Game Overview

**What it is:** A 2D local co-op platformer built in Godot 4.7.2. Two players
share one keyboard and can climb on each other's heads to reach higher places.
They are **cats in Spring and dogs in Summer** — same controls, same movement,
same ride/stack system, only the artwork changes.

**Main concept:** Two-player local co-op platforming where the players are the
platforms for each other. One player can stand on the other's head, be carried
around, and jump off.

**Two seasons are playable: Spring and Summer.** Each has its own goal, its own
collectables and its own completion screen, and the shared `Next Level` button
chains one into the other. Autumn, Winter, a season selector and a level manager
still **do not exist**, and the chain currently loops Spring -> Summer -> Spring
because there is nowhere after Summer to go yet.

**Each season's goal is sorting, not a door.** The exit door that used to be in
the level has been **removed entirely**. In Spring a cat carries soil, then
seeds, then water to a pot, in that order, and the plant grows into a flower:

```
Pot_Empty -> Pot_Soil -> (seeds) -> Pot_Sprout -> Pot_Flower -> Level Complete picture
                                                            +-> Next Level button -> Summer
```

In Summer a dog carries rubbish to the bin that matches it:

```
Paper   -> Paper Bin   \
Plastic -> Plastic Bin  >-> (all three) -> Level Complete picture
Glass   -> Glass Bin   /                     +-> Next Level button -> Spring
```

**Current MVP scope (what is actually playable today):**
- **Spring**: one single-screen level with flat ground, three floating
  platforms, two side walls, two cats, three collectable gardening items and a
  plant pot.
- **Summer**: one single-screen level with sand ground, three platform shelves, a
  sea drawn behind everything, two dogs, three pieces of rubbish and three bins,
  each of which accepts exactly one kind.
- Full movement, jumping, stacking, carrying, and player-to-player collision —
  identical in both seasons, and unchanged by either.
- Either season's goal shows the `Level Complete` picture and, with it, a
  clickable `Next Level` button that loads the other season.

---

## 2. Current Features

Everything in this section was **read from the code and/or verified by running
the project and the automated test suites.**

### Godot project setup
- Godot 4.7.2, `config_version=5`, renderer `gl_compatibility`.
- Main scene: `res://scenes/Level.tscn`.
- Viewport 1280x720, stretch mode `canvas_items`.
- `3d/physics_engine="Jolt Physics"` is set in `project.godot`, but this is a
  2D game so it has **no effect**; 2D physics is Godot Physics.
- **This is a git repository since 2026-10-01.** The project had no version
  control at all until then; the first commit is the working project as it stood
  before the Summer bin fixes, and the second is those fixes. `git log` is now
  meaningful, and `.gitignore` keeps `.godot/`, `/android/`, build output,
  throwaway `/_probe_*` measurement scripts and OS clutter out of it.

### 2-player local multiplayer
- Two players spawned by `scenes/Level.gd` from the `PLAYER_SPAWNS` array.
- P1 spawns at `(120, 559)`, P2 spawns at `(232, 559)`.
- Each player is a separate `Player.tscn` instance with its own exported
  input actions and its own cat texture.
- Input is read through Godot's `Input` singleton using per-player exported
  action names, so the two players never share a key.
- On-screen help labels in `Level.tscn` show the controls.

### Player 1 controls
- `A` = left, `D` = right, `Space` = jump.
- Actions: `p1_left`, `p1_right`, `p1_jump`.
- Physical keycodes 65, 68, 32.

### Player 2 controls
- `Left Arrow` = left, `Right Arrow` = right, `Enter` = jump.
- Actions: `p2_left`, `p2_right`, `p2_jump`.
- Physical keycodes 4194319, 4194321, 4194309.

### Cat1 / Cat2 sprites
- P1 uses `assets/Spring/Cat1.png`, P2 uses `assets/Spring/Cat2.png`.
- Each player crops its PNG to the opaque artwork via an exported
  `cat_region` (`Rect2(11,16,129,96)` for P1, `Rect2(9,15,128,96)` for P2), so
  the visible cat is centred and its feet line up with the collider base.
- `_apply_artwork()` scales the cat uniformly to `display_height` (56px) with no
  distortion, so proportions are never squashed.
- Each player has a `NameLabel` showing `P1` / `P2`.
- **Facing direction is fixed and verified:** both cat textures are authored
  facing LEFT, so `flip_h = true` is what turns them right. This is handled in
  `Player.gd` and covered by an automated test.
- **Summer swaps only the artwork.** P1 uses `assets/Summer/Dog1.png` and P2 uses
  `assets/Summer/Dog2.png`, both cropped to `Rect2(8, 24, 240, 208)`, through the
  **same `cat_texture` / `cat_region` fields** and the same `display_height` of
  56. The dogs are also authored facing LEFT, so facing, stacking, carrying and
  every control work with **no change at all to `Player.gd` or `Player.tscn`**.
  The field names are now a misnomer; see §7.

### Movement
- `SPEED = 260.0`, horizontal only, no acceleration/friction (instant).
- Direction read via `Input.get_axis(left_action, right_action)`.

### Jumping
- `JUMP_VELOCITY = -600.0`, `GRAVITY = 1400.0`.
- Coyote time `COYOTE_TIME = 0.1`s and jump buffering `JUMP_BUFFER = 0.1`s are
  both implemented, which makes jumps feel fair and responsive.
- Floor snap (`floor_snap_length = 6.0`) is disabled only while rising
  (`velocity.y < 0.0`), so a jump is never cancelled before it has moved, and
  is restored immediately afterwards.

### Gravity
- Constant gravity applied in `_physics_process` every frame.
- Measured jump height in the tests is ~133.7px.

### Ground / platform collision
- Ground and platforms are built at runtime by `Level.gd` from constants, not
  hand-placed in the editor.
- Tiles are 64x56. Ground is a 20-column, 3-row block starting at row 10.
- Three floating platforms at rows 8, 6 and 4.
- Each tile is a `GroundTile.tscn` `StaticBody2D` on **collision layer 1**.
- Tiles below the top ground row are flipped vertically (`buried = true`) purely
  for looks; the collider is unaffected.
- Two side walls are generated as `StaticBody2D` (layer 1) with a `Polygon2D`
  drawn on top.

### Player-to-player collision
- Players are `CharacterBody2D` on **collision layer 2**, mask **3**
  (layer 1 = world, layer 2 = players).
- Player collider is a `RectangleShape2D` of **60x52**, positioned at
  `(0, -26)`, so the collider hangs below the node origin and the node's y
  position is the cats' feet.
- Side-by-side players are solid and do not interpenetrate. **Verified.**

### Stacking
- A player standing on another player forms a **ride link**: the supporter adds
  the rider to its `_riders` list, and the rider records the supporter in
  `_support`.
- The rider rests exactly one body height above the supporter; the offset is
  derived from the collider size, not from current positions.
- The supporter **explicitly places the rider vertically** each step (both in
  the air and on the ground) and **carries it horizontally** by the same delta
  it moved, as long as the rider is not pressing its own movement key.
- If the rider presses its own direction, the supporter stops carrying it
  sideways so it does not move at double speed; the rider then steers itself.
- A rider is considered "perched" only while its horizontal offset from the
  supporter is within half the body width, so walking off the head ends the ride
  immediately.
- A supporter that has jumped **carries the rider up with it**, keeping the
  pair together through the whole jump. **Verified.**
- A rider that jumps **leaves the stack** by clearing its own support, rises
  above the supporter, and lands back on the head it came from. **Verified.**
- Links are kept alive for a short grace period (`SUPPORT_GRACE = 0.1`s) and,
  while the supporter is rising, within `RIDE_CATCH = 10.0`px of the riding
  offset, so a link does not time out from under a standing rider.
- `Level.gd::_process()` re-sorts the two players' `z_index` by y position
  every frame so the lower cat is always drawn behind the upper one.

### Spring gardening mechanic
Added 2026-09-28. Full description in §2.1; rules in §6.

- `GardenItem` (`Area2D`, layer 8, mask 2) is one collectable thing. Three of
  them are built by `Level.gd`: soil, seeds, water.
- An item is picked up by **standing in it**, and only if the cat's hands are
  empty. Picked up by `Player.pick_up()`, which shows the item beside the cat.
  The cat's own label is left alone — it just stays `P1`/`P2`, because the
  picture beside the cat already says what is being carried.
- **One item per cat.** A cat already carrying something cannot pick up a
  second item; the item is simply ignored until the first one is dealt with.
- Picking an item up gives the cat **two `Callable`s**, so `Player.gd` never has
  to know what type of thing the item is: `respawn` (put it back) and `consume`
  (use it up for good).
- There is **exactly one lot of each item in the level**, and an item only ever
  leaves it one of two ways:
  - **Put back.** A refused item goes to its own spawn point with a
    `respawn_delay` of 0.35s before it can be taken again, so the physics server
    has a frame to forget where it was.
  - **Used up.** When the pot takes it, the node is **removed from the level
    for good** — it is not hidden, not moved, and never recreated.
- `PlantPot` (`Area2D`, layer 8, mask 2) holds the five stages and the only
  rule: it wants soil, then seeds, then water, in that order.
- The pot polls the cats standing in it every frame rather than using
  `body_entered`, so a cat already carrying the right thing can walk straight
  in and be served.
- **Wrong items are refused and can be handed back.** Standing at the pot with
  the wrong thing prints `WRONG ITEM - JUMP TO PUT IT BACK`; jumping there puts
  it back on its spawn point. This is what stops a wrong pick-up from
  dead-ending a player with nothing to do. A refused item is only put back —
  it is never used up.
- The item is only consumed **after** the pot has moved to its next stage.
- Watering produces a sprout, which grows into the flower by itself after
  `grow_time` (default 3.0s). Nobody has to carry anything for that part.
- `Pot_Flower` emits `level_complete`, which `Level.gd` uses to start the pause
  before the `Level Complete` picture appears. That is the whole end-of-level
  behaviour for now.
- **No item carries any text.** The pictures speak for themselves.

### The pause before the Level Complete banner
**The banner no longer appears on the same frame as the flower.** Growing the
flower is the reward, so it is left alone on screen for a moment first.

- `Level.gd` has `@export_range(0.0, 5.0, 0.1) var complete_banner_delay:
  float = 1.5`. 1.5s is the middle of the 1-2s that was asked for. Set it to
  `0` to get the old instant behaviour back.
- `_on_level_complete()` does **not** reveal anything. It sets
  `_banner_timer = complete_banner_delay`, and `_process` counts that down and
  calls `_reveal_banner()` when it reaches zero.
- It is a plain `float` countdown in the existing `_process`, not a `Timer`
  node and not an `await`, so there is nothing new in the scene and nothing that
  can be orphaned or left dangling if the level is freed.
- The countdown is **guarded** (`_banner_shown`, and `_banner_timer >= 0.0`), so
  a second signal can neither start a second countdown nor reshow the banner.
  The pot only fires once anyway, but the guarantee is now local and obvious
  rather than something to have to remember.
- **The pot was deliberately not touched.** `PlantPot._set_stage()` still emits
  `level_complete` on the very frame it becomes a flower, so the signal keeps
  its honest meaning of "the pot is now a flower" and the delay lives with the
  thing being displayed rather than with the game rule.

Measured, not assumed. Under a real renderer at 60fps the banner appeared at
**1501ms** for a 1.5s pause, and a headless run tracked `_banner_timer` against
the wall clock to within a few ms across the whole pause. The countdown is
driven by `delta`, so it is frame-rate independent.

### Known gap: the banner covers the flower once it appears
The pause gives the flower its moment, but the banner then lands on top of it
and hides it completely. Measured from two real frames of the finished level:
the flower is at `x 848..952, y 384..560` and the banner at `x 286..993,
y 168..552`, so the banner covers **100% of the flower** (95.5% by area before
the reveal, and after the reveal the flower contributes 0 of its own pixels
where the banner's orange contributes 6996). The flower's `Pot_Flower` colours
are plainly present in the frame captured mid-pause and entirely absent from
the frame captured after the reveal.

This is only settled if the banner is moved or resized, which would undo the
centred 708x384 sizing above, so it is recorded as an open question rather than
changed on a guess. The cheap options, if it is wanted:
- shrink the banner to about `0.85` (401x218) so its right edge lands at
  x=841, just clear of the flower, keeping it centred; or
- move the banner's centre left to about x=494, keeping its size; or
- draw the pot in front of the banner by raising the pot's `z_index` above 100,
  though that would also put the pot in front of the cats.

**The Next Level button barely adds to this.** At its authored position it
occupies `x 870..1228.4, y 542..721.2`, which clips the bottom-left corner of
the flower (`x 848..952, y 384..560`) over `x 870..952, y 542..560` — about
82x18px of the lower left. Since the banner already covers 100% of the flower,
this changes nothing in practice, and the position is the author's choice and
was deliberately not moved.

### Level complete banner
**The `LEVEL COMPLETE!` label has been replaced by a picture.** The old
`Label` node is gone from `Level.tscn`; `LevelComplete` is now a `Sprite2D`
using `assets/Level Complete.png` (`res://assets/Level Complete.png`,
`uid://boypxeav1ftwo`).

- **Centred, and confirmed centred.** The node sits at `(640, 360)`, the exact
  middle of the 1280x720 screen and of the static camera's view. The picture
  is 512x256 with empty padding around the artwork, so it is cropped to the
  opaque region with `region_rect = Rect2(16, 0, 472, 256)`, the same trick the
  cats, the items and the pot use. Scaled 1.5x it draws 708x384, landing on
  `x 286..993, y 168..551` - comfortably inside the screen.
- `z_index = 100` so it is always drawn over the level.
- `texture_filter = 1` (nearest) to match every other sprite in the project.
- `visible = false` in the scene, revealed by `_reveal_banner()` after the pause
  described below. Because the pot only emits `level_complete` at the flower
  stage, nothing else can ever start that pause.
- The artwork is a large orange signboard on a small stand, with two lines of
  lettering. The lettering is centred in the crop (centre x = 237 against a crop
  centre of 236) and sits slightly above the crop's centre, with the stand
  filling the space below it, so the whole thing reads as deliberately balanced.

**The Next Level button shares the completion screen.** `NextLevel` is a
`TextureButton` in `Level.tscn`, using `assets/Next Level.png`
(`res://assets/Next Level.png`), `z_index = 101` (above the banner). It is
positioned where the author wants it: `offset_left 870`, `offset_top 542`,
`offset_right 1382`, `offset_bottom 798`, `scale 0.7`, which draws 358.4x179.2
with its centre at `(1049.2, 631.6)`. Its bottom edge lands at y=721.2 on a
720px-tall screen, so ~1.2px of its transparent padding hangs off the bottom;
its centre is comfortably on screen, which is what a click needs, so the
position is left exactly as authored.

**It is hidden during gameplay, in two independent places.** The scene has
`visible = false`, and `_ready()` in `Level.gd` also sets
`next_level_button.visible = false` and `disabled = true`. This is deliberate:
see §9, 2026-09-30, "Next Level button was visible from the first frame". An
editor re-save once dropped the scene's `visible = false` line, and because
`TextureButton.visible` defaults to `true` the button drew from frame one —
`disabled` stops clicks but does **not** stop a button being drawn. The code
side makes that class of mistake harmless. `_reveal_banner()` is the only thing
that ever turns it on, and it runs only once the pot has become a flower.
`Level.gd` connects its `pressed` signal to `_on_next_level_pressed()`, which
loads `res://scenes/SummerLevel.tscn`.

**Verified against the real framebuffer, not just the node flags.** The finished
level was played through by hand under a real renderer and the screen was
captured twice, once with the banner showing and once with it hidden. Diffing
the two captures changed exactly 246,184 pixels inside a bounding box of
`x 286..993, y 168..551` - the 708x384 box the scene predicts, to the pixel,
with no spill outside it. Sampling inside that box returns the picture's own
colours (orange `229,126,0`, brown `68,39,10`) where the same pixels are bare
white sky in the no-banner capture, which confirms it is drawn *over* the level
rather than behind it. (Headless runs cannot do this: `--headless` uses the
dummy renderer, so `frame_post_draw` never fires and
`get_viewport().get_texture().get_image()` returns null. A real
`--rendering-driver opengl3` run is needed.)

### Exit / door
**The exit door has been deleted.** `scenes/LevelExit.tscn`,
`scenes/LevelExit.gd` and its `.uid` are gone, `Level.gd` no longer has
`EXIT_POSITION`/`EXIT_SCENE`/`_build_exit()`, and the `Props` node in
`Level.tscn` has been replaced by `Garden`. The old `player_reached_exit`
signal no longer exists — the pot's `level_complete` is the hook now.

### Camera
- A single static `Camera2D` at `(640, 360)` with limits matching the 1280x720
  viewport. The level fits exactly one screen, so there is no camera scrolling
  or following.

### Automated test suites
Four headless test scenes exist purely for verification. They build the real
level, drive it with simulated input, and assert on the results.

- `_stack_walk_test.tscn` / `_stack_walk_test.gd` — **66 checks, ALL PASSING.**
- `_stack_jump_test.tscn` / `_stack_jump_test.gd` — **41 checks, ALL PASSING.**
- `_garden_test.gd` (`_garden_test.tscn`) — **133 checks, ALL PASSING.** Covers
  the whole gardening mechanic: both cats picking things up, one item at a
  time, the pot refusing everything out of order, a used-up item being gone from
  the level for good and not re-pickable at its old spot, the plant growing into
  the flower, level completion, the water being out of a single cat's reach,
  carrying an item while stacked, and no wording on any item.
  A new section 1b checks the completion display specifically: that the old
  `LEVEL COMPLETE!` wording is gone, that `LevelComplete` is a `Sprite2D` and
  not a `Label`, that it carries the new picture, that it starts hidden, is
  cropped to its artwork, is centred on `(640, 360)`, is big enough to read,
  stays inside the screen and draws on top — and that the `NextLevel` button is
  a real `TextureButton` with the `Next Level` picture, **hidden and inert
  before the level is finished**, whose centre is on screen so it can be
  clicked, and which is drawn above the banner. Sections 7, 8
  and 9 now also check the banner is still hidden at the soil, seeded, sprout
  and growing stages, and appears with the correct texture exactly once the pot
  is at `FLOWER`, with the Next Level button turning up on the same screen and
  **not being moved** from where it was authored.
  Section 8 additionally covers the pause: the banner is not on screen on the
  very frame the flower appears, not halfway through the pause, nor with the
  pause nearly over; the flower is on show by itself throughout; and the wait
  really was about as long as `complete_banner_delay` asks for.
- `_next_level_test.gd` (`_next_level_test.tscn`) — **20 checks + a live scene
  change, ALL PASSING.** Drives a real Spring run (soil, seeds, water, flower),
  checks the completion pause and that the Level Complete picture and Next Level
  button appear together, then presses the button. The press loads the built
  Summer level, which detects the `--next-level-check` user argument, prints
  `NEXT LEVEL REACHED SUMMER` and exits 0 — so the round trip leaves Spring and
  lands in Summer. The test never presses unless every prior check passed.
- `_summer_test.gd` (`_summer_test.tscn`) — **152 checks, ALL PASSING.** Builds
  the real Summer scene and drives it. Proves Summer is built and is not Spring;
  two dogs cropped to the dog art with Spring's controls untouched; sand on all
  69 tiles; the sea is sprites only, nothing solid in it, drawn behind the level;
  three bins with three different pictures, spaced 260-300px apart, standing on the
  ground with their artwork's bottom edge on it and centred over their own node,
  and none of them drawn into a wall or on top of a dog; three pieces of rubbish,
  each nearest its own bin; the completion banner and button hidden and inert at
  the start; both dogs walk, jump, face correctly and stack on their own keys, and
  can stack while carrying. **Every piece of rubbish is jumped for for real** from
  the sand shelf below it, once with one dog and once with the two dogs stacked.
  **All six wrong-bin pairs** show `Wrong bin!`, keep the item in the dog's hands,
  consume nothing, fill no bin, and do not finish the level — and the notice clears
  itself once the dog has left. Each right bin sorts for good, the rubbish cannot
  be picked up again at its old spot, and the completion screen only arrives after
  the third sort. The Next Level button is deliberately **not pressed** (that would
  free the test), so its target is read from the level's `NEXT_SCENE` constant
  instead.

**412 checks total, 0 failures, across five suites.** (The 67/42 figures in
earlier versions of this file were off by one each: they counted the
`ALL CHECKS PASSED` summary line as a check. The real counts were always 66 and
41. The garden suite went from 81 to 102 when the permanent-consumption rules
were added on 2026-09-28, from 102 to 116 when the completion banner was changed
from a label to a picture on 2026-09-28, from 116 to 125 when the pause before
the banner was added later the same day, from 125 to 132 when the Next Level
button was added, and from 132 to 133 when the button-position guard was added.
`_next_level_test` was added with the button, and `_summer_test` (129) with
Summer on 2026-09-30, later 152 on 2026-10-01 when the bin-anchoring,
wall-clearance and rubbish-reachability checks were added.)

How to run them (headless, no editor needed):

```powershell
& "C:\Users\Chloe Cheng\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --headless --path "C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons" `
  --scene "res://_stack_walk_test.tscn"
```

Swap the scene for `res://_stack_jump_test.tscn`, `res://_garden_test.tscn` or
`res://_summer_test.tscn` to run the others. Those four print
`ALL CHECKS PASSED` at the end. The season-transition suite needs a user
argument the Summer level looks for, and instead of a summary it ends by printing
`NEXT LEVEL REACHED SUMMER` and quitting 0:

```powershell
& "C:\Users\Chloe Cheng\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --headless --path "C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons" `
  --scene "res://_next_level_test.tscn" -- --next-level-check
```

To smoke-test the real game (Spring, the main scene):

```powershell
& "C:\Users\Chloe Cheng\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --headless --path "C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons" --quit-after 300
```

and for Summer, add `--scene "res://scenes/SummerLevel.tscn"`.

That pair was last run for 180 frames each with **zero errors and zero
warnings**.

### 2.1 Where the Spring gardening things are

All three items and the pot are declared in `Level.gd` (`GARDEN_ITEMS` and
`POT_POSITION`) and built in `_build_garden()`. The existing ground and
platform layout is **unchanged** — no new platforms were added.

| Thing | Position | Notes |
|---|---|---|
| Soil | `(460, 532)` | Flat ground on the left, no platform overhead. The easy first errand. |
| Seeds | `(640, 308)` | On the row 6 platform (top y=336). |
| Water | `(1024, 16)` | Top right corner, above the row 4 platform. |
| Pot | `(900, 560)` | Flat ground on the right. |

**The water deliberately needs both cats.** A single cat's feet never get above
y=90, even jumping off the highest platform in the level (row 4, top y=224), and
the water's pickup box only reaches down to y=32. A cat standing on the other's
head starts one body height higher (y=172) and jumps to y=38, which is inside
the box. Either cat jumping is enough, and the top cat collects the water on the
way past it, so **no landing on anything is required** — which matters, because
a rider can never end up standing on something directly above its supporter
(the supporter owns the rider's height).

**The pot is not under a platform on purpose.** The platforms cover x=192..768
and the pot grows to 176 tall with a status label above it, so at x=640 its
label would have been hidden behind the row 6 platform. `_garden_test` §8
checks this at every stage so a future move cannot reintroduce it.

### 2.2 The Summer sorting mechanic

Everything in Summer is declared in `SummerLevel.gd` (`TRASH_ITEMS`, `BINS`,
`PLAYER_SPAWNS`, `PLATFORM_ROWS`) and built in `_ready()`. The map is
1280x720 with 64x56 tiles; the ground surface is y = 560, the same as Spring.

| Thing | Position | Notes |
|---|---|---|
| Paper | `(434, 322)` | Floating above the row 8 platform (surface y=448), the way the picture puts it. Jump for it from that platform. |
| Plastic bag | `(752, 200)` | Floating above the row 6 platform (surface y=336), above the right-hand end of it. Jump for it from that platform. |
| Glass bottle | `(1136, 230)` | Level with the right-hand end of the row 4 platform (surface y=224). Jump for it from that platform. |
| Paper bin | `(560, 560)` | Flat ground, left of the bins. |
| Plastic bin | `(860, 560)` | Flat ground, centre. |
| Glass bin | `(1120, 560)` | Flat ground, right. |

**Why the bins cannot sit anywhere else on the ground.** The beach floor is
already spoken for, and all three of these were measured in the built level, not
guessed: the two dogs start at x=120 and x=232 and their pictures reach to
x=264, and the lowest sand platform covers x=320..512, which is precisely the band
a bin standing on the ground would be drawn into (bin art is 112 tall, so its top
lands at y=448, inside that platform's 448..504). The left wall takes x=0..16. So
the ground a bin can actually stand on starts at x≈560, and the bins are spaced
along it from there. Each bin is the nearest bin to its own rubbish by a clear
margin (paper 126px, plastic 108px, glass 16px in x), and every piece of rubbish is
checkable by actually jumping for it — `_summer_test` §3 stands a dog on the shelf
below each piece and confirms the pickup happens, once with one dog and once with
the two stacked.

**The sea is scenery, not a hazard.** `Water.png` is drawn as plain `Sprite2D`s
in a `Water` node at `z_index = -10`, behind everything, with **no collider**. It
cannot be stood on, walked into or picked up, and `_summer_test` §1 asserts
exactly that (80 sprites, no `CollisionShape2D` anywhere under it, none at a
non-negative `z_index`).

**The bins stand on the ground, they do not hover over it.** `TrashBin.gd` lifts
the centred sprite by half its own height (`offset = (0, -region.height * 0.5)`,
the same anchor `Player.gd` uses for the dogs), so the artwork's bottom edge lands
exactly on the node and its middle sits over the node. With every bin at y=560 the
art really is drawn from y=448 to y=560 — measured against a real render, and
asserted in `_summer_test` §1 from `TrashBin.drawn_rect()`, which reads the sprite's
own transform. Before this was fixed the artwork hung a whole `display_height`
above the ground and a half-width to the left of its node, which is what had the
paper bin's picture overlapping the left wall.

**The bins are far enough apart that nothing sorts by accident.** Their pickup
boxes are 90x110 and sit 210px and 170px apart (paper 515..605, plastic 815..905,
glass 1075..1165 on the x axis). `_summer_test` §1 measures the real colliders and
asserts they neither overlap nor touch even with 24px of slack, that no dog can be
in two at once, and that no bin is drawn into a wall or on top of a dog.

**The rule, in full** (`TrashBin.gd`, four branches):
- a dog with empty hands is ignored, so standing next to a bin is never a problem;
- the wrong kind emits `wrong_bin` — the level shows `Wrong bin!` and takes
  **nothing**. The item stays in the dog's hands and can be carried to the right
  bin;
- the right kind calls `Player.consume_carried()`, latches `is_filled` and emits
  `rubbish_sorted`. **The item's node leaves the level for good** — it does not
  come back to where it was found, which is the one behaviour this rule exists to
  guarantee and `_summer_test` §4 checks by standing an empty dog back on each
  item's old spot;
- the bin node stays in the level either way, filled or not.

**Completion.** `rubbish_sorted` is counted against the kinds taken from the bins
themselves, so the level and its bins cannot disagree about what "finished"
means. After the third kind there is the same 1.5s pause Spring uses, then the
shared `Level Complete.png` and the shared `Next Level.png` button together. The
button was hidden and disabled from the first frame and is only shown by
`_reveal_banner()`, exactly as in Spring.

**The notice.** `Wrong bin!` is one `Label` at the top of the screen
(`z_index` 102, above the completion banner). It re-shows every frame while a dog
carrying the wrong thing stands in the bin, and takes itself down 1.2s after the
dog leaves. `_summer_test` checks it does not cover any bin or any piece of
rubbish, so it cannot hide what the player needs to see.

---

## 3. Current Assets

**Assets are grouped by the level they belong to.** Everything that is only
used by Spring lives in `assets/Spring/`; a file that any level would need
lives loose in `assets/`. Reorganised 2026-09-30 — see §9. The rule for where a
new picture goes: *if only one season would ever use it, put it in that
season's folder; if it is shared, leave it in `assets/`.*

```
assets/
  Level Complete.png        <- shared, used by every level
  Cat.png                   <- unused
  Spring/
    Cat1.png
    Cat2.png
    BasicTile.png
    Soil.png
    Water.png
    Seeds.png
    Pot_Empty.png
    Pot_Soil.png
    Pot_Sprout.png
    Pot_Flower.png
  Summer/
    Dog1.png
    Dog2.png
    Sand.png
    Water.png
    Paper.png
    Plastic bag.png
    Glass bottle.png
    Paper Bin.png
    Plastic Bin.png
    Glass bin.png
```

| File | Used for | Currently in use? |
|---|---|---|
| `assets/Spring/Cat1.png` | P1's cat artwork (129x96 region cropped) | **Yes** — preloaded in `Level.gd`, also the default in `Player.tscn` |
| `assets/Spring/Cat2.png` | P2's cat artwork (128x96 region cropped) | **Yes** — preloaded in `Level.gd`, assigned to the second spawn |
| `assets/Spring/BasicTile.png` | The single 64x56 ground/platform tile texture | **Yes** — used by `GroundTile.tscn` |
| `assets/Spring/Soil.png` | The soil collectable (opaque part 184x144) | **Yes** — `GARDEN_ITEMS` in `Level.gd` |
| `assets/Spring/Seeds.png` | The seeds collectable (opaque part 80x96) | **Yes** — `GARDEN_ITEMS` in `Level.gd` |
| `assets/Spring/Water.png` | The water collectable (opaque part 104x160) | **Yes** — `GARDEN_ITEMS` in `Level.gd` |
| `assets/Spring/Pot_Empty.png` | Pot stage 1, an empty pot | **Yes** — `PlantPot.STAGE_TEXTURES` |
| `assets/Spring/Pot_Soil.png` | Pot stages 2 **and** 3 | **Yes** — soil, and also the seed stage |
| `assets/Spring/Pot_Sprout.png` | Pot stage 4, after watering | **Yes** — `PlantPot.STAGE_TEXTURES` |
| `assets/Spring/Pot_Flower.png` | Pot stage 5, level complete | **Yes** — `PlantPot.STAGE_TEXTURES` |
| `assets/Level Complete.png` | The end-of-level banner (512x256, artwork 472x256) | **Yes** — the `LevelComplete` `Sprite2D` in `Level.tscn`, and `COMPLETE_TEXTURE` in `_garden_test.gd`. **Deliberately left in the root of `assets/` — it is shared by every level, not Spring's.** |
| `assets/Next Level.png` | The Next Level button picture (512x256, artwork 408x232) | **Yes** — the `NextLevel` `TextureButton` in `Level.tscn`, and `NEXT_TEXTURE` in `_garden_test.gd` / `_next_level_test.gd`. Also shared, so also left in the root of `assets/`. |
| `assets/Cat.png` | An earlier/generic cat image | **No — unused.** Imported by the engine but referenced by no scene or script. Safe to delete, but left alone. |
| `icon.svg` | Window/project icon | **Yes** — `config/icon` in `project.godot` |
| `.gitattributes`, `.gitignore` | Repo hygiene files | **Yes** — the project is a git repo since 2026-10-01. `.gitignore` covers `.godot/`, `/android/`, build folders, throwaway `/_probe_*` scripts and OS clutter. |

### The Summer pictures

All of Summer's art came with the project and is used as-is. Nothing was drawn,
resized on disk, recoloured or replaced. Every one is cropped with a `region_rect`
at runtime, the same way Spring crops its cats and pots.

| File | Used for | Currently in use? |
|---|---|---|
| `assets/Summer/Dog1.png` | P1's dog, replacing Cat1 (256x256, opaque `Rect2(8, 24, 240, 208)`) | **Yes** — `PLAYER_SPAWNS` in `SummerLevel.gd`, via `cat_texture` |
| `assets/Summer/Dog2.png` | P2's dog, replacing Cat2 (same crop) | **Yes** — same table, second spawn |
| `assets/Summer/Sand.png` | Every ground and platform tile (93x82, opaque `Rect2(15, 13, 64, 56)`) | **Yes** — `SAND_REGION` in `SummerLevel.gd`, applied through `GroundTile.surface_texture` |
| `assets/Summer/Water.png` | The sea behind the level (89x82, opaque `Rect2(13, 13, 64, 56)`) | **Yes** — `WATER_REGION` in `SummerLevel.gd`. **Scenery only: plain `Sprite2D`s, no collider, nothing pickable.** |
| `assets/Summer/Paper.png` | The paper rubbish (opaque `Rect2(24, 48, 224, 176)`) | **Yes** — `TRASH_ITEMS` in `SummerLevel.gd` |
| `assets/Summer/Plastic bag.png` | The plastic rubbish (opaque `Rect2(24, 16, 184, 232)`) | **Yes** — same table |
| `assets/Summer/Glass bottle.png` | The glass rubbish (opaque `Rect2(88, 32, 88, 184)`) | **Yes** — same table |
| `assets/Summer/Paper Bin.png` | The paper bin (opaque `Rect2(40, 40, 160, 192)`) | **Yes** — `BINS` in `SummerLevel.gd` |
| `assets/Summer/Plastic Bin.png` | The plastic bin (opaque `Rect2(48, 32, 160, 192)`) | **Yes** — same table |
| `assets/Summer/Glass bin.png` | The glass bin (same crop as the plastic bin) | **Yes** — same table |

> **Watch the spelling.** The file on disk is `Glass bin.png` — a **lowercase `b`**
> in `bin`. Anything referring to `Glass Bin.png` will fail to load on a
> case-sensitive filesystem. `SummerLevel.gd` uses the exact on-disk name, and
> `_summer_test.gd` preloads it the same way.

> **The dogs face left**, exactly like the cats, and are the same size
> (`display_height = 56`, same uniform scale). That is why they were assigned to
> the existing `cat_texture` / `cat_region` fields instead of needing any change
> to `Player.gd` — the field names are now a bit of a misnomer. See §7.

All twenty-two PNGs have `.import` files and are imported by the engine.

**The pot pictures are all different sizes**, and the opaque part of each is
cropped with a `region_rect` (see `PlantPot.STAGE_REGIONS`) and drawn from its
bottom edge. Without that the pot would jump about and sit at different heights
in every stage.

**Everything in `assets/Summer/` is cropped the same way at runtime** — see the
Summer table above.

No background/sky art, no audio, no fonts beyond the Godot default. None of
these exist yet.

---

## 4. Current Scenes

| Scene | Purpose |
|---|---|
| `scenes/Level.tscn` | **Main scene.** A mostly empty `Node2D` that acts as a container: `Terrain`, `Walls`, `Garden`, `Players` child nodes, a static `Camera2D`, two control-help labels, a `GoalHelp` line, a hidden `LevelComplete` banner, and the `NextLevel` `TextureButton` that shares its completion screen. `Level.gd` populates all of it in code at `_ready()`. |
| `scenes/SummerLevel.tscn` | **Summer, built 2026-09-30.** A `Node2D` that `SummerLevel.gd` fills in code at `_ready()`, exactly like Spring's `Level.tscn`: `Water`, `Terrain`, `Walls`, `Trash`, `Bins`, `Players`, a static `Camera2D`, control-help labels, a `GoalHelp` line, a `WrongBin` `Label` (hidden, `z_index` 102), the shared `LevelComplete` banner (hidden, `z_index` 100) and the shared `NextLevel` `TextureButton` (hidden, disabled, `z_index` 101, same offsets/scale as Spring). Also prints `NEXT LEVEL REACHED SUMMER` and quits 0 under `--next-level-check`, so `_next_level_test` still works. **A finished Summer loads Spring again** (`NEXT_SCENE = res://scenes/Level.tscn`) because Autumn and Winter do not exist yet. |
| `scenes/TrashBin.tscn` | One Summer bin. `Area2D` (layer 8, mask 2) with a `Bin` `Sprite2D`, a 90x110 collider at `(0, -45)`, and a `BinLabel` `Label` above it (added 2026-10-01) reading "Paper Bin" / "Plastic Bin" / "Glass Bin". Only the art and the accepted kind differ per bin, so all three are the same scene with different exported values. |
| `scenes/Player.tscn` | One cat. `CharacterBody2D` (layer 2, mask 3, snap 6) with a `Sprite2D` (`Cat`), a hidden `CarriedIcon` `Sprite2D` for a carried gardening item, a `CollisionShape2D` (60x52 at y=-26), and a `NameLabel`. Ships with Cat1 as a placeholder texture; `Level.gd` and `SummerLevel.gd` override it per player — **Summer overrides it with a dog and needs nothing else changed.** |
| `scenes/GroundTile.tscn` | One 64x56 ground/platform tile. `StaticBody2D` on layer 1 with a collider at `(32, 28)`. |
| `scenes/GardenItem.tscn` | One collectable. `Area2D` (layer 8, mask 2) with a `Sprite2D` and a `CollisionShape2D` that `GardenItem.gd` resizes from `pickup_size`. **It has no `Label` child any more** — the picture is the only thing that identifies it. |
| `scenes/PlantPot.tscn` | The pot. `Area2D` (layer 8, mask 2) with a `Pot` `Sprite2D`, a 100x170 collider at y=-85, and a `Status` `Label` that floats above the pot. |
| `_stack_walk_test.tscn` | Test scene: wraps `_stack_walk_test.gd`. Not part of the game. |
| `_stack_jump_test.tscn` | Test scene: wraps `_stack_jump_test.gd`. Not part of the game. |
| `_garden_test.tscn` | Test scene: wraps `_garden_test.gd`. Not part of the game. |
| `_next_level_test.tscn` | Test scene: wraps `_next_level_test.gd`. Not part of the game. |
| `_summer_test.tscn` | Test scene: wraps `_summer_test.gd`. Not part of the game. |
| `_diag.tscn` | A leftover physics-trace diagnostic. Not part of the game; see §7. |

---

## 5. Current Scripts

| Script | Purpose |
|---|---|
| `scenes/Level.gd` | Builds the entire level procedurally from constants: ground, platforms, walls, players, and the garden (three items plus the pot). Holds `PLAYER_SPAWNS` (per-player actions/texture/crop/spawn) and `GARDEN_ITEMS`. Every frame it sorts the players by y to set `z_index` so the lower cat draws behind. `_ready()` forces the `NextLevel` button hidden and disabled so it cannot appear during gameplay. `_on_level_complete()` starts the `complete_banner_delay` countdown that reveals the `LevelComplete` banner; `_reveal_banner()` shows the banner and the `NextLevel` button together, and `_on_next_level_pressed()` loads Summer (`SUMMER_SCENE`). Also holds `PLATFORM_ROWS`, `GROUND_ROW`, `POT_POSITION`, `TILE_WIDTH/HEIGHT`. |
| `scenes/SummerLevel.gd` | Builds the whole Summer level in code from constants, the same way `Level.gd` builds Spring: sand ground (row 10, 20 columns, 3 rows) and three platform rows, the decorative sea, walls, two dogs, three pieces of rubbish and three bins **on the ground at y=560** (paper `(560,560)`, plastic `(860,560)`, glass `(1120,560)`). Holds `PLAYER_SPAWNS` (the dogs, cropped like the cats), `TRASH_ITEMS` (paper `(434,322)`, plastic bag `(752,200)`, glass bottle `(1136,230)`), `BINS` (each bin's kind, picture, crop and position), `PLATFORM_ROWS`, `wrong_bin_notice_time` (1.2s) and `complete_banner_delay` (1.5s, the same pause Spring uses). `_on_rubbish_sorted()` counts against the kinds taken from the bins themselves and calls `_finish_level()` on the last one; `_on_wrong_bin()` shows the `WrongBin` label and starts its timer; `_reveal_banner()` shows the banner and the Next Level button together; `_on_next_level_pressed()` loads `NEXT_SCENE`. Also still quits 0 with `NEXT LEVEL REACHED SUMMER` under `--next-level-check`. |
| `scenes/TrashBin.gd` | One Summer bin. The sorting rule, and nothing else: exports `accepts_kind`, `bin_texture`, `art_region`, `display_height`; crops its own picture and anchors it **bottom edge to its node** (`sprite.offset = (0, -region.height * 0.5)`, the same anchor `Player.gd` uses — the sprite is centred, so the old `(-width * 0.5, -height)` offset drew the artwork a whole `display_height` above the ground and half a width to the left); polls overlapping players every frame and serves **every** dog in the box, not just the first (the same way `PlantPot.gd` does, so a dog that walks in already carrying the right thing is served, and a stacked pair is never missed). The right kind calls `Player.consume_carried()`, sets `is_filled` and emits `rubbish_sorted`; the wrong kind emits `wrong_bin` and **takes nothing**; an empty dog is ignored. `drawn_rect()` reports the artwork's real screen pixels, read from `sprite.get_rect()` through the sprite's global transform. **The bin node stays in the level either way.** |
| `scenes/Player.gd` | All cat behaviour: input, gravity, jumping, coyote/buffer, floor snap, artwork, facing, the ride/stack system, and carrying one gardening item. Tuning constants at the top (`SPEED`, `GRAVITY`, `JUMP_VELOCITY`, `COYOTE_TIME`, `JUMP_BUFFER`, `SUPPORT_GRACE`, `RIDE_CATCH`, `PLAYER_LAYER`, `CARRIED_ICON_HEIGHT`). Carrying is only `carried_kind`, `drop_carried()`, `consume_carried()` and `_clear_carrying()` — the movement and ride code below them is untouched. |
| `scenes/GroundTile.gd` | Flips the tile sprite vertically when `buried` is true so the ground block looks filled in. Also applies the optional `surface_texture` / `surface_region` overrides, which is how Summer puts sand on the same tile scene. **Both default to Spring's values, so Spring is unaffected.** |
| `scenes/GardenItem.gd` | One collectable. Crops and scales its picture, picks itself up when an empty-handed cat stands in it, and has the two ways out: `respawn()` puts itself back on its spawn point, `consume()` removes the node from the level for good. |
| `scenes/PlantPot.gd` | The five pot stages, the one ordering rule, the wrong-item refusal and hand-back, the permanent consumption of an accepted item, the timed sprout growth, and the `level_complete` signal. All the pot artwork is a `const` table keyed by stage. |
| `_stack_walk_test.gd` | Automated regression suite (66 checks) for walking, carrying, riding off, stacked jumps, collisions, controls, facing, art, platforms. |
| `_stack_jump_test.gd` | Automated regression suite (41 checks) for the original stacking/jump behaviour, separation, and re-stacking. |
| `_garden_test.gd` | Automated regression suite (133 checks) for the Spring gardening mechanic, including used-up items being gone for good, the water needing both cats, carrying while stacked, the completion banner being the `Level Complete` picture rather than the old label, the `NextLevel` button sharing the completion screen (real `TextureButton`, right picture, **hidden and inert before the finish**, centre on screen, above the banner, unmoved by the reveal), and the pause between the flower appearing and the banner turning up. |
| `_next_level_test.gd` | Automated end-to-end suite (20 checks) for the season transition: a real Spring run to the flower, the completion pause, the banner and Next Level button appearing together, the button's `pressed` being wired to the level's handler, and then pressing it — the scene change frees the test and the built Summer level proves the arrival by printing `NEXT LEVEL REACHED SUMMER` and quitting 0. Never presses the button if any earlier check failed. |
| `_summer_test.gd` | Automated regression suite (**152 checks**) for Summer: the scene really is built and is not Spring, two dogs cropped to the dog art, the controls unchanged, sand on every tile, the sea is decoration only and drawn behind the level, three bins with three different pictures that do not touch, each standing on the ground with its artwork's bottom edge on the ground and centred over its own node, none drawn into a wall or on top of a dog, three pieces of rubbish each nearest its own bin, the completion screen and button hidden and inert at the start, dogs move/jump/face/stack on their own keys and can stack while carrying, **every piece of rubbish is really picked up by jumping for it from the shelf below it, solo and stacked**, **all six wrong-bin pairs are refused with a notice that clears itself**, each right bin sorts for good and the rubbish cannot be picked up again, and the completion screen only arrives after the third sort. The Next Level button is never pressed — pressing it would free the test — so its target is read from `NEXT_SCENE` instead. |
| `_diag.gd` | Leftover one-off trace script used to debug the stacking bug. Prints a per-frame table and quits. Not part of the game. |

---

## 6. Controls

**Player 1**
- `A` = left
- `D` = right
- `Space` = jump

**Player 2**
- `Left Arrow` = left
- `Right Arrow` = right
- `Enter` = jump

These are defined as real Godot input actions (`p1_left`, `p1_right`, `p1_jump`,
`p2_left`, `p2_right`, `p2_jump`) in `project.godot`, so they can be rebound in
the editor without touching any script. The test suites verify all six work.

**One extra use of jump in Spring:** standing at the pot carrying the wrong
item, jump puts that item back where it was found. Nothing else about jumping
changed, and it works for both players with their own jump key.

---

## 7. Known Bugs

### ✅ Bug: an item put in the pot came back to where it was — **FIXED AND TESTED**

**Original description:** Carrying the soil (or the seeds, or the water) to the
pot worked — the pot changed stage — but the item then **reappeared at its
original position** and could be picked up again. Nothing was ever really
consumed.

**Root cause:** `PlantPot._serve()` called `player.drop_carried()` for **both**
outcomes — the pot accepting an item *and* the pot refusing one. But
`Player.drop_carried()` is the **put-back** path: it calls the `respawn`
callable that the item handed over when it was picked up
(`GardenItem._collect()`), and `respawn()` does `global_position =
_spawn_position; visible = true; is_collected = false`. So on the frame the pot
took the soil, the soil teleported straight back to its spawn point and became
collectable again. The code even had a comment claiming the item "is only
consumed after the pot has moved to its next stage" — it was consumed in name
only, and immediately un-consumed.

**The fix — one line of behaviour, split into two paths.** The distinction
between "put back" and "used up" now exists in three small places:

- `scenes/GardenItem.gd` — new `consume()`. Sets `is_consumed`/`is_collected`,
  turns the pickup box off with `set_deferred` (deferred because `monitoring`
  cannot change while the physics server is busy), hides the sprite, and calls
  `queue_free()`. The node is genuinely removed from the level, so there is
  nothing left to see, touch, pick up or offer to the pot again. `respawn()`
  now refuses to run on a consumed item.
- `scenes/Player.gd` — new `consume_carried()`, which fires the second callable
  the item handed over instead of the first. Both `drop_carried()` and
  `consume_carried()` end in a shared `_clear_carrying()` that deliberately
  calls *neither* callback — the caller decides the item's fate. Carrying is
  still strictly one item at a time.
- `scenes/PlantPot.gd` — `_serve()` calls `consume_carried()` when the pot takes
  the item, and keeps `drop_carried()` for the refusal hand-back. A refused item
  is still only put back, never used up.

**How it was verified:**
- `_garden_test.gd` §7 and §8 now assert `not is_instance_valid(item)` and a
  falling count of collectables left in the level, instead of asserting the item
  went back where it was.
- §9 is new: after the flower, a cat with empty hands is walked over all three
  spots the items used to be on, and the assertion is that **nothing is picked
  up and no item reappears**. That is done for both cats.
- **Negative test, run deliberately:** changing `PlantPot._serve()` back to
  `drop_carried()` makes **18 checks fail**, and the failure output reproduces
  the reported symptom exactly (`left=3`, `carrying=soil` at the old soil spot).
  So the suite genuinely catches this bug rather than passing for a different
  reason. Reverted straight afterwards and re-run green.
- `_stack_walk_test` 66/66, `_stack_jump_test` 41/41, `_garden_test` 102/102.
  The real game scene ran 400 frames headless with zero errors and zero
  warnings.

**Not verified:** a human has still not played it. Everything above is headless
with simulated input.

### ✅ Bug: Bottom player gets stuck when another player is standing on top — **FIXED AND TESTED**

**Original description:** When one cat stood on top of another, the bottom cat
sometimes could not move horizontally because of the player-to-player
collision/physics interaction.

**Root cause:** Two player colliders resting face to face report a **zero
collision normal** `(0, 0)`. `move_and_slide()` cannot slide along a zero
normal, so the motion of whichever cat is trying to move gets cancelled, and
Godot's depenetration shoves the pair sideways instead.

There were actually **two** separate failures, and fixing only the first made
things worse:

1. Excluding `PLAYER_LAYER` only for the **supporter** stopped the bottom cat
   freezing — but the **rider** then became the moving body getting shoved
   4.33px sideways per frame. The rider outran the supporter, fell outside the
   "perched" width window, stopped counting as a rider, and the supporter's
   collision mask snapped back on mid-stride, re-freezing it.
2. Because the rider no longer physically touches its supporter,
   `is_on_floor()` returns `false` for it, so its **coyote timer** drained to
   zero and the **top cat could not jump at all**.

**The fix (all in `scenes/Player.gd`):**
- The `PLAYER_LAYER` exclusion is now **symmetric**: a supporter ignores its
  rider during its own step, *and* a rider ignores its supporter during its
  own step. The mask is restored immediately after `move_and_slide()`.
- The supporter **explicitly places the rider vertically** and carries it
  horizontally by its own movement delta, so positioning no longer depends on
  contact at all.
- `is_on_floor() or riding` now counts being carried as grounded, which
  restores the rider's coyote time and therefore its jump.
- `_update_support()` keeps the ride link alive when there is no contact to
  detect, and while a rising supporter is within `RIDE_CATCH` px.
- `Level.gd` is unchanged. No new scenes, no autoloads, no architecture.

**How it was verified:**
- `_stack_walk_test.tscn`: **67/67 checks pass**, covering both stack orders
  (P1 on P2 and P2 on P1) for walking left/right, exact 1:1 rider carry,
  rider walking off, rider jumping off with coyote, side-by-side solidity,
  solo and stacked jump heights, no interpenetration, walking into a wall,
  re-stacking after separating, all six controls, sprite facing, artwork
  assignment, and platform collision.
- `_stack_jump_test.tscn`: **42/42 checks pass**, covering stacked jumps in both
  orders, carrying the rider up, no sinking or drift during the jump, landing
  back on the head, walking off and falling independently, independent jumps
  when not stacked, and not being permanently glued together.

> Count correction, added 2026-09-28: the two figures above were each one too
> high, because the `ALL CHECKS PASSED` summary line was counted as a check. The
> real numbers, and the ones to trust, are **66** and **41** — see §2. Both still
> pass today.
- The real game scene ran 300 frames headless with zero errors/warnings.

**Honest caveat:** verification was **headless and automated with simulated
input**. A quick manual play in the editor is still worth doing as a
confidence check, but the behaviour is not merely asserted — it is exercised
over hundreds of physics frames in both stack orders.

### Known limitation: the whole player layer is ignored while linked

`scenes/Player.gd` removes **all** of `PLAYER_LAYER` from the collision mask
while a player is linked, not just the specific supporter or rider. With
exactly two players this is correct and cannot go wrong. **If a third player is
ever added, a cat carrying a rider could walk straight through the third cat.**
Fixing this properly means tracking which specific body to ignore rather than
the whole layer. Not a bug today because there are only two players.

### Season transition: Spring -> Summer -> Spring

Growing the flower emits `level_complete`, which waits 1.5s and then reveals
the `Level Complete` picture **and** the `Next Level` button together. Pressing
the button changes the scene to `res://scenes/SummerLevel.tscn`, which is now
the **real** Summer level (built 2026-09-30 — see §2 and §9). Summer keeps the
same shared completion screen, and its button loads `NEXT_SCENE`, which is
`res://scenes/Level.tscn` (Spring) because **Autumn and Winter do not exist**.
So the chain loops Spring -> Summer -> Spring rather than dead-ending. That is a
deliberate stopgap: the moment Autumn exists, change `NEXT_SCENE` in
`SummerLevel.gd` and nothing else.

### Known gap: no seasonal content beyond Summer

See §1. Spring and Summer are implemented; Autumn, Winter, the season selector
and the level manager are all still unimplemented. Autumn/Winter were explicitly
out of scope for the Summer session.

### Known naming wart: the dogs are stored in fields called `cat_*`

`SummerLevel.gd` assigns the dog artwork to `Player.cat_texture` and
`Player.cat_region`, because that is what the existing player fields are called
and **renaming them would have meant editing `Player.gd`, `Player.tscn`,
`Level.gd` and two Spring test suites for no gameplay gain.** The dogs are the
same size and, like the cats, face left, so nothing else had to change. If the
fields are ever renamed, these are the places: the two `@export`s on `Player`,
the assignments in `Level.gd` and `SummerLevel.gd`, the `Cat` sprite in
`Player.tscn`, and `_stack_walk_test.gd` / `_summer_test.gd`.

### Known gap: no visual sign that a bin has been filled

A correctly sorted bin stays in the level and refuses everything after that,
because `is_filled` latches — but it looks exactly as it did before. There is no
lid, no colour change, no "thank you" and no per-bin counter. The only feedback
is that the rubbish is gone from the level. This was left as-is because inventing
art was out of scope; if it is ever added, it belongs as an extra `Sprite2D` or
`tint` on `TrashBin.tscn` driven by `is_filled`.

### Known limitation: a dog is sorted by touching, not by aiming

`TrashBin` polls its 90x110 box every frame, so a dog carrying the right thing
is sorted the moment its collider overlaps the bin — including brushing past it
on the way to somewhere else. That is the behaviour the brief asked for
("the player carries the item to the correct bin"), and it is also how Spring's
pot behaves, so it is consistent. But it does mean the bins need to be spaced out
enough that walking past one cannot sort by accident. They are: paper at x=560,
plastic at x=860, glass at x=1120, so the boxes sit 210px and 170px apart and
`_summer_test` §1 asserts they neither overlap nor touch even with 24px of slack.
Note that a stacked pair can now be inside a bin's box at the same time, which is
why `_serve` runs for every overlapping dog instead of stopping at the first.

### Known design risk: the water's reach margin is about 6px

The water is meant to be unreachable by one cat. A solo cat's feet top out at
y≈90 and the water's pickup box reaches down to y=32, so the margin is only
~6px. If `JUMP_VELOCITY` or `GRAVITY` in `Player.gd` are ever raised, a single
cat will start being able to reach the water and the co-op errand is lost. This
is not a crash — the item simply becomes easier to get. `_garden_test` §6
asserts the solo reach every run, so the change will be caught by a failing
test rather than going unnoticed.

### Housekeeping issues (harmless, but confusing)

- `_diag.gd` / `_diag.tscn` are leftover debug traces from the stacking bug.
  They are **not** part of the game and nothing runs them. They can be deleted.
- `_stack_walk_test`, `_stack_jump_test`, `_garden_test`, `_next_level_test` and
  `_summer_test` are test harnesses sitting in the project root. They are useful
  and passing — keep them, but do not let them be mistaken for game code.
- `assets/Cat.png` is unused.
- ~~The project is not under version control.~~ **Fixed 2026-10-01:** `git init`
  was run, a Godot `.gitignore` was added, and the working project was committed
  before the Summer fixes were started, so every change since is recoverable.
  Throwaway `/_probe_*` measurement scripts are ignored as well as deleted.

### How to move a picture after this session

`assets/` is organised by season, so a future Summer/Autumn/Winter will mean
actually moving things. Doing it **from inside the Godot editor's FileSystem
dock** (drag the file) is the safe way: the editor rewrites the references in
the scenes, fixes the `.import` file and reimports the texture, all in one
step. Doing it by hand outside the editor means four things, and missing any
one of them leaves a picture that looks fine in the folder and fails to load
in game:

1. move the `.png` **and** its `.png.import` together;
2. fix `source_file=` inside the moved `.import` to the new path;
3. update every `res://assets/...` reference (the `.tscn` `[ext_resource]` lines
   and the `preload(...)` lines in the `.gd` files);
4. run Godot with `--import` so the imported-texture path is regenerated —
   its filename contains a hash **of the source path**, so it changes whenever
   a picture moves.

Moving a picture inside the editor, by contrast, keeps its Godot `uid://` and
takes care of all four. Note that the `.tscn` files here reference textures by
**path, not by uid**, so the `uid://` values are free to change; they were
preserved anyway.

### Not bugs — gotchas when testing

These cost real time during the fix and will mislead anyone testing again:

- **GDScript lambdas capture local variables by value.** A `func():` assigned to
  a variable cannot write back to a plain local (e.g. a float). Use a one-
  element `Array` or a `Dictionary` instead. This silently made the first
  version of the test suite report false results.
- **Directly teleporting a player** (`position = ...`) does not instantly
  update the physics server. If you teleport one cat onto the spot the other
  still occupies in the physics server, they interpenetrate for a frame and
  Godot separates them by shoving one sideways — which looks exactly like the
  stacking bug. **Always park both players apart and wait a few physics frames
  before forming a stack.**
- **A fixed wait after teleporting is not enough to build a stack.** Dropping a
  cat onto another's head and waiting a set number of frames leaves it still
  falling most of the time, and a test that measures it then measures a cat in
  mid-air. `_garden_test` uses `_wait_for_stack()`, which waits for the ride
  link to actually close. Do the same in any new test — a stack test that does
  not wait can pass for entirely the wrong reason.
- **Empty hands over an item pick it straight back up.** That is the game
  working, not a bug, but it makes a "did putting it down work?" check fail if
  the cat is standing on something else at the time. Move the cat away first.
- **`disabled` is not `visible`.** A disabled `BaseButton` still draws; only
  `visible = false` hides it. This is what let the Next Level button appear from
  the first frame: the scene had `disabled = true` but had lost its
  `visible = false`, and `Control.visible` defaults to `true`. When hiding UI
  for later, set **both**, and prefer asserting `visible` in a test rather than
  `disabled`.
- **The editor can drop a `visible = false` line when it re-saves a scene.**
  `scenes/Level.tscn` came back from an editor save with `load_steps` and the
  `visible = false` gone from the `NextLevel` node, while the offsets the author
  had just changed by hand were written out correctly. Do not assume the scene
  file still holds what you last wrote to it: re-read it after any editor save,
  and keep the runtime invariant in `_ready()` as well, so a lost property
  cannot reintroduce a bug. `_garden_test` §1b caught this immediately.
- **Synthetic mouse events never reach a `Control` under `--headless`.** Both
  `Input.parse_input_event()` and `Viewport.push_input()` were tried and
  verified to deliver nothing: the button's `gui_input` signal never fires, and
  `get_window().grab_focus()` first makes no difference. Godot's GUI picking
  needs a real window. `_next_level_test` therefore proves the click by
  checking `button.pressed.is_connected(...)` and then emitting that signal
  itself — which is exactly what a real click does once BaseButton emits
  `pressed`. `Control._gui_input()` is a virtual and cannot be called directly
  either.
- **`await`ing on `self` does not survive a scene change that frees it.** The
  continuation still resumes, on a freed node, and every method call on it
  fails with `Parameter "data.tree" is null`. So a test that triggers
  `change_scene_to_file()` must not await anything afterwards; stamp the time
  and let a `_process` watchdog report the failure, because once the node is
  freed `_process` stops by itself. This is why `_run()` in
  `_next_level_test.gd` does nothing after the click.
- **A frame count is not a time.** `_next_level_test` uses wall-clock waits
  (`Time.get_ticks_msec()` + `create_timer`) for the completion pause rather
  than `_wait(60)`, because headless frame rate is not a fixed 60Hz and a
  frame-count wait can come back early or late.
- **An item that was just put back cannot be taken again for 0.35s**
  (`respawn_delay`). Wait for `_respawn_timer` rather than guessing frames, or
  a grab will silently do nothing.
- **x = 160 is not clear ground.** The platform at row 8 starts at x = 192, so
  a cat standing at x = 160 has its collider right against that ledge. Use
  x = 700 (or similar flat, open ground) for walk-off and jump tests. Note the
  pot is at x = 900 and its detection box spans x = 850..950, so keep carried
  items out of that stretch during stacking tests or the pot will eat them.
- The ground surface is y = 560; the player collider spans y-52 to y.
- **A scene whose root node has no `script =` line loads as a bare node and
  fails completely silently.** `SummerLevel.tscn` was written without it once:
  Godot reported **zero** errors and the scene ran fine, because a `Node2D` with
  no script has no `@onready` lookups to fail and simply builds nothing. Every
  test then failed on "Invalid access to property 'trash'". After an edit to a
  `.tscn`, check that the root node still has its script.
- **A new `class_name` script must be imported before another script can name
  the type.** Adding `scenes/TrashBin.gd` with `class_name TrashBin` gave
  `Could not find type "TrashBin"` from the scene that used it, until
  `godot --headless --path <proj> --import` refreshed the global class cache.
- **Overriding `_process()` with no parameters is a parse error.** It must be
  `_process(_delta: float)`. (`PlantPot.gd` and `TrashBin.gd` both need it.)
- **Indexing a `Dictionary` with a key that is not there is a runtime error, not
  a null.** Use `.get(key, null)`. Likewise, reading a **freed** object out of a
  `Dictionary` and assigning it to a typed variable raises `Trying to assign
  invalid previously freed instance` — check `is_instance_valid()` on a `Variant`
  *before* the typed assignment, not after.
- **Bins sort on contact, so a test can sort rubbish by accident.** Parking a dog
  in a bin's box means it gets served: `PARK_B` used to sit at x = 620, inside the
  plastic bin's box, which cascaded into 13 bogus failures before anything else in
  the suite was true. Any spot a test parks a dog in must be clear of every bin
  box *and* every rubbish spawn, and that has to be re-checked whenever a bin
  moves. `_summer_test.gd` has `PARK_A` (150), `PARK_B` (750) and `STACK_X` (150)
  constants chosen for exactly that reason, with the bins at x = 560, 860 and
  1120 reaching 45px either side of those points.

---

## 8. Current Task / Next Task

**DONE: the Spring gardening mechanic**, **the items are now used up for good**
rather than going back where they were found, and **completing Spring now goes
somewhere**: the `Level Complete` picture and the `Next Level` button appear
together, and pressing the button loads Summer (see §1, §2 and
§9 for what was built).

**Also done: the Next Level button no longer shows up during gameplay.** It was
drawing from the first frame because an editor re-save of `Level.tscn` dropped
its `visible = false`; the flag is restored and is now also enforced in
`_ready()`. A cold start of the real main scene was checked to confirm no
completion UI appears at all until the level is finished, and a deliberate
negative run confirmed the tests fail if that protection is removed. The
author's chosen button position was left untouched. See §9, 2026-09-30.

**DONE: Summer is built for real** (see §9, 2026-09-30). The scene is no longer a
placeholder — it is a playable single-screen level with two dogs, sand, a sea,
three pieces of rubbish, three bins, the wrong-bin notice and the shared
completion screen. A finished Summer currently goes back to Spring, because
Autumn and Winter were explicitly out of scope.

**NEXT TASK: play both seasons manually in the Godot editor.**

Everything automated is green — **412 checks across five suites** — but all of it
is headless with simulated input. A human has still not played either loop by
hand, so that is the first thing to do:

1. Open the editor and play a full Spring run, then Spring -> Summer via the
   Next Level button, with both players. Watch for what the tests cannot see:
   whether the dogs read as clearly as the cats did, whether the carried
   rubbish is legible with no words on it, whether the `Wrong bin!` notice is
   readable and is on screen long enough, whether the sea reads as water or as
   clutter behind the level, and whether a filled bin looking unchanged is
   confusing (§7).
2. Confirm the transition both ways by hand: Spring's button must land on
   Summer, and Summer's button must land back on Spring.
3. ~~`git init` and commit.~~ **Done 2026-10-01** — two commits so far: the
   project as it stood before the Summer bin fixes, and the fixes themselves.
   Keep committing as work lands; this list is the only other record of what has
   happened and it is not a substitute for history.
4. Then, and only then, decide what Autumn should be — and change `NEXT_SCENE`
   in `SummerLevel.gd` when it exists.

**One thing to watch on that first manual playthrough:** the Summer bins now sit
in a row along the right-hand half of the beach (`x = 560, 860, 1120`) instead of
being spread to the far left as the layout picture has it, because the dogs spawn
on the left of the beach floor and the lowest sand shelf covers the rest of it. A
human should confirm that row of bins still reads as three separate destinations
rather than as a fence, and that the `Bin` labels sit legibly on each.

**Explicitly not started, and not to be started yet:** Autumn, Winter, menus,
level selection, and any level-management or scene-flow architecture beyond the
single hard-coded transition. One working season chain beats four half-built
worlds. Also not done: any per-bin "filled" feedback, and any change to the
`cat_*` field names (§7).

---

## 9. Completed Work

### 2026-09-30 - Summer is built: dogs, sand, sea, three bins

**The task.** Read the project first and reuse it: two dogs in place of the cats,
a single-screen sand-and-sea map, three kinds of rubbish and three matching bins,
a wrong-bin refusal that keeps the item in your hands, a shared completion screen,
and no changes to Spring. Autumn, Winter, menus and level selection were
explicitly out of scope, and no replacement art was to be drawn.

**What was reused, deliberately.** `Player.gd` / `Player.tscn` untouched — the
dogs are assigned to the existing `cat_texture` / `cat_region` fields, which
works because they are the same size as the cats and, like them, face left, so
`PLAYER_SPAWNS` needed no new shape. `GardenItem` is the rubbish: it already had
"used up for good" (`consume()` removes the node) as distinct from "put back"
(`respawn()`). `GroundTile.tscn` is the sand, via two new optional exports.
`PlantPot.gd` was the model for `TrashBin.gd`, down to polling its area every
frame instead of using `body_entered`. The `Level Complete.png` banner and the
`Next Level.png` button are the shared ones, at Spring's exact offsets and scale.

**What was new.** `scenes/TrashBin.gd` / `.tscn` — one scene, three bins, differing
only in `accepts_kind` and the artwork. The rule is four lines: an empty dog is
ignored; the wrong kind emits `wrong_bin` and takes nothing; the right kind calls
`Player.consume_carried()`, latches `is_filled` and emits `rubbish_sorted`; the
bin node stays in the level whatever happens. `scenes/SummerLevel.gd` /
`.tscn` — the level, built in code from constants exactly like `Level.gd` does.

**The map.** 1280x720, 64x56 tiles. Ground row 10, 20 columns, 3 rows (rows 11-12
buried so the block looks solid). Platforms at `[[8,13,3],[6,8,3],[4,11,3]]` —
three shelves stepping up to the right, so the glass bottle up on the top one
needs a jump or a stack. `Water.png` is drawn as plain `Sprite2D`s behind
everything (`z_index = -10`), rows 3-6, with **no collider**: it is scenery, not
a hazard, so it can never be walked into, stood on or picked up. Bins at x = 320,
720 and 1140 on the flat ground, ~310px apart, which is why nothing can sort by
accident on the way past. The glass bin file is `Glass bin.png` with a lowercase
`b` (§3).

**The rules, as tested.** Each of the three kinds can be carried by either player
(one item, the other stays empty). Carrying does not break stacking, and a stack
can carry. **All six wrong-bin pairs** are refused: the notice appears, the item
stays in the dog's hands, the piece is not consumed, the bin does not fill, and
the level is not finished. The notice re-shows while a dog stands in a wrong bin
and clears itself 1.2s after the dog leaves. Each right bin sorts for good: the
node leaves the level, the hands empty, the bin remains, and — the bug this
mechanic exists to prevent — **the rubbish cannot be picked up a second time** at
its old spot. After the third sort there is the same 1.5s pause Spring has, then
the banner and the button together.

**Testing.** New `_summer_test.gd` / `.tscn`, **129 checks**, and
`_summer_test.tscn` builds the real scene and reads the level's own state, so a
check cannot pass because the level was never built. All five suites are green:

| Suite | Checks | Exit |
|---|---|---|
| `_summer_test` | 129 | 0 |
| `_stack_walk_test` | 66 | 0 |
| `_stack_jump_test` | 41 | 0 |
| `_garden_test` | 133 | 0 |
| `_next_level_test` (`--next-level-check`) | 20 | 0 |
| **Total** | **389** | |

`_next_level_test` still passes end to end: the real button is pressed, the scene
changes, and the now-built Summer level proves the arrival by printing
`NEXT LEVEL REACHED SUMMER` and quitting 0. Both scenes were also run cold for
180 frames with zero errors or warnings, and Spring's `Level.gd` and `Level.tscn`
were not touched.

**Proved the tests can fail.** `TrashBin`'s acceptance condition was temporarily
replaced with one that can never match, which should mean no bin ever accepts
anything. The suite failed as it should: **20 failures, exit 1**, every one of
them a "the right bin did not sort it" or a knock-on completion failure. The
change was reverted and re-verified.

**Three real bugs this session found, all mine, all fixed.** The root node of
`SummerLevel.tscn` was written without its `script =` line, so the level loaded as
a bare `Node2D` **and reported no errors at all**; `TrashBin.gd` first overrode
`_process()` with no parameter, which is a parse error; and `_process` needs the
exact signature. See §7 for the full list, including the class-cache import and
the Dictionary traps.

**Known gaps left open on purpose.** No per-bin "filled" feedback — a filled bin
looks unchanged. `NEXT_SCENE` points back at Spring until Autumn exists. The dogs
still live in fields called `cat_*`. And no human has played it yet: everything
here is headless with simulated input.

### 2026-09-30 - Next Level button was visible from the first frame

**The bug.** The `Next Level.png` button drew during ordinary gameplay, from
the moment the game started, instead of appearing only on the completion
screen.

**Root cause.** `scenes/Level.tscn` had been re-saved by the Godot editor (the
author repositioned the button in it), and that save wrote out the new offsets
correctly but **dropped the `visible = false` line** from the `NextLevel`
node. The node was left with only `disabled = true`. `Control.visible` defaults
to `true`, and a disabled button is still drawn - `disabled` only stops it
responding to clicks. So `_reveal_banner()`, which was the only code that was
supposed to turn the button on, was working correctly all along; the button was
simply never hidden in the first place. This is exactly the sort of thing the
editor silently rewrites, so it is now recorded in section 7 as a gotcha.

**The fix - two independent guards, no change to the button itself.**
1. `scenes/Level.tscn`: restored `visible = false` on the `NextLevel` node.
   **The position, scale and z_index the author set were left exactly as they
   are** (`offset_left 870`, `offset_top 542`, `offset_right 1382`,
   `offset_bottom 798`, `scale 0.7`, `z_index 101`). The button was not
   recreated and not moved.
2. `scenes/Level.gd` `_ready()`: also sets
   `next_level_button.visible = false` and `next_level_button.disabled = true`.
   This puts the invariant in code, so an editor save that loses the scene
   property can never put the button back on screen during gameplay.

Nothing else was touched: the pot progression, player movement, jumping,
stacking, controls, the 1.5s pause, `_reveal_banner()`'s reveal and the
click -> Summer transition are all unchanged. Summer remains a placeholder with
no gameplay.

**Tested from a fresh game start**, as asked:
- A throwaway probe loaded the real main scene exactly as the game does, left it
  running untouched for 120 frames, and reported `Next Level button
  visible=false disabled=true`, `Level Complete visible=false`, `pot stage=0`,
  button centre `(1049.2, 631.6)` - **no completion UI during gameplay**. It
  exited 0 and was then deleted.
- Completing Spring still works end to end: `_next_level_test` passes all 20
  checks, the flower holds its ~1.5s pause on its own, then the `Level Complete`
  picture and the `Next Level` button appear together, and pressing the button
  reaches the Summer placeholder (`NEXT LEVEL REACHED SUMMER`, exit 0).

**Negative test, run deliberately.** Removing both guards reproduces the
reported bug and the tests catch it, which is what proves they are not vacuous:
- fresh-start probe: `visible=true` -> `FAIL the Next Level button is on screen
  during gameplay`, exit 1;
- `_garden_test`: `FAIL and is hidden before the level is finished`, exit 1;
- `_next_level_test`: `FAIL the Next Level button starts hidden`, exit 1.
Both guards were then restored and everything re-run green.

**A second bug found by that negative test:** `_next_level_test` *hung* instead
of reporting when a check failed before the press, because `_run()` had no
summary path once the click was skipped. Fixed with an idempotent `_finish()`
(guarded by a `_finished` flag) and a `_run()` tail that finishes only when no
press happened (`_press_timestamp_ms == 0`), which is exactly the case where no
scene changed and the node is therefore still safe to touch. It now fails fast
with its `FAILURES` summary and exit 1.

**Tests.** `_garden_test` 132 -> **133 checks** (one more: the reveal must not
move the button). Two on-screen checks were corrected rather than the button
being moved: they asserted the whole 358.4x179.2 rect sat inside the 1280x720
viewport, which is false by ~1.2px at the author's chosen position (drawn
bottom edge y=721.2). They now assert the button's **centre** is on screen,
which is what decides whether a click lands, and its geometry is recorded
before the level is finished and re-checked after the reveal to prove it does
not move. Totals: 66 + 41 + 133 + 20 = **260 checks, 0 failures**. Smoke test
`--quit-after 400` runs with zero errors and zero warnings.

**Files modified:** `scenes/Level.tscn` (`visible = false` restored),
`scenes/Level.gd` (`_ready()` guard), `_garden_test.gd` (centre-based on-screen
check, new position guard), `_next_level_test.gd` (no-hang fix), `PROGRESS.md`.

### 2026-09-30 — Spring finishes and leads to Summer placeholder

**What changed.** The Spring completion screen now has a real exit: alongside
the `Level Complete` picture, a clickable `Next Level` button appears when the
flower finishes growing. Pressing it loads `scenes/SummerLevel.tscn`, which is
a minimal placeholder (sky, "SUMMER", note) with no gameplay; it prints
`NEXT LEVEL REACHED SUMMER` and quits 0 if run with `--next-level-check`, and
otherwise returns to Spring on any click or key. This makes the
`Spring Complete → Next Level → Summer` path real without building Summer's
game.

- `Level.tscn`: added `NextLevel` `TextureButton` (`visible=false`,
  `disabled=true`, `z_index=101`, positioned at the screen centre near the
  bottom: `offset_left=460.8`, `offset_top=520.4`, `scale=Vector2(0.7,0.7)`),
  using `assets/Next Level.png` (`uid://ecpkv7as3uxt`). The banner remains at
  `(640,360)`.
- `Level.gd`: wired the button to `next_level_button.pressed` in `_ready()`,
  shows+enables it in `_reveal_banner()` with the banner, added
  `const SUMMER_SCENE := "res://scenes/SummerLevel.tscn"`, and added
  `_on_next_level_pressed()` that calls `get_tree().change_scene_to_file(SUMMER_SCENE)`.
- `SummerLevel.gd` + `.tscn`: new minimal Control placeholder with
  `--next-level-check` support and return-to-Spring input.
- `_garden_test.gd`: now preloads `assets/Next Level.png`, asserts the button
  is a `TextureButton`, carries the correct texture, is hidden/inert before
  completion, sits on screen, is drawn above the banner, and that it turns up
  with the Level Complete picture on reveal.
- `_next_level_test.gd` + `.tscn`: end-to-end test driving a full Spring run,
  verifying both completion pictures appear, the button's pressed signal is
  wired, pressing it changes scene to Summer, and the Summer placeholder exits
  cleanly.

**Assets.** `assets/Next Level.png` and its `.import` (uid
`uid://ecpkv7as3uxt`, source `res://assets/Next Level.png`) are shared assets
and remain at `assets/` (not moved to `assets/Spring/`).

**Tests.** `_garden_test` 125 → **132 checks** (7 new assertions). Added
`_next_level_test` with **20 checks + live scene change**. Totals: 66+41+132+20
= **259 checks, 0 failures**. Both new suites pass cleanly (Summer placeholder
prints `NEXT LEVEL REACHED SUMMER` and exits 0). Existing suites unchanged in
behaviour and still pass. The smoke test `--headless --quit-after 400` runs
with **zero errors, zero warnings**.

**Files created:** `scenes/SummerLevel.gd`, `scenes/SummerLevel.tscn`,
`_next_level_test.gd`, `_next_level_test.tscn`.

**Files modified:** `scenes/Level.gd`, `scenes/Level.tscn`, `_garden_test.gd`,
`PROGRESS.md`.

### 2026-09-30 — assets grouped by level: Spring art moved into `assets/Spring/`

**What changed.** Ten Spring-only pictures moved from `assets/` into a new
`assets/Spring/` folder: `Cat1.png`, `Cat2.png`, `BasicTile.png`, `Soil.png`,
`Water.png`, `Seeds.png`, `Pot_Empty.png`, `Pot_Soil.png`, `Pot_Sprout.png`,
`Pot_Flower.png`. `Level Complete.png` stayed in `assets/` because every level
will need it, not just Spring. The resulting tree is in §3.

**Every reference was found first, then updated.** A search of every `.gd` and
`.tscn` in the project for the ten names found **12 live references across 4
files**, and all 12 were repointed:

| File | Line | Reference |
|---|---|---|
| `scenes/Level.gd` | 22, 23 | `CAT1_TEXTURE`, `CAT2_TEXTURE` `preload` |
| `scenes/Level.gd` | 60, 68, 76 | the soil, seeds and water `GARDEN_ITEMS` textures |
| `scenes/PlantPot.gd` | 22-26 | all five `STAGE_TEXTURES` entries |
| `scenes/GroundTile.tscn` | 4 | `[ext_resource]` for the tile texture |
| `scenes/Player.tscn` | 4 | `[ext_resource]` for the placeholder cat texture |

The two references to `Level Complete.png` — `scenes/Level.tscn` line 4 and
`COMPLETE_TEXTURE` in `_garden_test.gd` line 18 — were **left untouched on
purpose**, because that file did not move.

The `.import` files moved with their pictures, each one's `source_file=`
repointed at the new path, and then `--import` was run so Godot regenerated the
imported-texture files. **The old texture UIDs were preserved** rather than
regenerated, so nothing that ever referred to a picture by `uid://` can be
broken by this. That was safe to do because the scenes reference textures by
path, not by uid — worth knowing, since it is not how Godot scenes usually work.

**What did not change.** No file was renamed. No gameplay, movement, jumping,
stacking, carrying, gardening rule, pot stage, tile position, crop `Rect2` or
display scale was touched — a moved file keeps the same name and the same
bytes, so every crop and measurement in `Level.gd` and `PlantPot.gd` is still
correct by construction. `scenes/Player.gd`, `scenes/GardenItem.gd`,
`scenes/GroundTile.gd` and `project.godot` were not modified at all. Nothing
was rebuilt; no scene was re-saved, only edited as text.

**How it was checked.** A **baseline** of all three suites was taken *before*
the move and was green, so the after-run is a real comparison rather than a
vague "it looks fine":

| Suite | Before | After |
|---|---|---|
| `_stack_walk_test` | 66 PASS, 0 FAIL | **66 PASS, 0 FAIL** |
| `_stack_jump_test` | 41 PASS, 0 FAIL | **41 PASS, 0 FAIL** |
| `_garden_test` | 125 PASS, 0 FAIL | **125 PASS, 0 FAIL** |

**232 checks, 0 failures, same as before the move.** Every one of those
asserts on the *artwork itself* — the cats' crop regions, the items' pictures
and sizes, all five pot stages including the one where the banner appears over
`Pot_Flower` — so a picture that failed to load could not have passed. The real
`Level.tscn` then ran 400 frames headless: exit code 0, and **not one line of
output** beyond Godot's own version banner, i.e. zero errors and zero warnings.
A grep for the old `res://assets/<name>.png` paths across every script and
scene now returns nothing, and `--import` reported exactly the 10 expected
files reimporting and no others.

**One harmless leftover.** The ten previous imported-texture files are still in
the `.godot/imported/` cache under their old hashed names. They are orphans:
nothing references them, and the editor garbage-collects that folder itself.
Left alone rather than deleted by hand, because `.godot` is a generated cache
and Godot manages it.

**For future sessions:** §7 now has a short "how to move a picture" note,
because moving a file by hand outside the editor is four separate steps and
missing the `--import` one is the easy mistake. Dragging the file inside the
editor's FileSystem dock does all four automatically.

**Still not verified:** nobody has played this with a human. As before, all of
the above is headless and driven by simulated input.

### 2026-09-28 — the Level Complete banner waits 1.5s so the flower is seen first

**What changed.** One new exported field and three lines of logic in
`scenes/Level.gd`. `_on_level_complete()` no longer shows anything; it sets
`_banner_timer = complete_banner_delay` and the existing `_process` counts it
down before calling `_reveal_banner()`. `complete_banner_delay` defaults to
`1.5`. A `_banner_shown` guard makes it impossible for a second signal to start
a second countdown or reshow the banner.

**What did not change.** `PlantPot.gd` is completely untouched — it still emits
`level_complete` on the same frame it becomes a flower, so the signal still
means "the pot is a flower" and only the *display* waits. Soil/Seeds/Water
progression, all five pot sprites, item consumption, the pot's status wording,
movement, jumping, stacking, riding, controls and the level layout are all
exactly as they were. No scene was rebuilt, no new node was added, and the
banner's position, crop, scale and z_index are unchanged.

**How it was checked.** Beyond the suite, the finished level was played through
under a real renderer and two frames were captured — one mid-pause and one after
the reveal. The mid-pause frame contains 2048 of the `Pot_Flower` artwork's own
pixels in the pot's box and none of the banner's; the frame after the reveal
contains 6996 banner pixels there and none of the flower's. So the flower really
is on show by itself first, and the banner really does arrive after it. Timing
was measured rather than assumed: the banner appeared at 1501ms for a 1500ms
pause, and a headless run tracked `_banner_timer` against the wall clock to
within a few ms.

**Tests - `_garden_test.gd`, 116 -> 125 checks, all passing.** Section 8 now
asserts the banner is not on screen on the very frame the flower appears, not
halfway through the pause, and not with the pause nearly over; that the flower
is on show by itself at each of those points; that the pause is within the
1-2s that was asked for; and that the elapsed wait is within 0.3s of
`complete_banner_delay`. The clock is anchored by a watcher coroutine that
stamps the moment the flower appears, because the frame waits overshoot that
moment by over a second. **The suite was confirmed to catch the old behaviour:**
patching `_on_level_complete` back to showing the banner immediately makes 4
checks fail, including the frame-precise one, and restoring the delay makes them
pass again.

**Regression - 232 checks, 0 failures:** `_stack_walk_test` 66/66,
`_stack_jump_test` 41/41, `_garden_test` 125/125, with zero errors and zero
warnings. The real game scene ran 400 frames headless, exit code 0, silent.

**Left open on purpose.** Once the banner appears it hides the flower completely
(measured: 0 flower pixels where 6996 banner pixels). Keeping the flower visible
alongside the banner would mean moving or shrinking the banner, or drawing the
pot in front of it — all of which trade against the centred 708x384 sizing, and
the requirement was conditional on the layout allowing it. Not changed on a
guess; the options are written up under the known gap above.

### 2026-09-28 — the Level Complete picture replaces the LEVEL COMPLETE! label

**What changed.** The `LEVEL COMPLETE!` `Label` in `Level.tscn` is gone.
`LevelComplete` is now a `Sprite2D` using `assets/Level Complete.png`, cropped
to the artwork (`region_rect = Rect2(16, 0, 472, 256)`), scaled 1.5x and
centred on `(640, 360)`, the middle of the screen, with `z_index = 100` and
`texture_filter = 1` to match the rest of the project's sprites. It starts
hidden and is revealed by the existing `_on_level_complete()`, so it can only
ever appear once the pot reaches `FLOWER`. The GDScript reference was renamed
`level_complete_label` -> `level_complete_banner` and retyped from `Label` to
`Sprite2D`.

**What did not change.** The pot, the `level_complete` signal, item
consumption, movement, jumping, stacking, carrying, the two help labels, the
`GoalHelp` line and the pot's own `NEEDS SOIL/SEEDS/WATER` wording are all
exactly as they were. Only the end-of-level display was touched.

**How it was checked.** Beyond the test suite, the finished level was actually
played through under a real renderer and the screen was captured twice — with
the banner showing and with it hidden — then differenced. Exactly 246,184
pixels changed, inside a bounding box of `x 286..993, y 168..551`, which is
the 708x384 box the scene predicts to the pixel, with nothing spilling outside
it. Pixels inside that box return the picture's own colours where the no-banner
capture has bare white sky, proving the banner draws over the level. The
artwork's lettering was also checked to be centred in the crop (237 against a
crop centre of 236).

Worth knowing: `--headless` uses Godot's dummy renderer, where
`frame_post_draw` never fires and `get_viewport().get_texture().get_image()`
returns null (and errors out). Capturing the screen needs a real
`--rendering-driver opengl3` run.

**Tests - `_garden_test.gd`, 102 -> 116 checks, all passing.** A new section 1b
asserts the old wording is gone, that the node is a `Sprite2D` rather than a
`Label`, that it carries the new texture, that it starts hidden, is cropped,
is centred on `(640, 360)`, is large enough to read, fits inside the screen and
has a positive `z_index`. Sections 7, 8 and 9 additionally assert the banner is
still hidden at the soil, seeded, sprout and growing stages, and appears with
the right texture exactly once `FLOWER` is reached.

**Regression - 223 checks, 0 failures:** `_stack_walk_test` 66/66,
`_stack_jump_test` 41/41, `_garden_test` 116/116, with zero errors and zero
warnings. The real game scene ran 400 frames headless, exit code 0, silent.

**One observation, deliberately not acted on.** The lettering inside
`Level Complete.png` is low contrast against its orange plaque — the green is
1.75:1 and the pale yellow 2.48:1 by WCAG ratio. At the 1.5x scale the text is
roughly 90px tall, so it reads fine in practice, but the artwork is the
user's own and was left untouched. It is worth a look if legibility ever
becomes a concern.

### 2026-09-28 — items are used up for good, and the item wording is gone

**Note:** the request asked for `Project.md` as well as `PROGRESS.md`. **There is
no `Project.md` in the project.** This file is the only markdown document there,
and it was used as the source of truth for the session.

**Bug fixed — a used-up item came back.** See §7 for the full write-up. In short:
`PlantPot._serve()` used `Player.drop_carried()` — the *put-back* path — even
when the pot had accepted the item, so `GardenItem.respawn()` teleported the
item straight back to its spawn point on the same frame and made it collectable
again. The fix splits the two outcomes into `drop_carried()` (put back) and the
new `consume_carried()` (used up), where consumption calls the new
`GardenItem.consume()`, which removes the node from the level for good.

**Changed:**
- `scenes/GardenItem.gd` — added `is_consumed` and `consume()`. `respawn()` now
  refuses to resurrect a consumed item. `_collect()` hands the cat a second
  `Callable` alongside the put-back one. `_process()` also guards on
  `is_consumed`.
- `scenes/Player.gd` — added `consume_carried()` and a shared `_clear_carrying()`.
  `pick_up()` takes the extra callable. **The movement, jumping, gravity,
  collision and ride code were not touched.**
- `scenes/PlantPot.gd` — one line: the accept branch now calls
  `consume_carried()`. The refusal branch still calls `drop_carried()`.
- `scenes/GardenItem.tscn` — the `Name` `Label` node was **deleted**, not
  hidden.

**Item wording removed:**
- The `SOIL` / `SEEDS` / `WATER` label under each item is gone — the `Name` node
  was removed from `GardenItem.tscn` and `GardenItem.gd` no longer references it.
- The carried item is no longer appended to the cat's label, so a carrying cat
  reads `P1`, not `P1  SOIL`. The `P1`/`P2` label itself is unchanged.
- **Nothing was put in their place.** No new labels.
- **Deliberately kept, after asking:** the pot's status line still says
  `NEEDS SOIL` / `NEEDS SEEDS` / `NEEDS WATER` / `GROWING...`, and the
  `GoalHelp` line in `Level.tscn` still reads "Spring: carry the soil, the seeds
  and the water to the pot, in that order." The user confirmed both should stay
  — they are the pot's feedback and the level's one-line instruction, not labels
  on an item. **So the three words are still visible on screen in those two
  places.** If they ever want those gone too, it is `_refresh_status()` in
  `PlantPot.gd` and the `GoalHelp` text in `Level.tscn`.

**Test changes — `_garden_test.gd`, 81 -> 102 checks, all passing.** Items are
now single-use, so several old checks were asserting behaviour that is now
deliberately wrong and had to go:
- "the soil went back to where it was" and "the seeds went back to where they
  were" asserted the **bug**. They now assert the item node is removed and that
  the collectable count in the level has gone down.
- "the water was used up" asserted `water.visible`, i.e. the bug. It now
  asserts the node is gone.
- **"a second lot of soil is refused" was deleted outright.** There is only one
  lot of soil in the level, so there is no second lot to carry in. It is
  replaced by "an empty-handed cat leaves the pot where it is", which still
  covers the pot not advancing on a cat it has nothing to take from.
- The test sections were **reordered**, because any section that needs an item to
  still be lying around has to run before the section that spends it:
  burial (2) moved up next to the static level check, and the water-needs-two-
  cats (5) and carrying-while-stacked (6) sections now run before the right
  order (7). A comment at the top of `_run()` says so, so a future reorder does
  not silently break it.
- New helpers: `_items_left()`, `_labels_under()` and an `item_spots` snapshot
  taken in `_gather()` (the nodes themselves are gone by the last section, so
  the spots where they used to be have to be recorded up front).
- New checks: every item has no `Label` under it at all; the carrying cat's
  label stays plain; a refused item is put back but *not* used up.

**Tested — all seven items the request asked for:**
1. Soil -> pot -> gone permanently. Covered by §7
   ("the soil is gone from the level for good") **and by the negative test
   below.**
2. Touching the old soil spot afterwards -> nothing picked up. §9, for all
   three items and both cats.
3. Seeds -> pot -> gone permanently. §7.
4. Water -> pot -> gone permanently. §8.
5. No `SOIL`/`SEEDS`/`WATER` on any item. §1 walks every `Label` under every item
   and requires the list to be empty; §3 requires the carrying cat's label to
   stay `P1`. See the "deliberately kept" note above for the two places the
   words are intentionally still on screen.
6. Both players still interact normally. §3 ("P2 can pick the same thing up"),
   §4, §7 (P2 carries the water to the pot), §9 (P2 walks all three old spots).
7. Movement, jumping and stacking unchanged. `_stack_walk_test` 66/66 and
   `_stack_jump_test` 41/41 both pass untouched, and the real `Level.tscn` ran
   400 frames headless with zero errors and zero warnings.

**Regression — 209 checks, 0 failures:** `_stack_walk_test` 66/66,
`_stack_jump_test` 41/41, `_garden_test` 102/102.

**The negative test is the important part of this entry.** Changing the one line
in `PlantPot._serve()` back to `drop_carried()` was done on purpose to confirm
the suite catches the reported bug. It failed **18 checks**, and the output
reproduced the report exactly: `left=3` items in the level, and
`carrying=soil` when a cat was put back on the old soil spot. It was then
reverted and re-run green. A suite that passes is worth much more when you have
seen it fail for the right reason.

**Not verified:** nobody has played this with a human. Everything above is
headless and driven by simulated input.

### 2026-09-28 — Spring gardening mechanic

Session started by comparing this file against the actual project. **The file
was stale:** §3 listed 4 PNGs when `assets/` held 11. The seven extra
(`Soil`, `Seeds`, `Water`, `Pot_Empty`, `Pot_Soil`, `Pot_Sprout`, `Pot_Flower`)
had no `.import` files at all, so Godot had never even imported them, and
nothing referenced them. Their names pointed at a gardening mechanic that had
not been started. This section is that mechanic.

**Implemented:**
- Imported the seven unused assets (`--import`); all eleven PNGs now have
  `.import` files.
- Measured the opaque part of every new picture so the pot can be cropped and
  drawn from its base, and the items cropped like the cats.
- `GardenItem.gd` / `.tscn` — a collectable on layer 8. Picks itself up when an
  empty-handed cat stands in it, shows itself beside that cat, and puts itself
  back on its spawn point. Holds no reference to the pot, so the pot owns the
  rules entirely.
- `PlantPot.gd` / `.tscn` — five stages, the soil→seeds→water order, refusal of
  anything else, the hand-back, the timed sprout growth and `level_complete`.
- `Player.gd` — added `carried_kind`, `_put_back`, and `can_pick_up()`,
  `pick_up()`, `drop_carried()`. Added a `CarriedIcon` `Sprite2D` to
  `Player.tscn` and widened the name label. **The movement, jumping, gravity,
  collision and ride code were not touched.**
- `Level.gd` — `GARDEN_ITEMS` and `POT_POSITION` constants, `_build_garden()`,
  `_on_level_complete()`. The `Props` node became `Garden`; added `GoalHelp`
  and a hidden `LevelComplete` label to `Level.tscn`.
- **Deleted the exit door:** `LevelExit.tscn`, `LevelExit.gd` and its `.uid`,
  plus every reference in `Level.gd`. Completing the level no longer involves a
  door at all.

**Design decisions worth remembering:**
- **The seed stage reuses `Pot_Soil`.** The seeds are down in the soil and
  nothing has come up yet, so there is nothing new to draw. No new art asset was
  created. The pot's status label still says `NEEDS WATER`, so the player is
  never told a stage they have already reached.
- **The water is a high item, not a high platform.** The first attempt was a
  ledge above the top platform. That does not work: a rider can never end up
  standing on anything directly above its supporter, because the supporter owns
  the rider's height and re-seats it every step. Since pickup is a touch and not
  a landing, a high *floating* item sidesteps the whole problem — the top cat
  collects it on the way past. **No new platform was added; the existing level
  layout is unchanged.**
- **A wrong item is refused, not unpickable.** The pot says
  `WRONG ITEM - JUMP TO PUT IT BACK` and jumping there returns the item to its
  spawn. Without this, picking up the water first would leave a cat holding
  something useless forever, with no way to pick up anything else.
- **The pot is at x=900, not x=640.** The platforms cover x=192..768 and the pot
  grows to 176 tall with a status label above it, so at x=640 the label would
  have been drawn behind the row 6 platform. Caught by review, then locked down
  by a test (§8 of the suite) that checks every pot stage against every tile.

**Tested — `_garden_test.gd`, 81 checks, all passing:**
- Both cats can pick the same item up; only one item each; the carried icon and
  name label appear and are cleaned up.
- Water and seeds are both refused by an empty pot; water is refused after soil;
  a second lot of soil is refused. The pot only ever moves on by exactly one
  correct step.
- Soil → soil pot, seeds → seeded pot, water → sprout, and the sprout grows
  into the flower on its own. The item is only consumed after the pot takes it.
- `level_complete` fires exactly once and the `LEVEL COMPLETE!` label appears.
- The water cannot be reached by one cat: solo reach measured at y=90.3 against
  a box reaching down to y=32, and the water was never picked up over three
  jumps. Stacked, the top cat reaches y=38.4 and picks it up, with the lower cat
  still standing on the platform underneath.
- Carrying an item does not disturb stacking: the bottom cat walked 86.7px with
  a rider on its head, still carrying the soil, and still jumped correctly.
- Nothing is buried: every item's pickup box and the pot at all five stages are
  clear of every terrain tile.

**Regression — all three suites green, 188 checks, 0 failures:**
`_stack_walk_test` 66/66, `_stack_jump_test` 41/41, `_garden_test` 102/102. The
real game scene then ran 400 frames headless with zero errors and zero warnings.
Movement, jumping, gravity, player collision, stacking, riding, bottom-player
movement while carrying a rider, and sprite facing are all unchanged and still
covered.

**Bugs found and fixed during this work** (all were in the new test suite, not
in the game):
- The stack helper used a fixed wait after teleporting, so it measured a cat
  still in mid-air. The "water needs two cats" check would have passed for the
  wrong reason. Replaced with `_wait_for_stack()`, which waits for the ride
  link to actually close.
- A grab issued inside an item's 0.35s put-back cooldown silently did nothing,
  and the test did not notice. Grabs now wait on `_respawn_timer` instead of
  guessing frame counts.
- Checking "putting it down empties the cat's hands" while the cat was standing
  on a *different* item failed, because empty hands over an item pick it up
  again immediately. The test now steps the cat away first. This is the game
  working correctly.

**Not verified:** nobody has played this with a human. Everything above is
headless and driven by simulated input.

### 2026-09-28 — earlier session (stacking fix)

- Existing multiplayer prototype inspected: `Level.gd` builds ground,
  platforms, walls, two players and an exit procedurally from constants.
- Cat1 / Cat2 implemented as per-player textures with per-player crop regions.
- Controls set to A/D/Space (P1) and Arrow keys/Enter (P2) as real Godot input
  actions in `project.godot`, and verified by tests.
- Sprite facing direction fixed (textures authored facing left, so `flip_h`
  turns them right) and verified by tests.
- Player stacking implemented: ride links, supporter carries rider, rider can
  ride off, rider can jump off.
- **Bug found:** the bottom player could not move horizontally while another
  player stood on it.
- **Bug diagnosed:** face-to-face player colliders produce a zero collision
  normal; `move_and_slide()` cancels the mover's motion and depenetration shoves
  the pair sideways.
- **First fix attempt was insufficient:** excluding the player layer only for the
  supporter made the *rider* get shoved instead, which then re-froze the
  supporter when the rider fell out of the perch window.
- **Second regression found and fixed:** with the rider no longer touching its
  supporter, `is_on_floor()` was false for the rider, so its coyote timer
  drained and the top cat could not jump.
- **Final fix:** symmetric player-layer exclusion, explicit vertical seating and
  horizontal carry by the supporter, `is_on_floor() or riding` for coyote, and a
  link that survives the absence of contact. All in `scenes/Player.gd`.
- Built `_stack_walk_test.gd` (67 checks) to cover the bug and everything
  around it.
- Repaired `_stack_jump_test.gd` (42 checks), whose 12 earlier failures were
  **test-harness** problems, not game bugs: lambdas capturing locals by value,
  contact-based floor checks that are meaningless now that riders do not touch
  their supporters, and a stack built at x = 160 against a ledge.
- Both suites now report `ALL CHECKS PASSED` (109 checks total).
- Main game scene ran 300 frames headless with zero errors and warnings.
- Removed eight temporary debug trace scenes created during the investigation
  (`_walk_trace`, `_walk_trace2`, `_walk_probe`, `_walk_matrix`,
  `_walk_overlap`, `_jump_trace`, `_jump_trace2`, `_invert_trace`).
- Created this `PROGRESS.md`.

---

## 10. Development Rules

- This is an **existing** project. Do not rebuild it from scratch unless
  explicitly instructed.
- Inspect the existing code before changing it. The project files are the
  source of truth over any description, including this one.
- Modify existing systems instead of creating duplicates. There is already one
  `Player.gd`, one `Level.gd` — extend them.
- Keep the implementation **simple**, because the developer is a beginner. A
  beginner must be able to read and change the code tomorrow.
- Avoid unnecessary architecture: no managers, no autoloads, no state machines,
  no signals-and-event-bus layering unless there is a concrete need.
- Do not change working features when fixing an unrelated bug.
- **Test changes after implementing them.** Five runnable suites exist for
  exactly this; use them, and keep them passing.
- **Do not mark a bug as fixed without testing it.**
- Keep the game small and achievable — the deadline is close.
- Leave the game itself untouched when a task is only about documentation or
  inspection.
- Record findings honestly. If something is unverified, say so. A wrong claim
  in this file costs a future session more time than a missing claim.

---

## 11. Session Checklist

**Start of every session**
1. Read this `PROGRESS.md` **before** making any changes.
2. Skim the current state of `scenes/Player.gd`, `scenes/Level.gd` and
   `scenes/SummerLevel.gd` and compare them against §2 and §7. If they
   disagree, trust the code and correct this file.
3. Confirm all five test suites still pass before trusting any of this file.

**End of every session**
Update this file with:
- what was completed,
- what was changed,
- what was tested,
- what is currently broken,
- any new bugs discovered,
- what should be done next.

**Do not erase previous progress.** Append new dated entries to §9 and keep the
history.


### 2026-10-01 - Summer level: added bin labels and verified implementation

**What was done:**

- Added Label nodes to `TrashBin.tscn` and `TrashBin.gd` to display the exact bin labels ("Paper Bin", "Plastic Bin", "Glass Bin") as required (using Godot text labels, not relying on PNG text).
- Verified all five test suites still pass with 0 failures: Summer (129), Stack Walk (66), Stack Jump (41), Garden (133), and Next Level transition (20) - 389 checks total.
- Spring and Summer both function correctly with the existing shared systems.

**Next task:** Manual play in the Godot editor to verify the Summer layout, controls, sorting, and transitions behave correctly in practice.


### 2026-10-01 - Summer bins stand on the ground, and every piece of rubbish is reachable

**What was done:**

- Git initialised (`.gitignore` set up for Godot: `.godot/`, `/android/`, build
  folders, throwaway `/_probe_*` measurement scripts, OS clutter) and the working
  project committed as it stood *before* any of these changes, then committed again
  with them.
- **`TrashBin.gd` sprite anchoring fixed.** The sprite is centred, so
  `offset = (-region.width * 0.5, -region.height)` put the artwork a whole
  `display_height` above the ground and a half-width to the left of its node.
  Measured against a real render: a bin at `(640, 560)` was drawing
  `y 392..504` and `x 546.7..640` — i.e. hovering 56px above the ground with its
  right edge on the node. It now uses `(0, -region.height * 0.5)`, the same anchor
  `Player.gd` uses for the dogs, so the bottom edge lands on the node and the
  middle sits over it. This is what had the paper bin's picture overlapping the
  left wall.
- **`TrashBin.drawn_rect()` fixed.** It used `global_position + sprite.offset`
  with `region.size * scale`, which ignored the sprite's centred rect and its
  parent transform entirely. It now reads `sprite.get_rect()` through
  `sprite.global_transform`, which matches the rendered pixels exactly.
- **`TrashBin._process()` no longer stops at the first dog.** It returned after
  serving one overlapping player, so if the lower dog was holding something this
  bin refuses while the upper dog was holding exactly what it wants, the
  delivery was missed. Every dog in the bin is now served.
- **Bins moved onto the ground, at y=560:** paper `(560, 560)`, plastic
  `(860, 560)`, glass `(1120, 560)`. They were at `(58, 551)`, `(630, 540)` and
  `(1169, 582)` — the first overlapped the left wall with both its art and its
  collider, and none of the three sat on the ground.
- **Plastic bag moved from `(634, 65)` to `(752, 200)`.** At y=65 it was up in
  the top-left corner of the sky: a scan of every standable surface found exactly
  **one** spot in the whole level from which a dog could reach it (x=848 on the
  top platform, jumping left), and two with the dogs stacked. A piece of rubbish
  one jump away from being unreachable leaves the level unfinishable. It is now
  above the right-hand end of the row 6 platform, reachable from **13** spots solo
  and **19** stacked.
- **Rubbish reachability is now a test.** New `_summer_test` §3 stands a dog on
  the sand shelf below each piece of rubbish, jumps, and only passes if the
  pickup really happens — once with one dog and once with the two dogs stacked
  (six checks), then confirms all three pieces are still in the level afterwards.
- **Bin checks tightened.** The old check asserted `offset.y == -region.height`,
  which is the bug itself. It is now the real invariant: the artwork's bottom
  edge is on the node's y, its middle is over the node's x, and no bin's artwork
  or collider touches a wall or is drawn on top of a dog.
- `PARK_B` moved from `(620, 560)` to `(750, 560)`. At 620 it was standing inside
  the plastic bin's pickup box, which was the source of most of the 23 failures
  this suite was reporting: the dog was being served by a bin it was only parked
  next to, and the glass-to-plastic refusal case was testing the wrong bin.
- Stale positions and totals corrected in §2.2 and §7 (they still described a
  layout from before Summer was first built).

**Measured, not assumed:** every position, box and gap above came out of a
throwaway probe that instantiated the real `SummerLevel.tscn`, read the real
`CollisionShape2D`s and sprite transforms, and for the two art questions rendered
a bin with a real renderer and measured the painted pixels. The probe scripts are
deleted and `.gitignore`d.

**Testing.** All five suites pass with 0 failures — Summer **152** (was 129),
Stack Walk 66, Stack Jump 41, Garden 133, Next Level 20 — **412 checks total**.

**Still open:** the bins cannot go near the left wall even though the picture puts
the paper bin there, because the two dogs start on the beach floor at x=120 and
x=232 (art out to x=264) and the lowest sand platform covers x=320..512, which is
exactly the band a ground-standing bin would be drawn into. The ground a bin can
use starts at x≈560. If the dogs' spawns or the platforms move, the bins can move
left again.
