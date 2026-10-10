-- Norns clock adapter for the pure Shoal core.
-- The planning half is pure Lua and can be tested without norns. The runtime
-- half expects the standard norns clock API, injected as the third argument.

local Clock = {}
Clock.__index = Clock

function Clock.new(core, on_step, runtime, track_count, hooks)
  assert(core and on_step and runtime, "core, callback and clock runtime required")
  track_count = track_count or core.NUM_TRACKS
  assert(track_count >= 1 and track_count <= core.NUM_TRACKS,
    "track count must fit the core")
  return setmetatable({
    core = core,
    on_step = on_step,
    runtime = runtime,
    track_count = track_count,
    tick_count = 0,
    reset_pending = true,
    running = false,
    coroutine_id = nil,
    next_beat = {},
    periods = {},
    hooks = hooks or {},
  }, Clock)
end

function Clock:reset()
  self.core:reset()
  self.tick_count = 0
  self.reset_pending = true
  self.next_beat = {}
  self.periods = {}
end

-- A step k occurs at beat k * den / num. Choose only steps in the current
-- [tick, tick + 1) interval, preserving phase across fractional rates.
-- Offsets are beats after the master quarter-note tick.
function Clock:plan_tick()
  if self.core.freeze then
    self.tick_count = self.tick_count + 1
    return {}
  end
  if self.reset_pending then
    self.tick_count = 0
    self.next_beat = {}
    self.periods = {}
  end

  local tick = self.tick_count
  if self.hooks.before_tick then self.hooks.before_tick(tick) end

  local events = {}
  for track = 1, self.track_count do
    local num, den = self.core.rate_ratio(self.core.tracks[track].rate)
    local period = den / num
    local next_beat = self.next_beat[track] or tick
    local old_period = self.periods[track]
    if next_beat < tick - 1e-9 then next_beat = tick end
    if old_period and old_period ~= period then
      -- Preserve the fraction remaining until the next event when Rate moves.
      next_beat = tick + (next_beat - tick) * period / old_period
    end
    while next_beat < tick + 1 - 1e-9 do
      local offset = math.max(0, next_beat - tick)
      events[#events + 1] = {
        track = track,
        offset = offset,
        step_beats = period,
        beat = tick + offset,
      }
      next_beat = next_beat + period
    end
    self.next_beat[track] = next_beat
    self.periods[track] = period
  end

  table.sort(events, function(a, b)
    if a.offset == b.offset then return a.track < b.track end
    return a.offset < b.offset
  end)
  self.tick_count = self.tick_count + 1
  self.reset_pending = false
  return events
end

function Clock:fire(item)
  if self.core.freeze then return end
  if self.hooks.before_step then self.hooks.before_step(item.track, item.beat) end
  local event = self.core:advance(item.track)
  self.on_step(event, item.step_beats)
  if self.hooks.after_step then self.hooks.after_step(item.track, event, item.beat) end
end

function Clock:start()
  if self.running then return end
  self.running = true
  self.coroutine_id = self.runtime.run(function()
    while self.running do
      self.runtime.sync(1)
      if not self.running then break end
      local plan = self:plan_tick()
      local previous_offset = 0
      local beat_seconds = self.runtime.get_beat_sec()
      for _, item in ipairs(plan) do
        if not self.running then break end
        local wait_beats = item.offset - previous_offset
        if wait_beats > 0 then self.runtime.sleep(wait_beats * beat_seconds) end
        if not self.running then break end
        self:fire(item)
        previous_offset = item.offset
      end
    end
  end)
end

function Clock:stop()
  self.running = false
  if self.coroutine_id then
    self.runtime.cancel(self.coroutine_id)
    self.coroutine_id = nil
  end
end

return Clock
