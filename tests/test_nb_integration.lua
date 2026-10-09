local root = arg[0]:match("^(.*)/tests/test_nb_integration%.lua$") or "."
local checks = 0
local function equal(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  checks = checks + 1
end

local values, actions, groups, separators = {}, {}, {}, {}
params = {
  add_separator = function(_, id) separators[id] = true end,
  add_group = function(_, id, _, count) groups[id] = count end,
  add_option = function(_, id, _, _, default) values[id] = default end,
  add_number = function(_, id, _, _, _, default) values[id] = default end,
  add_text = function(_, id, _, default) values[id] = default end,
  add_trigger = function(_, id) values[id] = false end,
  hide = function() end,
  set_action = function(_, id, action) actions[id] = action end,
  get = function(_, id) return values[id] end,
  string = function(_, id) return tostring(values[id]) end,
  set = function(_, id, value)
    values[id] = value
    if actions[id] then actions[id](value) end
  end,
  delta = function(self, id, amount) self:set(id, values[id] + amount) end,
  lookup_param = function(_, id)
    if id:match("_nb$") then
      return { get_player = function()
        return { note_on = function() end, note_off = function() end }
      end }
    end
  end,
}

local nb_init, nb_selectors, nb_sound_groups = 0, 0, 0
local fake_nb = {
  init = function() nb_init = nb_init + 1 end,
  add_param = function(_, id, label)
    nb_selectors = nb_selectors + 1
    params:add_option(id, label, { "none", "voice" }, 1)
    params:add_text(id .. "_hidden_string", "hidden", "")
    params:hide(id .. "_hidden_string")
  end,
  add_player_params = function()
    nb_sound_groups = nb_sound_groups + 1
    params:add_group("mock_voice", "mock voice", 1)
    params:add_number("mock_tone", "tone", 0, 100, 50)
  end,
}
package.preload["nbout/lib/nb/lib/nb"] = function()
  -- A loaded library must not be able to clear the script's engine choice.
  engine.name = nil
  return fake_nb
end

engine = { name = "", hz = function() end, amp = function() end,
  release = function() end }
local connected_midi_port, midi_note_count = nil, 0
midi = { connect = function(port)
  connected_midi_port = port
  return { note_on = function() midi_note_count = midi_note_count + 1 end,
    note_off = function() end }
end }
crow = { output = { {}, {}, {}, {} } }
local clock_task
clock = { run = function(fn)
  clock_task = coroutine.create(fn)
  return clock_task
end, cancel = function() end,
  sync = function() coroutine.yield() end, sleep = function() end,
  get_beat_sec = function() return 0.5 end }
metro = { init = function() return { start = function() end,
  stop = function() end } end }
screen = { clear = function() end, level = function() end,
  move = function() end, text = function() end, text_right = function() end,
  font_face = function() end, font_size = function() end,
  text_extents = function(value) return #value * 3 end,
  aa = function() end, rect = function() end,
  fill = function() end, stroke = function() end, update = function() end }
include = function(path)
  return dofile(root .. "/" .. path:match("(lib/.+)$") .. ".lua")
end

dofile(root .. "/shoal-norns.lua")
init()
equal(engine.name, "PolyPerc", "PolyPerc survives loading the n.b. library")
equal(nb_init, 1, "shared nbout library initialized")
equal(nb_selectors, 4, "four independent n.b. selectors")
equal(nb_sound_groups, 1, "voice parameter groups added")
equal(groups.shoal_group_t1, 23, "track group includes hidden n.b. state")
equal(groups.shoal_group_t4, 23, "fourth track group includes n.b.")
equal(separators.shoal_nb_sound, true, "voice sound section labelled")
params:set("shoal_t1_route", 3)
equal(values.shoal_t1_route, 3, "n.b. route selectable")
params:set("shoal_midi_port", 16)
equal(connected_midi_port, 16, "MIDI port 16 selectable with n.b. installed")
params:set("shoal_t1_route", 4) -- MIDI follows n.b. in the route list
local sequencer_task = clock_task
local ok, err = coroutine.resume(sequencer_task)
assert(ok, err)
ok, err = coroutine.resume(sequencer_task)
assert(ok, err)
equal(midi_note_count, 1, "MIDI note emitted with n.b. installed")
cleanup()

print(string.format("ok - %d n.b. integration assertions", checks))
