local root = arg[0]:match("^(.*)/tests/test_grid%.lua$") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local GridUI = require("shoal_grid")
local checks = 0
local function equal(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  checks = checks + 1
end

local values, notices = {}, {}
for track = 1, 4 do
  for _, page in ipairs(GridUI.PAGES) do
    for _, field in ipairs(page) do
      values[string.format("shoal_t%d_%s", track, field.id)] = field.low
    end
  end
  values[string.format("shoal_t%d_mute", track)] = 1
end
values.shoal_run = 2
values.shoal_freeze = 1
local parameters = {
  get = function(_, id) return values[id] end,
  string = function(_, id)
    if id == "shoal_t1_direction" and values[id] == 15 then return "anchor" end
    return tostring(values[id])
  end,
  set = function(_, id, value) values[id] = value end,
}
local led = {}
local updates = 0
local connected = {
  device = { id = 10, port = 1, cols = 16, rows = 8 },
  all = function(_, value) led = {}; equal(value, 0, "redraw clears LEDs") end,
  led = function(_, x, y, level)
    assert(x >= 1 and x <= 16 and y >= 1 and y <= 8
      and level >= 0 and level <= 15, "LED outside 16 x 8 grid")
    led[x .. ":" .. y] = level
  end,
  refresh = function() updates = updates + 1 end,
}
local selected = 1
local random_calls = 0
local random_first = false
local ui = GridUI.new({
  params = parameters,
  grid = { connect = function() return connected end },
  selected_track = function() return selected end,
  select_track = function(track) selected = track end,
  feedback = function(message) notices[#notices + 1] = message end,
  random = function(count)
    random_calls = random_calls + 1
    if random_first then return 1 end
    return random_calls == 13 and 8 or count
  end,
})
ui:connect()
ui:redraw_if_dirty()
equal(led["1:8"], 15, "selected track LED")
equal(led["6:8"], 15, "first page LED")
equal(led["16:8"], 7, "Random action has a steady LED")
local prior_updates = updates
ui:redraw_if_dirty()
equal(updates, prior_updates, "grid stays quiet when unchanged")

connected.key(16, 1, 1)
equal(values.shoal_t1_rate, 26, "Grid tops out at x16, not x64")
connected.key(9, 8, 1)
connected.key(1, 1, 1)
equal(values.shoal_t1_rate, 25, "fine left decreases one rate")
connected.key(16, 1, 1)
equal(values.shoal_t1_rate, 26, "fine right increases one rate")
connected.key(9, 8, 0)
connected.key(8, 1, 1)
equal(values.shoal_t1_rate, 13, "x1 rate sits at column 8")
connected.key(10, 1, 1)
equal(values.shoal_t1_rate, 15, "x1.3 rate remains available")
connected.key(11, 1, 1)
equal(values.shoal_t1_rate, 16, "x1.5 has its own Grid key")
connected.key(9, 2, 1)
equal(values.shoal_t1_length, 16, "16 steps have a dedicated key")
connected.key(8, 3, 1)
equal(values.shoal_t1_chance, 50, "Chance 50 shares x1 rate column")
connected.key(1, 3, 1)
equal(values.shoal_t1_chance, 0, "chance minimum")
connected.key(16, 3, 1)
equal(values.shoal_t1_chance, 100, "chance maximum")
connected.key(15, 5, 1)
equal(values.shoal_t1_direction, 15, "last direction direct select")
equal(notices[#notices], "T1 DIRECTION ANCHOR",
  "direction name is uppercase in Grid feedback")
connected.key(16, 5, 1)
equal(values.shoal_t1_direction, 15, "unused direct-select key ignored")
connected.key(8, 6, 1)
equal(values.shoal_t1_shift, 0, "bipolar zero has center key")
connected.key(9, 6, 1)
equal(values.shoal_t1_shift, 0, "Shift zero repeats at second center key")
connected.key(7, 6, 1)
equal(values.shoal_t1_shift, -1, "Shift has one-step backward key")
connected.key(10, 6, 1)
equal(values.shoal_t1_shift, 1, "Shift has one-step forward key")
connected.key(16, 6, 1)
equal(values.shoal_t1_shift, 12, "Shift coarse ladder ends at twelve steps")
connected.key(5, 7, 1)
equal(values.shoal_t1_source, 5, "follow Track 4 direct select")

for _, row in ipairs({ 1, 2, 3, 4, 6 }) do
  local field = GridUI.PAGES[1][row]
  for x, expected in ipairs(field.values) do
    connected.key(x, row, 1)
    equal(values["shoal_t1_" .. field.id], expected,
      string.format("SEQ %s column %d", field.id, x))
  end
end

connected.key(4, 8, 1)
equal(selected, 4, "grid selects fourth track")
connected.key(7, 8, 1)
equal(ui.page, 2, "second grid page")
connected.key(1, 1, 1)
equal(values.shoal_t4_note, -100, "negative note variation")
connected.key(9, 1, 1)
equal(values.shoal_t4_note, 5, "Note column 9 is a gentle positive amount")
connected.key(8, 1, 1)
equal(values.shoal_t4_note, 0, "Note zero appears only at column 8")
connected.key(16, 1, 1)
equal(values.shoal_t4_note, 100, "positive note variation")
connected.key(8, 2, 1)
equal(values.shoal_t4_oct, 0, "Oct zero at column 8")
connected.key(9, 2, 1)
equal(values.shoal_t4_oct, 5, "Oct positive side starts at 5")
connected.key(5, 3, 1)
equal(values.shoal_t4_octave, -3, "octave lower direct option")
connected.key(11, 3, 1)
equal(values.shoal_t4_octave, 3, "octave upper direct option")
connected.key(8, 4, 1)
equal(values.shoal_t4_transpose, 0, "transpose centered")
connected.key(16, 5, 1)
equal(values.shoal_t4_min_note, 127, "minimum note full range")
connected.key(16, 7, 1)
equal(values.shoal_t4_spread, 200, "spread full range")
connected.key(8, 7, 1)
equal(values.shoal_t4_spread, 100, "spread center at column 8")
connected.key(9, 7, 1)
equal(values.shoal_t4_spread, 100, "spread center repeats at column 9")
connected.key(7, 7, 1)
equal(values.shoal_t4_spread, 85, "spread decreases by 15 near center")
connected.key(10, 7, 1)
equal(values.shoal_t4_spread, 115, "spread increases by 15 near center")

for _, row in ipairs({ 1, 2, 7 }) do
  local field = GridUI.PAGES[2][row]
  for x, expected in ipairs(field.values) do
    connected.key(x, row, 1)
    equal(values["shoal_t4_" .. field.id], expected,
      string.format("NOTE %s column %d", field.id, x))
  end
end
connected.key(8, 1, 1)
connected.key(8, 7, 1)
ui:redraw_if_dirty()
equal(led["8:1"], 15, "Note zero lights column 8")
equal(led["9:1"], nil, "Note zero does not light column 9")
equal(led["8:7"], 15, "Spread 100 lights first center key")
equal(led["9:7"], 15, "Spread 100 lights second center key")

connected.key(15, 8, 1)
equal(values.shoal_t4_mute, 2, "fourth mute always accessible")
connected.key(10, 8, 1)
equal(values.shoal_freeze, 2, "freeze always accessible")
values.shoal_t4_seed = 42
local other_rate = values.shoal_t1_rate
connected.key(16, 8, 1)
equal(random_calls, 14, "Random visits both pages' fourteen parameters")
equal(values.shoal_t4_rate, 20, "Random Rate tops out at x4")
equal(values.shoal_t4_length, 64, "Random Length comes from a Grid key")
equal(values.shoal_t4_chance, 100, "Random Chance comes from a Grid key")
equal(values.shoal_t4_direction, 15, "Random Direction comes from a Grid key")
equal(values.shoal_t4_source, 4, "Random Follow avoids self and reverse chain")
equal(values.shoal_t4_note, 100, "Random reaches Note page")
equal(values.shoal_t4_min_note, 59, "Random sorts conflicting pitch bounds")
equal(values.shoal_t4_max_note, 127, "Random retains the upper pitch bound")
equal(values.shoal_t4_seed, 42, "Random does not change Seed")
equal(values.shoal_t4_mute, 2, "Random does not change Mute")
equal(values.shoal_freeze, 2, "Random does not change Freeze")
equal(values.shoal_run, 2, "Random leaves transport running")
equal(values.shoal_t1_rate, other_rate, "Random edits only selected track")
equal(ui.page, 2, "Random works from Note without changing page")
equal(notices[#notices], "T4 RANDOMIZED", "Random gives track feedback")
values.shoal_t2_source = 5
values.shoal_t3_source = 5
connected.key(16, 8, 1)
equal(values.shoal_t4_source, 1, "Random Follow falls back to Off when every target cycles")
random_first = true
connected.key(16, 8, 1)
equal(values.shoal_t4_rate, 8, "Random Rate starts at /4")
equal(values.shoal_t4_chance, 5, "Random Chance starts at 5%, not silence")
ui:redraw_if_dirty()
equal(led["15:8"], 15, "mute status shown")
equal(led["10:8"], 15, "freeze status shown")
equal(led["16:8"], 7, "Random key remains visible after use")
equal(notices[#notices], "T4 RANDOMIZED", "repeat Random reports action")
ui:disconnect({ id = 10, port = 1 })
equal(ui.device, nil, "disconnect releases grid")
ui:connect(1)
ui:clear()
equal(ui.device, nil, "cleanup releases grid")

print(string.format("ok - %d grid assertions", checks))
