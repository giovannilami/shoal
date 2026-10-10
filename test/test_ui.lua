local root = arg[0]:match("^(.*)/test/test_ui%.lua$") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local Core = require("shoal_core")
include = function(path)
  return dofile(root .. "/" .. path:match("(lib/.+)$") .. ".lua")
end
local UI = include("shoal-norns/lib/shoal_ui")
local checks = 0

local function equal(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  checks = checks + 1
end

for length = 1, 64 do
  local previous = 1
  for step0 = 0, length - 1 do
    local x, width = UI.step_geometry(length, step0)
    equal(x > previous, true, "unique column " .. length .. "/" .. step0)
    equal(width >= 1, true, "positive column width " .. length .. "/" .. step0)
    previous = x
  end
  local x, width = UI.step_geometry(length, length - 1)
  equal(x + width, 66, "final boundary " .. length)
end

local calls = {}
local level, path, antialias, face, size, x, y
local screen = {
  clear = function()
    calls = {}
    path, antialias, face, size = {}, nil, nil, nil
  end,
  level = function(value) level = value end,
  font_face = function(value) face = value end,
  font_size = function(value) size = value end,
  move = function(px, py) x, y = px, py end,
  text = function(value)
    calls[#calls + 1] = { kind = "text", value = value, x = x,
      y = y, width = #value * 4 }
  end,
  text_right = function(value)
    calls[#calls + 1] = { kind = "text_right", value = value, x = x, y = y }
  end,
  text_extents = function(value) return #value * 4 end,
  rect = function(rx, ry, rw, rh)
    assert(rx >= 0 and ry >= 0 and rw > 0 and rh > 0
      and rx + rw <= 128 and ry + rh <= 64,
      "screen rectangle outside the 128 x 64 display")
    path[#path + 1] = { x = rx, y = ry, w = rw, h = rh }
  end,
  fill = function()
    calls[#calls + 1] = { kind = "fill", rects = path, level = level }
    path = {}
  end,
  stroke = function()
    calls[#calls + 1] = { kind = "stroke", rects = path, level = level }
    path = {}
  end,
  aa = function(value) antialias = value end,
  update = function() end,
}

local core = Core.new()
core:set_track(1, "length", 64)
local windows = {}
for i = 1, 4 do windows[i] = { low = 0, high = 127, spread = 100 } end

local function draw()
  UI.draw(screen, core, true, 1, 4, windows, { page = 1 })
end

local function marker_x()
  for _, call in ipairs(calls) do
    if call.kind == "fill" and #call.rects == 1 then
      local rect = call.rects[1]
      if rect.y == 12 and rect.h == 9 then return rect.x end
    end
  end
end

local function has_text(value)
  for _, call in ipairs(calls) do
    if call.kind == "text" and call.value == value then return true end
  end
  return false
end

local function ink_in_region(left, top, right, bottom)
  for _, call in ipairs(calls) do
    if call.kind == "fill" then
      for _, rect in ipairs(call.rects) do
        if rect.x <= right and rect.x + rect.w - 1 >= left
          and rect.y <= bottom and rect.y + rect.h - 1 >= top then
          return true
        end
      end
    end
  end
  return false
end

core:advance(1)
draw()
equal(antialias, 0, "overview disables anti-aliasing")
equal(face, 68, "overview uses Particle")
equal(size, 8, "Particle renders at its preferred size")
equal(marker_x(), 2, "64-step playhead begins at first cell")
equal(UI.position_label(core.tracks[1]), "01/64", "header reports actual step")
equal(has_text("T1  01/64  S:1  FORWARDS"), true,
  "selected track's position, seed and direction appear in header")
core:set_track(1, "seed", 999, true)
equal(UI.overview_header(core, 1, false):find("S:999", 1, true) ~= nil,
  true, "maximum seed is labelled without an apparent thousands digit")
core:set_track(1, "seed", 1, true)
UI.draw(screen, core, true, 1, 4, windows,
  { page = 1, feedback = "T1 CHANCE 67%" })
equal(has_text("T1 CHANCE 67%"), true,
  "Grid edits briefly show their exact value on norns overview")
draw()
local values = UI.overview_values(core, 1)
equal(values[1], "x1", "first overview value is Rate")
equal(values[2], "64", "second overview value is Length")
equal(values[3], "%100", "third overview value is Chance")
equal(values[4], "E0", "fourth overview value is Evolve")
local row_text = {}
for _, call in ipairs(calls) do
  if call.kind == "text" and call.y == 20 and call.x >= 68 then
    row_text[#row_text + 1] = call
  end
end
equal(#row_text, 4, "Particle draws all four values on the track row")
for field = 1, 4 do
  equal(row_text[field].value, values[field], "overview value order " .. field)
  equal(row_text[field].x >= 68 and row_text[field].x + row_text[field].width <= 128,
    true, "overview value stays within right panel " .. field)
  if field > 1 then
    equal(row_text[field].x - row_text[field - 1].x
      - row_text[field - 1].width >= 3,
      true, "overview values have visible gaps " .. field)
  end
end
local bars = 0
for _, call in ipairs(calls) do
  if call.kind == "fill" and #call.rects == 1 then
    local rect = call.rects[1]
    if rect.x >= 2 and rect.x < 66
      and rect.y >= 15 and rect.y <= 20 then
      bars = bars + 1
    end
  end
end
equal(bars, 64, "all 64 step bars drawn in selected row")

equal(#calls[1].rects, 7, "running transport is a play triangle")
UI.draw(screen, core, false, 1, 4, windows, { page = 1 })
equal(#calls[1].rects, 1, "stopped transport is a square")
equal(calls[1].rects[1].w, 6, "stop square has visible width")
core:set_global("freeze", true)
UI.draw(screen, core, true, 1, 4, windows, { page = 1 })
equal(#calls[1].rects, 2, "frozen transport is two pause bars")
UI.draw(screen, core, false, 1, 4, windows, { page = 1 })
equal(#calls[1].rects, 1, "stop remains visible when frozen")
core:set_global("freeze", false)

core:advance(1)
draw()
equal(marker_x(), 3, "playhead follows second clock event")
equal(UI.position_label(core.tracks[1]), "02/64", "header follows second clock event")

core:set_track(1, "direction", "reverse")
core:reset()
core:advance(1)
draw()
equal(marker_x(), 65, "reverse starts on last actual position")
equal(UI.position_label(core.tracks[1]), "64/64", "reverse position shown numerically")

core:set_track(1, "direction", "forwards")
core:set_track(1, "chance", 0)
core:reset()
local rest = core:advance(1)
equal(rest.fires, false, "test event is silent")
draw()
equal(marker_x(), 2, "playhead still follows silent step")

core:set_track(1, "source", 2)
equal(UI.overview_header(core, 1, false):find("F2", 1, true) ~= nil,
  true, "follow source appears only when assigned")
equal(UI.overview_header(core, 1, true), "T1  E2 CHANCE  E3 EVOLVE",
  "holding K1 explains the secondary controls")
core:set_track(1, "seed", 2)
draw()
equal(has_text("T1  01/64  S:2*  F2  FWD"), true,
  "crowded header abbreviates direction without clipping another field")
for direction = 0, 14 do
  core:set_track(1, "direction", direction)
  draw()
  local header
  for _, call in ipairs(calls) do
    if call.kind == "text" and call.y == 8 then header = call end
  end
  equal(header ~= nil and header.width <= 102, true,
    "header fits with Follow and pending Seed in direction " .. direction)
  equal(header.value:find("S:2*", 1, true) ~= nil
    and header.value:find("F2", 1, true) ~= nil, true,
    "crowded header preserves Seed and Follow in direction " .. direction)
end
core:set_track(1, "source", 0)
core:set_track(1, "seed", 1, true)
core:set_track(1, "direction", "forwards")
core:set_track(1, "rate", "x1.25")
core:set_track(1, "chance", 100)
core:set_track(1, "evolve", 100)
draw()
equal(ink_in_region(68, 15, 127, 20), true,
  "all four values fit using compact numerals when Particle is too wide")

UI.draw(screen, core, true, 1, 4, windows, {
  page = 2,
  title = "",
  fields = { { label = "SHIFT", value = "5" } },
  cursor = 1,
})
equal(antialias, 0, "editor disables anti-aliasing")
equal(ink_in_region(11, 23, 60, 29), true, "editor draws pixel labels")
equal(ink_in_region(120, 23, 127, 29), true, "editor draws pixel values")

local tide_ui = Core.new()
tide_ui:set_track(1, "length", 11)
tide_ui:set_track(1, "direction", "tide")
tide_ui:set_track(1, "chance", 58)
tide_ui:set_track(1, "note", 37)
local function tide_bar_heights()
  UI.draw(screen, tide_ui, true, 1, 4, windows, { page = 1 })
  local result = {}
  for _, call in ipairs(calls) do
    if call.kind == "fill" and #call.rects == 1 then
      local rect = call.rects[1]
      if rect.x >= 2 and rect.x < 66 and rect.y >= 15
          and rect.y <= 20 and rect.h <= 6 then
        result[#result + 1] = rect.h
      end
    end
  end
  return result
end
for _ = 1, 11 do tide_ui:advance(1) end
local first_tide_bars = tide_bar_heights()
for _ = 1, 11 do tide_ui:advance(1) end
local second_tide_bars = tide_bar_heights()
equal(#first_tide_bars, 11, "first Tide pass draws every step")
equal(#second_tide_bars, 11, "second Tide pass draws every step")
local changed_tide_bars = 0
for position = 1, 11 do
  if not tide_ui:evaluate(1, position - 1).fires then
    equal(first_tide_bars[position], 1,
      "Tide first pass shows a fixed rest at position " .. position)
    equal(second_tide_bars[position], 1,
      "Tide second pass keeps the rest at position " .. position)
  elseif second_tide_bars[position] ~= first_tide_bars[position] then
    changed_tide_bars = changed_tide_bars + 1
  end
end
equal(changed_tide_bars > 0, true,
  "Tide preview changes pitch heights over fixed rhythm")

print(string.format("ok - %d UI assertions", checks))
