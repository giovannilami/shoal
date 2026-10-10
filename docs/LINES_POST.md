# Draft for a lines norns Library topic

Review the wording and add your preferred public name or lines handle before posting. This file is a draft, not a published topic.

## Topic title

shoal-norns — Shoal's generative melodies, adapted for norns

## Topic body

Shoal was created by **Ormer Modular** for the Expert Sleepers disting NT. I love the way a small seed grows into a repeatable melody, so I adapted that musical idea and part of the open-source Shoal algorithm into a four-track norns script. This is an unofficial port, not an Ormer Modular release. The original project and manual are here: https://github.com/ormermodular/shoal

The norns screen keeps all four complete patterns and their live positions in view. E1 selects a track; E2/E3 change Rate/Length; K1+E2/E3 change Chance/Evolve; K2 plays or stops; K3 arms a new seed. Further track, pitch and global settings have their own screen pages. A 16 × 8 Grid is optional: two pages give direct access to 14 parameters, while the last key randomizes those parameters for the selected track. Grid does not duplicate the sequencer display.

Each track can route to built-in PolyPerc, MIDI, crow or an n.b. note player. PolyPerc, MIDI, n.b., Grid controls and pset save/recall have been tried on hardware. Crow and some high-rate/timing edge cases still need testing, so I am calling this a community beta.

Source, illustrated guide and known differences: https://github.com/giovannilami/shoal-norns

Install from Maiden after the repository is public:

```text
;install https://github.com/giovannilami/shoal-norns
```

The original Shoal concept and musical algorithm are Ormer Modular's; their MIT notice is included in the repository. Tide follows the NT pitch-over-fixed-rhythm behavior; some output details still differ, and the README explains these boundaries. Feedback and test reports—especially for crow and different n.b. voices—are very welcome.

<!-- Optional before posting: add your public author/lines handle and a real photo or video. -->
