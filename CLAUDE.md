# Four Seasons — Claude Code notes

A 2D local co-op platformer in **Godot 4.7.2** (GL Compatibility), a student project
for DIT2234 Human Computer Interaction (proposal: `Four_Seasons_Proposal.docx`, due
**2026-10-09**). Two players share one keyboard and can stand on each other's heads.
Cats (Spring) → Dogs (Summer) → Foxes (Autumn) → Penguins (Winter), two levels per
season, between a story intro and an ending.

## Start here
- **Read `PROGRESS.md` before changing anything.** It is the full handover log
  (features, bugs, gotchas, dated history in §9). If it disagrees with the code, the
  code wins — fix `PROGRESS.md`.
- Follow `PROGRESS.md` §10 Development Rules: the developers are beginners, so keep
  code simple. No managers, autoloads or event buses; extend existing systems
  (one `Player.gd`); don't touch working features while fixing something else.
- At the end of a session, add a dated entry to `PROGRESS.md` §9. Don't erase history.

## Paths (this PC)
- Project: `C:\Users\Hp\Downloads\Four-Seasons`
- Godot console exe: `C:\Users\Hp\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
  (the folder name ends in `.exe`).
- `PROGRESS.md` commands use the other team PC's paths (`C:\Users\Chloe Cheng\...`).
  Swap in the paths above.
- The `.mcp.json` Godot MCP server points at the non-console exe in the same folder.

## Commands
```bash
G="/c/Users/Hp/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
P="C:/Users/Hp/Downloads/Four-Seasons"
"$G" --headless --path "$P" --import                                   # after adding a class_name
"$G" --headless --path "$P" --script res://scenes/X.gd --check-only    # real parse errors
"$G" --headless --path "$P" --scene res://tests/_menus_test.tscn        # one suite
```
Suites (all must print `ALL CHECKS PASSED` or their arrival line):
`_stack_walk_test`, `_stack_jump_test`, `_garden_test`, `_summer_test` (project root),
`tests/_autumn_test`, `tests/_winter_test` (~41s, legitimately slow), `tests/_menus_test`,
`tests/_level2_test`, `tests/_story_ending_test` (`-- --spring-check`),
`_next_level_test` (`-- --spring2-check`), and `tests/_season_chain_test`, once per leg,
named after the destination: `-- --summer-check`, `--summer2-check`, `--autumn-check`,
`--autumn2-check`, `--winter-check`, `--winter2-check`, `--ending-check`. They can run in
parallel. New test harnesses go in `tests/`.

## Status
- Flow: Title → Story intro → Spring 1 → Spring 2 → Summer 1 → Summer 2 → Autumn 1 →
  Autumn 2 → Winter 1 → Winter 2 → Ending (Play again → Spring 1).
- **2026-10-08:** title screen (now the main scene), a pause menu in every level, and
  a settings panel (music, sound, text size, fullscreen), each styled to its season.
- **2026-10-14:** a second level per season (Spring 2 / Summer 2 long and scrolling,
  Autumn 2 / Winter 2 one screen), a five-page story intro, and an ending (recap with
  each season's SDG fact, then a four-season finale).
- Tests: 12 suites (the chain suite runs as 7 legs), **1,299 checks, 0 failures**
  (2026-10-14).
- Known, pre-existing: the Winter suite prints leak warnings at exit (PROGRESS §7). It
  still passes; don't suppress the warnings.
- **Nobody has played the game by hand yet.** All verification so far is headless or
  scripted screenshots.

## Key decisions
| Decision | Why |
|---|---|
| Menus follow the proposal wireframes (Figure 3 A/C/D) but use season colours: Spring `#6BBF67`, Summer `#F3B843`, Autumn `#E07A30`, Winter `#80B5E3`, navy `#1F3B73` | The team wanted the mockup's layout with the four-seasons theme; colours come from the proposal's screen-flow figure (`scenes/SeasonTheme.gd`) |
| `GameSettings` is `class_name` + `static var`s, not an autoload | Static vars survive scene changes; this keeps the project's no-autoload rule |
| Saved settings are applied only when the level is `get_tree().current_scene` | Test suites build levels under a test node; a player's saved large text must not move what the tests measure |
| `PauseMenu` is one instanced node per level scene, with `season` set on it | No level `.gd` changes; each level picks its own theme |
| Pause button has `focus_mode = None` | Space/Enter are jump keys *and* `ui_accept`, so a focusable Pause button would be pressed by jumping |
| Always set `get_tree().paused = false` before `reload_current_scene()` / `change_scene_to_file()` | `paused` belongs to the tree and survives a scene change |
| Volume sliders drive `Music` / `SFX` buses created in code | There is no audio yet; sounds added later only need the right bus |
| Settings left out: slower icicles, shape patterns | The team asked for volume, text size and fullscreen only |
| Level 2 = the same season script with `stage = 2` and `STAGE_2_*` tables, not a new script | One script per season (PROGRESS §10); level-1 consts untouched, so old tests still describe level 1 |
| Level 1's Next Level → `STAGE_2_SCENE`; level 2's → `NEXT_SCENE` (still "the next season") | Keeps the existing chain assertions true |
| Spring/Summer camera follows only when the level is wider than one screen | Level 1 must render exactly as before |
| Level 2 banner/labels in a `UI` CanvasLayer, found by `%UniqueName` | They must not scroll away, and one script serves both layouts |
| Story = intro + ending only, "the wheel of the year has stopped" | The team chose no per-level story cards; the thread ties the seasons together |
| Ending recap shows the proposal's season-clear SDG facts | Partly closes the missing "season-clear fact" promise |
| Intro, ending and title share `TitleScreen`'s static season builders | No copied drawing code |

## Gotchas that cost time
- A headless run that prints **nothing** has a parse error; it isn't slow. Use `--check-only`.
- A test node with `PROCESS_MODE_ALWAYS` passes it on to child levels. Set the level
  back to `PAUSABLE` to test pausing.
- `GameSettings.ensure_loaded()` only reads the file the first time it's called.
  Tests redirect `GameSettings.save_path` and load once at the start.
- A real (non-headless) Godot window takes desktop keyboard input. If a screenshot
  looks wrong, take it again before trusting it.
- Headless process frames are uncapped, so waiting N process frames is not N/60s. Wait
  real time (`create_timer`) for Tweens, or physics frames.
- A used-up item is `queue_free()`d. Don't compare a loop variable against it later.
- The garden suite's pause-timing check can fail when all suites run in parallel (1.89s
  against 1.5s). It passes on its own.
- Long heredocs with quotes break in this Bash tool. Write scripts to the scratchpad first.
- Asset names are easy to mistype: `Glass bin.png`, `Autumn Tile.png`, `Autumn_Tree.png`,
  `Snow Tile.png`, `Ice tile.png`. Winter tiles crop 64x64, the others 64x56.
- More in `PROGRESS.md` §7 "Not bugs — gotchas when testing".

## The proposal vs the game
The proposal promises more than is built. Built since: the story intro and an
ending recap (with the SDG facts). Still missing: in-game HUD (season badge + checklist),
hint key (H), season-clear SDG fact screens *between* seasons, audio, and mouse
click-to-move. Mechanics also differ: the game is 2-player co-op
(the proposal reads as a leader with a following group), each season has two levels,
Autumn has 4 + 3 leaves and frames (the proposal has two rounds of baskets), Summer has
3 + 6 pieces of rubbish (the proposal has about 9), and Winter has an igloo, two fish and a full reset (the proposal has
warning shadows and snow-mound checkpoints). The conclusion still says "Little Seasons".
Ask which side should change, the game or the document.

## Next steps
- [ ] Play the whole game by hand, title → intro → all 8 levels → ending → Play again.
      PROGRESS §8 lists what to watch for in each new level.
- [ ] Menus by hand: Play → Esc → Settings (drag Text size) → Back → Restart → Back to
      title → Quit. Also try fullscreen for real.
- [ ] Decide which proposal gaps to close before the 2026-10-09 deadline, or reword the proposal.
- [ ] Manual checks still open from PROGRESS §8: the Autumn camera seams, the Winter fish routes, the whole season loop.
