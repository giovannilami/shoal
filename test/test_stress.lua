-- Deterministic offline load test of the complete musical/event path. This
-- does not replace a real norns/SD-card test, but catches Lua failures under
-- simultaneous LFOs, changing lengths, every Direction and fast output.
local root = arg[0]:match("^(.*)/test/test_stress%.lua$") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local Core = require("shoal_core")
local Clock = require("shoal_clock")
local GridUI = require("shoal_grid")
local Mod = require("shoal_mod")
local Pitch = require("shoal_pitch")
local Outputs = require("shoal_outputs")
include = function(path)
  return dofile(root .. "/" .. path:match("(lib/.+)$") .. ".lua")
end
local UI = include("shoal-norns/lib/shoal_ui")

local core, values, windows = Core.new(), {}, {}
for track = 1, 4 do
  local prefix = string.format("shoal_lfo_t%d_", track)
  windows[track] = { low = 24, high = 96, spread = 100 }
  values[prefix .. "on"] = 2
  values[prefix .. "shape"] = track % 3 + 1
  values[prefix .. "period"] = track
  for _, target in ipairs(Mod.TARGETS) do
    values[prefix .. target.id] = target.id == "rate" and 1 or 2
    values[prefix .. target.id .. "_range"] =
      Mod.range_pack(target.first, target.last)
    values[string.format("shoal_t%d_%s", track, target.id)] =
      target.id == "spread" and 100 or core.tracks[track][target.id]
  end
  core:set_track(track, "rate", ({ 27, 26, 20, 13 })[track])
end
local params = {
  get = function(_, name) return values[name] end,
  set = function(_, name, value) values[name] = value end,
}
local mod = Mod.new(core, params, windows, GridUI, 4)
local run_id, on_count, off_count, poly_count, nb_count = 0, 0, 0, 0, 0
local runtime = {
  run = function() run_id = run_id + 1; return run_id end,
  cancel = function() end,
  sync = function() end,
  sleep = function() end,
  get_beat_sec = function() return 0.5 end,
}
local midi_device = {
  note_on = function() on_count = on_count + 1 end,
  note_off = function() off_count = off_count + 1 end,
}
local nb_player = {
  note_on = function() nb_count = nb_count + 1 end,
  note_off = function() end,
}
local outputs = Outputs.new({
  engine = { hz = function() poly_count = poly_count + 1 end },
  midi = { connect = function() return midi_device end },
  crow = { output = { {}, {}, {}, {} } },
  clock = runtime,
  nb_player = function() return nb_player end,
}, 4)
outputs:set_midi_port(1)
outputs:set_route(2, "midi", 2)
outputs:set_route(3, "crow12", 3)
outputs:set_route(4, "nb", 4)

local event_count = 0
local sequencer = Clock.new(core, function(event, step_beats)
  local window = windows[event.track]
  local routed = Pitch.event(event, core.root, window.low, window.high,
    window.spread, core.scale_pcs)
  assert(routed.note >= 0 and routed.note <= 127)
  assert(step_beats > 0)
  outputs:step(routed, step_beats, core.tracks[event.track].gate, 100)
  event_count = event_count + 1
end, runtime, 4, {
  before_tick = function(beat) mod:before_tick(beat) end,
  before_step = function(track, beat) mod:before_step(track, beat) end,
  after_step = function(track, event, beat) mod:after_step(track, event, beat) end,
})

local screen = {
  clear = function() end, level = function() end, aa = function() end,
  font_face = function() end, font_size = function() end,
  move = function() end, text = function() end, text_right = function() end,
  text_extents = function(value) return #value * 4 end,
  fill = function() end, stroke = function() end, update = function() end,
  rect = function(x, y, width, height)
    assert(x >= 0 and y >= 0 and width > 0 and height > 0)
    assert(x + width <= 128 and y + height <= 64)
  end,
}

for beat = 0, 299 do
  if beat % 13 == 0 then
    for track = 1, 4 do
      core:set_track(track, "direction", (beat // 13 + track - 1) % 15)
    end
  end
  if beat % 29 == 0 then
    for track = 1, 4 do
      core:set_track(track, "length", 1 + (beat + track * 11) % 64)
    end
  end
  if beat % 31 == 0 then
    local track = beat % 4 + 1
    local target = Mod.TARGETS[(beat // 31) % #Mod.TARGETS + 1].id
    params:set(string.format("shoal_lfo_t%d_%s", track, target), 2)
  end
  if beat % 79 == 0 and beat > 0 then
    outputs:panic()
    sequencer:reset()
    mod:reset()
  end
  local planned = sequencer:plan_tick()
  assert(#planned <= 128, "at most four tracks at x32 in one beat")
  for _, item in ipairs(planned) do
    assert(item.offset >= 0 and item.offset < 1)
    sequencer:fire(item)
  end
  if beat % 6 == 0 then
    UI.draw(screen, core, true, beat % 4 + 1, 4, windows, { page = 1 })
  end
end
outputs:panic()
assert(event_count > 4000,
  string.format("stress run exercised high event density: %d events", event_count))
assert(poly_count > 0 and on_count > 0 and off_count > 0 and nb_count > 0)
local varied_events = event_count

-- Exercise the actual upper bound exposed by the script: four tracks at x32.
-- This verifies scheduling and routing, not SuperCollider's hardware load.
for track = 1, 4 do
  params:set(string.format("shoal_lfo_t%d_on", track), 1)
  mod:config_changed(track)
  core:set_track(track, "rate", 27)
  core:set_track(track, "direction", 0)
  core:set_track(track, "length", 16)
  core:set_track(track, "chance", 100)
  core:set_track(track, "breathe", 0)
  core:set_track(track, "source", 0)
  core:set_track(track, "mute", false)
end
sequencer:reset()
local maximum_events = 0
for _ = 1, 64 do
  local planned = sequencer:plan_tick()
  assert(#planned == 128, "four x32 tracks make 128 steps per beat")
  for _, item in ipairs(planned) do
    sequencer:fire(item)
    maximum_events = maximum_events + 1
  end
end
outputs:panic()
assert(maximum_events == 8192)
print(string.format("ok - stress: %d varied + %d maximum-rate events; 15 directions",
  varied_events, maximum_events))
