-- Per-track output router. Each adapter receives the same MIDI note numbers.
-- Notes are closed on rests, routing changes, stop, and script cleanup.

local Outputs = {}
Outputs.__index = Outputs

local function midi_to_hz(note)
  return 440 * (2 ^ ((note - 69) / 12))
end

function Outputs.new(devices, track_count)
  track_count = track_count or 8
  assert(track_count >= 1 and track_count <= 8, "track count must be 1..8")
  local self = setmetatable({
    devices = devices,
    track_count = track_count,
    routes = {},
    held = {},
    release_ids = {},
    midi_port = 1,
  }, Outputs)
  for track = 1, track_count do
    self.routes[track] = { kind = track == 1 and "polyperc" or "off", channel = track }
  end
  return self
end

function Outputs:set_midi_port(port)
  assert(port >= 1 and port <= 16, "MIDI port must be 1..16")
  self:panic()
  self.midi_port = port
  self.midi_device = self.devices.midi.connect(port)
end

function Outputs:set_route(track, kind, channel)
  self:stop_note(track)
  self.routes[track] = { kind = kind, channel = channel or track }
end

function Outputs:_cancel_release(track)
  local id = self.release_ids[track]
  if id then
    self.devices.clock.cancel(id)
    self.release_ids[track] = nil
  end
end

function Outputs:stop_note(track)
  self:_cancel_release(track)
  local held = self.held[track]
  if not held then return end

  if held.kind == "midi" then
    held.device:note_off(held.note, 0, held.channel)
  elseif held.kind == "nb" then
    held.player:note_off(held.note)
  elseif held.kind == "crow" then
    self.devices.crow.output[held.gate].volts = 0
  end
  self.held[track] = nil
end

function Outputs:panic()
  for track = 1, self.track_count do self:stop_note(track) end
end

function Outputs:hold_notes()
  for track = 1, self.track_count do self:_cancel_release(track) end
end

function Outputs:_start_note(track, note, velocity)
  local route = self.routes[track]
  local kind = route.kind
  if kind == "off" then return false end

  if kind == "polyperc" then
    self.devices.engine.hz(midi_to_hz(note))
    return false -- PolyPerc has a built-in percussive release.
  elseif kind == "midi" then
    local device = self.midi_device
    if not device then return false end
    device:note_on(note, velocity, route.channel)
    self.held[track] = {
      kind = "midi", device = device, note = note, channel = route.channel,
    }
  elseif kind == "nb" then
    local player = self.devices.nb_player and self.devices.nb_player(track)
    if not player then return false end
    player:note_on(note, velocity / 127)
    self.held[track] = { kind = "nb", player = player, note = note }
  elseif kind == "crow12" or kind == "crow34" then
    local crow = self.devices.crow
    if not crow or not crow.output then return false end
    -- A crow pitch/gate pair is monophonic even if multiple tracks route to it.
    for other = 1, self.track_count do
      if other ~= track and self.held[other]
          and self.routes[other].kind == kind then
        self:stop_note(other)
      end
    end
    local pitch = kind == "crow12" and 1 or 3
    local gate = pitch + 1
    crow.output[pitch].volts = (note - 48) / 12
    crow.output[gate].volts = 5
    self.held[track] = { kind = "crow", gate = gate, note = note }
  else
    error("unknown output kind: " .. tostring(kind))
  end
  return true
end

function Outputs:step(event, step_beats, gate_percent, velocity)
  local track = event.track
  self:stop_note(track)
  if not event.audible then return end

  local needs_release = self:_start_note(track, event.note, velocity)
  if not needs_release then return end
  local beats = event.tie and step_beats * 1.5
    or step_beats * gate_percent / 100
  local seconds = math.max(0.001, beats * self.devices.clock.get_beat_sec())
  self.release_ids[track] = self.devices.clock.run(function()
    self.devices.clock.sleep(seconds)
    self.release_ids[track] = nil
    self:stop_note(track)
  end)
end

return Outputs
