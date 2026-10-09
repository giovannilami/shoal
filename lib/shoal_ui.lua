-- Shoal performance display for the 128 x 64 norns screen.
-- The overview always shows every step of each track. The bright column is
-- the last position actually visited by Core:advance, including silent steps.

local Pitch = include("shoal-norns/lib/shoal_pitch")
local Font = include("shoal-norns/lib/shoal_font")
local UI = {}

-- The header names the selected track, freeing the left edge for all 64
-- distinct pattern columns and a wider, clearly separated value panel.
local PLOT_X = 2
local PLOT_WIDTH = 64
local VALUES_X = 68
local VALUE_GAP = 3
local preview_cache = {}
local particle_width_cache = {}

local SHORT_DIRECTIONS = {
  [0] = "FWD", "REV", "PEND", "RAND", "DRNK", "PONG", "TIDE",
  "SHUF", "POOL", "STRD", "GRAV", "CONV", "DIV", "SKIT", "ANCH",
}

-- 64 integer columns guarantee a distinct position even at Length 64.
function UI.step_geometry(length, step0)
  assert(length >= 1 and length <= 64 and step0 >= 0 and step0 < length)
  local first = PLOT_X + (step0 * PLOT_WIDTH) // length
  local after = PLOT_X + ((step0 + 1) * PLOT_WIDTH) // length
  return first, after - first
end

local function preview_key(core, index, window)
  local track = core.tracks[index]
  local source_index = core:effective_track(index)
  local source = core.tracks[source_index]
  return table.concat({
    track.length, track.chance, track.note, track.oct, track.octave,
    track.transpose, track.shift, track.direction, track.rot, track.pass,
    source_index, source.active_seed, source.pass, core.root, core.scale,
    core.weight, window.low, window.high, window.spread,
  }, ":")
end

local function preview(core, index, window)
  local key = preview_key(core, index, window)
  local cached = preview_cache[index]
  if cached and cached.key == key then return cached end

  local track = core.tracks[index]
  local result = { key = key, notes = {} }
  for step0 = 0, track.length - 1 do
    local event = core:evaluate(index, step0)
    -- A mute or Breathe dims the row; neither erases the underlying pattern.
    if event.fires then
      local note = Pitch.map(event.note, core.root, window.low,
        window.high, window.spread, core.scale_pcs)
      result.notes[step0 + 1] = note
      result.low = result.low and math.min(result.low, note) or note
      result.high = result.high and math.max(result.high, note) or note
    end
  end
  preview_cache[index] = result
  return result
end

function UI.position_label(track)
  local event = track.last_event
  if event and event.step0 < track.length then
    return string.format("%02d/%02d", event.step, track.length)
  end
  return string.format("--/%02d", track.length)
end

function UI.overview_values(core, index)
  local track = core.tracks[index]
  return {
    core.RATES[track.rate].name,
    tostring(track.length),
    "%" .. track.chance,
    "E" .. track.evolve,
  }
end

function UI.overview_header(core, selected, modifier, short_direction, separator)
  local selected_track = core.tracks[selected]
  separator = separator or "  "
  if modifier then
    return string.format("T%d  E2 CHANCE  E3 EVOLVE", selected)
  end
  local seed = string.format("S%03d%s", selected_track.seed,
    selected_track.pending_seed and "*" or "")
  local parts = {
    "T" .. selected,
    UI.position_label(selected_track),
    seed,
  }
  if selected_track.source > 0 and selected_track.source ~= selected then
    parts[#parts + 1] = "F" .. selected_track.source
  end
  parts[#parts + 1] = short_direction
    and SHORT_DIRECTIONS[selected_track.direction]
    or string.upper(core.DIRECTIONS[selected_track.direction])
  return table.concat(parts, separator)
end

local function particle_width(screen, value)
  local cached = particle_width_cache[value]
  if cached then return cached end
  local width = screen.text_extents(value)
  width = type(width) == "number" and math.ceil(width) or #value * 4
  particle_width_cache[value] = width
  return width
end

local function draw_transport(screen, running, frozen)
  screen.level(15)
  if not running then
    screen.rect(1, 3, 6, 6)
  elseif frozen then
    screen.rect(1, 2, 2, 7)
    screen.rect(5, 2, 2, 7)
  else
    for row = 0, 6 do
      local width = row <= 3 and row + 1 or 7 - row
      screen.rect(1, 2 + row, width, 1)
    end
  end
  screen.fill()
end

local function draw_row_values(screen, core, index, y, active, dim, modifier)
  local values = UI.overview_values(core, index)
  local widths = {}
  local total = VALUE_GAP * 3
  for field = 1, 4 do
    widths[field] = particle_width(screen, values[field])
    total = total + widths[field]
  end
  local compact = total > 128 - VALUES_X
  if compact then
    total = VALUE_GAP * 3
    for field = 1, 4 do
      widths[field] = Font.compact_width(values[field])
      total = total + widths[field]
    end
  end
  assert(total <= 128 - VALUES_X, "overview values exceed right column")
  local x = 128 - total
  for field = 1, 4 do
    local focused = modifier and field >= 3 or not modifier and field <= 2
    screen.level(dim and 3 or active and (focused and 15 or 9) or 7)
    if compact then
      Font.compact_left(screen, x, y - 1, values[field])
    else
      screen.move(x, y)
      screen.text(values[field])
    end
    x = x + widths[field] + VALUE_GAP
  end
end

local function draw_overview(screen, core, running, selected, track_count, windows, state)
  screen.font_face(68) -- Particle, chosen for dense norns screens.
  screen.font_size(8)
  screen.aa(0)

  draw_transport(screen, running, core.freeze)
  local page_label = "1/4"
  local header = state.feedback
    or UI.overview_header(core, selected, state.modifier)
  local available = 127 - particle_width(screen, page_label) - 2 - 11
  if particle_width(screen, header) > available then
    header = UI.overview_header(core, selected, state.modifier, true)
  end
  if particle_width(screen, header) > available then
    header = UI.overview_header(core, selected, state.modifier, true, " ")
  end
  screen.level(15)
  screen.move(11, 8)
  screen.text(header)
  screen.move(127, 8)
  screen.text_right(page_label)

  for index = 1, track_count do
    local track = core.tracks[index]
    local y = 20 + (index - 1) * 14
    local active = index == selected
    local dim = track.mute or track.resting
    local data = preview(core, index, windows[index])

    if track.mute or track.pending_seed or track.resting then
      screen.level(dim and 3 or active and 15 or 7)
      screen.rect(0, track.mute and y - 5 or track.pending_seed and y - 6
        or y - 2, 1, track.mute and 5 or track.pending_seed and 1 or 2)
      screen.fill()
    end

    for step0 = 0, track.length - 1 do
      local x, cell_width = UI.step_geometry(track.length, step0)
      local note = data.notes[step0 + 1]
      local height = note and (data.high > data.low
        and 1 + math.floor((note - data.low) * 5 / (data.high - data.low))
        or 3) or 1
      local width = math.min(4, math.max(1, cell_width - 1))
      local bar_x = x + (cell_width - width) // 2
      screen.level(note and (dim and 2 or active and 11 or 6) or 2)
      screen.rect(bar_x, y - height + 1, width, height)
      screen.fill()
    end

    -- Draw over the pattern so the playhead remains visible at 33-64 steps.
    if track.last_event and track.last_event.step0 < track.length then
      local x, cell_width = UI.step_geometry(track.length, track.last_event.step0)
      screen.level(active and 15 or 11)
      if cell_width >= 3 then
        local cursor_width = math.min(6, cell_width)
        screen.rect(x + (cell_width - cursor_width) // 2,
          y - 7, cursor_width, 8)
        screen.stroke()
      else
        screen.rect(x, y - 8, 1, 9)
        screen.fill()
      end
    end

    draw_row_values(screen, core, index, y, active, dim, state.modifier)
  end
end

local function draw_editor(screen, core, running, selected, state)
  local page = state.page
  local fields = state.fields
  local cursor = state.cursor
  local start = math.max(1, math.min(cursor - 1, #fields - 3))

  screen.level(15)
  Font.left(screen, 1, 8, core.freeze and "FRZ" or running and "RUN" or "STOP")
  Font.left(screen, 35, 8,
    state.title == "" and "T" .. selected or state.title .. " T" .. selected)
  Font.right(screen, 127, 8, page .. "/4")

  screen.level(4)
  Font.left(screen, 1, 18, "E1 TRK E2 PICK E3 EDIT")

  for row = 0, 3 do
    local field_index = start + row
    local field = fields[field_index]
    if field then
      local y = 29 + row * 11
      local active = field_index == cursor
      screen.level(active and 15 or 6)
      if active then Font.left(screen, 1, y, ">") end
      Font.left(screen, 11, y, field.label)
      local value_left = 11 + Font.width(field.label) + 4
      Font.right(screen, 127, y, field.value, 128 - value_left)
    end
  end
end

function UI.draw(screen, core, running, selected, track_count, windows, state)
  screen.clear()
  screen.aa(0)
  if not state or state.page == 1 then
    draw_overview(screen, core, running, selected, track_count, windows, state or {})
  else
    draw_editor(screen, core, running, selected, state)
  end
  screen.update()
end

return UI
