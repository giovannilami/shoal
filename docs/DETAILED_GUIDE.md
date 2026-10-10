# Shoal for norns — detailed guide and porting notes

An incremental, test-first port of [Ormer Modular Shoal](https://github.com/ormermodular/shoal) to norns.

This build is a playable norns community beta. `lib/shoal_core.lua` remains a pure Lua 5.3, eight-track reference port. The norns instrument runs four of those tracks. `lib/shoal_clock.lua` schedules them against the norns quarter-note clock; `lib/shoal_outputs.lua` routes events to PolyPerc, n.b., MIDI, or crow. `shoal-norns.lua` supplies parameters and a four-row performance screen; an optional 16 × 8 Grid provides a two-page live parameter editor without copying the sequencer. The overview uses norns Particle (face 68, size 8); `lib/shoal_font.lua` draws sharp pixel glyphs for the editing pages and an exact compact fallback for crowded overview values.

Unless noted, file paths and test commands below are relative to the repository root.

## Install and play on Norns

1. From this repository copy `shoal-norns.lua`, the complete `lib/` folder, `LICENSE` and `THIRD_PARTY_NOTICES.md` into `/home/we/dust/code/shoal-norns/` on norns using SFTP or the file share. Leave `docs/` and `test/` on your computer. Do not merge the new files with an older installation: move the old `shoal-norns` folder out of `dust/code` first. The main script must end up at `/home/we/dust/code/shoal-norns/shoal-norns.lua`. An old `tests/` (plural) folder can appear as extra scripts in SELECT. When the GitHub repository is public, its URL can be passed to Maiden's `;install` command instead; see [the publishing checklist](PUBLISHING.md).
2. Open Maiden at `norns.local`, then choose `SHOAL-NORNS` from the Norns SELECT menu. If the script is not listed yet, restart Norns or reload the script list.
3. Track 1 is routed to the built-in PolyPerc engine by default. Listen on Norns headphones or audio outputs. Tracks 2–4 start with output Off; all four advance their musical state.
4. On the overview, use E1 to select a track, E2 for its rate, E3 for its length, K1+E2 for Chance, and K1+E3 for Evolve. K2 runs/stops; K3 arms a new seed for the selected track. Hold K1 and press K3/K2 to move forward/backward through the four script pages. More settings are in PARAMETERS.
5. In PARAMETERS > EDIT, open one of the four `TRACK` groups to set its Output to MIDI, crow 1/2, crow 3/4, or n.b. as desired. For MIDI, set the global `MIDI port` (1–16) to the same virtual slot shown under `SYSTEM > DEVICES > MIDI` on your Norns; it defaults to 1. Set the track's `MIDI channel` to the channel expected by the receiver. You can also edit Output, MIDI port, and channel on the script's Global page. For crow, connect the first output of a pair to pitch and the second to a gate input. The pitch convention is 0 V = MIDI note 48 (C3), 1 V/octave.

n.b. support activates with either the copy bundled by `nbout` or a standalone library at `dust/code/nb`, plus a compatible voice. Select `Output = n.b.` and an `n.b. voice` in the track group. Then return to the top-level EDIT list and open that voice's group beneath `N.B. SOUND` to shape its sound. This is the same n.b. parameter mechanism used by nbout: a voice's sound parameters belong to the voice, so two tracks selecting the same voice share those settings. The script starts and plays PolyPerc without n.b. For MIDI or crow, attach the relevant device before selecting that output. Maiden's `matron` log is the place to inspect load or runtime errors.

The overview has one row per track. It draws the **whole pattern**, not an eight-step page: short patterns get wide cells, long patterns progressively narrower ones, up to 64 distinct columns. Bar height suggests pitch; a low tick is a rest. A bright outline/column marks the position most recently visited by that track's clock, even when the step is silent. A play triangle or stop square replaces RUN/STOP (two bars mean Freeze). The top line follows E1's selected track: `T1`, position/length such as `07/16`, `S:123` Seed (`*` means a reseed is armed), `F2` if following Track 2, and Direction. The colon prevents the Particle-font `S` from looking like an extra digit 5: `S:419` is seed 419, never 5,419. Its fields normally have two spaces between them; in a crowded header, Direction is abbreviated and spacing may shrink to one space rather than cutting a label mid-word. Holding K1 briefly replaces that text with the Chance/Evolve encoder hint. The selected row is brighter, while its `T` number appears in the header; omitting row numerals frees enough horizontal space to retain all 64 step columns and separate the four values clearly.

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

## Parameter reference: what each control changes

Shoal is not a conventional sequencer in which you enter every note. A **Seed** generates a repeatable set of pitches, rests and Tie decisions. On each clock event, **Direction** chooses a position, **Shift** offsets the position used for lookup, and the track's pitch settings shape the resulting note. **Chance** may turn that position into a rest; **Breathe** or **Mute** may silence it. Finally, the norns-only **Min note / Max note / Spread** stage adjusts the note sent to the selected **Output**. Changing a parameter does not rewrite the Seed. With Evolve at 0, returning to the same settings returns to the same generated material.

Parameters marked *global* affect all four tracks. The others belong to one track; choose it with E1, then use the indicated screen page or its `TRACK 1`–`TRACK 4` group under **PARAMETERS → EDIT**. The menu is the complete editor. Page 1 and Grid provide quicker access to selected values, not separate copies of the parameters. A norns pset saves these settings.

### Global controls

| Parameter | Where; range | What you will hear or see |
| --- | --- | --- |
| **Run** | K2; menu `Off / On` | Starts or stops all four playheads together. Stopping closes held MIDI, n.b. and crow notes; starting again resumes the musical state rather than choosing new seeds. It is transport, not a track mute. |
| **Freeze** | Page 4, Grid row 8 column 10, menu `Off / On` | Suspends advances on every track. Notes already held by MIDI, n.b. or crow are sustained until playback continues; it does not create notes when nothing is sounding. PolyPerc's own percussive decay cannot be held. A frozen symbol replaces Play/Stop in the overview. |
| **Scale** | Page 4 or menu; 13 choices | Chooses the pitch classes available to all tracks: Chromatic, Major, Natural minor, Harmonic minor, Dorian, Phrygian, Lydian, Mixolydian, Major/Minor pentatonic, Blues, Hirajoshi and In-sen. For instance, C Major uses C–D–E–F–G–A–B; changing to C Natural minor changes the pitches generated from the same seed. Scale does not change rate or rests. |
| **Root MIDI note** | Page 4 or menu; `0–127`, default `48` (C3) | Sets the tonal centre for the scale and for Spread. It does **not** force every note to equal the root. With default Min/Max and Spread, moving Root by 12 shifts the melody by an octave except where MIDI-range folding intervenes. |
| **Weight** | Page 4 or menu; `0–100`, default `0` | On approximately this percentage of *sounding* steps, pulls the chosen scale degree toward the root, third or fifth of the selected scale. At 0 there is no pull; at 100 every sounding step gets this treatment. It changes pitch, not the likelihood of a rest. Try 60 with a large Note variation to make a wandering melody gravitate toward more stable tones. |
| **MIDI port** | Page 4 or menu; `1–16`, default `1` | Selects the norns MIDI device slot shared by every track routed to MIDI. Match the slot in **SYSTEM → DEVICES → MIDI**; it is **not** the MIDI channel. Switching ports closes held notes and reconnects the output. |
| **Reset playheads** | Menu trigger | Puts the clock and playheads back at their starting positions for the next advance. It does not choose new seeds or clear accumulated Evolve changes. Useful when you want several tracks to restart together. |
| **Reseed all** | Menu trigger | Generates a Seed value for each of the four tracks. Each one is armed and takes effect at that track's next loop origin, which may occur at different times when rates or lengths differ. It does not mean “reset all playheads.” |

Norns' **CLOCK** menu controls the master tempo and external synchronization; this script does not add a separate BPM or MIDI-clock-source parameter. Rate ×1 means one step per quarter-note beat of that clock.

### Per-track rhythm, movement and generation

| Parameter | Where; range | What it changes in practice |
| --- | --- | --- |
| **Seed** | Page 2 or menu; `0–999` | A recipe number for repeatable musical material, **not** an amount of randomness. Entering another number or pressing K3 arms a new recipe; the `*` in the overview shows that it is pending. It becomes active at that track's loop origin, rather than interrupting the current phrase. The same seed and settings yield the same base material. If the track follows another, it uses the source's active seed; its own seed remains available when Follow is turned Off. |
| **Length** | E3 on page 1; menu/Grid; `1–64`, default `16` | Number of positions in this track's pattern. A 7-step track beside a 16-step track creates a polymetric cycle. Length does not automatically change when you stop, start or reseed. Changing it alters where the walk wraps and how Shift/Tide are interpreted. |
| **Rate** | E2 on page 1; menu/Grid; `/32` to `×32`, default `×1` | Speed relative to the norns beat. `×1` plays one position per quarter note; `×2` plays two; `×4` plays four (16th-note spacing in 4/4); `/2` advances once every two beats. Fractional choices such as `×1.5` produce three advances in two beats without rounding to a simpler rate. Rate changes timing, **not** Length or Seed. The menu has 27 choices; Grid offers a musical subset. |
| **Direction** | Page 2 or menu/Grid; 15 modes | Selects the order in which positions are visited. It does not directly transpose notes. See the complete mode table below; Tide is a special case because it rotates pitch against a fixed rhythmic position. |
| **Shift** | Page 2 or menu/Grid; `−63…+63` steps, default `0` | Offsets the seeded lookup relative to the visited position. On a 16-step track, `+1` makes position 1 read the material previously at position 2; `−1` reads position 16. It shifts notes **and** seeded rests/Tie decisions, but leaves the playhead's clock position alone. The change persists; set it back to 0 to recover the unshifted lookup. It is not a semitone transpose. |
| **Chance** | K1+E2 on page 1; menu/Grid; `0–100%`, default `100%` | Whether each visited position produces a note. At 100% every position passes; at 0% none do; at 50% roughly half are rests. This is seeded, so the rest pattern normally repeats rather than being newly tossed on every loop. The playhead still advances through rests. |
| **Evolve** | K1+E3 on page 1; menu/Grid; `0–100%`, default `0%` | At a phrase boundary, approximately this share of positions receives a new generation “epoch,” changing its pitch and potentially its Chance/Tie result without changing the Seed number. At 0 the material stays fixed; try 5% for slow movement. These changes accumulate. Reseeding starts a fresh lineage. A follower hears the source's evolving material; its own Evolve setting does not independently re-roll the source material. |
| **Breathe** | Page 2 or menu; `0–100%`, default `0%` | Probability that the track sits out a phrase while the playhead continues. At 0 there is no phrase-level silence; 100 can keep it silent. Unlike Chance, it silences a whole stretch rather than selecting individual rests. It is most straightforward with an ordered Direction such as Forwards. In Random, Drunk, Pools and Skitter, the current core treats each advance as a boundary, so Breathe (and Evolve) can update more often than once per Length steps. |
| **Gate length** | Page 2 or menu; `5–95%`, default `50%` | Duration requested for a note as a percentage of the interval to the next step. With Rate ×1, a 50% gate asks for half a beat. It matters most on sustained MIDI, n.b. or crow voices; a percussive PolyPerc hit has its own envelope. A rest, mute, stop or new event can close a note sooner. |
| **Tie** | Page 2 or menu; `0–100%`, default `0%` | Seeded probability of marking a sounding position as tied. In this norns output layer a tied event requests a provisional 1.5-step gate, but the next event still closes and retriggers it. Do **not** expect guaranteed NT-style legato or slides yet. Chance=0 still makes a rest; Tie is not a substitute for a sounding step. |
| **Sample source / Follow** | Page 2 or menu/Grid; `Off`, Track 1–4 | Borrows another track's **active seed and evolution**, so melodies can be related while each track retains its own Rate, Length, Direction, Chance, Shift, pitch offsets, Breathe, Gate, Mute and output. Example: set Track 2 to follow Track 1, Octave `−1` and Rate `/2` for a slower bass relative. The source's reseed reaches the follower when it becomes active. `Off` returns to Track 2's own seed; avoid self-follow or circular source chains in the menu. |
| **Mute** | Page 2, menu, Grid bottom row columns 12–15 | Silences this track's output immediately and closes any held note, but its playhead and generation continue. Unmuting rejoins the current position, not the beginning. The Grid has a separate mute key for each track. `Output = Off` also makes a track silent, but changes the routing rather than its mute state. |

### Per-track pitch and output

Shoal first calculates a scale-constrained MIDI note. The following pitch controls shape that calculation; the final Min/Max/Spread controls then map the note for output. These are different from Rate, Length, Chance and Gate: they affect **which pitch** is sent, not **when** a step occurs.

| Parameter | Where; range | What it changes in practice |
| --- | --- | --- |
| **Note variation** (`NOTE +/−`) | Page 3 or menu/Grid; `−100…+100`, default `0` | The absolute amount controls both how often and how far a note deviates from its seeded base pitch, up to 12 **scale degrees** at full amount. The sign chooses direction: positive only reaches upward, negative downward. `0` removes this added variation and reveals the base melody; it does not silence the track. This is seeded, so a given step's deviation repeats until its material evolves or is reseeded. |
| **Oct variation** (`OCT +/−`) | Page 3 or menu/Grid; `−100…+100`, default `0` | Similar to Note variation, but makes occasional whole-octave jumps in the signed direction, up to five octaves at full amount. `+30` means occasional upward leaps, **not** “transpose everything by 30%.” Set to 0 to remove the extra jumps. |
| **Octave** | Page 3 or menu/Grid; `−3…+3`, default `0` | Fixed octave offset for **every** sounding note on this track: `−1` lowers it by one octave, `+1` raises it by one. This is the simple way to put a follower into bass or high-register territory. Extreme results are folded back into MIDI range 0–127. |
| **Transpose** | Page 3 or menu/Grid; `−7…+7`, default `0` | Fixed shift in **scale degrees**, not semitones. In C Major, `+2` shifts C to E; in a different scale the semitone distance may differ. This keeps the track inside the selected global scale. For a fixed chromatic semitone shift, change Root instead—but Root affects all tracks. |
| **Min note** | Page 3 or menu/Grid; MIDI `0–127`, default `0` | Lowest MIDI pitch the norns output transform may send for this track. Set it, for example, to 48 to keep a bass voice at C3 or above. If raised past Max note, Max is raised to match. It does not change the Seed or the track's timing. |
| **Max note** | Page 3 or menu/Grid; MIDI `0–127`, default `127` | Highest MIDI pitch the output transform may send. Set it to 72 to keep a voice at C5 or below. If lowered beneath Min note, Min follows. Together Min and Max make a hard pitch window; when it contains scale notes, the output snaps to the nearest one. |
| **Spread %** | Page 3 or menu/Grid; `0–200%`, default `100%` | Contracts or expands each note's distance from the global Root **before** applying Min/Max and scale snapping. `100%` preserves the core pitch, `0%` draws it to the nearest allowed note around Root, and `150%` pushes it farther away. For example, with Root C3 (48), a raw note C4 (60) targets 54 at 50% or 66 at 150%, before scale/range snapping. It does not alter the seeded pattern. The overview's bars show the mapped notes, normalized within each track; they are not a numeric MIDI-note display. |
| **Output** | Page 4 or menu per track; `Off`, PolyPerc, n.b. (if installed), MIDI, crow 1/2 or crow 3/4 | Chooses **where** this track's notes go. Track 1 defaults to PolyPerc; Tracks 2–4 default to Off but still run internally. A routing change closes a held note. PolyPerc plays through norns audio; MIDI goes to the chosen port/channel; n.b. uses a selected note player; crow uses output 1/3 for pitch and 2/4 for a 5 V gate. One crow pair is monophonic, so sharing a pair between tracks can cut off the other track's note. |
| **MIDI channel** | Page 4 or menu per track; `1–16`, default = track number | Channel sent by this track **when Output is MIDI**. It does not pick the physical device—that is the global MIDI port. The current script sends a fixed velocity of 100; there is no per-track velocity parameter. |
| **n.b. voice** | Menu per track, only when n.b. is installed | Chooses which installed note player receives the track when `Output = n.b.`. The selected voice's own synthesis/sample controls appear under **N.B. SOUND** in the top-level EDIT menu, not in Shoal's Track/Pitch pages. Their names and meanings depend on that voice. Two tracks assigned the same voice share its sound settings. |

The 13 scales are shared by all tracks, while Min/Max/Spread and the other track pitch settings are independent. For a safe first pitch experiment, leave Min/Max at `0–127` and Spread at `100%`, set a scale and Root, then try Note variation `+30` on one track. Only after you like the melody, narrow that track's Min/Max or change its Spread. This makes it easier to hear which layer is responsible for the change.

### All 15 Direction modes

Direction changes the **walk through positions**, not the Seed. A numbered example below assumes a pattern of at least four positions. Random-like modes can revisit or skip positions; the ordered modes have recognizable cycles. Changing back to Forwards with Evolve at 0 lets you hear the seed's ordinary order again.

| Mode | Movement and practical use |
| --- | --- |
| **Forwards** | `1, 2, 3, 4…` then wraps. The clearest starting point for hearing what a Seed contains. |
| **Reverse** | Visits the last position, then moves backward to 1. Same material in reverse order. |
| **Pendulum** | Moves forward and back, repeating each end before changing direction: `1, 2, 3, 4, 4, 3, 2, 1, 1…`. Can give the ends extra emphasis. |
| **Random** | Chooses a position on every advance. It may repeat one immediately or miss others for a while; the walk uses a shared runtime random stream, so interleaving with other tracks matters. |
| **Drunk** | From the current position, roughly 50% chance forward, 25% stay, 25% back, wrapping at the edges. Good for a wandering but locally connected melody. |
| **Pong** | Bounces between ends like Pendulum, but plays each end only once: `1, 2, 3, 4, 3, 2, 1…`. |
| **Tide** | Visits the rhythmic positions in order. After each complete pass, the **pitch lookup** rotates one position while Chance rests and Tie decisions stay at their rhythmic positions. A pitch that sat behind a rest can become audible at another position. It realigns after `Length` passes; this rotation does not rewrite the Seed. |
| **Shuffle** | Visits every position exactly once per pass in a reshuffled order. Unlike Random, there are no omitted or repeated positions within one pass. Useful for rearranging a motif while retaining its ingredients. |
| **Pools** | Circles a small pocket of three or four nearby positions for a while, then jumps to another pocket. Makes short motifs that linger and move on. |
| **Stride** | Overlapping two-ahead/one-back walk such as `1, 3, 2, 4, 3, 5…`. A cycle takes twice Length advances; produces a loping feel. |
| **Gravity** | Mostly moves forward, but sometimes snaps back to position 1 at a seed-derived rate. This is movement gravity, separate from pitch **Weight**. |
| **Converge** | Alternates inward from both ends: `1, last, 2, second-last…`. A motif folds toward its centre. |
| **Diverge** | Starts near the centre and alternates outward toward the ends—the counterpart of Converge. |
| **Skitter** | Random positions, but never the same one twice in a row (unless Length is 1). Useful when Random's immediate repetitions are too static. |
| **Anchor** | Alternates position 1 with positions 2, 3, 4…: `1, 2, 1, 3, 1, 4…`. Makes a recurring anchor note between excursions. |

For an immediate comparison, set one track to Length 4, Chance 100%, Evolve 0% and Rate ×1. Listen in Forwards, then Pendulum, Pong, Shuffle and Tide without changing Seed. In Tide, watch the **rest positions** if you lower Chance: they stay in place while sounding pitches move from pass to pass. In Shuffle, the visited position itself jumps. If you want a completely fresh melody instead, change Seed or press K3.

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

Tap a key on a row to jump to its deliberately chosen value; the Grid does **not** divide each parameter's full range into sixteen arbitrary pieces. A dim-to-bright horizontal bar shows the current coarse choice. Direction uses columns 1–15, Follow 1–5 (`Off`, T1–T4), Octave 5–11 (−3…+3), and Transpose 1–15 (−7…+7). `NOTE` and `OCT` variation have a single zero at column 8; Spread 100% has a double centre at columns 8–9. The former Grid Fine key now controls the LFO; use the Norns encoders or parameter menu for exact values between Grid choices. Values are changed through Norns parameters, so the Grid, encoders, parameter menu and saved presets share one state.

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

Bottom row (row 8): columns **1–4** select a track; **6–7** select `SEQ` / `NOTE`; **9** controls the selected track's LFO; **10** toggles Freeze; **12–15** mute/unmute tracks 1–4 directly; **16** randomizes the selected track. Columns 5, 8 and 11 are blank separators. The selected track, page and active switches are brighter; Random is a steady mid-brightness key. K2 on Norns still runs/stops playback, and K3 reseeds the selected track. Seed, Scale, Root, Weight, Breathe, Gate and Tie remain editable on Norns rather than taking Grid space. Output and n.b. voice shaping remain in PARAMETERS.

Random on Grid **8/16** works from either Grid page and changes all 14 parameters available across `SEQ` and `NOTE`, using only values reachable by Grid keys (duplicate centre values count once). For more immediately usable results, it restricts Rate to `/4` through `×4` and Chance to `5–100%`; direct Grid editing and the Norns menu still allow their full ranges, including Chance 0%. It does not alter Seed, Mute, Freeze, transport or another track. Minimum and maximum MIDI note are sorted into a valid range; Follow avoids self-reference and cycles. On the Norns overview, the header briefly confirms `Tn RANDOMIZED`.

To set a specific Seed rather than a random new one, open page 2/4: Seed is its first field, editable with E3. As on the NT, the changed seed is armed and becomes active at the track's loop origin; `*` in the overview header shows that it is pending.

Shift is not a transient pitch change. It rotates which seeded pattern step is looked up on every clock event, including its note and rest state; the setting persists across loops. The same notes therefore return in a different order, which can make the effect feel momentary when listening for changes in pitch range. Use Transpose or Octave on page 3 for a lasting pitch shift.

Shift uses **steps**, not percent: the suggested −90…+90 numbers cannot be entered literally because Shoal's Shift range is −63…+63 steps. The Grid therefore offers musically useful offsets up to ±12; the Norns parameter menu retains access to every integer in the full range. With an exactly 16-step pattern, ±16 would reproduce the same order and is deliberately absent from the coarse Grid keys.

Direction `Tide` matches the disting NT original: Chance rests and Tie decisions remain attached to their rhythmic steps, while the pitch lookup moves forward by one step on each complete pass. The screen therefore keeps rests at the same positions while note-bar heights may change there; a pitch previously hidden behind a rest may become audible on another pass. With Evolve off and unchanged parameters, Tide is non-destructive: it realigns after `Length` passes, and Forwards reads the unrotated seed melody. Evolve and reseeding change the underlying material independently. `Shuffle` visits every step once per pass in a new seeded order. Entering Shuffle while running, changing Length during Shuffle, and returning to Shuffle after another direction all initialise its order safely.

Each track now has `Min note`, `Max note`, and `Spread %` in its group. Spread 100% preserves Shoal's note (subject to the chosen range), 0% contracts toward the global Root, and up to 200% expands away from it. The result is snapped to the chosen scale inside the hard range when possible. This is an optional, deterministic output transform; it does not change the Shoal core, seed, direction, or pattern evolution. Defaults 0–127 and 100% retain the previous output. If Min is raised above Max, Max follows it, and vice versa.

## Clock-synced LFO

Each track has **one independent LFO phase**. Its Shape and Period are shared by every target enabled on that track, but each target has a separate pair of endpoints. The feature is norns-only; the original Shoal NT does not use it. It does not change Seed, the stored manual settings, or the parameter values saved in a pset. Grid and the overview show the effective moving values when the LFO is on; PARAMETERS → EDIT shows the saved manual/base values.

In **PARAMETERS → EDIT → LFO T1** (or T2–T4), set `Enabled` to On, choose a `Shape` and `Period`, and turn on one or more target names. Shapes are **Triangle** (low to high to low), **Random steps** (one deterministic choice per cycle), and **Sine** (a smoother curve, quantized to the Grid ladder). Period is a full cycle of **1, 2, 4 or 8 four-beat bars**; the initial choice is two bars. All targets begin with a usable range, but you can replace each range from the Grid. If no targets are On, enabling the LFO has no audible effect. Turning a target or the whole LFO Off immediately restores its manual value.

For live range editing, select the track with Grid row 8 columns 1–4. **Tap 8/9** to toggle its LFO. **Hold 8/9**, press two keys on the same eligible parameter row, then release 8/9. The two keys become lower and upper endpoints, whichever order you press them; this gesture also switches that target On in the LFO menu. **Repeat on as many target rows as you want:** a completed pair does not replace earlier assignments. You may keep holding 8/9 and press **8/6** or **8/7** to switch Grid page, then choose another pair there. You may also release and hold 8/9 again for the next pair; touching any row prevents that hold from toggling the LFO on release. The Grid briefly reports the exact chosen values on the norns screen. With the LFO running, each assigned row's endpoints remain lit and its bright cursor follows its effective value. A press on another row before finishing a pair starts a new pair rather than combining two different parameters. To remove one target without stopping the others, repeat its **same pair of endpoint columns** while holding 8/9; either order works. Its manual value returns immediately. You can also switch that target Off in `LFO Tn`.

| Grid page/row | LFO target | Initial range when enabled from the menu |
| --- | --- | --- |
| `SEQ` 1 | Rate | ×1 to ×1.5 |
| `SEQ` 2 | Length | 12 to 16 steps |
| `SEQ` 3 | Chance | 50–100% |
| `SEQ` 6 | Shift | −1 to +1 step |
| `NOTE` 1 | Note variation | −15 to +15 |
| `NOTE` 2 | Oct variation | −15 to +15 |
| `NOTE` 7 | Spread | 85–130% |

For example, to make Track 1's Chance drift between 50% and 100%, go to `SEQ`, hold **8/9**, press **8/3** then **16/3**, release **8/9**, and tap **8/9** if the LFO was not already On. To give the same track a moving Spread, go to `NOTE` and repeat the two-endpoint gesture on row 7. Both parameters then follow the same phase, through different value ladders. To remove Chance alone, hold **8/9** again and press **8/3** and **16/3** in either order. Grid's ordinary taps still edit the saved base value; holding the LFO key edits the modulation range instead. Precise manual values remain available from Norns.

**Rate** is sampled on each master beat before that beat's notes are scheduled. Changing it preserves the fraction of the interval remaining until the next note; it does not reset the playhead or force a simultaneous retrigger. Very fast rates can still put multiple notes inside one beat, beyond the norns screen's 20 fps display. **Length** is sampled after a completed phrase and applied immediately before the next step, so the current phrase is not cut short and the UI does not temporarily show a position larger than its length. These rules are deliberately more conservative than direct manual edits. For Random/Shuffle/Tide and other non-linear Directions, a changing Length will naturally change the position walk or pitch rotation; test the musical result, especially when changing from a long to a very short pattern.

Random steps uses a private deterministic hash of track number and cycle count; it does not consume Shoal's seed or shared direction RNG. It chooses among the discrete values between the two Grid endpoints, not arbitrary numbers between them. On Stop, the script's LFO phase waits with the sequencer; on Freeze, sounding values hold but the master beat count continues, so unfreezing may resume at a later LFO phase. Basic LFO operation has now been tried on a real norns. Dynamic Rate/Length at extreme settings, long sessions and pset recall of LFO ranges still need hardware verification.

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
./test/run.sh
```

`test/test_core.lua` checks golden hash/melody vectors, rate arithmetic, direction walks, follow, evolve, reseed, and freeze; it also verifies that Tide keeps rests/Tie fixed, rotates pitch, and returns to the initial alignment. `test/test_grid.lua` checks the two 16 × 8 Grid pages, their exact key values, Random and the other permanent bottom-row actions. `test/test_mod.lua` checks multi-target LFO assignments, discrete ranges and restoring manual values. `test/test_runtime.lua` checks scheduling, outputs, live Shuffle, entry-point startup and Grid interaction with a simulated Norns runtime. `test/test_stress.lua` exercises all 15 Directions with changing parameters and then four tracks at ×32. `test/test_ui.lua` checks the 64-column display, moving cursor and Tide's changing pitch heights over fixed rests. `test/test_nb_integration.lua` checks the nbout-compatible n.b. branch. `test/upstream_reference.cpp` is an independent C++ oracle for the lowest-level golden values. The original source remains the reference except for the documented Norns adaptations. Offline tests cannot measure SuperCollider CPU usage or the microSD's health.

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
