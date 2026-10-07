# PROGRESS — FourSeasons

**Last updated:** 2026-10-08
**Project root:** `C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons`
**Engine:** Godot 4.7.2 stable (`4.7`, GL Compatibility renderer)

> **Read this file at the start of every session before making changes.**
> The actual project files are the source of truth. If this file and the code
> disagree, the code is correct and this file is stale — fix this file.

---

## 1. Game Overview

**What it is:** A 2D local co-op platformer built in Godot 4.7.2. Two players
share one keyboard and can climb on each other's heads to reach higher places.
They are **cats in Spring, dogs in Summer and foxes in Autumn** — same controls,
same movement, same ride/stack system, only the artwork changes.

**Main concept:** Two-player local co-op platforming where the players are the
platforms for each other. One player can stand on the other's head, be carried
around, and jump off.

**Four seasons are playable and all four are in one loop.** Each has its own goal and
its own completion screen, and the shared `Next Level` button chains one into the
next:

```
Spring -> Summer -> Autumn -> Winter -> Spring
```

**The game now opens on a title screen** (built 2026-10-08): Play, How to Play,
Settings, Quit, over a background that cycles through the four seasons. Every
level has a **pause menu** (Esc or the Pause button) and a **settings panel**
(music, sound, text size, fullscreen), both dressed in that level's season
colours. See §9, 2026-10-08. A season selector and a level manager still
**do not exist** — Play always starts Spring.

Winter was built on 2026-10-04, and on the same day Autumn was wired to hand over to
it, which closed the loop over all four finished seasons. That handover was a
deliberate one-line change to `AutumnLevel.NEXT_SCENE`, and the Autumn suite's
transition assertion was **strengthened** rather than swapped over to match — see §7
and §9.

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
Glass   -> Glass Bin   /                     +-> Next Level button -> Autumn
```

In Autumn a fox carries a leaf to the frame whose ghosted leaf silhouette it
matches. **Which frame wants which leaf is only ever visible** — there is no
number, no wording and no colour coding:

```
leaf1..leaf4 -> the frame whose silhouette matches it -> Level Complete picture
                                                        +-> Next Level button -> Spring
```

**Autumn is the first level that is longer than one screen.** Spring and Summer
are each a single 1280x720 screen. Autumn is a 4800x720 world with a camera that
follows the two foxes, eleven shelves, four leaves spread across the map and four
frames in a row on a raised terrace at the right-hand end. See §2.3.

**Current MVP scope (what is actually playable today):**
- **Spring**: one single-screen level with flat ground, three floating
  platforms, two side walls, two cats, three collectable gardening items and a
  plant pot.
- **Summer**: one single-screen level with sand ground, three platform shelves, a
  sea drawn behind everything, two dogs, three pieces of rubbish and three bins,
  each of which accepts exactly one kind.
- **Autumn**: one long scrolling level with autumn ground, eleven shelves, a
  terrace, two foxes, four leaves, four picture-matched frames and ten decorative
  trees. See §2.3.
- Full movement, jumping, stacking, carrying, and player-to-player collision —
  identical in all three seasons, and unchanged by any of them.
- Any finished season's completion screen shows the `Level Complete` picture and,
  with it, a clickable `Next Level` button that loads the next season.

---

## 2. Current Features

Everything in this section was **read from the code and/or verified by running
the project and the automated test suites.**

### Godot project setup
- Godot 4.7.2, `config_version=5`, renderer `gl_compatibility`.
- Main scene: `res://scenes/TitleScreen.tscn` (since 2026-10-08; it was
  `res://scenes/Level.tscn`, Spring, before that).
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
occupies `x 948..1144, y 542..719`, which clips the bottom-right corner of the
flower (`x 848..952, y 384..560`) not at all — the button starts at x=948 and the
flower ends at x=952, so the only overlap is a 4px sliver over `x 948..952,
y 552..560`. Since the banner already covers 100% of the flower, this changes
nothing in practice, and the position is the author's choice and was deliberately
not moved. (These figures were measured again on 2026-10-04, after the button's
picture changed; see §9.)

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

**The Next Level button's picture is now `assets/Next_Button.png`.** It was
`assets/Next Level.png` until 2026-10-04; see §9 for the swap and the
measurements. `NextLevel` is still one `TextureButton`, still in all three level
scenes, still `z_index = 101` (above the banner), still `visible = false` and
`disabled = true` in the scene file, still wired to `_on_next_level_pressed()`,
and still only ever shown by `_reveal_banner()`.

- **The new picture is 196x177**, opaque artwork `Rect2(22, 10, 160, 160)` — a
  square 160x160 with a little transparent padding, unlike the old 512x256.
- **It is drawn at its own size, unscaled and undistorted.** The button rect is
  the PNG's own 196x177 at `offset_left 948`, `offset_top 542`,
  `offset_right 1144`, `offset_bottom 719`, and `scale` is left at the default
  `Vector2(1, 1)` — the old `scale 0.7` is gone. The old picture had to be
  shrunk because it was authored at 512x256; this one is authored at the size it
  is drawn, so there is no scaling step to distort it.
- **The position barely moved.** `offset_top` is still exactly `542` and the
  whole rect is now *inside* the screen rather than overhanging the bottom by
  1.2px, which is what let `offset_left/right` shrink from `870..1382` to
  `948..1144`. Centre moved from `(1049.2, 631.6)` to `(1046, 630.5)`, and the
  drawn artwork now lands on `x 970..1130, y 552..712` — comfortably on screen,
  which is what a click needs.
- **The whole rect is the click target**, transparent padding included, so it is
  a 196x177 target rather than the old 358.4x179.2 but still far larger than the
  artwork alone.
- **Verified against the real framebuffer, not just the node flags.** A throwaway
  probe run under a real `--rendering-driver opengl3` renderer captured the
  finished level with the button present and absent, and diffing the two changed
  exactly **15,232 pixels inside `x 970..1130, y 552..712`** — the 160x160 box
  the scene predicts, to the pixel, with no spill outside it. A 290-point grid
  over the drawn artwork matched the PNG's own pixels with a worst per-channel
  difference of **0.00000**, and beat all twelve deliberately wrong pixel
  alignments, so there is no resampling anywhere in the chain.
- **A real mouse click works.** Under the same real renderer, warping the cursor
  to the button's centre and sending a real press/release pair fires `pressed`
  exactly once; a click 60px outside it fires nothing. (A synthetic event alone
  is not enough — the GUI hit-tests against the real cursor position, so
  `Input.warp_mouse()` has to come first. This is the same reason
  `_next_level_test` presses the button through its own signal.)

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
- **Spring and Summer:** a single static `Camera2D` at `(640, 360)` with limits
  matching the 1280x720 viewport. Each level fits exactly one screen, so there is
  no camera scrolling or following.
- **Autumn:** the only level that scrolls. One `Camera2D` at `y = 360` with limits
  `left = 0`, `right = 4800`, `top = 0`, `bottom = 720`, following the midpoint
  between the two foxes (`_foxes_centre()`), never one camera per fox.
- **Autumn's camera is smoothed, but always lands on a whole pixel.** See §9,
  2026-10-03: engine `position_smoothing` is off and the level does the easing
  itself (`1 - exp(-8 * delta)`), then assigns `roundf()` to the camera x. This
  is deliberate and is what removed the white seams between ground tiles while
  panning. Do not "simplify" it back to `position_smoothing_enabled = true`.

### Automated test suites
Six headless test scenes exist purely for verification. They build the real
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
  clicked, and which is drawn above the banner. Three further checks, added
  2026-10-04 with the new button picture, pin down that the picture is shown
  **undistorted**: the button's drawn size must equal the PNG's own size, its
  `scale` must be uniform (never squashed sideways), and the whole button must
  sit inside the screen rather than merely its middle. Sections 7, 8
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
- `tests/_autumn_test.gd` (`tests/_autumn_test.tscn`) — **282 checks, ALL
  PASSING, 9 sections.** Builds the real Autumn scene and drives it. Sections:
  1 the level really is Autumn; 2 the world is long and the camera follows and
  comes back; 3 **every tree is scenery and a fox walks and jumps through all ten
  of them**; 4 every leaf is really jumped for, solo and stacked; 5 four leaves,
  each its own picture, spread right across the map; 6 the frames match by picture
  alone, with no wording anywhere; 7 **every wrong frame refuses all three other
  leaves**; 8 the right frames place for good; 9 the completion screen. Notably
  it reads its expectations back out of the level's own constant map, so a leaf or
  frame that moves cannot leave the suite quietly testing stale numbers.

**697 checks total, 0 failures, across six suites.** (The 67/42 figures in
earlier versions of this file were off by one each: they counted the
`ALL CHECKS PASSED` summary line as a check. The real counts were always 66 and
41. The garden suite went from 81 to 102 when the permanent-consumption rules
were added on 2026-09-28, from 102 to 116 when the completion banner was changed
from a label to a picture on 2026-09-28, from 116 to 125 when the pause before
the banner was added later the same day, from 125 to 132 when the Next Level
button was added, from 132 to 133 when the button-position guard was added, and
from 133 to 136 on 2026-10-04 when the button's picture was replaced and three
undistorted-display guards went in with it.
`_next_level_test` was added with the button, and `_summer_test` (129) with
Summer on 2026-09-30, later 152 on 2026-10-01 when the bin-anchoring,
wall-clearance and rubbish-reachability checks were added.)

How to run them (headless, no editor needed):

```powershell
& "C:\Users\Chloe Cheng\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
  --headless --path "C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons" `
  --scene "res://_stack_walk_test.tscn"
```

Swap the scene for `res://_stack_jump_test.tscn`, `res://_garden_test.tscn`,
`res://_summer_test.tscn`, `res://tests/_autumn_test.tscn` or
`res://tests/_winter_test.tscn` to run the others.
Those six print `ALL CHECKS PASSED` at the end. The season-transition suite
needs a user argument the Summer level looks for, and instead of a summary it
ends by printing `NEXT LEVEL REACHED SUMMER` and quitting 0:

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

and for Summer, add `--scene "res://scenes/SummerLevel.tscn"`; for Autumn, add
`--scene "res://scenes/AutumnLevel.tscn"`.

> **On Windows, always pass the arguments as one quoted string.** Both the
> `--path` and the `--scene` value contain spaces (`C:\Users\Chloe Cheng\...`), and
> `Start-Process -ArgumentList` will silently split an unquoted value into two
> arguments and hand Godot a truncated path:
> ```powershell
> Start-Process -FilePath $exe -NoNewWindow -PassThru `
>   -ArgumentList '--headless --path "C:\Users\Chloe Cheng\OneDrive\Documents\FourSeasons" ' `
>                 + '--scene "res://tests/_autumn_test.tscn"'
> ```
> **`_next_level_test` needs its user argument or it will hang, not fail** — see
> §7 and §9, 2026-10-03.

That pair was last run for 180 frames each with **zero errors and zero
warnings**.

> **How long a suite is allowed to take: `tests/_winter_test` takes about 41
> seconds**, measured on 2026-10-04, and it is *supposed* to. It is bound to real
> time, not to work done: it `await`s roughly 2,500 physics frames of genuinely
> simulated walking, sliding, jumping, stacking and falling at the engine's 60Hz,
> so it cannot be made faster by a faster machine. Do **not** wrap it in a
> 60-second `Wait-Process -Timeout` and read the timeout as a failure — see §7,
> 2026-10-04, for the run that did exactly that and what it was really reporting.
> If a suite seems to hang, the check is whether it printed anything at all: a
> suite that is running prints constantly, and a suite that printed nothing and
> never exited never got started (§7, "gotchas when testing").


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
shared `Level Complete.png` and the shared `Next_Button.png` button together. The
button was hidden and disabled from the first frame and is only shown by
`_reveal_banner()`, exactly as in Spring.

**The notice.** `Wrong bin!` is one `Label` at the top of the screen
(`z_index` 102, above the completion banner). It re-shows every frame while a dog
carrying the wrong thing stands in the bin, and takes itself down 1.2s after the
dog leaves. `_summer_test` checks it does not cover any bin or any piece of
rubbish, so it cannot hide what the player needs to see.

### 2.3 The Autumn leaf-frame mechanic, and the first scrolling level

Everything in Autumn is declared in `AutumnLevel.gd` (`TILE_*`, `LEVEL_*`,
`PLATFORM_ROWS`, `TREES`, `LEAVES`, `FRAMES`, `FRAME_ART`, `PLAYER_SPAWNS`) and
built in `_ready()`, the same way Spring's `Level.gd` and `SummerLevel.gd` build
theirs.

**The map — 4800x720, three and a half screens wide.** Tiles are 64x56. Ground
row 10 for 75 columns, three rows deep (rows 11-12 buried so the block looks
solid), the same `GroundTile.tscn` Spring and Summer use with Autumn's own
texture through the existing `surface_texture` / `surface_region` exports.
`TILE_REGION` is `Rect2(16, 13, 64, 56)`. Two 16px side walls, exactly as in the
other two seasons. **302 tiles** in total.

**Eleven shelves** in `PLATFORM_ROWS`, plus a raised terrace:

| Row | Columns | Spans | Surface y |
|---|---|---|---|
| 8 | 2-5 | 128..384 | 448 |
| 8 | 11-14 | 704..960 | 448 |
| 6 | 16-20 | 1024..1344 | 336 |
| 8 | 21-24 | 1344..1600 | 448 |
| 6 | 26-30 | 1664..1984 | 336 |
| 4 | 31-34 | 1984..2240 | 224 |
| 8 | 36-39 | 2304..2560 | 448 |
| 6 | 43-47 | 2752..3072 | 336 |
| 4 | 48-51 | 3072..3328 | 224 |
| 8 | 51-54 | 3264..3520 | 448 |
| 6 | 55-58 | 3520..3776 | 336 |

Plus the terrace: columns 60-74, top row 8, surface y = 448, which is where the
four frames stand.

**The four leaves, one per area.** Each is the existing `GardenItem` scene, so a
leaf is picked up by standing in it and has the same two ways out as a gardening
item — but Autumn never refuses one, so they are always used up.

| Leaf | Position | Above which shelf |
|---|---|---|
| `leaf1` | `(832, 340)` | the row 8 shelf at x 704..960 |
| `leaf2` | `(1824, 240)` | the row 6 shelf at x 1664..1984 |
| `leaf3` | `(2432, 300)` | the row 8 shelf at x 2304..2560 |
| `leaf4` | `(3200, 120)` | the row 4 shelf at x 3072..3328 |

**The heights are measured, not guessed.** A fox standing on a surface at `y = S`
sweeps its collider through every height from `S-52` (standing) to `S-186` (the
top of a jump), so a leaf is gettable from that surface when its box overlaps that
band. Each leaf's box sits inside the band of the shelf named in its comment and
outside the band of the floor, so **every leaf takes a jump and never a plain
walk**. `_autumn_test` §4 proves this by really jumping for all four, once with
one fox and once with the two stacked.

**The four frames, on the terrace at the right-hand end**, 240px apart, in a
deliberately **non-sequential** order so the row reads as four things to be
matched rather than four things to be done in order:

| x | Artwork | Takes |
|---|---|---|
| 3950 | `Leaf_frame4` | `leaf4` |
| 4190 | `Leaf_frame2` | `leaf2` |
| 4430 | `Leaf_frame3` | `leaf3` |
| 4670 | `Leaf_frame1` | `leaf1` |

240px apart leaves 156px of clear ground between their 84px pickup boxes; a fox is
60px wide, so it cannot be inside two frames at once and cannot place a leaf by
walking past.

**The rule is visual and nothing else** (`LeafFrame.gd`, deliberately the same
shape as Summer's `TrashBin` rather than something new). Each frame's own
artwork has a **ghosted leaf silhouette burned into the middle of it**, and every
leaf's outline matches exactly one silhouette — measured out of the PNGs into
`FRAME_ART`. There is **no `Label`, no number, no colour and no wording on the
scene at all**: the picture alone says where a leaf goes. The right leaf calls
`Player.consume_carried()`, draws itself scaled to the silhouette inside the frame
and emits `leaf_placed`; anything else emits `wrong_leaf` and **takes nothing** —
the fox keeps carrying it and walks on, exactly as a wrong bin behaves in Summer.
**A refused leaf is not put back**, because there is nothing to undo.

**Completion.** `leaf_placed` is counted against the four kinds declared in the
level's own `FRAMES` table, so the level and its frames cannot disagree about
what "finished" means. After the fourth there is the same 1.5s pause the other
seasons use, then the shared `Level Complete.png` and the shared `Next_Button.png`
button together, hidden and disabled from the first frame. Autumn's
`NEXT_SCENE` is `res://scenes/Level.tscn`, so the chain loops rather than
dead-ending.

**The foxes are the same `Player` scene as the cats and the dogs.** 256x256
artwork cropped to `Rect2(16, 40, 216, 168)`, `display_height` 56, same as a cat
or a dog, and authored facing LEFT, so `flip_h` still means "turn right" and
`Player.gd` needed **no change at all**. `PLAYER_Z = 2` draws them over the
ground.

**Every tree is decoration — this is now enforced by the tests.** See §9,
2026-10-03. All ten `Autumn_Tree.png` pictures are still in the level, at
`x = 96, 400, 512, 1280, 1632, 2176, 2272, 2656, 2880, 3648`, drawn at 104px tall
behind everything at `z_index = -5`. **None of them has a collision shape, a
physics body or an area any more**, and a fox walks and jumps straight through
every one of them.

### 2.4 The Winter ice and icicles, and the fourth scrolling level

Winter is the fourth season and the second long level. Everything in it is declared
in `WinterLevel.gd` and built in `_ready()`, exactly as Autumn's is. Its goal is the
igloo at the far right, and it counts only when **both** penguins are in it **and both
fish have been collected** — so it cannot be finished by one player rushing ahead, and
cannot be finished without crossing the level.

**Almost all of it is reused.** The tiles are the same `GroundTile.tscn` the other
three seasons use, the penguins are the same `Player.tscn` (so they move, jump,
stack and collide exactly as the cats, dogs and foxes do), and the end of the level
is the same `Level Complete.png` and the same single `Next_Button.png` button.
Winter adds **one** export to the shared tile (`slippery`), **one** branch to
`Player.gd`, and four new scenes. There is no second banner and no second button.

**The map — 4800x720, three and three quarter screens wide, one screen tall.** The
same shape as Autumn, deliberately. Ground row 10 for 75 columns and three rows deep
(rows 11-12 buried so the block reads solid), 16px side walls, unbroken floor with
no holes at all. **265 tiles** — 225 floor plus 40 shelf.

**Nine shelves**, using only rows 8 and 6 (surfaces 448 and 336):

| Row | Columns | Spans | Surface y |
|---|---|---|---|
| 8 | 2-5 | 128..384 | 448 |
| 8 | 10-13 | 640..960 | 448 |
| 6 | 14-18 | 896..1216 | 336 |
| 8 | 23-26 | 1472..1728 | 448 |
| 6 | 27-31 | 1728..2048 | 336 |
| 8 | 36-39 | 2304..2560 | 448 |
| 6 | 40-44 | 2560..2880 | 336 |
| 8 | 49-52 | 3136..3392 | 448 |
| 6 | 53-57 | 3392..3712 | 336 |

**The heights are bounded on purpose: no step is more than 112px** (336 to 448),
which is inside the 128px a jump reaches, so every shelf can be got to by walking and
jumping. The map also never asks for a jump it cannot make from the floor, and no
shelf ever crosses an icicle's drop line. This is the one place Winter is stricter
than it needs to be, and it is strict because **this game has no way to lose and
respawn** — a penguin in a pit it could not jump out of would be stuck forever, so
every fall in Winter has to land somewhere you can walk off again. `_winter_test`
proves the reachable part of this by really jumping every gap.

**Ice — twelve patches, 41 tiles, on rows players actually walk on.** Ice is not a
different texture alone: each of these tiles is also marked `slippery`, which is the
flag `Player.gd` reads. Where a normal surface keeps the old
`velocity.x = direction * SPEED` — identical maths to every other season — ice uses
`ICE_ACCELERATION := 900.0` and `ICE_DECELERATION := 260.0`.

Most of the ice is on the **floor**, so the slippery surface is met during ordinary
walking rather than only by going off a shelf: 22 of the 41 tiles sit on row 10,
against 19 up on the shelves. The elevated patches are kept because dropping onto ice
is a different problem from running onto it, and both are worth having. Two rules
decide where a patch may go, and the test suite now enforces both:

- **No patch covers an icicle's drop line**, so no icicle ever has to be crossed on
  ice you cannot stop on.
- **Clear snow is left between the floor patches** — the six are 4, 4, 3, 3, 4 and 4
  tiles, with 7, 9, 3, 5 and 12 tiles of unbroken snow between them (longest run 12).
  The level is never one long slide; the ice is something you meet in places.

The last patch is deliberately on the floor in the run-up to the igloo, as a slippery
approach rather than somewhere to stand and think.

| Row | Columns | Spans | Surface y |
|---|---|---|---|
| 10 | 12-15 | 768..1024 | 560 |
| 6 | 15-18 | 960..1216 | 336 |
| 10 | 23-26 | 1472..1728 | 560 |
| 8 | 24-26 | 1536..1728 | 448 |
| 6 | 29-31 | 1856..2048 | 336 |
| 10 | 36-38 | 2304..2496 | 560 |
| 8 | 37-39 | 2368..2560 | 448 |
| 10 | 42-44 | 2688..2880 | 560 |
| 6 | 42-44 | 2688..2880 | 336 |
| 10 | 50-53 | 3200..3456 | 560 |
| 8 | 50-52 | 3200..3392 | 448 |
| 10 | 66-69 | 4224..4480 | 560 |

**The six icicles are the only genuinely new piece of behaviour** (`Icicle.gd`, one
scene reused six times). Each hangs from `y = 0` and drops to the floor, in one of
the clear vertical corridors the shelves leave between them, so a drop line never
crosses a platform and an icicle never lands on a shelf. Each corridor is at least
256px wide and an icicle at most 104px across, so there is always a way round one
that has already dropped.

| x | Artwork | Chamber |
|---|---|---|
| 512 | `Icicle1` | A, x 384..640 |
| 1344 | `Icicle2` | B, x 1216..1472 |
| 2176 | `Icicle1` | C, x 2048..2304 |
| 3008 | `Icicle2` | D, x 2880..3136 |
| 3904 | `Icicle1` | open right |
| 4096 | `Icicle2` | off the ice run-up |

Four states — `HANGING`, `WARNING`, `FALLING`, `SPENT`. A penguin entering the
150x160 ground zone starts a 0.9s warning, shaking up to 5px at 26Hz; then it falls
under gravity 1800 up to 900; a hit spends it, switching its hazard off so it can
never kill twice from one fall.

**The one thing worth knowing if you touch `Icicle.gd`: the root does not move.** The
root and the ground zone are both static, and only the inner `Moving` node — which
carries the art and the hazard — is animated. Moving the trigger with the icicle was
tried first and is wrong: an `Area2D` reports bodies entering it when its shape
*moves*, so a falling trigger re-reports the penguin standing in it every frame and
the level resets forever. The ground zone also stays monitoring permanently and the
state guards the start, because a zone that switches monitoring off and on again
re-reports its occupant too. Both of those cost a real debugging cycle; see §9.

**A hit does not kill, it resets.** 0.35s later both penguins are put back on their
own spawns, every icicle goes back on its chain, the igloo empties and the camera
snaps home. `Player.reset_to_position()` clears velocity, timers, support and
riders, and restores the collision mask — the shared stacking code's state machine,
not a Winter-only one.

**The igloo is a goal, not a wall** (`Igloo.gd`). 44x38 artwork drawn 152px tall —
exactly 4x, so it lands on clean doubled pixels — standing at `(4600, 560)` on solid
snow, past every icicle. There is deliberately **no solid collider on it**, only a
168x140 goal area: a solid dome with a doorway narrower than a 60px penguin would be
either unenterable or a pocket a penguin could get stuck in, and a goal you can walk
into and stand in cannot be either. It tracks penguins in a `Dictionary` rather than
counting arrivals, so one penguin cannot be counted twice by jittering on the edge.
It is also built in code rather than placed in the scene file, because a node that
lives in the `.tscn` is readied **before** the level's own `_ready` runs, and it
would work out its own scale from a texture it had not been given yet.

**The tile crop is 64x64, not 64x56, and that is a bug that was actually fixed.**
Every tile in the game ends with 8 rows of shaded underside — Spring and Autumn put
theirs at rows 48..55, and Winter's are at rows 56..63. Cropping Winter's tiles to
the collider's 56 rows quietly deleted that underside, so ledges were drawn with no
bottom face at all, with no error anywhere to say so. `_winter_test` now measures
each texture's real opaque bounding box and insists the region asked for covers all
of it and no more, which is the check that catches this class of mistake.

**The camera is Autumn's camera, borrowed exactly.** One shared `Camera2D` on the
middle of the two penguins, clamped by the usual limits, fixed at `y = 360` because
the level is one screen tall, and rounded to a whole pixel every frame so the 64x56
tile seams cannot open white lines as the view pans.

**The penguins are the same `Player` scene**, 23x28 artwork with no padding drawn at
the same 56px as a cat or a fox, so the collider and the whole ride system work
unchanged. As in Autumn they go in the `cat_*` fields, because renaming those would
mean editing `Player.gd`, `Player.tscn` and `Level.gd` for a cosmetic rename.

**Two fish, and the number 198 is the whole design.** `assets/Winter/Fish.png` is
29x30 with a dark outline and gold fins, drawn 60px tall — exactly 2x, so the pixel art
lands on clean doubled pixels like everything else in the game. Each gets a 64x64
pickup box, deliberately a little larger than the 58x60 it is drawn at: a collectible
you have to aim at pixel by pixel is not a collectible, it is a trap.

Both float with **y = 330**, so the bottom of each box is at 362 — **198px above the
floor** at 560.

| Fish | Centre | Box | Where | How it is taken |
|---|---|---|---|---|
| 1 | `(1560, 330)` | 1528..1592 x 298..362 | over the C low shelf, on its ice | jump from the shelf |
| 2 | `(4300, 330)` | 4268..4332 x 298..362 | over the ice run-up, past the last shelf | stack, then the rider jumps |

**A jump is nominally 128px and really rises about 134px**, because the engine
integrates velocity and *then* moves the body, overshooting the analytic apex by half a
frame of travel. That distinction is the entire margin: 198px is comfortably more than
134, so **neither fish can be taken from the floor**, and 134+52 is comfortably less,
so a stacked penguin's head *does* reach. Getting this wrong is not a matter of taste —
the first placement attempt used y=344, reasoned from the nominal 128, and left only
**3.4px** of clearance. The real jump ate it, and fish 2 was collectable by a single
floor jump. `_winter_test` now derives the real number from `Player.JUMP_VELOCITY` and
`Player.GRAVITY` and asserts the clearance, so the check cannot be re-broken by editing
the table alone.

Fish 1 is over the C low shelf's **icy right half**, so it is a shelf jump followed by a
jump made while sliding — a different problem from jumping on snow. Standing on that
shelf does not reach it (a penguin's head is at y=396, under the box), so it has to be
jumped for. There is a second way in, stepping off the left edge of the C high shelf
above, which the test pins down too; it is no cheaper, since it means climbing to the
high shelf first.

Fish 2 has **nothing at all to climb to** — the E high step ends at 3712, more than
500px short — so the only way up is for one penguin to stand on the other's head and
jump, on ice. That makes it the harder of the two, as intended.

Neither fish is within 150px of an icicle's ground zone, so neither ever asks a player
to be standing under a falling icicle while they work out how to reach it.

**`Fish.gd` is `GardenItem`'s polling with one deliberate difference.** It reads
`get_overlapping_bodies()` every frame for the same reason `GardenItem` does: a penguin
already inside the box when monitoring comes back on has not "entered" anything, and a
signal would miss it. But `GardenItem` ends in `queue_free()`, whereas a Winter fish
**must survive** — an icicle hit is the attempt restarting, and there is no way in this
game to get a collectible back once it is gone. So collecting hides the fish, switches
its own monitoring and monitorable off, and `reset()` puts both back.

Two things there are easy to get wrong:

- **`_process` guards on `monitoring`, not just `is_collected`.** `reset()` clears the
  flag immediately but re-enables monitoring *deferred*, because the physics server will
  not accept the change mid-step. For that one frame the flag says available and the
  server says asleep, and asking a non-monitoring area for overlaps is an error.
- **The art is centred on the node (`offset = Vector2.ZERO`)**, unlike `Igloo`, which
  shifts its picture up by half its height because the node it hangs from is the ground
  it stands *on*. A fish hangs in mid-air, so offsetting it would float the artwork a
  whole body-height above the box that actually collects it.

**A collected fish is visibly carried, and deliberately does not take the pot's
one-item slot.** `_collect()` hands the fish to the penguin through the shared
`Player.pick_up()` — the same five-plus-one-argument call `GardenItem` makes, with
`self` passed as the new `item_node` — so the fish is drawn in the penguin's `CarriedIcon`
and tracked in `Player._carried_fish`. `_carried_by` is what lets `reset()` empty the
penguin's hands before putting the fish back, so nobody is left holding a picture of a
fish lying on the ice again.

What it **must not** do is go through `Player.can_pick_up()`. That gate is Spring's rule
— one item per cat, because a cat has to carry it to one pot and be told *wrong item* if
it brings the wrong one — and `pick_up()` sets `carried_kind`, which makes
`can_pick_up()` false. A fish has no destination, no wrong answer and no hand-off: it is
collected by touching it and it is gone from the world. So `_process()` collects **any**
overlapping penguin. The alternative is a soft-lock nobody would see: a penguin picks up
fish 1, its hands are now full, it can never pick up fish 2, and since Winter has exactly
two fish and the igloo requires both, that penguin has locked itself out of finishing
and the other player has to cross the whole level again to undo it. The fish is still
shown in the penguin's hands; it just does not reserve them.

**The completion gate has two halves and both are guarded**
(`_on_penguins_at_igloo`): the box must hold every player *and* `_collected_fish` must
hold both indexes. The fish half is checked again inside `_on_fish_collected()`, and
that re-check is not decoration — the igloo only speaks when a penguin *enters or
leaves* it. If both penguins were already waiting when the last fish was taken,
nothing would ever report them again and the level would sit there looking finished and
not being finished for good. Ordinary play cannot even produce that state (you cannot be
inside the igloo and at a fish at once), so `_winter_test` reaches it by hand, on a
throwaway level pushed 20000px off to the side — the goal box is an `Area2D` that sees
*anything* on the penguin layer, and every level in this game shares one collision layer
and one coordinate space.

**A collected fish comes back on any icicle hit**, in `_reset_winter()`, which is the
level's existing "this attempt is over" path. If the fish did not return, one player
walking under a falling icicle could cost the other player work they had already done.

**One fish ordering subtlety worth knowing if you extend this.** `_collected_fish` is a
`Dictionary` used as a set, not a counter: an `Area2D` can report the same body more
than once, and a count incremented that way would drift upwards. This is `Igloo`'s
trick, for the same reason.

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
  Next_Button.png           <- shared, the Next Level button picture
  Next Level.png            <- unused since 2026-10-04, the button's old picture
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
  Autumn/
    Fox1.png
    Fox2.png
    Autumn Tile.png
    Autumn_Tree.png
    Leaf1.png
    Leaf2.png
    Leaf3.png
    Leaf4.png
    Leaf_frame1.png
    Leaf_frame2.png
    Leaf_frame3.png
    Leaf_frame4.png
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
| `assets/Next_Button.png` | The Next Level button picture (196x177, artwork 160x160) | **Yes** — the `NextLevel` `TextureButton` in `Level.tscn`, `SummerLevel.tscn` and `AutumnLevel.tscn`, and `NEXT_TEXTURE` in `_garden_test.gd` / `_summer_test.gd` / `_next_level_test.gd` / `tests/_autumn_test.gd`. `uid://gxeab5jg1850`. Also shared, so also left in the root of `assets/`. **Replaced `Next Level.png` on 2026-10-04** — see §9. |
| `assets/Next Level.png` | The button's **previous** picture (512x256, artwork 408x232) | **No — unused since 2026-10-04.** No scene or script refers to it any more. Imported by the engine but referenced by nothing, exactly like `Cat.png`. Safe to delete, but left alone. |
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

### The Autumn pictures

Like Summer, all of Autumn's art came with the project and is used as-is. Nothing
was drawn, resized on disk, recoloured or replaced; every picture is cropped
with a `region_rect` at runtime.

| File | Used for | Currently in use? |
|---|---|---|
| `assets/Autumn/Fox1.png` | P1's fox, replacing Cat1 (256x256, opaque `Rect2(16, 40, 216, 168)`) | **Yes** — `PLAYER_SPAWNS` in `AutumnLevel.gd`, via `cat_texture` |
| `assets/Autumn/Fox2.png` | P2's fox, replacing Cat2 (same crop) | **Yes** — same table, second spawn |
| `assets/Autumn/Autumn Tile.png` | Every ground, shelf and terrace tile (opaque `Rect2(16, 13, 64, 56)`) | **Yes** — `TILE_REGION` in `AutumnLevel.gd`, applied through `GroundTile.surface_texture`. It comes with padding, so without the crop the tile would draw mostly air. |
| `assets/Autumn/Autumn_Tree.png` | All ten trees (27x36, drawn at 104px tall) | **Yes** — `TREE_TEXTURE` in `AutumnLevel.gd`. **Scenery only: plain `Sprite2D`s at `z_index = -5`, no collider, no area, nothing standable.** |
| `assets/Autumn/Leaf1..4.png` | The four collectable leaves (opaque regions in `LEAVES`) | **Yes** — the `LEAVES` table |
| `assets/Autumn/Leaf_frame1..4.png` | The four frames (opaque region + ghosted-silhouette size in `FRAME_ART`) | **Yes** — the `FRAMES` / `FRAME_ART` tables |

> **Watch the naming.** The tile is `Autumn Tile.png` with a **space**, and the
> tree is `Autumn_Tree.png` with an **underscore**. Easy to mistype, and a wrong
> path fails to load rather than falling back.

All twelve PNGs have `.import` files and are imported by the engine. Note that
`Autumn Tile.png` has **no mipmaps** and `fix_alpha_border` enabled, which
matters for the pixel-art look.

All twenty-two Spring and Summer PNGs have `.import` files and are imported by
the engine.

**The pot pictures are all different sizes**, and the opaque part of each is
cropped with a `region_rect` (see `PlantPot.STAGE_REGIONS`) and drawn from its
bottom edge. Without that the pot would jump about and sit at different heights
in every stage.

**Everything in `assets/Summer/` is cropped the same way at runtime** — see the
Summer table above.

| `assets/Winter/Penguin1.png` | P1's penguin, replacing Cat1 (23x28, no padding) | **Yes** — `PLAYER_SPAWNS` in `WinterLevel.gd`, via `cat_texture` |
| `assets/Winter/Penguin2.png` | P2's penguin, replacing Cat2 (same, no crop needed) | **Yes** — same table, second spawn |
| `assets/Winter/Snow Tile.png` | Every snowy ground and shelf tile (80x88, opaque `Rect2(9, 12, 64, 64)`) | **Yes** — `SNOW_REGION` in `WinterLevel.gd`, via `GroundTile.surface_region`. Padding comes with it, so without the crop the tile would draw mostly air. **The crop is 64 tall, not 56** — see §2.4. |
| `assets/Winter/Ice tile.png` | The 23 slippery tiles (90x90, opaque `Rect2(13, 12, 64, 64)`) | **Yes** — `ICE_REGION`, plus `slippery` on each tile. Same 64-tall crop as the snow. |
| `assets/Winter/Icicle1.png` | Three of the six icicles (192x496, no padding) | **Yes** — `ICICLE1_TEXTURE`, drawn 248px tall (half size, so 96x248) |
| `assets/Winter/Icicle2.png` | The other three (208x464, no padding) | **Yes** — `ICICLE2_TEXTURE`, also 248px tall (104x232) |
| `assets/Winter/Igloo.png` | The finish line (44x38, no padding) | **Yes** — `IGLOO_TEXTURE` in `WinterLevel.gd`, drawn 152px tall (4x) |
| `assets/Winter/Fish.png` | Both collectibles (29x30, no padding) | **Yes** — `FISH_TEXTURE` in `WinterLevel.gd`, drawn 60px tall (**2x**) |

> **The two tiles are cropped differently from every other season on purpose.**
> Spring, Summer and Autumn crop to 64x56 because their opaque box really is 64x56.
> Winter's snow and ice are **64x64**, and the last 8 rows are the tiles' shaded
> underside, so cropping to 56 would delete it and draw ledges with no bottom face.
> `_winter_test` measures the real opaque box of every tile and fails if the region
> does not match it exactly. See §2.4.

All seven PNGs have `.import` files and are imported by the engine.

> **Watch the naming.** Both tiles are `Snow Tile.png` and `Ice tile.png` with a
> **space**, and note the **capital T** in `Ice tile`. Easy to mistype, and a wrong
> path fails to load rather than falling back.

No background/sky art, no audio, no fonts beyond the Godot default. None of
these exist yet.

---

## 4. Current Scenes

| Scene | Purpose |
|---|---|
| `scenes/Level.tscn` | **Spring** (was the main scene until 2026-10-08; Play on the title loads it). A mostly empty `Node2D` that acts as a container: `Terrain`, `Walls`, `Garden`, `Players` child nodes, a static `Camera2D`, two control-help labels, a `GoalHelp` line, a hidden `LevelComplete` banner, and the `NextLevel` `TextureButton` that shares its completion screen. `Level.gd` populates all of it in code at `_ready()`. |
| `scenes/SummerLevel.tscn` | **Summer, built 2026-09-30.** A `Node2D` that `SummerLevel.gd` fills in code at `_ready()`, exactly like Spring's `Level.tscn`: `Water`, `Terrain`, `Walls`, `Trash`, `Bins`, `Players`, a static `Camera2D`, control-help labels, a `GoalHelp` line, a `WrongBin` `Label` (hidden, `z_index` 102), the shared `LevelComplete` banner (hidden, `z_index` 100) and the shared `NextLevel` `TextureButton` (hidden, disabled, `z_index` 101, same offsets/scale as Spring). Also prints `NEXT LEVEL REACHED SUMMER` and quits 0 under `--next-level-check`, so `_next_level_test` still works. **A finished Summer loads Autumn** (`NEXT_SCENE = res://scenes/AutumnLevel.tscn`, changed 2026-10-03). |
| `scenes/TrashBin.tscn` | One Summer bin. `Area2D` (layer 8, mask 2) with a `Bin` `Sprite2D`, a 90x110 collider at `(0, -45)`, and a `BinLabel` `Label` above it (added 2026-10-01) reading "Paper Bin" / "Plastic Bin" / "Glass Bin". Only the art and the accepted kind differ per bin, so all three are the same scene with different exported values. |
| `scenes/AutumnLevel.tscn` | **Autumn, built 2026-10-02.** A `Node2D` that `AutumnLevel.gd` fills in code at `_ready()`, the same way the other two seasons work: `Terrain`, `Walls`, `Trees`, `Leaves`, `Frames`, `Players` child nodes, a `Camera2D` (limits 0..4800 / 0..720, `y = 360`), control-help labels, and the shared `LevelComplete` banner and `NextLevel` `TextureButton` at Spring's exact offsets. Also prints `NEXT LEVEL REACHED AUTUMN` and quits 0 under `--autumn-check`. **The first scrolling level.** |
| `scenes/LeafFrame.tscn` | One Autumn leaf frame. `Area2D` with a `Frame` `Sprite2D`, an 84px-wide collider, and **no `Label` child at all** — the ghosted leaf silhouette in the frame's own artwork is the only thing that says which leaf it takes. When filled, the leaf is drawn inside it. All four frames are the same scene with different exported values. |
| `scenes/Player.tscn` | One cat. `CharacterBody2D` (layer 2, mask 3, snap 6) with a `Sprite2D` (`Cat`), a hidden `CarriedIcon` `Sprite2D` for a carried gardening item, a `CollisionShape2D` (60x52 at y=-26), and a `NameLabel`. Ships with Cat1 as a placeholder texture; `Level.gd` and `SummerLevel.gd` override it per player — **Summer overrides it with a dog and needs nothing else changed.** |
| `scenes/GroundTile.tscn` | One 64x56 ground/platform tile. `StaticBody2D` on layer 1 with a collider at `(32, 28)`. |
| `scenes/GardenItem.tscn` | One collectable. `Area2D` (layer 8, mask 2) with a `Sprite2D` and a `CollisionShape2D` that `GardenItem.gd` resizes from `pickup_size`. **It has no `Label` child any more** — the picture is the only thing that identifies it. |
| `scenes/PlantPot.tscn` | The pot. `Area2D` (layer 8, mask 2) with a `Pot` `Sprite2D`, a 100x170 collider at y=-85, and a `Status` `Label` that floats above the pot. |
| `_stack_walk_test.tscn` | Test scene: wraps `_stack_walk_test.gd`. Not part of the game. |
| `_stack_jump_test.tscn` | Test scene: wraps `_stack_jump_test.gd`. Not part of the game. |
| `_garden_test.tscn` | Test scene: wraps `_garden_test.gd`. Not part of the game. |
| `_next_level_test.tscn` | Test scene: wraps `_next_level_test.gd`. Not part of the game. |
| `_summer_test.tscn` | Test scene: wraps `_summer_test.gd`. Not part of the game. |
| `tests/_autumn_test.tscn` | Test scene: wraps `tests/_autumn_test.gd`. Not part of the game. **Kept in `tests/` rather than the project root**, because Autumn is the first level large enough that the root had stopped being a sensible place for its harness. |
| `scenes/WinterLevel.tscn` | **Winter, built 2026-10-04.** A `Node2D` that `WinterLevel.gd` fills in code at `_ready()`, the same way the other three seasons work: `Terrain`, `Walls`, `Icicles`, `Goals`, `Players` child nodes, a `Camera2D` (limits 0..4800 / 0..720, `y = 360`), control-help labels, a `GoalHelp` line, and the shared `LevelComplete` banner and `NextLevel` `TextureButton` at Spring's exact offsets. **The igloo is NOT placed in the scene file** — `$Goals` is an empty container and the igloo is instantiated in code, so its exports are filled in before it is ever readied. **The second long level.** |
| `scenes/Icicle.tscn` | One icicle, reused six times. `Area2D` root that **never moves**: a static `Trigger` child holding the 150x160 ground zone, and a static `Moving` child that is the only animated node, carrying the `Art` `Sprite2D` and the `Hazard` `Area2D`. The hazard's monitoring is off unless the icicle is actually falling. **Do not animate the root or the trigger** — see §2.4 and §9. |
| `scenes/Igloo.tscn` | The Winter goal. `Area2D` with an `Art` `Sprite2D` and **no solid collider at all** — only a `CollisionShape2D` on the goal area itself, sized from `goal_size`. Deliberately not enterable-but-solid, so a penguin can never be trapped in it. |
| `scenes/Fish.tscn` | One of Winter's two fish, reused twice. `Area2D` root with an `Art` `Sprite2D` and a `Pickup` `CollisionShape2D` built in code from `pickup_size`. On no collision layer, masking only the penguin layer. **Collecting hides it and turns its own monitoring off; it is never freed**, because an icicle hit has to be able to bring it back. |
| `tests/_winter_test.tscn` | Test scene: wraps `tests/_winter_test.gd`. Not part of the game. In `tests/` for the same reason as Autumn's. |
| `tests/_season_chain_test.tscn` | Test scene: wraps `tests/_season_chain_test.gd`. Not part of the game. Needs a `--autumn-check` or `--winter-check` user argument to run. |
| `scenes/TitleScreen.tscn` | **Main scene since 2026-10-08.** The title (wireframe A): a `Seasons` `Node2D` that `TitleScreen.gd` fills with four season backgrounds in code, and a `UI` `CanvasLayer` with the title, season badge, Play / How to Play / Settings / Quit, a hidden How to Play panel and a hidden `SettingsMenu` instance. |
| `scenes/PauseMenu.tscn` | The pause menu (wireframe C), **one instance in each of the four level scenes**, with `season` set on the node. A `CanvasLayer` (layer 50, `process_mode = Always`) holding the corner Pause button, the hidden overlay (Resume / Restart this season / Settings / Back to title, plus the inline "Go back to the title?" confirm) and a `SettingsMenu` instance. |
| `scenes/SettingsMenu.tscn` | The settings panel (wireframe D): Music volume, Sound volume and Text size sliders, a Fullscreen check box, Back. Used by both the title and the pause menu. |
| `tests/_menus_test.tscn` | Test scene: wraps `tests/_menus_test.gd`. Not part of the game. |
| `_diag.tscn` | A leftover physics-trace diagnostic. Not part of the game; see §7. |

---

## 5. Current Scripts

| Script | Purpose |
|---|---|
| `scenes/Level.gd` | Builds the entire level procedurally from constants: ground, platforms, walls, players, and the garden (three items plus the pot). Holds `PLAYER_SPAWNS` (per-player actions/texture/crop/spawn) and `GARDEN_ITEMS`. Every frame it sorts the players by y to set `z_index` so the lower cat draws behind. `_ready()` forces the `NextLevel` button hidden and disabled so it cannot appear during gameplay. `_on_level_complete()` starts the `complete_banner_delay` countdown that reveals the `LevelComplete` banner; `_reveal_banner()` shows the banner and the `NextLevel` button together, and `_on_next_level_pressed()` loads Summer (`SUMMER_SCENE`). Also holds `PLATFORM_ROWS`, `GROUND_ROW`, `POT_POSITION`, `TILE_WIDTH/HEIGHT`. |
| `scenes/SummerLevel.gd` | Builds the whole Summer level in code from constants, the same way `Level.gd` builds Spring: sand ground (row 10, 20 columns, 3 rows) and three platform rows, the decorative sea, walls, two dogs, three pieces of rubbish and three bins **on the ground at y=560** (paper `(560,560)`, plastic `(860,560)`, glass `(1120,560)`). Holds `PLAYER_SPAWNS` (the dogs, cropped like the cats), `TRASH_ITEMS` (paper `(434,322)`, plastic bag `(752,200)`, glass bottle `(1136,230)`), `BINS` (each bin's kind, picture, crop and position), `PLATFORM_ROWS`, `wrong_bin_notice_time` (1.2s) and `complete_banner_delay` (1.5s, the same pause Spring uses). `_on_rubbish_sorted()` counts against the kinds taken from the bins themselves and calls `_finish_level()` on the last one; `_on_wrong_bin()` shows the `WrongBin` label and starts its timer; `_reveal_banner()` shows the banner and the Next Level button together; `_on_next_level_pressed()` loads `NEXT_SCENE`. **`NEXT_SCENE` is now `res://scenes/AutumnLevel.tscn`** — changed 2026-10-03, see §9. Also still quits 0 with `NEXT LEVEL REACHED SUMMER` under `--next-level-check`. |
| `scenes/TrashBin.gd` | One Summer bin. The sorting rule, and nothing else: exports `accepts_kind`, `bin_texture`, `art_region`, `display_height`; crops its own picture and anchors it **bottom edge to its node** (`sprite.offset = (0, -region.height * 0.5)`, the same anchor `Player.gd` uses — the sprite is centred, so the old `(-width * 0.5, -height)` offset drew the artwork a whole `display_height` above the ground and half a width to the left); polls overlapping players every frame and serves **every** dog in the box, not just the first (the same way `PlantPot.gd` does, so a dog that walks in already carrying the right thing is served, and a stacked pair is never missed). The right kind calls `Player.consume_carried()`, sets `is_filled` and emits `rubbish_sorted`; the wrong kind emits `wrong_bin` and **takes nothing**; an empty dog is ignored. `drawn_rect()` reports the artwork's real screen pixels, read from `sprite.get_rect()` through the sprite's global transform. **The bin node stays in the level either way.** |
| `scenes/AutumnLevel.gd` | Builds the whole Autumn level in code from constants, the same way `Level.gd` and `SummerLevel.gd` do: 302 tiles of autumn ground, eleven shelves, the raised terrace at columns 60-74, walls, ten **decoration-only** trees, four leaves, four frames on the terrace and two foxes. Holds `LEVEL_WIDTH = 4800`, `PLATFORM_ROWS`, `TREES`, `LEAVES`, `FRAMES`, `FRAME_ART`, `PLAYER_SPAWNS`, `CAMERA_Y = 360`, `CAMERA_SMOOTHING = 8.0` and `NEXT_SCENE = res://scenes/WinterLevel.tscn`. `_foxes_centre()` is the midpoint of the two foxes; `_follow_foxes(delta)` does the smoothing **itself** with `1 - exp(-8 * delta)` and assigns `roundf()` to the camera x — see §9, 2026-10-03, and do not revert that to engine `position_smoothing`. `_on_leaf_placed()` counts against the kinds declared in its own `FRAMES` table and calls `_finish_level()` on the last one; `_on_wrong_leaf()` shows the shared notice; `_reveal_banner()` shows the banner and the Next Level button together. Also prints `NEXT LEVEL REACHED AUTUMN` and quits 0 under `--autumn-check`. |
| `scenes/LeafFrame.gd` | One Autumn leaf frame, and the Autumn sorting rule. Deliberately the same shape as `TrashBin.gd` rather than something new: an `Area2D` that watches which foxes are standing in it, decides, and hands the leaf's fate back through the same two callables. Exports `accepts_kind`, `frame_texture`, `art_region`, `leaf_texture`, `leaf_region` and the silhouette size. The right leaf calls `Player.consume_carried()`, draws itself scaled to the silhouette inside the frame and emits `leaf_placed`; anything else emits `wrong_leaf` and **takes nothing**. **There is no `Label` on this scene** — no number, no wording, no colour; the frame says nothing at all. **A refused leaf is not put back**, exactly as in Summer. |
| `scenes/Player.gd` | All cat behaviour: input, gravity, jumping, coyote/buffer, floor snap, artwork, facing, the ride/stack system, and carrying one gardening item. Tuning constants at the top (`SPEED`, `GRAVITY`, `JUMP_VELOCITY`, `COYOTE_TIME`, `JUMP_BUFFER`, `SUPPORT_GRACE`, `RIDE_CATCH`, `PLAYER_LAYER`, `CARRIED_ICON_HEIGHT`). Carrying is only `carried_kind`, `drop_carried()`, `consume_carried()` and `_clear_carrying()` — the movement and ride code below them is untouched. |
| `scenes/WinterLevel.gd` | Builds the whole Winter level in code from constants, the same way the other three do: **265** tiles of snow, nine shelves, walls, six icicles, the igloo and two penguins. Twelve `ICE_PATCHES` covering 41 tiles (22 on the floor row, 19 on shelves), see §2.4. Holds `LEVEL_WIDTH = 4800`, `PLATFORM_ROWS`, `ICE_PATCHES`, `ICICLES`, `PLAYER_SPAWNS`, `CAMERA_Y = 360`, `CAMERA_SMOOTHING = 8.0`, `RESET_PAUSE = 0.35` and `NEXT_SCENE = res://scenes/Level.tscn`. `_is_ice(column, row)` is read from the same `ICE_PATCHES` table the level is built from, so the picture a penguin sees and the surface it slides on cannot disagree. `_penguins_centre()` / `_follow_penguins()` are Autumn's camera, borrowed unchanged — the smoothing is done in the level with `1 - exp(-8 * delta)` so the result can be `roundf()`d, see §9 and **do not revert that to engine `position_smoothing`**. `_on_icicle_hit()` waits `RESET_PAUSE` so the player sees the icicle land, then puts both penguins on their own spawns, resets every icicle, empties the igloo and snaps the camera home. `_on_penguins_at_igloo()` counts against the number of players the level itself built, so the two cannot disagree about what "finished" means, and **also requires `_collected_fish` to hold both indexes** - so Winter cannot be finished without collecting, and cannot be finished by skipping the level. It then uses the same 1.5s `complete_banner_delay` as every other season. **Builds the two fish** from `FISHES` (`_build_fish()`, `_fish_nodes`, `_on_fish_collected()`, `_required_fish()`) and resets them in `_on_icicle_hit()`'s existing reset path - see §2.4. Also prints `NEXT LEVEL REACHED WINTER` and quits 0 under `--winter-check`, which is the arrival hook `tests/_season_chain_test.gd` uses to prove Autumn -> Winter really happens; it has no effect on normal play. |
| `scenes/Icicle.gd` | One icicle: four states (`HANGING`, `WARNING`, `FALLING`, `SPENT`), the shake, the fall and the one-shot hit. `WARNING_TIME = 0.9`, `FALL_GRAVITY = 1800`, `MAX_FALL_SPEED = 900`, `SHAKE_MAX = 5.0`, `SHAKE_HZ = 26.0`, `TRIGGER_WIDTH/HEIGHT = 150x160`. **The root and the ground zone never move** — only the inner `Moving` node is animated, and only it carries the hazard. `reset()` puts it back without a trigger ever being re-reported, and the state guards the start so a zone that is already being stood in cannot restart it. |
| `scenes/Igloo.gd` | The Winter goal: crops and scales the igloo picture, and reports how many penguins are inside. It keeps its occupants in a **`Dictionary` keyed by body, not a counter**, so a penguin hovering on the edge cannot be counted twice and a stacked pair are both counted. No solid collider. Emits `penguins_changed(count)`. |
| `scenes/GroundTile.gd` | Flips the tile sprite vertically when `buried` is true so the ground block looks filled in. Also applies the optional `surface_texture` / `surface_region` overrides, which is how Summer puts sand on the same tile scene, and the `slippery` flag Winter's ice sets. **All three default to Spring's values, so Spring, Summer and Autumn are unaffected.** |
| `scenes/Fish.gd` | One fish: crops/scales the artwork uniformly, builds the 64x64 pickup box, and polls `get_overlapping_bodies()` each frame like `GardenItem` — but **does not free itself**. Emits `collected(index)`. **Three things to keep:** `_process` guards on `monitoring` as well as `is_collected`, because `reset()` re-enables monitoring deferred and there is one frame where neither is true; `art.offset` stays `Vector2.ZERO`, unlike `Igloo`, because a fish hangs in mid-air rather than standing on its node; and `_process` collects **any** overlapping penguin rather than gating on `Player.can_pick_up()`, because `_collect()` hands the fish to `Player.pick_up()` (visible in `CarriedIcon`, tracked in `Player._carried_fish`) and that would fill the penguin's hands and lock it out of the second, required fish — see §2.4. |
| `scenes/Player.gd` | The shared player. **Winter added exactly one branch**: when the tile underfoot is `slippery`, horizontal movement uses `ICE_ACCELERATION = 900` / `ICE_DECELERATION = 260` instead of the usual `velocity.x = direction * SPEED`, which is left byte-for-byte as it was so no other season can be affected. Also added `reset_to_position()`, which clears velocity, timers, support and riders and restores the collision mask — the shared stacking state machine, not a Winter-only one — and `pick_up()`'s optional `item_node` argument plus `_carried_fish`, which is what lets a Winter fish be carried **without** becoming a second Spring-style item: `can_pick_up()` is unchanged, so Spring's one-item-to-the-pot rule is untouched. |
| `scenes/GardenItem.gd` | One collectable. Crops and scales its picture, picks itself up when an empty-handed cat stands in it, and has the two ways out: `respawn()` puts itself back on its spawn point, `consume()` removes the node from the level for good. |
| `scenes/PlantPot.gd` | The five pot stages, the one ordering rule, the wrong-item refusal and hand-back, the permanent consumption of an accepted item, the timed sprout growth, and the `level_complete` signal. All the pot artwork is a `const` table keyed by stage. |
| `_stack_walk_test.gd` | Automated regression suite (66 checks) for walking, carrying, riding off, stacked jumps, collisions, controls, facing, art, platforms. |
| `_stack_jump_test.gd` | Automated regression suite (41 checks) for the original stacking/jump behaviour, separation, and re-stacking. |
| `_garden_test.gd` | Automated regression suite (136 checks) for the Spring gardening mechanic, including used-up items being gone for good, the water needing both cats, carrying while stacked, the completion banner being the `Level Complete` picture rather than the old label, the `NextLevel` button sharing the completion screen (real `TextureButton`, right picture, **hidden and inert before the finish**, centre on screen, above the banner, unmoved by the reveal, **drawn at the picture's own size with a uniform scale so it cannot be stretched or squashed, and wholly inside the screen**), and the pause between the flower appearing and the banner turning up. |
| `_next_level_test.gd` | Automated end-to-end suite (20 checks) for the season transition: a real Spring run to the flower, the completion pause, the banner and Next Level button appearing together, the button's `pressed` being wired to the level's handler, and then pressing it — the scene change frees the test and the built Summer level proves the arrival by printing `NEXT LEVEL REACHED SUMMER` and quitting 0. Never presses the button if any earlier check failed. |
| `_summer_test.gd` | Automated regression suite (**152 checks**) for Summer: the scene really is built and is not Spring, two dogs cropped to the dog art, the controls unchanged, sand on every tile, the sea is decoration only and drawn behind the level, three bins with three different pictures that do not touch, each standing on the ground with its artwork's bottom edge on the ground and centred over its own node, none drawn into a wall or on top of a dog, three pieces of rubbish each nearest its own bin, the completion screen and button hidden and inert at the start, dogs move/jump/face/stack on their own keys and can stack while carrying, **every piece of rubbish is really picked up by jumping for it from the shelf below it, solo and stacked**, **all six wrong-bin pairs are refused with a notice that clears itself**, each right bin sorts for good and the rubbish cannot be picked up again, and the completion screen only arrives after the third sort. The Next Level button is never pressed — pressing it would free the test — so its target is read from `NEXT_SCENE` instead. |
| `scenes/TitleScreen.gd` | The title screen. Builds the four season backgrounds from the levels' own pictures and crops (sky colour, three rows of ground tiles, the two animals hopping, and each season's props: pot/soil/seeds, sea + three bins, trees + falling leaves, igloo + icicle + fish + falling snow), crossfades to the next season every `SEASON_TIME` (5s) in level order, and re-themes the menu to match. Play loads `SPRING_SCENE`. Esc closes an open panel. |
| `scenes/PauseMenu.gd` | Pauses with `get_tree().paused`. Esc steps back one layer at a time (Settings -> confirm -> menu -> play). **Always unpauses before `reload_current_scene()` / `change_scene_to_file()`**, because `paused` belongs to the tree and would survive into the next scene. Applies the saved settings (audio, fullscreen, text size) **only when its level is `get_tree().current_scene`**, so the test suites, which build levels inside a test node, are never affected by a player's saved text size. |
| `scenes/SettingsMenu.gd` | Shows and edits `GameSettings`. Every change applies and saves at once (no Apply button). `open(season)` dresses it in a season; emits `closed` on Back. |
| `scenes/GameSettings.gd` | `class_name GameSettings`, **static vars, not an autoload**: `music_volume`, `sound_volume`, `text_scale` (0.8..1.5), `fullscreen`, saved to `user://settings.cfg` with `ConfigFile`. `apply_audio()` creates `Music` and `SFX` buses on first use (no sounds exist yet; a sound put on those buses will follow the sliders). `apply_text_scale(root)` resizes every Label/Button under a node from its designed size, kept in node meta so it never compounds. `save_path` is a var so tests can redirect it. |
| `scenes/SeasonTheme.gd` | `class_name SeasonTheme`, static only. The four season colours (from the proposal's screen-flow figure), panel tints, skies, names, and `make_theme(season)`, which builds a whole `Theme` (buttons, panels, sliders with a drawn round knob, check boxes, labels) plus the `PrimaryButton`, `TitleLabel`, `HeadingLabel` and `SeasonBadge` variations. |
| `tests/_menus_test.gd` | Automated suite (**171 checks, 7 sections**) for the title, the settings and the pause menu. Uses its own settings file, never the player's. See §9, 2026-10-08. |
| `_diag.gd` | Leftover one-off trace script used to debug the stacking bug. Prints a per-frame table and quits. Not part of the game. |
| `tests/_winter_test.gd` | Automated regression suite (**140 checks, 12 sections**) for Winter. See §2.4 for what it covers. It reads its expectations back out of the level's own constants rather than hard-coding them, and it measures each tile's real opaque bounding box out of the PNG to prove no crop is cutting any of the artwork off — the check that catches a tile quietly losing its underside. Its fish checks derive the **real** jump rise from `Player.JUMP_VELOCITY` and `Player.GRAVITY` rather than trusting the nominal 128, and really jump for both fish rather than asserting coordinates. |
| `tests/_season_chain_test.gd` | End-to-end suite (4 checks per leg) for the two chain legs no static check can cover. Run with `-- --autumn-check` it builds the real Summer, finishes it, proves the shared completion screen and button are up and wired, and calls the handler, so Autumn loads and quits 0. Run with `-- --winter-check` it does the same from Autumn, so Winter loads and quits 0. Also proves the button press actually changed the scene: the press frees the test, so a test still alive at 90s is itself the failure. With neither argument it fails in a second with the invocation it needs. |
| `tests/_autumn_test.gd` | Automated regression suite (**284 checks, 9 sections**) for Autumn. See §2.3 for what it covers. It reads its expectations back out of the level's own `get_script_constant_map()` rather than hard-coding them, so moving a leaf, frame or tree moves the expectations with it instead of letting the suite quietly test stale numbers. Its chain checks were **strengthened** on 2026-10-04 when Autumn began handing over to Winter — see §7. |

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

**These are the same six keys in all four seasons.** Winter added no key bindings
at all: the penguins are the shared `Player` scene, so they move and jump on exactly
the keys the cats, dogs and foxes do. In particular **no W/S aliases were added**,
because unused bindings would show up in the rebinding screen for no reason.

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

### ✅ Bug: `Fish.gd` did not parse, so the Winter suite hung forever and printed nothing — **FIXED AND TESTED**

**Original description:** a headless run of `tests/_winter_test.tscn` was killed by
`Wait-Process -Timeout 60` with **no output at all** beyond the engine banner, and no
Godot window appeared:

```text
Wait-Process : This command stopped operation because process
"Godot_v4.7.2-stable_win64_console (31696)" is not stopped in the specified time-out.
```

It looked like an infinite loop in the Winter code. **It was not.** Nothing in the game
loops forever, and nothing in the test hangs; the process was sitting in an empty Godot
main loop because the test script had never loaded.

**Root cause:** `scenes/Fish.gd:119` had an `if` with an **empty body**. The
`by.pick_up(...)` call that the new fish-carrying work added had come out of its `if`
block by one indentation level:

```gdscript
	if by != null and by.can_pick_up():
	by.pick_up(fish_kind, fish_texture, art_region, ...)   # not indented
```

GDScript reports this as `Expected indented block after "if" block.` Read from
`_winter_test.gd` it arrives wrapped and much less useful, as
`Could not parse global class "Fish"`, fourteen times over, followed by two
`Cannot infer the type of "..." because the value doesn't have a set type` errors (the
test's `fishes: Array[Fish]` and `for one in fishes` lose their type) and finally
`Failed to load script "res://tests/_winter_test.gd" with error "Parse error"`.

**Why it hung instead of failing.** `class_name Fish` is what let the error reach
`_winter_test.gd` at all, but the hang is the same trap as the bare-`Node2D` one in
"gotchas when testing": the `.tscn` still loads, the root node still exists, and with no
script on it there is no `_run()`, no `_finish()` and therefore **no `get_tree().quit()`
ever called**. Headless, with nothing to draw, Godot then idles until something external
kills it. A `--headless` suite that produces no output is not slow; it never started.

**The fix** (`scenes/Fish.gd` only — `Fish.tscn` needed nothing):

1. The `pick_up(...)` call is back inside its `if`, which is the parse fix.
2. The gate lost `can_pick_up()`. `_collect()` hands the fish to `Player.pick_up()`, and
   that sets `carried_kind`, which makes `can_pick_up()` false — so a penguin that had
   taken fish 1 could never take fish 2, and since both are required to finish, it had
   locked itself out of the level. `_winter_test` §10 takes **both** fish with P1
   (`_take_fish(1)` then `_take_fish(2)`), so this was not hypothetical: with the gate
   left in, that section fails. A fish has no destination and no wrong answer, so it does
   not reserve the pot's one-item slot. The fish is still visibly carried. See §2.4.
3. Comment-only tidying: reuse `_put_back` / `_use_up` for the two callables instead of
   building them twice, and document `reset()`'s order (empty the hands, *then* respawn).

**How it was verified:**

- `--check-only` run over **all 22** `.gd` files in the project: 0 parse errors.
  (`--headless --path <proj> --script res://<file.gd> --check-only` is the way to get the
  *real* error message instead of the `Could not parse global class` wrapper.)
- `tests/_winter_test.tscn`: **140 checks, 0 failures, `ALL CHECKS PASSED`, exit code 0**,
  in 41.4s — including every fish check: two fish only, each in the level's own table
  position, 198px above the floor, unreachable by a floor jump and reachable from the
  shelf and by stacking, one `collected` signal each and never twice, monitoring off
  while collected, both fish back on their exact spots after an icicle hit, and the level
  refusing to finish with zero or one fish.
- `scenes/WinterLevel.tscn` for 400 frames headless: exit 0, **zero errors, zero
  warnings** — the game itself was never affected, only the test could not load.
- No test was changed, no timeout was raised, and nothing was committed.

### Known limitation: the whole player layer is ignored while linked


`scenes/Player.gd` removes **all** of `PLAYER_LAYER` from the collision mask
while a player is linked, not just the specific supporter or rider. With
exactly two players this is correct and cannot go wrong. **If a third player is
ever added, a cat carrying a rider could walk straight through the third cat.**
Fixing this properly means tracking which specific body to ignore rather than
the whole layer. Not a bug today because there are only two players.

### Season transition: Spring -> Summer -> Autumn -> Winter -> Spring

Growing the flower emits `level_complete`, which waits 1.5s and then reveals
the `Level Complete` picture **and** the `Next Level` button together. Pressing
the button changes the scene to `res://scenes/SummerLevel.tscn`, which is the
real Summer level (built 2026-09-30 — see §2 and §9). Summer keeps the same
shared completion screen, and its button loads `NEXT_SCENE`, which is
`res://scenes/AutumnLevel.tscn` because Autumn exists. Autumn's `NEXT_SCENE` is
`res://scenes/WinterLevel.tscn` because Winter exists. Winter's own
`NEXT_SCENE` is `res://scenes/Level.tscn` (Spring), which closes the loop. So
the chain is a proper loop over all four finished seasons.

`SummerLevel.NEXT_SCENE` was changed from `res://scenes/Level.tscn` to
`res://scenes/AutumnLevel.tscn` on 2026-10-03, and `AutumnLevel.NEXT_SCENE`
from `res://scenes/Level.tscn` to `res://scenes/WinterLevel.tscn` on
2026-10-04. **Each time that one constant was the whole change** to that level
— nothing else in Summer or Autumn was touched.

### The Autumn -> Winter handover, and why its test was strengthened not relaxed

Wiring Autumn to Winter means one of Autumn's own assertions became false: it
used to require `NEXT_SCENE == res://scenes/Level.tscn`. That assertion was
**not** deleted or loosened to make the change pass. It was replaced with
checks that are strictly harder to satisfy:

- Autumn must lead to Winter **specifically**, and that scene must exist —
  where before, any scene at all would do.
- Autumn must **not** lead back to Spring or sideways to Summer, which is what
  actually pins Autumn as no longer being the end of the chain. Before, this
  check only excluded Summer, so a regression straight back to Spring would
  have slipped through.
- Summer must still lead to Autumn, and Winter must still lead to Spring, both
  read from each season's own `NEXT_SCENE` rather than typed into the test, so
  all four legs are checked together and cannot disagree with each other.

`tests/_season_chain_test.gd` then proves the two legs no static check can:
it builds the real source level, finishes it, waits out the banner pause,
confirms the shared banner and button really are up and really are wired to
the handler, calls that handler, and the destination announces itself and
quits 0. See §9.

### Known bug: the Winter test leaks one physics body at exit — not the fish, not fixed

`tests/_winter_test` prints four shutdown warnings on every run:

```
ERROR: 1 RID allocations of type 'P11GodotBody2D' were leaked at exit.
WARNING: 1 RID of type "CanvasItem" was leaked.
WARNING: 3 ObjectDB instances were leaked at exit.
ERROR: 1 resources still in use at exit (run with --verbose for details).
```

It does **not** fail the suite and the exit code is still 0, so it has been left
alone — but it is a real leak and someone should own it.

**It is pre-existing, established by bisection rather than assumed.** Adding the two
fish added 48 checks and a whole new scene, which is exactly the kind of change that
would be blamed for a leak. It is not: the warnings still appear with `_build_fish()`
**disabled** and only the original sections 1-8 enabled. Every other suite
(Autumn, Summer, garden, stack walk, stack jump, both chain legs, next level) is
clean. So the fish are cleared.

The signature — a `P11GodotBody2D`, i.e. a 2D physics body, plus a `CanvasItem` and
exactly one still-loaded script resource — points at a `StaticBody2D` built from a
`GroundTile.gd`, which fits the **icicle reset path**: `_on_icicle_hit()` parks the
penguins, resets the icicles and empties the igloo, and a tile or shelf body created
around there is outliving the tree. Worth reproducing in isolation with
`--verbose` before fixing; do not "fix" it by suppressing the warning.

### Known gap: the penguins use the `cat_*` artwork fields

Winter's penguins are the shared `Player` scene with its own artwork, and that
artwork goes in `Player.gd`'s `cat_texture` / `cat_region`, because those fields
were named for the cats. Same wart Autumn's foxes already have — see the next
heading. Renaming would mean editing `Player.gd`, `Player.tscn` and `Level.gd`, and
it is not worth a cosmetic rename touching three files.

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
  and passing — keep them, but do not let them be mistaken for game code. The
  Autumn harness lives in `tests/` instead, which is where a new one should go.
- `SKY_COLOR` in `AutumnLevel.gd` is an unused constant left over from the level
  being written. The project clears the viewport to plain white rather than
  drawing a sky, exactly as Summer does, so nothing references it. Harmless; safe
  to delete.
- `assets/Cat.png` is unused.
- `tests/_fish_probe.gd.uid` is an **orphan**: the `.uid` Godot generated for
  `tests/_fish_probe.gd` is still there, but the throwaway script itself is not.
  It is harmless — every suite loads and runs clean with it present, and an
  unmatched `.uid` is not what broke the Winter suite on 2026-10-04 (§7) — but
  it is clutter and can be deleted whenever.

- ~~The project is not under version control.~~ **Fixed 2026-10-01:** `git init`
  was run, a Godot `.gitignore` was added, and the working project was committed
  before the Summer fixes were started, so every change since is recoverable.
  Throwaway `/_probe_*` measurement scripts are ignored as well as deleted.

### How to move a picture after this session

`assets/` is organised by season, so a future Winter will mean
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
- **An `if` with no indented body is a parse error, and the message you get is
  almost never the one that helps.** `Fish.gd` had exactly that, and read from
  a *different* file it surfaced as `Could not parse global class "Fish"` —
  fourteen copies — plus a pair of `Cannot infer the type of "..."` errors in
  the file that merely *mentioned* the type. The useful form is only in the
  offending file:
  `--headless --path <proj> --script res://<file.gd> --check-only`, which
  reports `Expected indented block after "if" block.` with a line number.
  Run that over every `.gd` before believing a `class_name` error is a type
  problem. Full story in §7, 2026-10-04.
- **A suite whose root script fails to parse hangs forever and says nothing.**
  Same mechanism as the bare-`Node2D` gotcha above, reached a different way:
  the `.tscn` loads, the node exists, but there is no `_run()` and so no
  `get_tree().quit()`. Headless Godot then idles with nothing drawn and no
  output, forever. **So a headless run that prints nothing is not a slow run —
  it never started.** Read the output, not the clock, when deciding which it
  is; and remember that `tests/_winter_test` legitimately takes ~41s while
  printing the whole time (§2).

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
- **A `CollisionShape2D` outside a `CollisionObject2D` does absolutely nothing.**
  Godot only registers a shape with the physics server when its parent is a
  `StaticBody2D`, `Area2D` or similar. A bare `CollisionShape2D` hung under a
  plain `Node2D` looks like a collider in the scene tree, reads like one when you
  grep for it, and is completely inert. This is worth knowing in **both**
  directions: it cannot accidentally block a fox, but it also cannot be relied
  on to block one. When checking "is this scenery solid?", assert on the node
  type as well as on the presence of a shape.
- **A test that triggers `change_scene_to_file()` has no watchdog left afterwards.**
  The scene change frees the test node along with the level, so its `_process`
  stops by itself and any "did the press work?" timer inside it never fires. If
  the target scene does not quit for its own reasons, **the run hangs silently
  until something external kills it.** This is what happened with
  `_next_level_test` (§9, 2026-10-03). The lesson is: anything a test hands over
  to must be able to finish on its own, and the test should refuse to start
  unless the hand-off argument is actually present.
- **Check the argument list you hand a process on Windows.** Both `--path` and
  `--scene` contain spaces here. An unquoted value in `Start-Process
  -ArgumentList` gets split, Godot receives a truncated path, and the result looks
  like a game bug rather than a shell bug. Pass the whole command line as a
  single quoted string.
- **A test threshold can be stricter than the level it is testing.** `_autumn_test`
  §5 asked for the closest pair of leaves to be at least 900px apart. That is
  **geometrically impossible**: each leaf's x is pinned to the shelf named in its
  comment, so the widest legal `leaf1..leaf2` gap is 748px at any combination of
  positions, let alone 900. The suite was failing on an **outdated number, not a
  layout defect**, and the correct fix was the expectation, not the map. Before
  "fixing" a layout to satisfy a spacing assertion, check the arithmetic: work
  out the best value the constraint allows and see whether the assertion can ever
  pass.
- **The player's jump is ~5.7px higher than the constant says.** `JUMP_VELOCITY /
  GRAVITY` works out to 128px of rise, but Godot applies velocity and then moves the
  body, so the body lands about half a frame past the analytic apex — **measured at
  133.7px**. Reasoning about reachability from the nominal 128 is therefore always
  optimistic, and by enough to matter: Winter's two fish were first placed at y=344
  assuming 128, which left 3.4px of margin and let a *single* floor jump collect the
  far one. When a test needs a real jump height, derive it —
  `v*v/(2*g) + abs(v)*delta*0.5` — and never hard-code 128.
- **Two level instances in one process share one collision layer *and* one coordinate
  space.** Every level puts its players on the same layer, so a goal `Area2D` in a
  test-only level happily reports the *live* level's penguins standing inside its box.
  `_winter_test`'s soft-lock check builds a throwaway level and the first version put
  it at the origin: the throwaway igloo counted the real penguins, finished early, and
  then kept references to nodes that were about to be freed. **Build any second level
  far off to the side** (20000px worked) before trusting its counts.
- **Two `StaticBody2D`s at the exact same position can be resolved by dropping one
  through the floor.** Parking both penguins at one point inside the igloo made the
  solver shove one out of the world, where it fell to y = -25323 and kept going —
  with no error and no failed check, just a level that quietly stopped counting.
  This is the sharp end of the "park both players apart" rule above: on a *floor* the
  pair separates sideways, but stacked at the same point inside a goal box it goes
  through. Use two distinct spots (4560 / 4640).

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
completion screen.

**DONE: Autumn is built for real** (see §9, 2026-10-03). A 4800x720 scrolling
level with two foxes, 302 tiles, eleven shelves, a terrace, four leaves, four
picture-matched frames and ten decorative trees, and its own pixel-art camera
fix. `SummerLevel.NEXT_SCENE` now points at it, so the season chain is
Spring -> Summer -> Autumn -> Winter -> Spring.

**NEXT TASK: play all three seasons manually in the Godot editor.**

Everything automated is green — **847 checks across nine suites** — but all of it
is headless with simulated input. A human has still not played any of the loops
by hand, so that is the first thing to do:

1. Open the editor and play a full Spring run, then Spring -> Summer -> Autumn
   via the Next Level button, with both players. Watch for what the tests cannot
   see: whether the dogs read as clearly as the cats did, whether the carried
   rubbish is legible with no words on it, whether the `Wrong bin!` notice is
   readable and is on screen long enough, whether the sea reads as water or as
   clutter behind the level, and whether a filled bin looking unchanged is
   confusing (§7).
2. **In Autumn specifically, watch the camera.** It is the only level that
   scrolls, so it is the only place the seam fix (§9, 2026-10-03) can be seen.
   Walk the full 4800px and confirm there are no white lines between the ground
   tiles at any point, and that the pan still reads as smooth rather than as
   stepping. Then check the frames on the terrace really do read as four things
   to be matched with no words on them.
3. Confirm the transition all the way round by hand: Spring's button lands on
   Summer, Summer's lands on Autumn, Autumn's lands on Winter, and Winter's lands
   back on Spring.
4. **Play Winter with both players, all the way to the igloo, and specifically try
   the two fish** (§2.4). The tests prove each fish *cannot* be taken from the floor
   and *can* be taken from the shelf / by stacking, but they do it by parking a
   penguin and pressing jump on the exact spot. A human has to confirm the routes
   are actually pleasant: that fish 1 reads as reachable rather than as a guessing
   game, that the stack for fish 2 comes out naturally on ice rather than needing
   pixel-perfect placement, and that the finished igloo feels earned rather than
   like a formality. **Also check the fish are drawn centred on their own box** —
   that was wrong once already (§9) and no headless check can see it.
5. ~~`git init` and commit.~~ **Done 2026-10-01** — keep committing as work lands;
   this list is the only other record of what has happened and it is not a
   substitute for history.

**One thing to watch on that first manual playthrough:** the Summer bins now sit
in a row along the right-hand half of the beach (`x = 560, 860, 1120`) instead of
being spread to the far left as the layout picture has it, because the dogs spawn
on the left of the beach floor and the lowest sand shelf covers the rest of it. A
human should confirm that row of bins still reads as three separate destinations
rather than as a fence, and that the `Bin` labels sit legibly on each.

**Explicitly not started, and not to be started yet:** level selection, and any
level-management or scene-flow architecture beyond the single hard-coded transition. One
working season chain beats four half-built worlds. Also not done: any per-bin "filled"
feedback, any change to the `cat_*` field names (§7), and any manual playthrough by a
human.

---

## 9. Completed Work

### 2026-10-08 - Title screen, pause menu and settings, each in its season's colours

Done on the second machine (`C:\Users\Hp\Downloads\Four-Seasons`; Godot is at
`C:\Users\Hp\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
there). Built from the proposal's wireframes A, C and D (Figure 3), with the
seasonal styling the team asked for.

**What was added**
- **Title screen, now the main scene** (`scenes/TitleScreen.tscn/.gd`). "Four Seasons",
  a season badge, and Play (highlighted, keyboard starts on it), How to Play,
  Settings, Quit (last). The background is four little season scenes made **only from
  existing art** with the levels' own crops - no new pictures - fading from one to the
  next every 5s in level order, and the menu's colours follow. Play starts Spring.
- **Pause menu in every level** (`scenes/PauseMenu.tscn/.gd`): Esc or the corner Pause
  button. Resume (highlighted, keyboard on it), Restart this season, Settings, Back to
  title, which asks first with the keyboard on "No, stay".
- **Settings** (`scenes/SettingsMenu.tscn/.gd`): Music volume, Sound volume, Text
  size, Fullscreen. Changes apply and save immediately. From the title it wears the
  season on show; from a level, that level's season.
- **Shared helpers, no autoload:** `GameSettings.gd` (static vars + `ConfigFile`) and
  `SeasonTheme.gd` (colours and a `Theme` built in code).

**What was changed**
- `project.godot`: `run/main_scene` is now `res://scenes/TitleScreen.tscn`.
- `Level.tscn`, `SummerLevel.tscn`, `AutumnLevel.tscn`, `WinterLevel.tscn`: one
  `PauseMenu` node each (with its `season`), nothing else. **No level `.gd` changed.**

**Decisions worth knowing**
- **Volume sliders have nothing to control yet** - there is no audio. They set the
  `Music` and `SFX` buses, which `GameSettings` creates, so a sound added later only
  has to be put on one of those buses.
- **The "slower icicles" and "shape patterns" settings from wireframe D were left
  out on purpose** - the team asked for volume, text size and fullscreen only.
- **Saved settings are only applied to the scene actually being played**, never to a
  level a test builds under its own node. Otherwise a player who chose large text
  would make Summer's "Wrong bin! does not cover a bin" checks fail.
- **Text size scales from each label's designed size** (kept in node meta), so moving
  the slider back and forth never compounds.
- **The Pause button cannot take keyboard focus** (`focus_mode = None`), because
  Space and Enter are both jump keys *and* `ui_accept`: a focusable Pause button
  would be pressed by a jump.

**Testing** - all on this machine, Godot 4.7.2:
- Baseline before any change: all nine existing suites green (847 checks).
- After: **ten suites, 1,018 checks, 0 failures** - stack walk 66, stack jump 41,
  garden 136, summer 152, autumn 284, winter 140, next level 20, both chain legs 4+4,
  and the new **menus 171**. `--check-only` on every new script: 0 errors. The title
  and each of the four levels ran 400 frames headless with 0 errors / 0 warnings.
- **Negative check:** with `PauseMenu.open()` made not to pause, the menus suite fails
  ("pressing Pause pauses the game", in every season). Restored, green again.
- **Real renderer:** a throwaway `_probe_` script captured the title in all four
  seasons, Settings and How to Play on the title, and every level playing, paused, in
  Settings and (Winter) at the confirm. All looked right; the confirm wording was
  shortened after seeing it wrap badly. The probe is deleted.
- The Winter suite still prints its **pre-existing** leak warnings (§7) - identical
  text before and after this work.

**Gotchas found**
- **A test node set to keep running while paused passes that on to its children.**
  The menus suite runs `PROCESS_MODE_ALWAYS` (so it can keep going while it pauses
  the game), and the first version's Summer level inherited it, so a dog walked
  while "paused". In the game a level sits under the root and does pause; the suite
  sets the level back to `PAUSABLE` to match.
- **`ensure_loaded()` only reads the file the first time.** A test that writes odd
  values to its settings file on purpose must have already loaded once, or the next
  scene to call `ensure_loaded()` picks them up (the title was laid out at 1.5x text).
- **A real (non-headless) probe window takes keyboard input**, so a key pressed on
  the desktop while it runs can open a menu in the capture. A capture that looks
  wrong should be re-taken before it is believed.

**Not verified:** nobody has clicked through the menus by hand yet, and fullscreen
was only exercised through the code path (the headless suites skip it).

**Next:** play it by hand from the title: Play -> Esc -> Settings -> Back -> Restart
-> Back to title -> Quit, and try the text-size slider inside a level.


### 2026-10-04 - `Fish.gd` is repaired, and the Winter suite runs to the end again

**The task.** A headless run of `tests/_winter_test.tscn` was killed by
`Wait-Process -Timeout 60` with no output and no window. Find out why, fix the cause at
the root, keep the fish behaviour, do not touch the tests, do not raise the timeout, do
not commit.

**What it actually was.** Not an infinite loop, not a stuck scene, not a hung game, and
not a slow test. `scenes/Fish.gd:119` had an `if` with an empty body — the `by.pick_up(...)`
call from the fish-carrying work had been dedented out of its block — so `Fish.gd` did
not parse, `class_name Fish` could not be resolved from `tests/_winter_test.gd`, and the
test script never loaded. The `.tscn` still loaded, so the root node still existed with
no script on it: no `_run()`, no `_finish()`, no `get_tree().quit()`, and headless Godot
idled in an empty main loop until the 60s timeout killed it. The whole story, including
the misleading `Could not parse global class "Fish"` wrapper, is in §7.

**The change is `scenes/Fish.gd` and nothing else.** The `pick_up(...)` call went back
inside its `if` (that is the parse fix), and the collection gate lost `can_pick_up()`.
The second part was not cosmetic. `_collect()` hands the fish to `Player.pick_up()` so it
is visibly carried, and that sets `carried_kind`, which is exactly what makes
`can_pick_up()` false — so with the gate left in, a penguin that took fish 1 could never
take fish 2, and because Winter has two fish and the igloo requires both, it would have
locked itself out of finishing the level. `_winter_test` §10 collects **both** fish with
P1, so this was a real failure waiting to happen, not a theoretical one. A fish has no
destination and no wrong answer, so it does not reserve Spring's one-item pot slot; it is
still drawn in the penguin's hands.

**All five requirements are intact and asserted, not assumed:**

| Requirement | Where it is proven |
|---|---|
| exactly 2 fish | §9: `fishes.size() == 2`, the level's own `FISHES` table agrees, `fishes[i] is Fish` |
| collectible | §9: real jumps — a floor jump **cannot** take either, the C shelf **can** take fish 1, a stacked rider **can** take fish 2 |
| visibly carried | `_collect()` → `Player.pick_up()` → `CarriedIcon` + `_carried_fish`; documented in §2.4 |
| back on their spots after an icicle hit | §9: both `not is_collected and visible`, monitoring back on, `level._collected_fish` empty, both `position`s equal to the table again |
| both required to finish | §10: no fish → no finish, one fish → no finish, both → finish; §12: both fish but only one penguin → still no finish |

**Verified, not assumed.**

- `--check-only` over **all 22** `.gd` files: 0 parse errors.
- `tests/_winter_test.tscn`: **140 checks, 0 failures, `ALL CHECKS PASSED`, exit code 0**,
  41.4s.
- `scenes/WinterLevel.tscn`, 400 frames headless: exit 0, **zero errors, zero warnings**.
  The game was never broken — only the test could not be loaded.

**Nothing else was touched.** No test was edited or weakened, no timeout was raised, no
game mechanic changed, and nothing was committed. `scenes/Fish.tscn` needed no change.

**Two things deliberately left alone.** The Winter suite's exit-time
`P11GodotBody2D` leak is still there and is still the known one in §7 — bisected to the
icicle/reset path, present with the fish disabled, and not caused by any of this.
`tests/_fish_probe.gd.uid` is an orphan `.uid` with no `.gd` beside it, left over from
the fish-reachability probe; it loads harmlessly and is recorded in §7's housekeeping
list rather than deleted.

**One thing worth carrying forward: `tests/_winter_test` takes about 41 seconds and is
supposed to.** It is bound to real time, not to work — it awaits roughly 2,500 physics
frames of genuinely simulated walking, sliding, jumping, stacking and falling at 60Hz.
Wrapping it in a 60-second `Wait-Process -Timeout` and reading the timeout as a failure
is what started this session.

### 2026-10-04 - Winter gets two fish, and the igloo stops counting without them

**The task.** Put the new `assets/Winter/Fish.png` into the game as exactly two
collectibles, each a little hard to reach, encouraging jumping, stacking and working
together; make collecting them matter by holding the finish open; put them back when an
icicle resets the level; test and document it. Add nothing to the map, change no
existing mechanic, and do not commit.

**What was built.** `scenes/Fish.tscn` + `Fish.gd` (one scene, reused twice), built by
`WinterLevel._build_fish()` from a new `FISHES` table, and a `_Fish` container node in
`WinterLevel.tscn`. `_on_penguins_at_igloo()` now needs both penguins **and** both fish.
Nothing else in Winter changed: same tiles, same ice, same icicles, same igloo, same
`Level Complete.png` and the same single `Next_Button.png`. **Nothing was committed.**

| Fish | Centre | Box | Reached by |
|---|---|---|---|
| 1 | `(1560, 330)` | 1528..1592 x 298..362 | jump from the C low shelf, on its ice |
| 2 | `(4300, 330)` | 4268..4332 x 298..362 | stack on the ice run-up, rider jumps |

**The number that mattered, and the bug it caused.** The brief was that neither fish
should sit in a normal path. Both were first placed at y=344, reasoned from the
*nominal* 128px jump: 184px of clearance "beat" it comfortably. Then the probe measured
the real jump and it rises **133.7px**, because Godot integrates velocity and then moves
the body, overshooting the analytic apex by half a frame. That left only **3.4px** of
margin, and the probe caught fish 2 being collected by a **single floor jump**. Moving
both to y=330 puts the box bottom at 362 — 198px up, a clear 64px past the real jump and
a clear 40px inside the stacked one. This is the one thing worth remembering from the
session: **the number in the comment was not the number in the engine.**

The test now derives that rise from `Player.JUMP_VELOCITY` and `Player.GRAVITY`, so it
cannot be re-broken by editing `FISHES` alone.

**Reachability is proven by jumping, not by asserting coordinates.** Each fish gets a
trial where a penguin is parked and made to jump for real: fish 1 must **not** be taken
from the floor and **must** be from the shelf; fish 2 must **not** be taken solo and
**must** be taken stacked. Walking off the C high shelf also catches fish 1, which the
test pins down too — that route still needs the climb, so it was left as a second
solution rather than designed away, and the comment that claimed it could not reach was
corrected rather than the level bent around it.

**Two bugs the new tests found in existing-looking code:**

- `Fish._process()` asked `get_overlapping_bodies()` on a frame where `is_collected` was
  already false but monitoring had not yet come back (re-enabled deferred). The engine
  errors on that, and worse, it could have reported a penguin as touching a fish that was
  not switched on yet. Now guards on `monitoring` as well.
- The fish art was offset by half its height, copied from `Igloo` — which is correct
  there, because the igloo's node is the ground it stands *on*. A fish hangs in mid-air,
  so it was floating a whole body-height above the box that collects it. Now centred.

**A test-harness trap worth recording.** Parking both penguins at the *identical* point
made the solver resolve the penetration by pushing one through the floor — p2 fell out of
the world and kept going to y = -25323. They now stand at two separate spots inside the
168px goal box. Separately, the soft-lock test needed its own level, and the first
attempt built it on top of the live one: the goal box is an `Area2D` that sees *anything*
on the penguin layer, and every level in this game shares one collision layer and one
coordinate space, so the throwaway igloo counted the live penguins and then cached freed
nodes. It is now pushed 20000px off to the side.

**The soft-lock check.** Ordinary play cannot collect a fish while standing in the
igloo, so "last fish taken while both penguins already wait" is unreachable by playing.
If the level only listened to the igloo, it would hang there forever looking finished.
`_on_fish_collected()` therefore re-runs the goal check, and the test reaches the state
by hand on a throwaway level — once with both penguins waiting (must finish) and once
with only one (must not).

| Suite | Checks | Result |
|---|---|---|
| `tests/_winter_test` | **140** (was 92) | all pass, 12 sections |
| `tests/_autumn_test` | 284 | all pass |
| `_summer_test` | 152 | all pass |
| `_garden_test` | 136 | all pass |
| `_stack_walk_test` | 66 | all pass |
| `_stack_jump_test` | 41 | all pass |
| `tests/_season_chain_test` (`--winter-check`) | 4 | all pass, `NEXT LEVEL REACHED WINTER` |
| `tests/_season_chain_test` (`--autumn-check`) | 4 | all pass, `NEXT LEVEL REACHED AUTUMN` |
| `_next_level_test` (`--next-level-check`) | 20 | all pass, `NEXT LEVEL REACHED SUMMER` |
| **Total** | **847** (was 799) | **0 failures**, 0 script errors |

**On "was 92" when the entry below says 88.** Both are right at different times. The
"Winter is built" entry's table recorded **88**; four jump-clearance checks were added
after that table was written, so the suite actually ran **92** before the fish went in.
That entry's table has been left as it was written rather than retro-fitted — the counts
in each §9 entry are that session's record, not a running total.

Winter also runs clean in the **real renderer** (1280x720): 0 script errors, 0 failed
loads, no texture warnings.

**One pre-existing issue, not caused by this work and left alone.** The Winter test
reports an exit-time leak (`1 RID of type P11GodotBody2D`, a detached `StaticBody2D`,
`GroundTile.gd` still in use). It was traced by bisection: it still appears with the
fish disabled *and* only the pre-existing sections 1-8 enabled, and every other suite
is clean. It comes from the icicle/reset path, not from the fish.

### 2026-10-04 - Autumn hands over to Winter, closing the four-season loop

**The task.** Make the progression `Spring -> Summer -> Autumn -> Winter`, as an
intentional gameplay change. Update Autumn's next-level reference, update the
Autumn transition assertion **without weakening it**, and prove all four legs work.

**The game change is one constant.** `AutumnLevel.NEXT_SCENE` went from
`res://scenes/Level.tscn` to `res://scenes/WinterLevel.tscn`. Nothing else in
Autumn changed — same pattern as the Summer handover on 2026-10-03. Winter's own
`NEXT_SCENE` was already Spring, so the loop closes without touching Winter's
gameplay at all.

**The test was made harder, not easier.** This is the part worth being explicit
about, because the easy way to do this task is to edit the failing assertion until
it goes green. Instead the old check — which required `NEXT_SCENE == Spring`, and
whose companion only ruled out `SUMMER_SCENE` — was replaced by four checks that
are each strictly stronger:

| | before | after |
|---|---|---|
| target | any scene that exists, if it was Spring | **Winter specifically**, and Winter must exist |
| not-a-dead-end | only excluded Summer | excludes **Spring and Summer both** |
| neighbours | not checked | Summer still leads to Autumn, Winter still leads to Spring |

The neighbours are read from each season's own `NEXT_SCENE` rather than typed into
the test, so all four legs are checked together and cannot drift apart. Net effect
on the suite: **282 -> 284 checks**. Worth noting the old pair could both have
passed while the chain was quietly broken — the "middle of the chain" check never
excluded the Spring regression it was standing in for.

**A static constant check is not proof that a transition works**, because the level
suites cannot press their own button: `change_scene_to_file` frees the very scene
running the test. So `tests/_season_chain_test.gd` was added to close that gap. It
builds the real source level, finishes it through the level's own handler, waits
out the banner pause, confirms the shared banner and button really are up and
really are wired to that handler, then calls it — and the destination announces
itself and quits 0:

```
chain Summer -> Autumn   NEXT LEVEL REACHED AUTUMN    exit 0
chain Autumn -> Winter   NEXT LEVEL REACHED WINTER    exit 0
```

Calling the handler counts as pressing the button because the Summer and Autumn
suites *separately* assert that the `Next Level` button's `pressed` signal is
connected to that exact handler; what this test adds is the part they cannot check
without freeing themselves — that the scene change really happens and the
destination really loads and builds.

**This also gave `--autumn-check` its first caller.** That arrival hook had been
sitting in `AutumnLevel.gd` since Autumn was built with nothing using it, so
**Summer -> Autumn had never actually been driven end to end** — it was only ever
read as a constant. It is now proven for real. Winter gained the same hook
(`--winter-check`), mirroring `SummerLevel` and `AutumnLevel` exactly: it only
prints and quits under that user argument, and has no effect on normal play.

The two legs need separate runs, because `--autumn-check` makes Autumn quit the
instant it loads, which would stop the Winter leg from ever starting. Running the
test with neither argument fails in one second with the invocation it needs, rather
than hanging until the runner's timeout.

| Suite | Checks | Result |
|---|---|---|
| `tests/_season_chain_test` (`--autumn-check`) | 4 | **all pass**, `NEXT LEVEL REACHED AUTUMN`, exit 0 |
| `tests/_season_chain_test` (`--winter-check`) | 4 | **all pass**, `NEXT LEVEL REACHED WINTER`, exit 0 |
| `_next_level_test` (`--next-level-check`) — Spring -> Summer | 20 | all pass, `NEXT LEVEL REACHED SUMMER`, exit 0 |
| `tests/_winter_test` | 88 | all pass |
| `tests/_autumn_test` | **284** | all pass |
| `_summer_test` | 152 | all pass |
| `_garden_test` | 136 | all pass |
| `_stack_walk_test` | 66 | all pass |
| `_stack_jump_test` | 41 | all pass |
| **Total** | **795** | **0 failures**, 0 script errors, every suite exit 0 |

Winter's own completion and Next Level behaviour is unchanged and still covered by
its 88 checks. **Player 1's controls were deliberately left as A/D + Space, with no
W/S aliases added.**

### 2026-10-04 - Winter is built: ice, falling icicles, and an igloo for two

**The task.** Build Winter from the supplied penguin, snow, ice, icicle and igloo
artwork, as a long horizontal two-player level, reusing the existing systems rather
than rebuilding them. Verified in stages, each stage proven before the next was
started. See §2.4 for the level itself.

**What was reused, deliberately.** `GroundTile.tscn` is the snow and the ice.
`Player.tscn` is the penguins — so they move, jump, stack and collide exactly as the
cats, dogs and foxes already did. The `Level Complete.png` banner and the single
`Next_Button.png` button are the shared ones, at Spring's exact offsets. The
completion rules, the 1.5s pause and the camera are borrowed from Autumn unchanged.
**`Player.gd`'s existing movement line is byte-for-byte untouched**, so no other
season can be affected by the ice.

**Three small additions to shared code, all opt-in and all defaulting to today's
behaviour:** `GroundTile.slippery` (false everywhere else), one ice branch in
`Player.gd`, and `Player.reset_to_position()`. Everything else Winter-specific is
four new scenes — `WinterLevel.tscn`, `Icicle.tscn`, `Igloo.tscn` and, added later the
same day, `Fish.tscn` (§9).

**Two real bugs found and fixed, both by measuring rather than looking.**

1. **An icicle whose trigger moved with it could never stop resetting.** An `Area2D`
   reports bodies entering it when its *shape moves*, so a trigger falling alongside
   its icicle re-reported the penguin standing in it every frame and the level reset
   forever. The same trap exists on the other side: a zone that switches its
   monitoring off and on again re-reports its current occupant. The fix is the
   structure now in `Icicle.tscn` — **the root and the ground zone are static and
   never move**, only the inner `Moving` node is animated, the ground zone stays
   monitoring for good, and the state guards the start. `tests/_winter_test` now
   counts the `player_hit` signal across a whole fall, because one fall reporting
   exactly one hit is the actual requirement and a single frame cannot show it.

2. **Every snow and ice tile was missing its underside.** The crop was 64x56,
   copied from the other seasons, but Winter's tiles are **64x64** and their last 8
   rows are a shaded bottom face — the same 8 rows Spring and Autumn have at
   48..55. Cropping to 56 deleted them, so ledges rendered with no bottom face, and
   **nothing anywhere reported an error**. Measuring each PNG's real opaque bounding
   box found it. `_winter_test` now measures the box and insists the region asked for
   matches it exactly, in both directions, so neither a short crop nor a padded one
   can come back.

**A third thing that was a test bug, not a level bug.** The first version of the
suite asserted an icicle stayed `SPENT` after it hit someone. It does not, and should
not: the level resets every icicle along with the players, so `SPENT` is a transient
frame. The check was rewritten to count hits per fall, which is the property that
matters, rather than to sample one frame.

**Also worth recording: the igloo is built in code, not placed in the scene file.**
An `Area2D` placed in `WinterLevel.tscn` is readied *before* the level's own
`_ready()` runs, so it computed its own scale from a texture it had not been given
yet — `display_height / 0`, i.e. an infinite scale. `$Goals` is an empty container
and `_build_igloo()` instantiates it after filling in its exports. This is the same
ordering Autumn's leaves and frames already rely on.

**Autumn was wired to hand over to Winter later the same day.** When Winter was
first built, Autumn's `NEXT_SCENE` was left pointing at Spring, because changing it
also falsified an assertion in `_autumn_test.gd` and editing a test to make a change
pass is not something to do quietly. Once that was called explicitly and confirmed
as intended, the handover was made and the assertion **strengthened rather than
relaxed** — see §7 for exactly how, and §9 for the end-to-end proof. The chain is
now `Spring -> Summer -> Autumn -> Winter -> Spring`.

**Testing.** New `tests/_winter_test.gd` / `.tscn`, **88 checks across 10 sections**.
Every suite in the project was rerun afterwards.

| Suite | Checks | Result |
|---|---|---|
| `tests/_winter_test` | 88 | **all pass** |
| `tests/_autumn_test` | 282 | all pass |
| `_summer_test` | 152 | all pass |
| `_garden_test` | 136 | all pass |
| `_stack_walk_test` | 66 | all pass |
| `_stack_jump_test` | 41 | all pass |
| `_next_level_test` (`--next-level-check`) | 20 | all pass, exits 0 |
| **Total** | **785** | **0 failures**, 0 script errors |

Also verified in the **real renderer** (`--rendering-driver opengl3`, 1280x720):
the level loads, builds and runs with no errors, warnings or leaks.

**Known gaps left open on purpose.** No human has played it. Winter is unreachable
because of the Autumn handover above. The ice acceleration is a first guess
(`900`/`260`) chosen to be felt rather than measured against a design target, and
may want tuning by hand. The cameras and tile seams still deserve a real eye on a
human monitor.

### 2026-10-04 - The Next Level button gets a new picture

**The task.** Swap the Next Level button's picture for a new PNG,
`assets/Next_Button.png`, changing nothing else: same click behaviour, same
transition, same place on the screen unless the new dimensions genuinely required
an adjustment, no redesign of the completion screen, no changes to any season's
gameplay, the camera or the completion rules, and no second button.

**The change is three scene files and four test constants.**

- `scenes/Level.tscn`, `scenes/SummerLevel.tscn`, `scenes/AutumnLevel.tscn`: the
  `3_next_texture` ext_resource now points at `res://assets/Next_Button.png`
  (`uid://gxeab5jg1850`) instead of `res://assets/Next Level.png`. The
  `NextLevel` node keeps its name, type, `z_index = 101`, `visible = false`,
  `disabled = true` and its position's top edge; only the rect and the scale
  changed, and only because the picture is a different size.
- `_garden_test.gd`, `_summer_test.gd`, `_next_level_test.gd`,
  `tests/_autumn_test.gd`: `NEXT_TEXTURE` now preloads the new PNG. These four
  suites are what assert the button carries the right picture, so leaving them
  pointing at the old file would have quietly stopped testing the swap.
- `assets/Next_Button.png.import` generated (`uid://gxeab5jg1850`), with byte-for-byte
  the same import settings as the picture it replaces: no mipmaps, no size limit,
  `fix_alpha_border` on. Nothing was resized on disk or recoloured.

**No gameplay code was touched.** `Level.gd`, `SummerLevel.gd` and
`AutumnLevel.gd` are unchanged: `_ready()` still forces the button hidden and
disabled, `_reveal_banner()` is still the only thing that shows it,
`_on_next_level_pressed()` still loads the same next season, and
`complete_banner_delay` is still 1.5s. The button is revealed on exactly the
same frame as before, through exactly the same code path.

**Why the rect and scale moved, and why that is the minimum.** The old picture
was 512x256 with 408x232 of artwork and had to be shrunk by `scale 0.7`. The new
one is 196x177 with 160x160 of artwork, which is already about the size the old
artwork was being drawn at (160 tall against 162.4), so it is now drawn **at
1:1** and the `scale` line is gone entirely. That is the whole reason the rect
is not the old one: a `TextureButton` draws its picture into its own rect, so
leaving the rect at 512x256 would have stretched the new picture to more than
twice its size and distorted it. `offset_top` is still exactly `542`, the whole
rect now fits inside the screen instead of overhanging the bottom by 1.2px, and
the centre moved 3.2px left and 1.1px up, from `(1049.2, 631.6)` to
`(1046, 630.5)`.

**The old picture was left on disk.** `assets/Next Level.png` is now referenced by
nothing, exactly like `assets/Cat.png`, and is recorded as unused in §3 rather
than deleted — deleting someone's art is not this task's call. Delete it whenever
you like; nothing will break.

**Verified, not assumed.**

- **All six suites pass, 697 checks, 0 failures, 0 script errors** — 66 stack
  walk, 41 stack jump, 136 garden, 152 summer, 282 autumn, 20 next level, plus
  the live Spring -> Summer scene change. The three seasons' gameplay, the
  camera and the completion rules are covered by those suites and are untouched.
- **Hidden when gameplay starts.** Asserted by four suites from the first frame
  (`not visible and disabled`), and re-checked after the reveal by all of them.
- **Appears only once the level is finished.** `_reveal_banner()` is the only
  writer of `visible = true`, and the garden and next-level suites both check the
  button is still hidden and disabled partway through the 1.5s completion pause.
- **It is clickable.** Under a real `--rendering-driver opengl3` renderer,
  `Input.warp_mouse()` to the button's centre plus a real press/release pair fires
  `pressed` exactly once; a click 60px outside fires nothing. `_next_level_test`
  separately presses it and lands in Summer (`NEXT LEVEL REACHED SUMMER`, exit 0).
- **The new PNG is displayed correctly, with no scaling and no distortion.**
  Measured from real frames, not from node flags: the button changed exactly
  **15,232 pixels inside `x 970..1130, y 552..712`** — the 160x160 artwork box
  the scene predicts, to the pixel, with no spill. A 290-point grid over the drawn
  artwork matched the PNG's own pixels with a worst per-channel difference of
  **0.00000**, and beat all twelve deliberately wrong pixel alignments, so nothing
  in the chain resamples it.
- Three of those guarantees are now permanent: `_garden_test` §1b asserts the
  button's drawn size equals the PNG's size, that its `scale` is uniform, and
  that the whole button is inside the screen (136 checks, up from 133).

**One thing worth knowing if you test mouse input yourself.** A synthetic
`InputEventMouseButton` on its own does **not** reach the control tree — the GUI
hit-tests against the real cursor position, so `Input.warp_mouse()` has to come
first. That is the same reason `_next_level_test` presses the button through its
own `pressed` signal rather than a fake click. And a real window with a script
that fails to parse will simply hang forever with no output, so a probe run
wants `--quit-after` as a backstop.

### 2026-10-03 - Autumn is built, the trees become scenery, and the camera stops tearing the ground

**Autumn is built.** `scenes/AutumnLevel.gd` / `.tscn` and
`scenes/LeafFrame.gd` / `.tscn`, built in code from constants exactly the way
Spring's `Level.gd` and Summer's `SummerLevel.gd` are. **4800x720** — the first
level in the project wider than one screen. 302 tiles, eleven shelves, a raised
terrace at columns 60-74 for the frames, two foxes, four leaves, four frames,
ten trees. Full layout and rules in **§2.3**.

**What was reused, not rewritten.** `Player.gd` / `Player.tscn` are **completely
untouched** — the foxes are 256x256 art cropped to `Rect2(16, 40, 216, 168)`, the
same 56px as a cat or a dog, and authored facing left, so `PLAYER_SPAWNS` needed
no new shape and facing still means `flip_h`. `GardenItem` is the leaf. The
`Level Complete.png` banner and `Next Level.png` button are the shared ones at
Spring's exact offsets and scale. `GroundTile.tscn` is the autumn ground, through
the two optional exports Summer already added. `TrashBin.gd` was the model for
`LeafFrame.gd` down to polling an area every frame instead of using
`body_entered`.

**The rule is visual and nothing else.** Each frame's artwork has a ghosted leaf
silhouette burned into it and every leaf matches exactly one, so the picture
alone says where it goes. **No `Label`, no number, no colour, no wording on the
scene.** The right leaf is consumed and drawn inside the frame; anything else is
refused and the fox keeps carrying it. Refusals are counted against the kinds
declared in the level's own `FRAMES` table, so the level and its frames cannot
disagree about what "finished" means.

**The trees are now decoration only.** Originally five of the ten were
`StaticBody2D`s on the world collision layer with a 72x88 box, so a fox had to
jump them. All ten are now plain `Node2D`s holding one `Sprite2D` at
`z_index = -5`, at their original x positions, with **no collision shape, no
physics body and no area anywhere**. `TREE_BOX` is deleted and `_build_trees()`
has no collision branch left at all. **The artwork, crop, scale and anchor are
unchanged**, and the map, shelves, leaves, frames and terrace were not touched.

**Proved behaviourally, not just by inspection.** `_autumn_test` §3 walks a fox
right through each of the ten trees in turn, reading the positions from the
level's own `TREES` constant so the test cannot drift from the map. With the old
collider a fox could only reach 66px past a trunk, so the check demands 100px
clear of every one, plus a jump through one, plus confirmation that no leaf got
picked up and the level is otherwise unchanged.

**Negative test, run deliberately.** Restoring the old `StaticBody2D` colliders
made **12 checks fail**, every one of them the right kind — `no tree has a
collision shape or area anywhere under it`, and all eleven walk-through checks
reproducing the old blocking exactly (`x=512` reached only 461, `x=2880` reached
2814). Reverted and re-verified green. A weaker negative was also run and is
worth remembering: a bare `CollisionShape2D` under a plain `Node2D` failed only
**1** check and blocked nothing at all, because Godot ignores a shape that is not
inside a `CollisionObject2D`.

**The white lines between the ground tiles are fixed.** See "Camera" in §2. Root
cause, measured rather than guessed: the smoothed camera sat on fractional
pixels (`87/90` sampled frames), and at exactly half a pixel the GL Compatibility
renderer leaves a one-pixel background gap at **every** 64px tile seam — 20 seams
x 160 rows = **3200 background pixels** in one frame at `camera.x = 2100.5`, while
`2100.0`, `2100.25` and `2100.75` were all clean. The tiles themselves were
exonerated: all 302 are on whole pixels at unit scale with nearest filtering, and
`Camera2D` in Godot 4.7.2 has **no** `snap_2d_transforms_to_pixel` property at
all, while the project-level `rendering/2d/snap/*` settings are both `false`.

**The fix is one line of behaviour and it does not touch the art.** Engine
`position_smoothing_enabled` is now off and the level eases the camera itself
with the same `CAMERA_SMOOTHING = 8.0` speed (`1 - exp(-8 * delta)`), then
assigns `roundf()` to the camera x. **The pan still reads as a smooth pan** — the
smoothing was moved, not removed. Nothing in the level moved. Verified by a
170-frame sweep of the real camera across the map: **0/170 frames off the pixel
grid, 0/170 frames with a seam gap, 0 background pixels in the ground band.**

**Two test bugs fixed, both mine, neither a gameplay change.**
- `_next_level_test` **hung for 400s after all 20 checks passed**, and the cause
  was the invocation, not the test: the suite presses Next Level, that frees the
  test node along with the Spring level, and the Summer level only quits when it
  sees the `--next-level-check` user argument. Run without it, Summer builds
  normally and runs forever, and the test's own `_process` watchdog is gone with
  the freed node. **A guard now fails fast in 0.3s with the invocation it needs**,
  because the test cannot finish without that argument. Run correctly it passes
  20/20 and exits in 3.5s.
- `_autumn_test` §5's leaf-spread assertion demanded 900px between the closest
  two leaves, which is **geometrically impossible** — the leaves are pinned to
  their shelves and the widest legal gap at any combination of positions is
  748px. It was an outdated expectation, not a layout defect, and the map was
  left alone. The bound is now 600px plus a new check on the first-to-last span,
  which is the property that actually forces a walk (2368px of a 4800px map).

**Testing.** New `tests/_autumn_test.gd` / `.tscn`, **282 checks across 9
sections**. It reads its expectations out of the level's own constant map rather
than hard-coding them, so moving a leaf or frame moves the expectations with it.

| Suite | Checks | Result |
|---|---|---|
| `tests/_autumn_test` | 282 | **all pass**, zero stderr |
| `_summer_test` | 152 | all pass |
| `_garden_test` | 136 | all pass |
| `_stack_walk_test` | 66 | all pass |
| `_stack_jump_test` | 41 | all pass |
| `_next_level_test` (`--next-level-check`) | 20 | all pass, exits 0 |
| **Total** | **697** | **0 failures** |

**Known gaps left open on purpose.** No human has played it: everything here is
headless with simulated input, and the camera fix in particular deserves a real
renderer's eye. `Winter` does not exist, so the loop returns to Spring after
Autumn. The dogs and foxes still live in fields called `cat_*`. There is still
no per-bin "filled" feedback. `SKY_COLOR` in `AutumnLevel.gd` is a leftover
unused constant.

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
