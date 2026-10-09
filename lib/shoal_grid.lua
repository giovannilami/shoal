-- Two-page, 16 x 8 performance editor. The norns screen remains the sequencer.
-- Norns services are injected so the key/value mapping can be tested in Lua.

local GridUI = {}
GridUI.__index = GridUI

GridUI.PAGES = {
  {
    title = "SEQ",
    -- Exact option indexes after the Norns rate list omits /64 and x64.
    -- x1 and Chance 50 share column 8; x1.5 is available at column 11.
    { id = "rate", label = "RATE", kind = "linear", low = 1, high = 27,
      values = { 2, 3, 5, 8, 9, 11, 12, 13, 14, 15, 16, 17, 19, 20, 25, 26 } },
    { id = "length", label = "LENGTH", kind = "linear", low = 1, high = 64,
      values = { 1, 2, 3, 4, 5, 7, 8, 12, 16, 17, 19, 24, 32, 40, 48, 64 } },
    { id = "chance", label = "CHANCE", kind = "linear", low = 0, high = 100,
      values = { 0, 5, 10, 15, 20, 25, 35, 50, 60, 65, 70, 75, 80, 90, 95, 100 } },
    { id = "evolve", label = "EVOLVE", kind = "linear", low = 0, high = 100,
      values = { 0, 1, 2, 3, 4, 5, 7, 10, 15, 20, 25, 35, 50, 65, 80, 100 } },
    { id = "direction", label = "DIRECTION", kind = "direct", low = 1, high = 15, first = 1 },
    { id = "shift", label = "SHIFT", kind = "bipolar", low = -63, high = 63,
      center = 0, double_center = true,
      values = { -12, -8, -6, -4, -3, -2, -1, 0,
        0, 1, 2, 3, 4, 6, 8, 12 } },
    { id = "source", label = "FOLLOW", kind = "direct", low = 1, high = 5, first = 1 },
  },
  {
    title = "NOTE",
    { id = "note", label = "NOTE", kind = "bipolar", low = -100, high = 100,
      center = 0, values = { -100, -90, -75, -60, -45, -30, -15, 0,
        5, 15, 30, 45, 60, 75, 90, 100 } },
    { id = "oct", label = "OCT", kind = "bipolar", low = -100, high = 100,
      center = 0, values = { -100, -90, -75, -60, -45, -30, -15, 0,
        5, 15, 30, 45, 60, 75, 90, 100 } },
    { id = "octave", label = "OCTAVE", kind = "direct", low = -3, high = 3, first = 5 },
    { id = "transpose", label = "TRANSPOSE", kind = "direct", low = -7, high = 7, first = 1 },
    { id = "min_note", label = "MIN NOTE", kind = "linear", low = 0, high = 127 },
    { id = "max_note", label = "MAX NOTE", kind = "linear", low = 0, high = 127 },
    { id = "spread", label = "SPREAD", kind = "bipolar", low = 0, high = 200,
      center = 100, double_center = true,
      values = { 0, 10, 25, 40, 55, 70, 85, 100,
        100, 115, 130, 145, 160, 175, 190, 200 } },
  },
}

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function round(value)
  return math.floor(value + 0.5)
end

local function track_id(track, name)
  return string.format("shoal_t%d_%s", track, name)
end

local function column_to_value(field, x)
  if field.values then return field.values[x] end
  if field.kind == "direct" then
    local value = field.low + x - field.first
    if value < field.low or value > field.high then return nil end
    return value
  elseif field.kind == "bipolar" then
    if x == 8 or x == 9 then return 0 end
    if x < 8 then return -round((8 - x) * -field.low / 7) end
    return round((x - 9) * field.high / 7)
  end
  return field.low + round((x - 1) * (field.high - field.low) / 15)
end

-- Randomise among values a Grid key can actually select. Repeated centre
-- keys (Shift and Spread) count once, so zero/100 has no accidental weight.
local function selectable_values(field)
  local choices, seen = {}, {}
  for x = 1, 16 do
    local value = column_to_value(field, x)
    if value ~= nil and not seen[value] then
      choices[#choices + 1] = value
      seen[value] = true
    end
  end
  return choices
end

local function value_to_column(field, value)
  if field.values then
    local best, distance = 1, math.huge
    for x, mapped in ipairs(field.values) do
      local eligible = field.kind ~= "bipolar"
        or value == field.center
        or value < field.center and x <= 7
        or value > field.center and x >= (field.double_center and 10 or 9)
      if eligible then
        local difference = math.abs(mapped - value)
        if difference < distance then
          best, distance = x, difference
        end
      end
    end
    return best
  end
  if field.kind == "direct" then return field.first + value - field.low end
  if field.kind == "bipolar" then
    if value == 0 then return 8 end
    if value < 0 then return 8 - round(-value * 7 / -field.low) end
    return 9 + round(value * 7 / field.high)
  end
  return 1 + round((value - field.low) * 15 / (field.high - field.low))
end

function GridUI.new(options)
  assert(options and options.params and options.grid
    and options.selected_track and options.select_track,
    "grid requires params, grid, and track callbacks")
  return setmetatable({
    params = options.params,
    api = options.grid,
    selected_track = options.selected_track,
    select_track = options.select_track,
    feedback = options.feedback or function() end,
    random = options.random or math.random,
    track_count = options.track_count or 4,
    page = 1,
    fine = false,
    device = nil,
    dirty = true,
  }, GridUI)
end

function GridUI:connect(port)
  local device = self.api.connect(port)
  self.device = device
  self.fine = false
  if device then
    device.key = function(x, y, z) self:key(x, y, z) end
  end
  self.dirty = true
end

function GridUI:disconnect(removed)
  local current = self.device and self.device.device
  if not current or not removed or current.id == removed.id
      or current.port == removed.port then
    self.device = nil
    self.fine = false
    self.dirty = true
  end
end

function GridUI:clear()
  if self.device and self.device.device then
    self.device:all(0)
    self.device:refresh()
  end
  self.device = nil
  self.fine = false
end

function GridUI:mark_dirty()
  self.dirty = true
end

function GridUI:_field_feedback(field, id, track)
  local value = self.params.string and self.params:string(id)
    or tostring(self.params:get(id))
  if field.id == "direction" then value = string.upper(value) end
  self.feedback(string.format("T%d %s %s", track, field.label, value))
end

function GridUI:_safe_source(track, option)
  if option == 1 then return true end -- Off
  local target, seen = option - 1, {}
  for _ = 1, self.track_count do
    if target == track or seen[target] then return false end
    seen[target] = true
    local next_option = self.params:get(track_id(target, "source"))
    if next_option == 1 or next_option == target + 1 then return true end
    if not next_option or next_option < 1
        or next_option > self.track_count + 1 then return false end
    target = next_option - 1
  end
  return false
end

function GridUI:_randomize_track()
  local track = self.selected_track()
  local chosen = {}
  for _, page in ipairs(GridUI.PAGES) do
    for _, field in ipairs(page) do
      local choices = selectable_values(field)
      if field.id == "source" then
        local safe = {}
        for _, value in ipairs(choices) do
          if self:_safe_source(track, value) then
            safe[#safe + 1] = value
          end
        end
        choices = safe
      end
      chosen[field.id] = choices[self.random(#choices)]
    end
  end

  -- These two Norns parameters constrain each other through their actions.
  -- Sort the sampled Grid values before applying them to avoid a narrowed or
  -- inverted pitch window, regardless of the old parameter values.
  local low = math.min(chosen.min_note, chosen.max_note)
  local high = math.max(chosen.min_note, chosen.max_note)
  chosen.min_note, chosen.max_note = low, high
  for _, page in ipairs(GridUI.PAGES) do
    for _, field in ipairs(page) do
      local id = track_id(track, field.id)
      local value = chosen[field.id]
      if value ~= self.params:get(id) then self.params:set(id, value) end
    end
  end
  self.feedback(string.format("T%d RANDOMIZED", track))
end

function GridUI:_bottom_key(x)
  if x >= 1 and x <= self.track_count then
    self.select_track(x)
    self.feedback("GRID " .. GridUI.PAGES[self.page].title .. " T" .. x)
  elseif x == 6 or x == 7 then
    self.page = x - 5
    self.feedback("GRID " .. GridUI.PAGES[self.page].title
      .. " T" .. self.selected_track())
  elseif x == 10 then
    local value = self.params:get("shoal_freeze") == 2 and 1 or 2
    self.params:set("shoal_freeze", value)
    self.feedback(value == 2 and "FREEZE ON" or "FREEZE OFF")
  elseif x >= 12 and x <= 15 then
    local id = track_id(x - 11, "mute")
    local value = self.params:get(id) == 2 and 1 or 2
    self.params:set(id, value)
    self.feedback(string.format("T%d MUTE %s", x - 11,
      value == 2 and "ON" or "OFF"))
  elseif x == 16 then
    self:_randomize_track()
  end
end

function GridUI:key(x, y, z)
  if x < 1 or x > 16 or y < 1 or y > 8 then return end
  if y == 8 and x == 9 then
    self.fine = z == 1
    self.dirty = true
    return
  end
  if z ~= 1 then return end
  if y == 8 then
    self:_bottom_key(x)
  else
    local field = GridUI.PAGES[self.page][y]
    local track = self.selected_track()
    local id = track_id(track, field.id)
    local old = self.params:get(id)
    local value
    if self.fine then
      value = clamp(old + (x <= 8 and -1 or 1), field.low, field.high)
    else
      value = column_to_value(field, x)
    end
    if value ~= nil then
      if value ~= old then self.params:set(id, value) end
      self:_field_feedback(field, id, track)
    end
  end
  self.dirty = true
end

function GridUI:_draw_field(device, field, y, value)
  local cursor = value_to_column(field, value)
  if field.kind == "direct" then
    for x = field.first, field.first + field.high - field.low do
      device:led(x, y, x == cursor and 15 or 3)
    end
  elseif field.kind == "bipolar" then
    local center = field.center or 0
    local at_center = value == center
    device:led(8, y, at_center and 15 or 3)
    if field.double_center then
      device:led(9, y, at_center and 15 or 3)
    end
    if value < center then
      for x = cursor, 7 do device:led(x, y, x == cursor and 15 or 5) end
    elseif value > center then
      for x = field.double_center and 10 or 9, cursor do
        device:led(x, y, x == cursor and 15 or 5)
      end
    end
  else
    for x = 1, 16 do
      device:led(x, y, x == cursor and 15 or x < cursor and 5 or 1)
    end
  end
end

function GridUI:redraw_if_dirty()
  if not self.dirty then return end
  local device = self.device
  local hardware = device and device.device
  if not hardware or hardware.cols ~= 16 or hardware.rows ~= 8 then return end
  device:all(0)
  local track = self.selected_track()
  for y = 1, 7 do
    local field = GridUI.PAGES[self.page][y]
    self:_draw_field(device, field, y,
      self.params:get(track_id(track, field.id)))
  end
  for t = 1, self.track_count do
    device:led(t, 8, t == track and 15 or 4)
    device:led(t + 11, 8,
      self.params:get(track_id(t, "mute")) == 2 and 15 or 4)
  end
  device:led(6, 8, self.page == 1 and 15 or 4)
  device:led(7, 8, self.page == 2 and 15 or 4)
  device:led(9, 8, self.fine and 15 or 3)
  device:led(10, 8, self.params:get("shoal_freeze") == 2 and 15 or 3)
  device:led(16, 8, 7) -- momentary Random, not the Norns K2 transport
  device:refresh()
  self.dirty = false
end

return GridUI
