# Four Seasons — Claude Code notes

A 2D local co-op platformer in **Godot 4.7.2** (GL Compatibility), a student project
for DIT2234 Human Computer Interaction (proposal: `Four_Seasons_Proposal.docx`, due
**2026-10-09**). Two players share one keyboard and can stand on each other's heads.
Cats (Spring) → Dogs (Summer) → Foxes (Autumn) → Penguins (Winter) → back to Spring.

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
`_next_level_test` (`-- --next-level-check`), and `tests/_season_chain_test`
(`-- --autumn-check` / `-- --winter-check`). They can run in parallel.
New test harnesses go in `tests/`.

## Status
- All four seasons are playable and chained in a loop, each with its own goal and the
  shared Level Complete + Next Level screen.
- **2026-10-08:** title screen (now the main scene), a pause menu in every level, and
  a settings panel (music, sound, text size, fullscreen), each styled to its season.
- Tests: 10 suites, **1,018 checks, 0 failures** (2026-10-08).
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

## Gotchas that cost time
- A headless run that prints **nothing** has a parse error; it isn't slow. Use `--check-only`.
- A test node with `PROCESS_MODE_ALWAYS` passes it on to child levels. Set the level
  back to `PAUSABLE` to test pausing.
- `GameSettings.ensure_loaded()` only reads the file the first time it's called.
  Tests redirect `GameSettings.save_path` and load once at the start.
- A real (non-headless) Godot window takes desktop keyboard input. If a screenshot
  looks wrong, take it again before trusting it.
- Asset names are easy to mistype: `Glass bin.png`, `Autumn Tile.png`, `Autumn_Tree.png`,
  `Snow Tile.png`, `Ice tile.png`. Winter tiles crop 64x64, the others 64x56.
- More in `PROGRESS.md` §7 "Not bugs — gotchas when testing".

## The proposal vs the game
The proposal promises more than is built. Still missing: story intro, in-game HUD
(season badge + checklist), hint key (H), season-clear SDG fact screens, ending recap,
audio, and mouse click-to-move. Mechanics also differ: the game is 2-player co-op
(the proposal reads as a leader with a following group), Autumn has 4 leaves and frames
(the proposal has two rounds of baskets), Summer has 3 pieces of rubbish (the proposal
has about 9), and Winter has an igloo, two fish and a full reset (the proposal has
warning shadows and snow-mound checkpoints). The conclusion still says "Little Seasons".
Ask which side should change, the game or the document.

## Next steps
- [ ] Play through by hand from the title: Play → Esc → Settings (drag Text size) → Back
      → Restart → Back to title → Quit. Also try fullscreen for real.
- [ ] Decide which proposal gaps to close before the 2026-10-09 deadline, or reword the proposal.
- [ ] Manual checks still open from PROGRESS §8: the Autumn camera seams, the Winter fish routes, the whole season loop.
