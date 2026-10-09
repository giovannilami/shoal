# shoal-norns

![Illustrated overview of four independent Shoal tracks on the norns screen](docs/overview.svg)

Four generative melodies for **norns**, with an optional **16 × 8 Grid** performance editor. Each track grows a repeatable pattern from a seed, then lets you reshape how it moves, changes and sounds. The norns screen shows all four complete patterns and their moving playheads; Grid is for hands-on parameter changes, not a second step sequencer.

> **Credit first:** [Shoal for the disting NT](https://github.com/ormermodular/shoal)—the original idea, musical algorithm, name and design—is by **Ormer Modular**. This is an **unofficial norns adaptation**, not an Ormer Modular release. The Lua musical core ports parts of their MIT-licensed C++ source; their copyright and licence are retained in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The norns adaptation, interface and routing are maintained by [@giovannilami](https://github.com/giovannilami).

This is a **community beta**. PolyPerc, MIDI, n.b., Grid interaction and pset save/recall have been exercised on a real norns. Some NT features and output edge cases remain unfinished; see [Known differences](#known-differences-and-limits).

## Start playing

1. Put the entire `shoal-norns` folder in `/home/we/dust/code/` on norns, or—once this repository is public—install it in Maiden with `;install https://github.com/giovannilami/shoal-norns`.
2. Select **SHOAL-NORNS** on norns. Track 1 plays the built-in PolyPerc engine immediately; Tracks 2–4 start with Output **Off** until you assign them.
3. Turn **E1** to select a track. Turn **E2** for Rate and **E3** for Length. Press **K3** to arm a new seed; it lands at the next loop start. **K2** stops or starts playback.
4. In **PARAMETERS → EDIT → TRACK 1–4**, choose an Output: PolyPerc, n.b., MIDI or crow. The Grid is optional.

If the script does not appear in SELECT after copying it, restart norns. Do not upload a `.tar.gz` file *inside* the repository and expect Maiden to unpack it: the repository itself must contain `shoal-norns.lua`, `lib/` and `docs/` at its root. See the [publishing checklist](docs/PUBLISHING.md) for the remaining release steps.

## The norns screen

The overview is deliberately a *whole-pattern* view: each row shows every step of that track, whether its Length is 4, 16 or 64. A brighter outline follows the last visited step; short bars represent rests and taller bars suggest note height. The selected track is brighter.

The top line reports the selected track, its current position/length, seed, Follow source when present and Direction. The four values to the right of each pattern are always **Rate · Length · Chance · Evolve**. The picture above is an explanatory drawing, not a screenshot of a running seed.

| On norns | Action |
| --- | --- |
| E1 | Select track 1–4 on any page |
| E2 / E3 on page 1 | Rate / Length of selected track |
| Hold K1 + E2 / E3 on page 1 | Chance / Evolve |
| K2 / K3 | Play–stop / reseed selected track |
| Hold K1 + K3 / K2 | Next / previous screen page |
| E2 / E3 on pages 2–4 | Choose field / edit value |

Page **1/4** is the performance overview. Page **2/4** edits Seed, Direction, Shift, Follow, Breathe, Gate, Tie and Mute. Page **3/4** edits Note/Oct variation, Octave, Transpose, Min/Max note and Spread. Page **4/4** contains Scale, Root, Weight, Freeze and output settings. The full parameter menu remains available under **PARAMETERS → EDIT**; n.b. voice-specific sound controls live there too.

## Optional 16 × 8 Grid

![Diagram of the sixteen-column, eight-row Grid controls](docs/grid-map.svg)

The Grid has two pages, **SEQ** and **NOTE**, independent of the four norns screen pages. Rows 1–7 set one parameter each. The last row always selects tracks and pages or performs an immediate action.

| Row | SEQ | NOTE |
| --- | --- | --- |
| 1 | Rate | Note variation |
| 2 | Length | Octave variation |
| 3 | Chance | Octave offset |
| 4 | Evolve | Transpose |
| 5 | Direction | Minimum MIDI note |
| 6 | Shift | Maximum MIDI note |
| 7 | Follow | Spread |
| 8 | T1–T4 · SEQ/NOTE · Fine · Freeze · Mutes · Random | Same actions |

Tap a row to choose one of its discrete values. Important landmarks: **Rate ×1 and Chance 50% share column 8; Rate ×1.5 is column 11; Length 16 is column 9.** Hold **row 8, column 9** (Fine) and press left/right on a parameter row for ±1 instead. **Row 8, column 16** randomizes *all 14 Grid-editable parameters* of the selected track, across both Grid pages, from the values those rows can select. It does not alter Seed, Mute, Freeze or playback. K2 on norns remains Play/Stop. Random Chance can be 0%, so a silent result is possible.

The Grid intentionally does not duplicate the asynchronous sequencer display. For exact value ladders and the meaning of each control, see the [detailed guide](docs/DETAILED_GUIDE.md).

## Sound and connections

| Output | What you need |
| --- | --- |
| PolyPerc | Built in; Track 1's default. A simple percussive sound for first launch. |
| MIDI | Set the global MIDI port to the virtual device slot in **SYSTEM → DEVICES → MIDI**, then set each track's MIDI channel. |
| crow | Use outputs 1/2 or 3/4 as pitch/gate pairs; 0 V is MIDI note 48 (C3), 1 V/octave. |
| n.b. | An installed n.b.-compatible player (via `nbout` or standalone `nb`). Assign a different voice per track if you like; edit the selected voice's sound under **N.B. SOUND** in PARAMETERS → EDIT. |

Each track routes independently. Shoal itself needs no custom SuperCollider engine; an n.b. voice may use its own sound engine. PolyPerc is available as the built-in first-play sound. MIDI and n.b. were tested by the port's user; crow remains a route to verify on hardware.

## Saving and recalling

Use norns' usual **PARAMETERS → PSET** menu. Psets save the script parameters, including seeds, routing and Grid-edited values. Saving and recalling a pset has been tested on hardware. Psets from an earlier development build with all 29 NT Rate options should have their Rate values checked: this norns build exposes `/32` through `×32`, not `/64` or `×64`, so old option numbers can refer to a neighbouring rate.

## Known differences and limits

- The reference core preserves Shoal's eight-track, 29-rate tables for source comparison. The playable norns instrument uses **four tracks** and **27 selectable rates** (`/32` to `×32`).
- **Tide** intentionally rotates the *whole phrase*—notes, rests and ties—one step per pass. On the NT original it rotates pitch against fixed rhythm. This adaptation follows hardware feedback from this norns port.
- **Shift** is an offset in *steps*, not a pitch transpose. The Grid offers selected values up to ±12; the norns parameter menu offers the full ±63. Use Transpose or Octave for pitch changes.
- **Min/Max note and Spread** are norns-only output-pitch controls. They do not change the seed or the reference musical core.
- NT-specific Current CV, Slop timing and exact gate/EOS pulse behavior are not implemented here. Tie handling, very high rates and crow timing need more hardware testing. PolyPerc is percussive, so Freeze cannot sustain it like a held MIDI or n.b. note.
- This is a port and adaptation, **not** a byte-for-byte reproduction of every NT output or interface feature.

See [detailed behavior, fidelity notes and test instructions](docs/DETAILED_GUIDE.md) before reporting an equivalence issue.

## Credits and licence

**Original Shoal:** [Ormer Modular](https://github.com/ormermodular/shoal), for the Expert Sleepers disting NT. Their original [manual](https://github.com/ormermodular/shoal/blob/main/docs/MANUAL.md) is the primary reference. **norns adaptation:** [@giovannilami](https://github.com/giovannilami), with its own interface and output routing. The original author deserves the primary credit for the musical concept and algorithm.

The norns-specific code is offered under the [MIT licence](LICENSE); the original Ormer Modular MIT notice is reproduced in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Contributions and bug reports are welcome once the public repository and lines thread exist. This project is not affiliated with or endorsed by Ormer Modular, Expert Sleepers or monome.
