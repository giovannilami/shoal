local root = arg[0]:match("^(.*)/tests/test_runtime%.lua$") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local Core = require("shoal_core")
local ShoalClock = require("shoal_clock")
local Outputs = require("shoal_outputs")
local Pitch = require("shoal_pitch")
local Font = require("shoal_font")
local checks = 0

local function equal(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  checks = checks + 1
end

local clock_task
local fake_clock = {
  run = function(fn)
    clock_task = coroutine.create(fn)
    return clock_task
  end,
  cancel = function() end,
  sync = function() coroutine.yield() end,
  sleep = function() end,
  get_beat_sec = function() return 0.5 end,
}

local function count_track(plan, track)
  local count = 0
  for _, item in ipairs(plan) do
    if item.track == track then count = count + 1 end
  end
  return count
end

local core = Core.new()
local scheduler = ShoalClock.new(core, function() end, fake_clock)
core:set_track(1, "rate", "x1.3")
equal(count_track(scheduler:plan_tick(), 1), 2, "x1.3 first tick")
equal(count_track(scheduler:plan_tick(), 1), 1, "x1.3 second tick")
local third = scheduler:plan_tick()
equal(count_track(third, 1), 1, "x1.3 third tick")
local fourth = scheduler:plan_tick()
equal(count_track(fourth, 1), 2, "x1.3 fourth tick")
local offsets = {}
for _, item in ipairs(fourth) do
  if item.track == 1 then offsets[#offsets + 1] = item.offset end
end
equal(offsets[1], 1 / 13, "first x1.3 substep in fourth beat")
equal(offsets[2], 11 / 13, "second x1.3 substep in fourth beat")

-- Every supported ratio must preserve its phase over many beats. This also
-- catches bunching at the beat boundary when the rate is not an integer.
for rate = 0, 28 do
  local rate_core = Core.new()
  rate_core:set_track(1, "rate", rate)
  local rate_clock = ShoalClock.new(rate_core, function() end, fake_clock)
  local num, den = Core.rate_ratio(rate)
  local step = 0
  local accurate = true
  for tick = 0, 129 do
    local plan = rate_clock:plan_tick()
    for _, item in ipairs(plan) do
      if item.track == 1 then
        local actual_beat = tick + item.offset
        local expected_beat = step * den / num
        accurate = accurate and item.offset >= 0 and item.offset < 1
          and math.abs(actual_beat - expected_beat) < 1e-10
        step = step + 1
      end
    end
  end
  equal(accurate, true, "rate phase " .. Core.RATES[rate].name)
  equal(step, (130 * num + den - 1) // den,
    "rate count " .. Core.RATES[rate].name)
end

scheduler:reset()
core:set_track(1, "rate", "/64")
equal(count_track(scheduler:plan_tick(), 1), 1, "reset primes slow track")
equal(count_track(scheduler:plan_tick(), 1), 0, "slow track waits")
core:set_global("freeze", true)
equal(#scheduler:plan_tick(), 0, "freeze suppresses advances")
core:set_global("freeze", false)

local four_clock = ShoalClock.new(Core.new(), function() end, fake_clock, 4)
equal(#four_clock:plan_tick(), 4, "norns adapter schedules four tracks")

local major = Core.SCALES[1].pcs
equal(Pitch.map(67, 60, 0, 127, 100, major), 67,
  "default pitch window preserves source note")
equal(Pitch.map(67, 60, 48, 72, 200, major), 72,
  "spread expands and obeys maximum")
equal(Pitch.map(55, 60, 60, 60, 100, major), 60,
  "one-note window obeys hard boundary")
local raw_event = { track = 1, note = 67, audible = true }
local mapped_event = Pitch.event(raw_event, 60, 60, 72, 0, major)
equal(mapped_event.note, 60, "zero spread contracts to root")
equal(raw_event.note, 67, "pitch window never alters core event")

local messages = {}
local connected_midi_port
local midi_device = {
  note_on = function(_, note, velocity, channel)
    messages[#messages + 1] = { "on", note, velocity, channel }
  end,
  note_off = function(_, note, velocity, channel)
    messages[#messages + 1] = { "off", note, velocity, channel }
  end,
}
local fake_devices = {
  engine = { hz = function() end },
  midi = { connect = function(port)
    connected_midi_port = port
    return midi_device
  end },
  crow = { output = { {}, {}, {}, {} } },
  clock = fake_clock,
}
local outputs = Outputs.new(fake_devices)
outputs:set_midi_port(1)
outputs:set_midi_port(16)
equal(connected_midi_port, 16, "all 16 norns MIDI ports supported")
outputs:set_route(1, "midi", 3)
outputs:step({ track = 1, audible = true, note = 60, tie = false }, 1, 50, 100)
equal(messages[1][1], "on", "MIDI note on")
equal(messages[1][4], 3, "MIDI channel")
outputs:set_route(1, "off", 3)
equal(messages[2][1], "off", "route change closes note")

outputs:set_route(1, "crow12")
outputs:step({ track = 1, audible = true, note = 60, tie = false }, 1, 50, 100)
equal(fake_devices.crow.output[1].volts, 1, "crow 1V/oct pitch")
equal(fake_devices.crow.output[2].volts, 5, "crow gate high")
outputs:panic()
equal(fake_devices.crow.output[2].volts, 0, "panic lowers crow gate")

local played_hz
fake_devices.engine.hz = function(hz) played_hz = hz end
outputs:set_route(2, "polyperc")
outputs:step({ track = 2, audible = true, note = 69 }, 1, 50, 100)
equal(played_hz, 440, "PolyPerc receives A4")

local nb_messages = {}
fake_devices.nb_player = function()
  return {
    note_on = function(_, note, velocity)
      nb_messages[#nb_messages + 1] = { "on", note, velocity }
    end,
    note_off = function(_, note)
      nb_messages[#nb_messages + 1] = { "off", note }
    end,
  }
end
outputs:set_route(2, "nb")
outputs:step({ track = 2, audible = true, note = 60 }, 1, 50, 100)
equal(nb_messages[1][1], "on", "n.b. note on")
equal(nb_messages[1][3], 100 / 127, "n.b. velocity normalized")
outputs:panic()
equal(nb_messages[2][1], "off", "n.b. note off on panic")

-- Loading and initializing the entry point catches missing norns API calls,
-- parameter collisions, and wiring mistakes before copying to hardware.
local values, actions, option_choices = {}, {}, {}
local screen_pixels = {}
local drawn_text = {}
local screen_updates = 0
local redraw_instance
local grid_updates = 0
local test_grid = {
  device = { id = 3, port = 1, cols = 16, rows = 8 },
  all = function() end,
  led = function() end,
  refresh = function() grid_updates = grid_updates + 1 end,
}
grid = { connect = function() return test_grid end }
local function add_pixels(pixels, x, y, width, height)
  for dy = 0, height - 1 do
    for dx = 0, width - 1 do
      pixels[(x + dx) .. ":" .. (y + dy)] = true
    end
  end
end

local function region(pixels, left, top, right, bottom)
  local bits = {}
  for y = top, bottom do
    for x = left, right do
      bits[#bits + 1] = pixels[x .. ":" .. y] and "1" or "0"
    end
  end
  return table.concat(bits)
end

local function expected_text(draw, left, top, right, bottom)
  local pixels = {}
  draw({ rect = function(x, y, width, height)
    add_pixels(pixels, x, y, width, height)
  end, fill = function() end })
  return region(pixels, left, top, right, bottom)
end
params = {
  add_separator = function() end,
  add_group = function() end,
  add_option = function(_, id, _, options, default)
    values[id] = default
    option_choices[id] = options
  end,
  add_number = function(_, id, _, _, _, default) values[id] = default end,
  add_trigger = function(_, id) values[id] = false end,
  set_action = function(_, id, action) actions[id] = action end,
  get = function(_, id) return values[id] end,
  string = function(_, id) return tostring(values[id]) end,
  set = function(_, id, value)
    values[id] = value
    if actions[id] then actions[id](value) end
  end,
  delta = function(self, id, amount) self:set(id, values[id] + amount) end,
}
engine = { name = "", hz = function() end, amp = function() end, release = function() end }
midi = fake_devices.midi
crow = fake_devices.crow
clock = fake_clock
metro = {
  init = function()
    redraw_instance = { start = function() end, stop = function() end }
    return redraw_instance
  end,
}
screen = {
  clear = function() screen_pixels = {}; drawn_text = {} end,
  level = function() end,
  aa = function() end,
  font_face = function() end, font_size = function() end,
  move = function() end,
  text = function(value) drawn_text[#drawn_text + 1] = value end,
  text_right = function(value) drawn_text[#drawn_text + 1] = value end,
  text_extents = function(value) return #value * 3 end,
  update = function() screen_updates = screen_updates + 1 end,
  rect = function(x, y, width, height)
    add_pixels(screen_pixels, x, y, width, height)
  end,
  fill = function() end, stroke = function() end,
}
include = function(path)
  return dofile(root .. "/" .. path:match("(lib/.+)$") .. ".lua")
end

dofile(root .. "/shoal-norns.lua")
init()
equal(engine.name, "PolyPerc", "playable engine selected")
redraw_instance.event()
equal(grid_updates > 0, true, "connected Grid receives initial layout")
local start_updates = screen_updates
local ok, err = coroutine.resume(clock_task)
assert(ok, err)
ok, err = coroutine.resume(clock_task)
assert(ok, err)
equal(screen_updates, start_updates, "clock event waits for display refresh")
redraw_instance.event()
equal(screen_updates, start_updates + 1, "clock event refreshes playhead")
local function has_text(wanted)
  for _, value in ipairs(drawn_text) do
    if value == wanted then return true end
  end
  return false
end
equal(has_text("T1  01/16  S001  FORWARDS"), true,
  "clocked position and seed appear in header")
enc(1, 1)
local selected_two = false
for _, value in ipairs(drawn_text) do
  if value:find("^T2 ") and value:find("S098", 1, true) then
    selected_two = true
  end
end
equal(selected_two, true, "E1 changes the header to the selected track")
enc(1, -1)
equal(values.shoal_t1_route, 2, "track 1 audible by default")
equal(values.shoal_t4_route, 1, "other tracks off by default")
equal(values.shoal_t5_route, nil, "only four track parameter groups")
equal(#option_choices.shoal_midi_port, 16, "UI exposes 16 MIDI ports")
equal(#option_choices.shoal_t1_rate, 27, "Norns omits /64 and x64 rates")
equal(option_choices.shoal_t1_rate[1], "/32", "Norns slowest rate is /32")
equal(option_choices.shoal_t1_rate[27], "x32", "Norns fastest rate is x32")
local sequencer_task = clock_task
params:set("shoal_midi_port", 16)
equal(connected_midi_port, 16, "MIDI port parameter connects selected port")
params:set("shoal_t1_route", 3) -- MIDI in the non-n.b. build
local previous_midi_messages = #messages
ok, err = coroutine.resume(sequencer_task)
assert(ok, err)
equal(messages[previous_midi_messages + 1][1], "on",
  "clocked Shoal event emits MIDI note on")
equal(messages[previous_midi_messages + 1][4], 1,
  "clocked Shoal event uses selected track channel")
params:set("shoal_t1_direction", 8) -- Shuffle selected while already playing
ok, err = coroutine.resume(sequencer_task)
assert(ok, err)
params:set("shoal_t1_length", 5)
ok, err = coroutine.resume(sequencer_task)
assert(ok, err)
equal(values.shoal_run, 2, "live Shuffle leaves transport running")
params:set("shoal_t1_direction", 1)
local length_before = values.shoal_t1_length
key(2, 1)
equal(values.shoal_run, 1, "K2 stops")
equal(values.shoal_t1_length, length_before, "K2 does not change length")
key(2, 1)
equal(values.shoal_run, 2, "K2 starts")
equal(values.shoal_t1_length, length_before, "restart does not change length")
key(3, 1)
equal(values.shoal_t1_length, length_before, "reseed does not change length")
local rate_before = values.shoal_t1_rate
enc(2, 1)
equal(values.shoal_t1_rate, rate_before + 1, "overview E2 edits displayed Rate")
equal(values.shoal_t1_length, length_before, "overview E2 leaves Length alone")
enc(3, 1)
equal(values.shoal_t1_length, length_before + 1,
  "overview E3 edits displayed Length")
key(1, 1)
equal(has_text("T1  E2 CHANCE  E3 EVOLVE"), true,
  "modifier displays overview control legend")
enc(2, -1)
enc(3, 1)
equal(values.shoal_t1_chance, 99, "K1+E2 edits Chance")
equal(values.shoal_t1_evolve, 1, "K1+E3 edits Evolve")
key(1, 0)
local seed_after_reseed = values.shoal_t1_seed
key(1, 1)
key(3, 1)
key(1, 0)
equal(values.shoal_t1_seed, seed_after_reseed,
  "K1+K3 changes page without reseeding")
equal(region(screen_pixels, 105, 2, 127, 8),
  expected_text(function(target) Font.right(target, 127, 8, "2/4") end,
    105, 2, 127, 8), "K1+K3 opens track edit page")
local length_on_edit = values.shoal_t1_length
params:set("shoal_t1_seed", 500)
enc(3, 1)
equal(values.shoal_t1_seed, 501, "Track page lets E3 edit Seed")
equal(values.shoal_t1_length, length_on_edit,
  "editing Seed leaves Length alone")
enc(2, 2) -- select Shift, the third Track field
enc(3, 1)
equal(values.shoal_t1_shift, 1, "E3 edits selected field")
equal(values.shoal_t1_length, length_on_edit,
  "selecting and editing Shift leaves Length alone")
key(1, 1)
key(3, 1)
key(1, 0)
local seed_on_pitch = values.shoal_t1_seed
enc(2, 100) -- the final Pitch field is Spread, not Seed
enc(3, 1)
equal(values.shoal_t1_spread, 101, "Pitch page ends with Spread")
equal(values.shoal_t1_seed, seed_on_pitch, "Pitch page does not change Track Seed")
key(1, 1)
key(2, 1)
key(1, 0)
key(1, 1)
key(2, 1)
key(1, 0)
equal(has_text("1/4"), true, "K1+K2 returns to overview")
params:set("shoal_t1_min_note", 72)
equal(values.shoal_t1_max_note, 127, "min stays below max")
params:set("shoal_t1_max_note", 60)
equal(values.shoal_t1_min_note, 60, "max below min moves lower bound")
test_grid.key(6, 8, 1)
test_grid.key(1, 3, 1)
equal(values.shoal_t1_chance, 0, "Grid edits current track through params")
test_grid.key(7, 8, 1)
test_grid.key(16, 1, 1)
equal(values.shoal_t1_note, 100, "Grid pitch page edits Note variation")
test_grid.key(2, 8, 1)
test_grid.key(16, 1, 1)
equal(values.shoal_t2_note, 100, "Grid track select follows editing target")
test_grid.key(13, 8, 1)
equal(values.shoal_t2_mute, 2, "Grid mute addresses Track 2")
local running_before_random = values.shoal_run
local seed_before_random = values.shoal_t2_seed
local other_note_before_random = values.shoal_t1_note
test_grid.key(16, 8, 1)
equal(values.shoal_run, running_before_random,
  "Grid Random does not change K2 transport")
equal(values.shoal_t2_seed, seed_before_random,
  "Grid Random leaves track seed unchanged")
equal(values.shoal_t1_note, other_note_before_random,
  "Grid Random leaves other tracks unchanged")
equal(values.shoal_t2_min_note <= values.shoal_t2_max_note, true,
  "Grid Random keeps MIDI pitch bounds ordered")
equal(values.shoal_t2_source ~= 3, true,
  "Grid Random never selects self as Follow source")
redraw_instance.event()
equal(grid_updates > 1, true, "Grid refreshes after performance edits")
cleanup()

print(string.format("ok - %d runtime assertions", checks))
