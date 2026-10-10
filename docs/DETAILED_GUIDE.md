# Shoal for norns — detailed guide and porting notes

An incremental, test-first port of [Ormer Modular Shoal](https://github.com/ormermodular/shoal) to norns.

This build is a playable norns community beta. `lib/shoal_core.lua` remains a pure Lua 5.3, eight-track reference port. The norns instrument runs four of those tracks. `lib/shoal_clock.lua` schedules them against the norns quarter-note clock; `lib/shoal_outputs.lua` routes events to PolyPerc, n.b., MIDI, or crow. `shoal-norns.lua` supplies parameters and a four-row performance screen; an optional 16 × 8 Grid provides a two-page live parameter editor without copying the sequencer. The overview uses norns Particle (face 68, size 8); `lib/shoal_font.lua` draws sharp pixel glyphs for the editing pages and an exact compact fallback for crowded overview values.

Unless noted, file paths and test commands below are relative to the repository root.

## Install and play on Norns

1. Copy this entire `shoal-norns` folder into `/home/we/dust/code/` on norns using SFTP or the file share. The main script must end up at `/home/we/dust/code/shoal-norns/shoal-norns.lua`. Once the public GitHub repository exists, its URL can be passed to Maiden's `;install` command instead; see [the publishing checklist](PUBLISHING.md).
2. Open Maiden at `norns.local`, then choose `SHOAL-NORNS` from the Norns SELECT menu. If the script is not listed yet, restart Norns or reload the script list.
3. Track 1 is routed to the built-in PolyPerc engine by default. Listen on Norns headphones or audio outputs. Tracks 2–4 start with output Off; all four advance their musical state.
4. On the overview, use E1 to select a track, E2 for its rate, E3 for its length, K1+E2 for Chance, and K1+E3 for Evolve. K2 runs/stops; K3 arms a new seed for the selected track. Hold K1 and press K3/K2 to move forward/backward through the four script pages. More settings are in PARAMETERS.
5. In PARAMETERS > EDIT, open one of the four `TRACK` groups to set its Output to MIDI, crow 1/2, crow 3/4, or n.b. as desired. For MIDI, set the global `MIDI port` (1–16) to the same virtual slot shown under `SYSTEM > DEVICES > MIDI` on your Norns; it defaults to 1. Set the track's `MIDI channel` to the channel expected by the receiver. You can also edit Output, MIDI port, and channel on the script's Global page. For crow, connect the first output of a pair to pitch and the second to a gate input. The pitch convention is 0 V = MIDI note 48 (C3), 1 V/octave.

n.b. support activates with either the copy bundled by `nbout` or a standalone library at `dust/code/nb`, plus a compatible voice. Select `Output = n.b.` and an `n.b. voice` in the track group. Then return to the top-level EDIT list and open that voice's group beneath `N.B. SOUND` to shape its sound. This is the same n.b. parameter mechanism used by nbout: a voice's sound parameters belong to the voice, so two tracks selecting the same voice share those settings. The script starts and plays PolyPerc without n.b. For MIDI or crow, attach the relevant device before selecting that output. Maiden's `matron` log is the place to inspect load or runtime errors.

The overview has one row per track. It draws the **whole pattern**, not an eight-step page: short patterns get wide cells, long patterns progressively narrower ones, up to 64 distinct columns. Bar height suggests pitch; a low tick is a rest. A bright outline/column marks the position most recently visited by that track's clock, even when the step is silent. A play triangle or stop square replaces RUN/STOP (two bars mean Freeze). The top line follows E1's selected track: `T1`, position/length such as `07/16`, `S123` Seed (`*` means a reseed is armed), `F2` if following Track 2, and Direction. Its fields have two spaces between them; when Follow plus a pending seed crowd the line, only Direction is abbreviated, not cut mid-word. Holding K1 briefly replaces that text with the Chance/Evolve encoder hint. The selected row is brighter, while its `T` number appears in the header; omitting row numerals frees enough horizontal space to retain all 64 step columns and separate the four values clearly.

The four values to the right of each row are always Rate, bare Length, `%` Chance and `E` Evolve, in that order. For example `x1   16   %50   E5` means rate ×1, length 16, Chance 50%, Evolve 5%. A minimum three-pixel gap now separates adjacent values, including in the compact fallback. E2/E3 edit the first two values; K1+E2/E3 edit the last two. The active pair is brighter on the selected row. A tiny marker at the left edge indicates mute, pending reseed, or a Breathe rest. The final instruction line was removed to give the four rows more height.

The editing pages retain the tested integer-aligned 5 × 7 pixel lettering with anti-aliasing off; their `5` and `G` are deliberately distinct. The overview uses the narrower Particle font, also without anti-aliasing. If its four right-hand values do not fit at a particular setting, they switch together to exact 3 × 5 pixel numerals rather than overlapping. Long editing-page values may end with a dot when shortened to avoid overlapping their label; the complete value is still available in PARAMETERS > EDIT.

The screen has four pages:

| Page | Contents | E2 / E3 |
| --- | --- | --- |
| 1 Overview | Four complete patterns, live playheads, Rate, Length, Chance, Evolve | Rate / Length (hold K1 for Chance / Evolve) |
| 2 Track | Seed, Direction, Shift, Follow, Breathe, Gate, Tie, Mute | Select field / Change value |
| 3 Pitch | Note and Oct variation, Octave, Transpose, Min/Max note, Spread | Select field / Change value |
| 4 Global | Scale, Root, Weight, Freeze, selected track's Output and MIDI channel, MIDI port | Select field / Change value |

E1 selects the track on every page. K2 toggles Run and K3 arms a new seed on every page; hold K1 with K2/K3 to switch pages without triggering those actions. The overview follows the NT manual's full-pattern density and live-position approach, adapted to norns' 128 × 64 screen. Its refresh is limited to 20 frames/s: at extreme selectable rates such as ×32, intermediate positions can pass between frames even though all clocked events still play.

## Optional 16 × 8 Grid

Connect the Grid to Norns (port 1 by default). The script works without one and also detects a Grid plugged in after launch. The Grid **does not show or edit steps**: the full, asynchronous patterns and moving playheads stay on the Norns screen. Grid pages are independent of the Norns screen pages. On overview page 1/4, the header briefly displays the exact parameter/value touched on Grid before returning to track/position/seed information.

Each of the first seven Grid rows controls one parameter of the selected track:

| Row | Grid page 1, `SEQ` | Grid page 2, `NOTE` |
| --- | --- | --- |
| 1 | Rate | Note variation ± |
| 2 | Length | Octave variation ± |
| 3 | Chance | Octave offset |
| 4 | Evolve | Transpose (scale degrees) |
| 5 | Direction | Minimum MIDI note |
| 6 | Shift | Maximum MIDI note |
| 7 | Follow / Sample source | Spread |

Tap a key on a row to jump to its deliberately chosen value; the Grid does **not** divide each parameter's full range into sixteen arbitrary pieces. A dim-to-bright horizontal bar shows the current coarse choice. Direction uses columns 1–15, Follow 1–5 (`Off`, T1–T4), Octave 5–11 (−3…+3), and Transpose 1–15 (−7…+7). `NOTE` and `OCT` variation have a single zero at column 8; Spread 100% has a double centre at columns 8–9. Hold the Fine key and tap the left half of any parameter row to decrease one unit, or the right half to increase one unit; the Norns header shows the exact result. Values are changed through Norns parameters, so the Grid, encoders, parameter menu and saved presets share one state.

The key landmarks on Grid page 1 are Rate ×1 and Chance 50% on **column 8**, Rate ×1.5 on **column 11**, and Length **16 steps on column 9**. The explicit 16-key ladders are:

| Row | Columns 1 → 16 |
| --- | --- |
| Rate | /16 · /8 · /6 · /4 · /3 · /2 · /1.5 · ×1 · ×1.25 · ×1.3 · ×1.5 · ×2 · ×3 · ×4 · ×8 · ×16 |
| Length | 1 · 2 · 3 · 4 · 5 · 7 · 8 · 12 · **16** · 17 · 19 · 24 · 32 · 40 · 48 · 64 |
| Chance % | 0 · 5 · 10 · 15 · 20 · 25 · 35 · **50** · 60 · 65 · 70 · 75 · 80 · 90 · 95 · 100 |
| Evolve % | 0 · 1 · 2 · 3 · 4 · 5 · 7 · 10 · 15 · 20 · 25 · 35 · 50 · 65 · 80 · 100 |
| Shift (steps) | −12 · −8 · −6 · −4 · −3 · −2 · −1 · **0** · **0** · +1 · +2 · +3 · +4 · +6 · +8 · +12 |
| Note ± / Oct ± | −100 · −90 · −75 · −60 · −45 · −30 · −15 · **0** · +5 · +15 · +30 · +45 · +60 · +75 · +90 · +100 |
| Spread % | 0 · 10 · 25 · 40 · 55 · 70 · 85 · **100** · **100** · 115 · 130 · 145 · 160 · 175 · 190 · 200 |

Bottom row (row 8): columns **1–4** select a track; **6–7** select `SEQ` / `NOTE`; **9** is hold-for-Fine; **10** toggles Freeze; **12–15** mute/unmute tracks 1–4 directly; **16** randomizes the selected track. Columns 5, 8 and 11 are blank separators. The selected track, page and active switches are brighter; Random is a steady mid-brightness key. K2 on Norns still runs/stops playback, and K3 reseeds the selected track. Seed, Scale, Root, Weight, Breathe, Gate and Tie remain editable on Norns rather than taking Grid space. Output and n.b. voice shaping remain in PARAMETERS.

Random on Grid **8/16** works from either Grid page and changes all 14 parameters available across `SEQ` and `NOTE`, using only values reachable by Grid keys (duplicate centre values count once). It does not alter Seed, Mute, Freeze, transport or another track. Minimum and maximum MIDI note are sorted into a valid range; Follow avoids self-reference and cycles. On the Norns overview, the header briefly confirms `Tn RANDOMIZED`. A random Chance of 0% can make the track silent until Chance is raised again.

To set a specific Seed rather than a random new one, open page 2/4: Seed is its first field, editable with E3. As on the NT, the changed seed is armed and becomes active at the track's loop origin; `*` in the overview header shows that it is pending.

Shift is not a transient pitch change. It rotates which seeded pattern step is looked up on every clock event, including its note and rest state; the setting persists across loops. The same notes therefore return in a different order, which can make the effect feel momentary when listening for changes in pitch range. Use Transpose or Octave on page 3 for a lasting pitch shift.

Shift uses **steps**, not percent: the suggested −90…+90 numbers cannot be entered literally because Shoal's Shift range is −63…+63 steps. The Grid therefore offers musically useful offsets up to ±12; the Norns parameter menu and Grid Fine key retain access to every integer in the full range. With an exactly 16-step pattern, ±16 would reproduce the same order and is deliberately absent from the coarse Grid keys.

Direction `Tide` matches the disting NT original: Chance rests and Tie decisions remain attached to their rhythmic steps, while the pitch lookup moves forward by one step on each complete pass. The screen therefore keeps rests at the same positions while note-bar heights may change there; a pitch previously hidden behind a rest may become audible on another pass. With Evolve off and unchanged parameters, Tide is non-destructive: it realigns after `Length` passes, and Forwards reads the unrotated seed melody. Evolve and reseeding change the underlying material independently. `Shuffle` visits every step once per pass in a new seeded order. Entering Shuffle while running, changing Length during Shuffle, and returning to Shuffle after another direction all initialise its order safely.

Each track now has `Min note`, `Max note`, and `Spread %` in its group. Spread 100% preserves Shoal's note (subject to the chosen range), 0% contracts toward the global Root, and up to 200% expands away from it. The result is snapped to the chosen scale inside the hard range when possible. This is an optional, deterministic output transform; it does not change the Shoal core, seed, direction, or pattern evolution. Defaults 0–127 and 100% retain the previous output. If Min is raised above Max, Max follows it, and vice versa.

## What works now

- Eight-track reference core with the original defaults and seeds; a four-track Norns instrument and compact parameter groups.
- Exact 32-bit `hash3` implementation.
- All 13 original scales.
- All 15 current directions: Forwards, Reverse, Pendulum, Random, Drunk, Pong, Tide, Shuffle, Pools, Stride, Gravity, Converge, Diverge, Skitter, and Anchor.
- The original 29 exact rate definitions remain in the reference core for C++ equivalence tests. The playable Norns instrument exposes only /32 through ×32: /64 and ×64 are unavailable from its menu, encoders and Grid.
- Existing saved Norns presets from the 29-rate version store Rate by option number. Removing the two extreme options changes those numbers; after updating, check each track's Rate and save the preset again if necessary.
- Chance, Note and Oct variation, octave offset, scale-degree transpose, Weight, Shift, follow/source chains, Evolve, Breathe, Freeze, quantised per-track reseed, and reseed-all seed scattering.
- Backend-neutral step events with note, tie, rest/mute, source, pass, and EOS information.
- A playable Norns entry point, tempo-following master clock, phase-preserving scheduling for the 27 selectable rates, output routing, gate timing, note-offs, and cleanup on stop or route change; optional hot-pluggable 16 × 8 Grid parameter editor.
- Per-track pitch windows and a four-row, full-pattern screen with live playheads and three editable parameter pages, implemented outside the Shoal core.

## Fidelity boundary

The reference is Shoal v1.2.0 at commit `845b8d0bbbc6315ffa09fd3338137362695f0f1a` (2026-10-01). The port intentionally keeps C++ enum indices and 0-based internal step positions. Public track numbers and returned `event.step` are 1-based; `event.step0` exposes the exact C++ position.

The following are direct ports of the C++ logic:

- hash, scale tables, stable-degree selection, melody evaluation, Chance/Tie rolls;
- Note/Oct variation, Weight, transpose, octave folding, and bar height;
- all direction walks, including Tide's pitch-only rotation against fixed Chance/Tie steps, and their shared runtime RNG;
- linked follow, including source seed and source evolution epochs;
- Evolve, Breathe, Shift, Freeze, reseed-at-origin, and reseed-all scattering;
- rate tables and per-master-tick advance counts.

Not yet verified or intentionally deferred:

- PolyPerc and n.b. sound, MIDI events matching the UI, the revised overview, Grid control and pset save/recall have been reported working on a real norns; crow still needs a hardware check;
- Slop delays, Current CV interpolation, and sample-accurate gate/EOS pulse widths;
- precise NT-style Tie behavior across adjacent notes: the current output layer gives tied events a longer provisional gate, but a following event can still close that note;
- sustained PolyPerc notes during Freeze: PolyPerc is percussive, while MIDI, n.b., and crow notes are held until playback continues;
- tempo changes partway through a beat or gate use the beat length measured at scheduling time; the next master beat follows the new tempo;
- high rates, especially multiple tracks at ×32, need a performance check on hardware;
- long-session testing of Grid randomization, transport and preset behavior across different norns software versions;
- direct jumping from a track's n.b. selector into the selected voice's parameter group; the voice group is currently reached from top-level PARAMETERS > EDIT as in nbout;
- long-duration overflow parity beyond the explicit 8/16/32-bit wraps already mirrored;
- hardware comparison against a running disting NT instance.

Random, Drunk, Pools, and Skitter use Shoal's fixed global runtime RNG stream. They are repeatable from a freshly constructed core with the same RNG state, but—as in the C++ source—their result also depends on the interleaving order of tracks. A musical `reset()` does not rewind that RNG. Call `advance_all()` to preserve the upstream track order (1 through 8).

## Core example

```lua
local Shoal = require("lib/shoal_core")
local core = Shoal.new({ scale = "dorian", root = 48, weight = 20 })

core:set_track(1, "seed", 347, true) -- immediate only for setup/loading
core:set_track(1, "length", 12)
core:set_track(1, "direction", "tide")
core:set_track(1, "note", 35)

local event = core:advance(1)
if event.audible then
  print(event.note)
end

core:set_track(1, "seed", 500) -- normal edit: armed until loop origin
```

## Tests

With Lua 5.3 on the path:

```sh
./tests/run.sh
```

`tests/test_core.lua` checks golden hash/melody vectors, rate arithmetic, direction walks, follow, evolve, reseed, and freeze; it also verifies that Tide keeps rests/Tie fixed, rotates pitch, and returns to the initial alignment. `tests/test_grid.lua` checks the two 16 × 8 Grid pages, their exact key values, Random and the other permanent bottom-row actions. `tests/test_runtime.lua` checks scheduling, outputs, live Shuffle, entry-point startup and Grid interaction with a simulated Norns runtime. `tests/test_ui.lua` checks the 64-column display, moving cursor and Tide's changing pitch heights over fixed rests. `tests/test_nb_integration.lua` checks the nbout-compatible n.b. branch. `tests/upstream_reference.cpp` is an independent C++ oracle for the lowest-level golden values. The original source remains the reference except for the documented Norns adaptations.

## Layout

```text
lib/shoal_core.lua       pure deterministic/event core
lib/shoal_clock.lua      norns scheduling and fractional rates
lib/shoal_grid.lua       optional 16 x 8 performance controls
lib/shoal_outputs.lua    per-track output routing and note lifecycle
lib/shoal_pitch.lua      seed-neutral, scale-aware output pitch window
lib/shoal_ui.lua         four-row performance view
shoal-norns.lua          Norns params and lifecycle
```

## Upstream licence

Shoal is MIT-licensed, copyright 2026 Ormer Modular. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). The norns-specific adaptation has its own [MIT licence](../LICENSE). This port keeps the upstream commit explicit because the rate and direction tables evolved between releases.
