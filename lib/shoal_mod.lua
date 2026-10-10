-- One clock-synced modulation phase per track, routed to several Grid values.
-- The module never writes the base musical parameters: psets keep manual values.

local Mod = {}
Mod.__index = Mod

Mod.SHAPES = { "Triangle", "Random steps", "Sine" }
Mod.PERIODS = { 4, 8, 16, 32 } -- beats: 1, 2, 4, 8 four-beat bars
Mod.TARGETS = {
  { id = "rate", page = 1, row = 1, label = "Rate", first = 8, last = 11 },
  { id = "length", page = 1, row = 2, label = "Length", first = 8, last = 9 },
  { id = "chance", page = 1, row = 3, label = "Chance", first = 8, last = 16 },
  { id = "shift", page = 1, row = 6, label = "Shift", first = 7, last = 10 },
  { id = "note", page = 2, row = 1, label = "Note +/-", first = 7, last = 10 },
  { id = "oct", page = 2, row = 2, label = "Oct +/-", first = 7, last = 10 },
  { id = "spread", page = 2, row = 7, label = "Spread", first = 7, last = 11 },
}

local targets = {}
for _, target in ipairs(Mod.TARGETS) do targets[target.id] = target end

local function id(track, suffix)
  return string.format("shoal_lfo_t%d_%s", track, suffix)
end

function Mod.range_pack(first, last)
  local low, high = math.min(first, last), math.max(first, last)
  assert(low >= 1 and high <= 16, "Grid range must be within 1..16")
  return (low - 1) * 16 + high
end

function Mod.range_unpack(packed)
  return (packed - 1) // 16 + 1, (packed - 1) % 16 + 1
end

function Mod.new(core, params, windows, grid, track_count)
  assert(core and params and windows and grid and track_count)
  return setmetatable({
    core = core,
    params = params,
    windows = windows,
    grid = grid,
    track_count = track_count,
    pending_length = {},
  }, Mod)
end

function Mod:field(target)
  local info = assert(targets[target], "unknown LFO target: " .. tostring(target))
  return self.grid.PAGES[info.page][info.row]
end

function Mod:is_target(target)
  return targets[target] ~= nil
end

function Mod:columns(track, target)
  return Mod.range_unpack(self.params:get(id(track, target .. "_range")))
end

function Mod:range_values(track, target)
  local first, last = self:columns(track, target)
  local field = self:field(target)
  return self.grid.value_at(field, first), self.grid.value_at(field, last)
end

function Mod:set_range(track, target, first, last)
  assert(targets[target] and track >= 1 and track <= self.track_count)
  self.params:set(id(track, target .. "_range"), Mod.range_pack(first, last))
end

function Mod:assign(track, target, enabled)
  assert(targets[target] and track >= 1 and track <= self.track_count)
  self.params:set(id(track, target), enabled and 2 or 1)
end

function Mod:toggle(track)
  local parameter = id(track, "on")
  self.params:set(parameter, self.params:get(parameter) == 2 and 1 or 2)
end

function Mod:enabled(track)
  return self.params:get(id(track, "on")) == 2
end

function Mod:assigned(track, target)
  return targets[target] ~= nil and self.params:get(id(track, target)) == 2
end

function Mod:active(track, target)
  return self:enabled(track) and self:assigned(track, target)
end

function Mod:value(track, target)
  if target == "spread" then return self.windows[track].spread end
  return self.core.tracks[track][target]
end

function Mod:_apply(track, target, value)
  if self:value(track, target) == value then return false end
  if target == "spread" then
    self.windows[track].spread = value
  else
    self.core:set_track(track, target, value)
  end
  return true
end

function Mod:restore(track, target)
  self:_apply(track, target, self.params:get(string.format("shoal_t%d_%s", track, target)))
end

function Mod:config_changed(track, target)
  if target then
    if not self:active(track, target) then
      if target == "length" then self.pending_length[track] = nil end
      self:restore(track, target)
    end
  elseif not self:enabled(track) then
    self.pending_length[track] = nil
    for _, item in ipairs(Mod.TARGETS) do self:restore(track, item.id) end
  end
end

function Mod:reset()
  self.pending_length = {}
end

function Mod:phase(track, beat)
  local period = Mod.PERIODS[self.params:get(id(track, "period"))]
  local shape = self.params:get(id(track, "shape"))
  local cycle = beat / period
  local part = cycle - math.floor(cycle)
  if shape == 2 then
    -- A private hash keeps Random Steps repeatable without changing Shoal Seed.
    return self.core.hash3(track, math.floor(cycle), 0x1f0) / 0xffffffff
  elseif shape == 3 then
    return (1 - math.cos(part * math.pi * 2)) / 2
  end
  return part <= 0.5 and part * 2 or (1 - part) * 2
end

function Mod:sample(track, target, beat)
  local first, last = self:columns(track, target)
  local field = self:field(target)
  local ladder, seen = {}, {}
  for column = first, last do
    local value = self.grid.value_at(field, column)
    if value ~= nil and not seen[value] then
      ladder[#ladder + 1] = value
      seen[value] = true
    end
  end
  local phase = self:phase(track, beat)
  local index = math.floor(phase * (#ladder - 1) + 0.5) + 1
  return ladder[index]
end

-- The scheduler calls this before planning a beat, so Rate is stable within it.
function Mod:before_tick(beat)
  local changed = false
  for track = 1, self.track_count do
    if self:active(track, "rate") then
      changed = self:_apply(track, "rate", self:sample(track, "rate", beat))
        or changed
    end
  end
  return changed
end

-- Other targets use the same phase at the actual event time.
function Mod:before_step(track, beat)
  if self.pending_length[track] then
    self:_apply(track, "length", self.pending_length[track])
    self.pending_length[track] = nil
  end
  for _, item in ipairs(Mod.TARGETS) do
    local target = item.id
    if target ~= "rate" and target ~= "length"
        and self:active(track, target) then
      self:_apply(track, target, self:sample(track, target, beat))
    end
  end
end

-- Length changes only after a complete phrase, never halfway through it.
function Mod:after_step(track, event, beat)
  if event.eos and self:active(track, "length") then
    self.pending_length[track] = self:sample(track, "length", beat)
  end
end

return Mod
