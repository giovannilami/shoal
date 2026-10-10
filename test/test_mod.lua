local root = arg[0]:match("^(.*)/test/test_mod%.lua$") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local Core = require("shoal_core")
local Clock = require("shoal_clock")
local GridUI = require("shoal_grid")
local Mod = require("shoal_mod")
local count = 0
local function equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s",
    label, tostring(expected), tostring(actual)))
  count = count + 1
end

local core = Core.new()
local windows = {}
local values, actions = {}, {}
for track = 1, 4 do
  windows[track] = { low = 0, high = 127, spread = 100 }
  local prefix = string.format("shoal_lfo_t%d_", track)
  values[prefix .. "on"] = 1
  values[prefix .. "shape"] = 1
  values[prefix .. "period"] = 1
  for _, item in ipairs(Mod.TARGETS) do
    values[prefix .. item.id] = 1
    values[prefix .. item.id .. "_range"] = Mod.range_pack(item.first,
      item.last)
    values[string.format("shoal_t%d_%s", track, item.id)] =
      item.id == "spread" and 100 or core.tracks[track][item.id]
  end
  values[string.format("shoal_t%d_mute", track)] = 1
  for _, page in ipairs(GridUI.PAGES) do
    for _, field in ipairs(page) do
      local name = string.format("shoal_t%d_%s", track, field.id)
      if values[name] == nil then values[name] = field.low end
    end
  end
end
values.shoal_freeze = 1
local params = {
  get = function(_, name) return values[name] end,
  set = function(_, name, value)
    values[name] = value
    if actions[name] then actions[name](value) end
  end,
}
local mod = Mod.new(core, params, windows, GridUI, 4)
for track = 1, 4 do
  local prefix = string.format("shoal_lfo_t%d_", track)
  actions[prefix .. "on"] = function() mod:config_changed(track) end
  for _, item in ipairs(Mod.TARGETS) do
    local target = item.id
    actions[prefix .. target] = function()
      mod:config_changed(track, target)
    end
  end
end
equal(Mod.range_pack(8, 16), Mod.range_pack(16, 8),
  "Grid endpoint order is immaterial")
local lo, hi = Mod.range_unpack(Mod.range_pack(7, 12))
equal(lo, 7, "packed lower endpoint")
equal(hi, 12, "packed upper endpoint")

mod:set_range(1, "chance", 8, 16)
mod:assign(1, "chance", true)
mod:toggle(1)
equal(mod:sample(1, "chance", 0), 50, "triangle starts at low")
equal(mod:sample(1, "chance", 2), 100, "triangle reaches high")
equal(mod:sample(1, "chance", 4), 50, "triangle returns to low")
mod:before_step(1, 2)
equal(core.tracks[1].chance, 100, "modulation uses effective core value")
equal(values.shoal_t1_chance, 100, "modulation preserves base parameter")
mod:before_step(1, 0)
equal(core.tracks[1].chance, 50, "next phase lowers effective chance")
mod:toggle(1)
mod:config_changed(1)
equal(core.tracks[1].chance, 100, "LFO off restores base chance")

mod:set_range(1, "spread", 8, 10)
mod:assign(1, "spread", true)
mod:toggle(1)
mod:before_step(1, 2)
equal(windows[1].spread, 115, "spread modulates output transform")
equal(values.shoal_t1_spread, 100, "spread base remains saved")
mod:assign(1, "spread", false)
mod:config_changed(1, "spread")
equal(windows[1].spread, 100, "unassigning restores spread")

mod:set_range(1, "length", 9, 10) -- 16 or 17 steps
mod:assign(1, "length", true)
for beat = 0, 14 do
  mod:before_step(1, beat)
  local event = core:advance(1)
  mod:after_step(1, event, beat)
end
equal(core.tracks[1].length, 16, "length remains fixed during phrase")
local eos = core:advance(1)
equal(eos.eos, true, "sixteenth step is a phrase boundary")
mod:after_step(1, eos, 15)
equal(core.tracks[1].length, 16, "completed phrase keeps old display length")
mod:before_step(1, 16)
equal(core.tracks[1].length, 17, "length changes before next phrase")
mod:assign(1, "length", false)
mod:config_changed(1, "length")
equal(core.tracks[1].length, 16, "unassigned length restores base")

local runtime = { run = function() end, sync = function() end,
  sleep = function() end, cancel = function() end,
  get_beat_sec = function() return 0.5 end }
local phase_core = Core.new()
phase_core:set_track(1, "rate", "/2")
local phase_clock = Clock.new(phase_core, function() end, runtime, 1)
local slow_first = phase_clock:plan_tick()
equal(#slow_first, 1, "slow rate begins on a downbeat")
phase_core:set_track(1, "rate", "x1")
local phase_change = phase_clock:plan_tick()
equal(#phase_change, 1, "new rate retains a pending event")
equal(phase_change[1].offset, 0.5,
  "rate change preserves half of remaining interval")
local beat_clock = Clock.new(core, function() end, runtime, 1, {
  before_tick = function(beat) mod:before_tick(beat) end,
  before_step = function(track, beat) mod:before_step(track, beat) end,
  after_step = function(track, event, beat) mod:after_step(track, event, beat) end,
})
mod:set_range(1, "rate", 8, 11) -- x1 to x1.5
mod:assign(1, "rate", true)
for beat = 0, 15 do
  local plan = beat_clock:plan_tick()
  local last = -1
  for _, item in ipairs(plan) do
    equal(item.offset >= 0 and item.offset < 1 and item.offset > last,
      true, "rate moves without duplicate or invalid beat offsets")
    last = item.offset
    beat_clock:fire(item)
  end
end
equal(values.shoal_t1_rate, 13, "rate base remains x1")
mod:toggle(1)
mod:config_changed(1)
equal(core.tracks[1].rate, 13, "rate restores when LFO stops")

values.shoal_lfo_t1_shape = 2
local a = mod:phase(1, 1)
equal(a, mod:phase(1, 3), "random steps hold across one bar")
equal(a, mod:phase(1, 1), "random steps are deterministic")
equal(mod:is_target("evolve"), false, "unrouted field rejected")

-- Exercise the physical LFO key and endpoint gesture, including two pages.
local device = { device = { cols = 16, rows = 8 }, all = function() end,
  led = function() end, refresh = function() end }
local notices = {}
values.shoal_lfo_t1_shape = 1
mod:assign(1, "chance", false)
local grid = GridUI.new({ params = params,
  grid = { connect = function() return device end }, mod = mod,
  selected_track = function() return 1 end,
  select_track = function() end,
  feedback = function(message) notices[#notices + 1] = message end })
grid:connect()
device.key(9, 8, 1)
device.key(9, 8, 0)
equal(mod:enabled(1), true, "Grid LFO key toggles on")
device.key(9, 8, 1)
device.key(8, 3, 1)
device.key(16, 3, 1)
device.key(9, 8, 0)
equal(mod:assigned(1, "chance"), true, "Grid gesture assigns Chance")
lo, hi = mod:range_values(1, "chance")
equal(lo, 50, "Grid chance lower limit")
equal(hi, 100, "Grid chance upper limit")
equal(mod:enabled(1), true, "range gesture does not toggle LFO")
mod:before_step(1, 0)
equal(core.tracks[1].chance, 50, "active Grid range modulates Chance")
device.key(9, 8, 1)
device.key(16, 3, 1)
device.key(8, 3, 1)
device.key(9, 8, 0)
equal(mod:assigned(1, "chance"), false,
  "same endpoint pair in reverse order removes assignment")
equal(core.tracks[1].chance, values.shoal_t1_chance,
  "removing Grid assignment restores manual Chance")
equal(mod:enabled(1), true, "removing one target leaves LFO running")
device.key(5, 8, 1)
equal(mod:enabled(1), true, "column 5 remains an empty spacer")
device.key(9, 8, 1)
device.key(8, 3, 1)
device.key(12, 3, 1)
device.key(9, 8, 0)
equal(mod:assigned(1, "chance"), true,
  "new endpoint pair reassigns target")
lo, hi = mod:range_values(1, "chance")
equal(lo, 50, "new pair sets lower limit")
equal(hi, 75, "new pair sets upper limit")
device.key(7, 8, 1)
device.key(9, 8, 1)
device.key(8, 7, 1)
device.key(10, 7, 1)
device.key(9, 8, 0)
lo, hi = mod:range_values(1, "spread")
equal(lo, 100, "second-page spread lower limit")
equal(hi, 115, "second-page spread upper limit")
mod:before_tick(2)
mod:before_step(1, 2)
equal(core.tracks[1].rate, 16, "Rate follows shared high phase")
equal(core.tracks[1].chance, 75, "Chance follows shared high phase")
equal(windows[1].spread, 115, "Spread follows same phase simultaneously")
grid:redraw_if_dirty()

print("ok - " .. count .. " modulation assertions")
