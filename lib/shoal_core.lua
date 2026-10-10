-- Shoal core for norns.
--
-- Pure Lua 5.3: no norns globals, clock, params, MIDI, crow, or n.b.
-- The musical logic is ported from Ormer Modular Shoal v1.2.0,
-- upstream commit 845b8d0bbbc6315ffa09fd3338137362695f0f1a.

local Core = {}
Core.__index = Core

Core.NUM_TRACKS = 8
Core.MAX_STEPS = 64
Core.UPSTREAM_COMMIT = "845b8d0bbbc6315ffa09fd3338137362695f0f1a"

local U32_MASK = 0xffffffff

local function u32(value)
  return value & U32_MASK
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- C++ integer division truncates toward zero. Lua 5.3's // floors, so the
-- negative case needs an explicit implementation for pitch calculations.
local function trunc_div(numerator, denominator)
  if numerator < 0 then
    return -((-numerator) // denominator)
  end
  return numerator // denominator
end

local function integer(value, label)
  local result = math.tointeger(value)
  assert(result, (label or "value") .. " must be an integer")
  return result
end

local function bounded_integer(value, low, high, label)
  value = integer(value, label)
  assert(value >= low and value <= high,
    string.format("%s must be between %d and %d", label, low, high))
  return value
end

-- Indices deliberately match the C++ enums: 0-based rather than Lua's usual
-- 1-based convention. This keeps saved state and future adapter code simple.
Core.RATES = {
  [0]  = { name = "/64",   num = 1,  den = 64 },
  [1]  = { name = "/32",   num = 1,  den = 32 },
  [2]  = { name = "/16",   num = 1,  den = 16 },
  [3]  = { name = "/8",    num = 1,  den = 8 },
  [4]  = { name = "/7",    num = 1,  den = 7 },
  [5]  = { name = "/6",    num = 1,  den = 6 },
  [6]  = { name = "/5.3",  num = 10, den = 53 },
  [7]  = { name = "/5",    num = 1,  den = 5 },
  [8]  = { name = "/4",    num = 1,  den = 4 },
  [9]  = { name = "/3",    num = 1,  den = 3 },
  [10] = { name = "/2.6",  num = 5,  den = 13 },
  [11] = { name = "/2",    num = 1,  den = 2 },
  [12] = { name = "/1.5",  num = 2,  den = 3 },
  [13] = { name = "x1",    num = 1,  den = 1 },
  [14] = { name = "x1.25", num = 5,  den = 4 },
  [15] = { name = "x1.3",  num = 13, den = 10 },
  [16] = { name = "x1.5",  num = 3,  den = 2 },
  [17] = { name = "x2",    num = 2,  den = 1 },
  [18] = { name = "x2.6",  num = 13, den = 5 },
  [19] = { name = "x3",    num = 3,  den = 1 },
  [20] = { name = "x4",    num = 4,  den = 1 },
  [21] = { name = "x5",    num = 5,  den = 1 },
  [22] = { name = "x5.3",  num = 53, den = 10 },
  [23] = { name = "x6",    num = 6,  den = 1 },
  [24] = { name = "x7",    num = 7,  den = 1 },
  [25] = { name = "x8",    num = 8,  den = 1 },
  [26] = { name = "x16",   num = 16, den = 1 },
  [27] = { name = "x32",   num = 32, den = 1 },
  [28] = { name = "x64",   num = 64, den = 1 },
}

Core.DIRECTIONS = {
  [0] = "forwards",
  [1] = "reverse",
  [2] = "pendulum",
  [3] = "random",
  [4] = "drunk",
  [5] = "pong",
  [6] = "tide",
  [7] = "shuffle",
  [8] = "pools",
  [9] = "stride",
  [10] = "gravity",
  [11] = "converge",
  [12] = "diverge",
  [13] = "skitter",
  [14] = "anchor",
}

Core.SCALES = {
  [0]  = { name = "chromatic",        pcs = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
  [1]  = { name = "major",            pcs = { 0, 2, 4, 5, 7, 9, 11 } },
  [2]  = { name = "natural minor",    pcs = { 0, 2, 3, 5, 7, 8, 10 } },
  [3]  = { name = "harmonic minor",   pcs = { 0, 2, 3, 5, 7, 8, 11 } },
  [4]  = { name = "dorian",           pcs = { 0, 2, 3, 5, 7, 9, 10 } },
  [5]  = { name = "phrygian",         pcs = { 0, 1, 3, 5, 7, 8, 10 } },
  [6]  = { name = "lydian",           pcs = { 0, 2, 4, 6, 7, 9, 11 } },
  [7]  = { name = "mixolydian",       pcs = { 0, 2, 4, 5, 7, 9, 10 } },
  [8]  = { name = "major pentatonic", pcs = { 0, 2, 4, 7, 9 } },
  [9]  = { name = "minor pentatonic", pcs = { 0, 3, 5, 7, 10 } },
  [10] = { name = "blues",            pcs = { 0, 3, 5, 6, 7, 10 } },
  [11] = { name = "hirajoshi",        pcs = { 0, 2, 3, 7, 8 } },
  [12] = { name = "in-sen",           pcs = { 0, 1, 5, 7, 10 } },
}

local function enum_index(value, values, maximum, label)
  if type(value) == "number" then
    return bounded_integer(value, 0, maximum, label)
  end
  assert(type(value) == "string", label .. " must be an index or name")
  local wanted = value:lower()
  for index = 0, maximum do
    local candidate = values[index]
    local name = type(candidate) == "table" and candidate.name or candidate
    if name:lower() == wanted then return index end
  end
  error("unknown " .. label .. ": " .. value)
end

function Core.hash3(a, b, c)
  a = u32(integer(a, "hash a"))
  b = u32(integer(b, "hash b"))
  c = u32(integer(c, "hash c"))
  local h = u32(u32(a * 0x9e3779b1) ~ u32(b * 0x85ebca77) ~ u32(c * 0xc2b2ae3d))
  h = u32(h ~ (h >> 16))
  h = u32(h * 0x7feb352d)
  h = u32(h ~ (h >> 15))
  h = u32(h * 0x846ca68b)
  h = u32(h ~ (h >> 16))
  return h
end

function Core.rate_ratio(rate)
  local index = enum_index(rate, Core.RATES, 28, "rate")
  local item = Core.RATES[index]
  return item.num, item.den, index
end

function Core.rate_advance_count(rate, tick_count)
  local num, den = Core.rate_ratio(rate)
  tick_count = bounded_integer(tick_count, 0, 0x7fffffff, "tick count")
  local before = (tick_count * num) // den
  local after = ((tick_count + 1) * num) // den
  return after - before
end

local function fresh_epochs()
  local result = {}
  for step = 0, Core.MAX_STEPS - 1 do result[step] = 0 end
  return result
end

local function default_track(index)
  return {
    length = 16,
    rate = 13,
    direction = 0,
    chance = 100,
    breathe = 0,
    note = 0,
    oct = 0,
    evolve = 0,
    gate = 50,
    tie = 0,
    slop = 0,
    octave = 0,
    transpose = 0,
    source = 0,
    mute = false,
    seed = 1 + (index - 1) * 97,
    shift = 0,

    active_seed = 1 + (index - 1) * 97,
    pending_seed = nil,
    pos = -1,
    dir = 1,
    phase = 0,
    rot = 0,
    pass = 0,
    pool_start = 0,
    pool_len = 0,
    pool_pos = 0,
    dwell = 0,
    order = {},
    epoch = fresh_epochs(),
    resting = false,
    eos_count = 0,
    last_event = nil,
  }
end

local function stable_degrees(scale)
  local pcs = scale.pcs
  local count = #pcs
  local stable = { 0 }
  local best_third, third_distance = -1, 99
  local best_fifth, fifth_distance = -1, 99

  for index = 1, count - 1 do
    local pc = pcs[index + 1]
    local d3 = math.abs(pc - 3)
    local d4 = math.abs(pc - 4)
    if d4 < d3 then d3 = d4 end
    if d3 < third_distance then
      third_distance, best_third = d3, index
    end
    local d7 = math.abs(pc - 7)
    if d7 < fifth_distance then
      fifth_distance, best_fifth = d7, index
    end
  end

  if best_third > 0 then stable[#stable + 1] = best_third end
  if best_fifth > 0 and best_fifth ~= best_third then
    stable[#stable + 1] = best_fifth
  end
  return stable
end

function Core.new(options)
  options = options or {}
  local self = setmetatable({}, Core)
  self.scale = enum_index(options.scale or 0, Core.SCALES, 12, "scale")
  self.root = bounded_integer(options.root or 48, 0, 127, "root")
  self.weight = bounded_integer(options.weight or 0, 0, 100, "weight")
  self.freeze = options.freeze == true
  self.rng = u32(options.rng or 0x7a31c0de)
  self.tracks = {}
  for index = 1, Core.NUM_TRACKS do self.tracks[index] = default_track(index) end
  self:_rebuild_scale()

  if options.tracks then
    for index, values in pairs(options.tracks) do
      for key, value in pairs(values) do self:set_track(index, key, value, true) end
    end
  end
  return self
end

function Core:_rebuild_scale()
  self.scale_pcs = Core.SCALES[self.scale].pcs
  self.stable_degrees = stable_degrees(Core.SCALES[self.scale])
end

function Core:set_global(key, value)
  if key == "scale" then
    self.scale = enum_index(value, Core.SCALES, 12, "scale")
    self:_rebuild_scale()
  elseif key == "root" then
    self.root = bounded_integer(value, 0, 127, "root")
  elseif key == "weight" then
    self.weight = bounded_integer(value, 0, 100, "weight")
  elseif key == "freeze" then
    assert(type(value) == "boolean", "freeze must be boolean")
    self.freeze = value
  else
    error("unknown global parameter: " .. tostring(key))
  end
end

local TRACK_RANGES = {
  length = { 1, 64 }, chance = { 0, 100 }, breathe = { 0, 100 },
  note = { -100, 100 }, oct = { -100, 100 }, evolve = { 0, 100 },
  gate = { 5, 95 }, tie = { 0, 100 }, slop = { 0, 100 },
  octave = { -3, 3 }, transpose = { -7, 7 }, source = { 0, 8 },
  shift = { -63, 63 },
}

function Core:set_track(index, key, value, immediate)
  index = bounded_integer(index, 1, Core.NUM_TRACKS, "track")
  local track = self.tracks[index]

  if key == "rate" then
    track.rate = enum_index(value, Core.RATES, 28, "rate")
  elseif key == "direction" then
    track.direction = enum_index(value, Core.DIRECTIONS, 14, "direction")
    if track.direction == 7 and track.pos >= 0 then
      self:_align_shuffle(index)
    end
  elseif key == "mute" then
    assert(type(value) == "boolean", "mute must be boolean")
    track.mute = value
  elseif key == "seed" then
    value = bounded_integer(value, 0, 999, "seed")
    track.seed = value
    if immediate then
      track.active_seed = value
      track.pending_seed = nil
    else
      track.pending_seed = value
    end
  elseif TRACK_RANGES[key] then
    local range = TRACK_RANGES[key]
    track[key] = bounded_integer(value, range[1], range[2], key)
    if key == "length" and track.direction == 7 and track.pos >= 0 then
      self:_align_shuffle(index)
    end
  else
    error("unknown track parameter: " .. tostring(key))
  end
end

function Core:effective_track(index)
  index = bounded_integer(index, 1, Core.NUM_TRACKS, "track")
  local current = index
  for _ = 1, Core.NUM_TRACKS do
    local source = self.tracks[current].source
    if source == 0 or source == current then break end
    current = source
  end
  return current
end

function Core:effective_seed(index)
  return self.tracks[self:effective_track(index)].active_seed
end

function Core:_next_rng()
  self.rng = u32(self.rng * 1664525 + 1013904223)
  return self.rng
end

function Core:_build_shuffle(track, length, seed, pass)
  for position = 0, length - 1 do track.order[position] = position end
  local random = Core.hash3(seed, pass, 0x5ffe)
  for position = length - 1, 1, -1 do
    random = u32(random * 1664525 + 1013904223)
    local other = (random >> 16) % (position + 1)
    track.order[position], track.order[other] = track.order[other], track.order[position]
  end
end

-- An already-running track can enter Shuffle (or change Length) without
-- passing through the startup branch. Build its order immediately and align
-- the phase to the currently displayed position, so the next clock event
-- continues from a valid permutation entry instead of indexing an empty table.
function Core:_align_shuffle(index)
  local track = self.tracks[index]
  local length = track.length
  track.pos = track.pos % length
  self:_build_shuffle(track, length, self:effective_seed(index), track.pass)
  for phase = 0, length - 1 do
    if track.order[phase] == track.pos then
      track.phase = phase
      return
    end
  end
end

function Core:evaluate(index, step)
  index = bounded_integer(index, 1, Core.NUM_TRACKS, "track")
  local track = self.tracks[index]
  step = bounded_integer(step, 0, track.length - 1, "step")

  local effective = self:effective_track(index)
  local source = self.tracks[effective]
  local seed = source.active_seed

  local walked_step = step
  step = (step + track.shift) % track.length
  -- As on the disting NT, Tide keeps Chance and Tie on the rhythm step while
  -- rotating only the pitch lookup by one step per completed pass.
  local pitch_step = step
  if track.direction == 6 and track.length > 1 then
    pitch_step = (step + track.rot) % track.length
  end

  local rhythm_epoch = source.epoch[step]
  local pitch_epoch = source.epoch[pitch_step]
  local rhythm_key = u32(step | (rhythm_epoch << 8))
  local pitch_key = u32(pitch_step | (pitch_epoch << 8))
  local fires = (Core.hash3(seed, rhythm_key, 0xf17e) % 100) < track.chance
  local tie = (Core.hash3(seed, rhythm_key, 0x071e) % 100) < track.tie

  local event = {
    track = index,
    source_track = effective,
    seed = seed,
    step0 = walked_step,
    step = walked_step + 1,
    lookup_step0 = step,
    pitch_step0 = pitch_step,
    pass = track.pass,
    fires = fires,
    tie = tie,
    resting = track.resting,
    muted = track.mute,
    audible = false,
    note = 0,
    bar_height = 0,
  }

  if not fires then return event end

  local scale_count = #self.scale_pcs
  local base_roll = Core.hash3(seed, pitch_key, 0xba5e) & 1023
  local degree = ((base_roll * (2 * scale_count)) >> 10) - scale_count
  local note_amount = track.note
  local octave_amount = track.oct
  local note_magnitude = math.abs(note_amount)
  local octave_magnitude = math.abs(octave_amount)
  local octave_variation = 0

  if note_magnitude > 0
      and (Core.hash3(seed, pitch_key, 0xa221) % 100) < note_magnitude then
    local reach = 1 + (note_magnitude * 11) // 100
    local deviation = 1 + Core.hash3(seed, pitch_key, 0x0007) % reach
    degree = degree + (note_amount > 0 and deviation or -deviation)
  end

  if octave_magnitude > 0
      and (Core.hash3(seed, pitch_key, 0x0c7a) % 100) < octave_magnitude then
    local reach = 1 + (octave_magnitude * 4) // 100
    octave_variation = 1 + Core.hash3(seed, pitch_key, 0x0c7b) % reach
    if octave_amount < 0 then octave_variation = -octave_variation end
  end

  if self.weight > 0 and (Core.hash3(seed, pitch_key, 0x0337) % 100) < self.weight then
    local octave = trunc_div(degree, scale_count)
    local within = degree - octave * scale_count
    if within < 0 then
      within = within + scale_count
      octave = octave - 1
    end

    local best, best_distance = 0, 99
    for _, stable in ipairs(self.stable_degrees) do
      local candidate = stable
      for _ = 0, 1 do
        local distance = math.abs(within - candidate)
        if distance < best_distance then
          best_distance, best = distance, candidate
        end
        candidate = candidate + scale_count
      end
    end
    degree = octave * scale_count + best
  end

  degree = degree + track.transpose
  local octave = trunc_div(degree, scale_count)
  local within = degree - octave * scale_count
  if within < 0 then
    within = within + scale_count
    octave = octave - 1
  end

  local note = self.root
    + 12 * (track.octave + octave + octave_variation)
    + self.scale_pcs[within + 1]
  while note < 0 do note = note + 12 end
  while note > 127 do note = note - 12 end

  local maximum_reach = note_magnitude > 0 and 1 + (note_magnitude * 11) // 100 or 0
  local low = -scale_count - (note_amount < 0 and maximum_reach or 0)
  local high = scale_count - 1 + (note_amount > 0 and maximum_reach or 0)
  local bar_height = 1 + ((degree - low) * 4) // math.max(high - low, 1)

  event.note = note
  event.degree = degree
  event.bar_height = clamp(bar_height, 1, 5)
  event.audible = not track.resting and not track.mute
  return event
end

local function is_origin(track)
  local mode = track.direction
  if mode == 1 then return track.pos == track.length - 1 end
  if mode == 7 then return track.phase == 0 end
  if mode == 9 or mode == 11 or mode == 12 or mode == 14 then
    return track.phase == 0
  end
  if mode == 3 or mode == 4 or mode == 8 or mode == 13 then return true end
  return track.pos == 0
end

function Core:_advance_position(index)
  local track = self.tracks[index]
  local length = track.length
  local mode = track.direction
  if track.pos >= length then track.pos = length - 1 end

  if track.pos < 0 then
    track.dir = 1
    track.phase = 0
    track.rot = 0
    track.pass = 0
    track.dwell = 0
    track.pool_pos = 0
    if mode == 7 then
      self:_build_shuffle(track, length, self:effective_seed(index), 0)
      track.pos = track.order[0] % length
    elseif mode == 12 then
      track.pos = (length - 1) // 2
    else
      track.pos = mode == 1 and length - 1 or 0
    end
    return
  end

  if mode == 0 then
    track.pos = (track.pos + 1) % length
  elseif mode == 1 then
    track.pos = (track.pos + length - 1) % length
  elseif mode == 2 then
    if length > 1 then
      if track.dir > 0 then
        if track.pos >= length - 1 then track.dir = -1 else track.pos = track.pos + 1 end
      else
        if track.pos <= 0 then track.dir = 1 else track.pos = track.pos - 1 end
      end
    end
  elseif mode == 5 then
    if length > 1 then
      if track.dir > 0 then
        if track.pos >= length - 1 then
          track.dir, track.pos = -1, track.pos - 1
        else
          track.pos = track.pos + 1
        end
      else
        if track.pos <= 0 then
          track.dir, track.pos = 1, track.pos + 1
        else
          track.pos = track.pos - 1
        end
      end
    end
  elseif mode == 3 then
    track.pos = (self:_next_rng() >> 16) % length
  elseif mode == 4 then
    local roll = (self:_next_rng() >> 16) % 100
    if roll < 50 then
      track.pos = (track.pos + 1) % length
    elseif roll >= 75 then
      track.pos = (track.pos + length - 1) % length
    end
  elseif mode == 6 then
    track.pos = (track.pos + 1) % length
    if track.pos == 0 and length > 1 then track.rot = (track.rot + 1) % length end
  elseif mode == 7 then
    track.phase = (track.phase + 1) % length
    track.pos = track.order[track.phase] % length
  elseif mode == 8 then
    if track.dwell == 0 then
      track.pool_len = 3 + ((self:_next_rng() >> 16) % 2)
      track.pool_start = (self:_next_rng() >> 16) % length
      track.dwell = track.pool_len * (2 + ((self:_next_rng() >> 16) % 3))
      track.pool_pos = 0
    end
    track.pos = (track.pool_start + track.pool_pos) % length
    track.pool_pos = (track.pool_pos + 1) % track.pool_len
    track.dwell = track.dwell - 1
  elseif mode == 9 then
    local period = length * 2
    track.phase = (track.phase + 1) % period
    local position = track.phase // 2
    track.pos = track.phase % 2 == 0 and position or (position + 2) % length
  elseif mode == 10 then
    local strength = 20 + Core.hash3(track.active_seed, 0x6e01, 0) % 41
    local key = u32((track.pass << 8) | track.pos)
    local roll = Core.hash3(track.active_seed, key, 0x6ea1) % 100
    if roll < strength and track.pos ~= 0 then
      track.pos = 0
    else
      track.pos = (track.pos + 1) % length
    end
  elseif mode == 11 then
    track.phase = (track.phase + 1) % length
    local phase = track.phase
    track.pos = phase % 2 == 0 and phase // 2 or length - 1 - phase // 2
  elseif mode == 12 then
    track.phase = (track.phase + 1) % length
    local phase = track.phase
    local distance = (phase + 1) // 2
    local offset = phase % 2 == 1 and distance or -distance
    track.pos = ((length - 1) + 2 * offset) // 2
  elseif mode == 13 then
    if length > 1 then
      local next_position
      repeat
        next_position = (self:_next_rng() >> 16) % length
      until next_position ~= track.pos
      track.pos = next_position
    end
  elseif mode == 14 then
    if length <= 1 then
      track.pos = 0
    else
      local period = (length - 1) * 2
      track.phase = (track.phase + 1) % period
      local phase = track.phase
      track.pos = phase % 2 == 0 and 0 or 1 + phase // 2
    end
  end
end

function Core:_apply_pass_boundary(index)
  local track = self.tracks[index]
  if not is_origin(track) then return end

  if track.pending_seed ~= nil then
    track.active_seed = track.pending_seed
    track.pending_seed = nil
    track.pass = 0
    track.resting = false
    for step = 0, Core.MAX_STEPS - 1 do track.epoch[step] = 0 end
    if track.direction == 7 then
      self:_build_shuffle(track, track.length, self:effective_seed(index), 0)
      track.pos = track.order[track.phase] % track.length
    end
    return
  end

  track.pass = (track.pass + 1) & 0xffff
  if track.direction == 7 then
    self:_build_shuffle(track, track.length, self:effective_seed(index), track.pass)
    track.pos = track.order[track.phase] % track.length
  end

  if track.evolve > 0 then
    for step = 0, track.length - 1 do
      local key = u32((track.pass << 8) | step)
      if (Core.hash3(track.active_seed, key, 0xe01f) % 100) < track.evolve then
        track.epoch[step] = (track.epoch[step] + 1) & 0xff
      end
    end
  end

  track.resting = track.breathe > 0
    and (Core.hash3(track.active_seed, track.pass, 0xb4ea) % 100) < track.breathe
end

function Core:advance(index)
  index = bounded_integer(index, 1, Core.NUM_TRACKS, "track")
  local track = self.tracks[index]
  if self.freeze then return track.last_event, "frozen" end

  self:_advance_position(index)
  self:_apply_pass_boundary(index)
  track.eos_count = track.eos_count + 1
  local eos = false
  if track.eos_count >= track.length then
    track.eos_count = 0
    eos = true
  end

  local event = self:evaluate(index, track.pos)
  event.eos = eos
  track.last_event = event
  return event
end

function Core:advance_all()
  if self.freeze then return nil, "frozen" end
  local events = {}
  for index = 1, Core.NUM_TRACKS do events[index] = self:advance(index) end
  return events
end

function Core:reset()
  for _, track in ipairs(self.tracks) do
    track.pos = -1
    track.eos_count = 0
  end
end

function Core:reseed_all(base)
  base = bounded_integer(base, 0, 999, "reseed base")
  local seeds = {}
  for index = 1, Core.NUM_TRACKS do
    local seed = Core.hash3(base, index - 1, 0x5eed) % 1000
    self:set_track(index, "seed", seed)
    seeds[index] = seed
  end
  return seeds
end

return Core
