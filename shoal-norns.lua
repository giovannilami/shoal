-- shoal-norns v0.1.0
-- 4 generative tracks
-- port: @giovannilami
-- Shoal: Ormer Modular
-- K2 play / stop
-- K3 new seed
-- E1 track  E2 rate
-- E3 length

local Core = include("shoal-norns/lib/shoal_core")
local ShoalClock = include("shoal-norns/lib/shoal_clock")
local Outputs = include("shoal-norns/lib/shoal_outputs")
local Pitch = include("shoal-norns/lib/shoal_pitch")
local UI = include("shoal-norns/lib/shoal_ui")
local GridUI = include("shoal-norns/lib/shoal_grid")
-- Prefer the same n.b. instance used by nbout when its mod is installed.
-- A standalone dust/code/nb installation remains supported as a fallback.
local nb_available, nb = pcall(require, "nbout/lib/nb/lib/nb")
if not nb_available then nb_available, nb = pcall(require, "nb/lib/nb") end
-- Some optional note-player libraries alter engine.name while loading. Set the
-- script's own engine only after all top-level includes and requires complete.
engine.name = "PolyPerc"
print("shoal-norns: requested engine " .. engine.name)
local TRACKS = 4

local core
local sequencer
local outputs
local selected_track = 1
local redraw_timer
local redraw_pending = false
local grid_ui
local grid_feedback
local grid_feedback_ticks = 0
local key1_down = false
local page = 1
local field_cursor = { [2] = 1, [3] = 1, [4] = 1 }
local pitch_windows = {}
for track = 1, TRACKS do
  pitch_windows[track] = { low = 0, high = 127, spread = 100 }
end

local routes = { "off", "polyperc" }
local route_names = { "Off", "PolyPerc" }
if nb_available then
  routes[#routes + 1] = "nb"
  route_names[#route_names + 1] = "n.b."
end
for _, entry in ipairs({ { "midi", "MIDI" }, { "crow12", "crow 1/2" },
    { "crow34", "crow 3/4" } }) do
  routes[#routes + 1] = entry[1]
  route_names[#route_names + 1] = entry[2]
end

local function track_id(track, name)
  return string.format("shoal_t%d_%s", track, name)
end

-- Overview + three short edit pages. The norns parameter menu remains the
-- complete editor (including n.b. player-specific sound parameters).
local edit_pages = {
  [2] = { title = "", fields = {
    { "seed", "SEED" }, { "direction", "DIRECTION" },
    { "shift", "SHIFT" }, { "source", "FOLLOW" },
    { "breathe", "BREATHE" },
    { "gate", "GATE" }, { "tie", "TIE" }, { "mute", "MUTE" },
  } },
  [3] = { title = "PITCH", fields = {
    { "note", "NOTE +/-" }, { "oct", "OCT +/-" },
    { "octave", "OCTAVE" }, { "transpose", "TRANSPOSE" },
    { "min_note", "MIN NOTE" }, { "max_note", "MAX NOTE" },
    { "spread", "SPREAD" },
  } },
  [4] = { title = "GLOBAL", fields = {
    { "shoal_scale", "SCALE", true },
    { "shoal_root", "ROOT", true },
    { "shoal_weight", "WEIGHT", true },
    { "shoal_freeze", "FREEZE", true },
    { "route", "OUTPUT" }, { "channel", "MIDI CH" },
    { "shoal_midi_port", "MIDI PORT", true },
  } },
}

local function field_id(field)
  return field[3] and field[1] or track_id(selected_track, field[1])
end

local function editor_state()
  if page == 1 then
    return { page = 1, modifier = key1_down, feedback = grid_feedback }
  end
  local definition = edit_pages[page]
  local fields = {}
  for _, field in ipairs(definition.fields) do
    local id = field_id(field)
    fields[#fields + 1] = {
      label = field[2],
      value = params.string and params:string(id) or tostring(params:get(id)),
    }
  end
  return { page = page, title = definition.title,
    fields = fields, cursor = field_cursor[page] }
end

local function show_grid_feedback(message)
  grid_feedback = message
  grid_feedback_ticks = 40 -- two seconds at the existing 20 Hz UI refresh
  redraw()
end

if grid then
  function grid.add(device)
    if grid_ui then grid_ui:connect(device.port) end
  end

  function grid.remove(device)
    if grid_ui then grid_ui:disconnect(device) end
  end
end

local function set_track_param(track, name, value)
  core:set_track(track, name, value)
end

local function add_track_number(track, name, label, low, high, default)
  local id = track_id(track, name)
  params:add_number(id, label, low, high, default)
  params:set_action(id, function(value)
    set_track_param(track, name, value)
    redraw()
  end)
end

local function add_track_option(track, name, label, options, default, convert)
  local id = track_id(track, name)
  params:add_option(id, label, options, default)
  params:set_action(id, function(value)
    set_track_param(track, name, convert(value))
    redraw()
  end)
end

local function setup_params()
  params:add_separator("Shoal")
  params:add_option("shoal_run", "Run", { "Off", "On" }, 2)
  params:set_action("shoal_run", function(value)
    if value == 2 then sequencer:start() else sequencer:stop(); outputs:panic() end
    redraw()
  end)

  params:add_option("shoal_freeze", "Freeze", { "Off", "On" }, 1)
  params:set_action("shoal_freeze", function(value)
    core:set_global("freeze", value == 2)
    if value == 2 then outputs:hold_notes() end
    redraw()
  end)

  local scales = {}
  for index = 0, 12 do scales[#scales + 1] = Core.SCALES[index].name end
  params:add_option("shoal_scale", "Scale", scales, 1)
  params:set_action("shoal_scale", function(value)
    core:set_global("scale", value - 1)
    redraw()
  end)

  params:add_number("shoal_root", "Root MIDI note", 0, 127, 48)
  params:set_action("shoal_root", function(value)
    core:set_global("root", value)
    redraw()
  end)
  params:add_number("shoal_weight", "Weight", 0, 100, 0)
  params:set_action("shoal_weight", function(value)
    core:set_global("weight", value)
    redraw()
  end)
  local midi_ports = {}
  for port = 1, 16 do midi_ports[port] = tostring(port) end
  params:add_option("shoal_midi_port", "MIDI port", midi_ports, 1)
  params:set_action("shoal_midi_port", function(value)
    outputs:set_midi_port(value)
  end)
  params:add_trigger("shoal_reset", "Reset playheads")
  params:set_action("shoal_reset", function()
    outputs:panic()
    sequencer:reset()
    redraw()
  end)
  params:add_trigger("shoal_reseed_all", "Reseed all")
  params:set_action("shoal_reseed_all", function()
    local base = math.random(0, 999)
    for track = 1, TRACKS do
      local seed = Core.hash3(base, track - 1, 0x5eed) % 1000
      params:set(track_id(track, "seed"), seed)
    end
    redraw()
  end)

  local rates = {}
  -- Keep the complete 29-rate table in the reference core, but expose only
  -- /32 ... x32 on norns. Option index now equals the core rate index.
  for index = 1, 27 do rates[#rates + 1] = Core.RATES[index].name end
  local directions = {}
  for index = 0, 14 do directions[#directions + 1] = Core.DIRECTIONS[index] end
  local sources = { "Off" }
  for index = 1, TRACKS do sources[#sources + 1] = "Track " .. index end

  for track = 1, TRACKS do
    -- Includes n.b.'s hidden string parameter when that library is present.
    params:add_group("shoal_group_t" .. track, "TRACK " .. track,
      nb_available and 23 or 21)
    local route_id = track_id(track, "route")
    params:add_option(route_id, "Output", route_names, track == 1 and 2 or 1)
    params:set_action(route_id, function(value)
      outputs:set_route(track, routes[value], params:get(track_id(track, "channel")))
      redraw()
    end)
    local channel_id = track_id(track, "channel")
    params:add_number(channel_id, "MIDI channel", 1, 16, track)
    params:set_action(channel_id, function(value)
      outputs:set_route(track, routes[params:get(route_id)], value)
    end)

    add_track_number(track, "length", "Length", 1, 64, 16)
    add_track_option(track, "rate", "Rate", rates, 13,
      function(value) return value end)
    add_track_option(track, "direction", "Direction", directions, 1,
      function(value) return value - 1 end)
    add_track_number(track, "chance", "Chance", 0, 100, 100)
    add_track_number(track, "breathe", "Breathe", 0, 100, 0)
    add_track_number(track, "note", "Note variation", -100, 100, 0)
    add_track_number(track, "oct", "Oct variation", -100, 100, 0)
    add_track_number(track, "evolve", "Evolve", 0, 100, 0)
    add_track_number(track, "gate", "Gate length", 5, 95, 50)
    add_track_number(track, "tie", "Tie", 0, 100, 0)
    add_track_number(track, "octave", "Octave", -3, 3, 0)
    add_track_number(track, "transpose", "Transpose", -7, 7, 0)
    add_track_number(track, "shift", "Shift", -63, 63, 0)
    add_track_option(track, "source", "Sample source", sources, 1,
      function(value) return value - 1 end)
    local mute_id = track_id(track, "mute")
    params:add_option(mute_id, "Mute", { "Off", "On" }, 1)
    params:set_action(mute_id, function(value)
      set_track_param(track, "mute", value == 2)
      if value == 2 then outputs:stop_note(track) end
      redraw()
    end)
    add_track_number(track, "seed", "Seed", 0, 999, 1 + (track - 1) * 97)
    local min_id = track_id(track, "min_note")
    local max_id = track_id(track, "max_note")
    params:add_number(min_id, "Min note", 0, 127, 0)
    params:set_action(min_id, function(value)
      pitch_windows[track].low = value
      if value > params:get(max_id) then params:set(max_id, value) end
      redraw()
    end)
    params:add_number(max_id, "Max note", 0, 127, 127)
    params:set_action(max_id, function(value)
      pitch_windows[track].high = value
      if value < params:get(min_id) then params:set(min_id, value) end
      redraw()
    end)
    local spread_id = track_id(track, "spread")
    params:add_number(spread_id, "Spread %", 0, 200, 100)
    params:set_action(spread_id, function(value)
      pitch_windows[track].spread = value
      redraw()
    end)
    if nb_available then nb:add_param(track_id(track, "nb"), "n.b. voice") end
  end
  if nb_available then
    params:add_separator("shoal_nb_sound", "N.B. SOUND")
    nb:add_player_params()
  end
end

function init()
  core = Core.new()
  if nb_available then nb:init() end

  outputs = Outputs.new({
    engine = engine,
    midi = midi,
    crow = crow,
    clock = clock,
    nb_player = nb_available and function(track)
      local parameter = params:lookup_param(track_id(track, "nb"))
      return parameter and parameter:get_player()
    end or nil,
  }, TRACKS)
  outputs:set_midi_port(1)

  sequencer = ShoalClock.new(core, function(event, step_beats)
    local track = core.tracks[event.track]
    local window = pitch_windows[event.track]
    local routed = Pitch.event(event, core.root, window.low, window.high,
      window.spread, core.scale_pcs)
    outputs:step(routed, step_beats, track.gate, 100)
    -- Every clocked position, including a rest or muted step, moves the cursor.
    redraw_pending = true
  end, clock, TRACKS)

  setup_params()
  if grid and grid.connect then
    grid_ui = GridUI.new({
      params = params,
      grid = grid,
      track_count = TRACKS,
      selected_track = function() return selected_track end,
      select_track = function(track)
        selected_track = track
        redraw()
      end,
      feedback = show_grid_feedback,
    })
    grid_ui:connect()
  end
  engine.amp(0.5)
  engine.release(0.2)
  redraw_timer = metro.init()
  redraw_timer.time = 0.05
  redraw_timer.event = function()
    if grid_feedback_ticks > 0 then
      grid_feedback_ticks = grid_feedback_ticks - 1
      if grid_feedback_ticks == 0 then
        grid_feedback = nil
        redraw_pending = true
      end
    end
    if redraw_pending then redraw(true) end
    if grid_ui then grid_ui:redraw_if_dirty() end
  end
  redraw_timer:start()
  sequencer:start()
  redraw()
end

function key(number, down)
  if number == 1 then
    key1_down = down == 1
    redraw()
    return
  end
  if down ~= 1 then return end
  if key1_down and (number == 2 or number == 3) then
    page = ((page - 1 + (number == 3 and 1 or -1)) % 4) + 1
    redraw()
    return
  end
  if number == 2 then
    params:set("shoal_run", params:get("shoal_run") == 2 and 1 or 2)
  elseif number == 3 then
    local id = track_id(selected_track, "seed")
    local old = params:get(id)
    local next_seed = math.random(0, 998)
    if next_seed >= old then next_seed = next_seed + 1 end
    params:set(id, next_seed)
  end
end

function enc(number, delta)
  if number == 1 then
    selected_track = math.max(1, math.min(TRACKS, selected_track + delta))
  elseif number == 2 then
    if page == 1 then
      params:delta(track_id(selected_track, key1_down and "chance" or "rate"), delta)
    else
      field_cursor[page] = math.max(1, math.min(#edit_pages[page].fields,
        field_cursor[page] + delta))
    end
  elseif number == 3 then
    if page == 1 then
      params:delta(track_id(selected_track, key1_down and "evolve" or "length"), delta)
    else
      params:delta(field_id(edit_pages[page].fields[field_cursor[page]]), delta)
    end
  end
  redraw()
end

function redraw(from_clock)
  if not core then return end
  UI.draw(screen, core, sequencer and sequencer.running, selected_track,
    TRACKS, pitch_windows, editor_state())
  if grid_ui and not from_clock then grid_ui:mark_dirty() end
  redraw_pending = false
end

function cleanup()
  if sequencer then sequencer:stop() end
  if outputs then outputs:panic() end
  if redraw_timer then redraw_timer:stop() end
  if grid_ui then grid_ui:clear() end
end
