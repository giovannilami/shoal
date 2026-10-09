local root = arg[0]:match("^(.*)/tests/test_font%.lua$") or "."
local Font = dofile(root .. "/lib/shoal_font.lua")
local Core = dofile(root .. "/lib/shoal_core.lua")
local checks = 0

local function equal(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  checks = checks + 1
end

equal(table.concat(Font.glyph_rows("5"), "/"),
  "#####/#..../#..../####./....#/#...#/.###.", "5 has a complete top and distinct lower curve")
equal(Font.glyph_rows("G")[4], "#.###", "G has its inner bar")
equal(Font.glyph_rows("6")[4], "####.", "G and 6 have different inner bars")
equal(Font.width("1"), 3, "narrow 1")
equal(Font.width("E1 TRK E2 PICK E3 EDIT") <= 127, true,
  "editor instructions fit display")
local compact_total = Font.compact_width("X1.25")
  + Font.compact_width("64") + Font.compact_width("%100")
  + Font.compact_width("E100") + 9
equal(compact_total <= 60, true,
  "four compact overview values fit with three-pixel gaps")
for rate = 0, 28 do
  local total = Font.compact_width(Core.RATES[rate].name)
    + Font.compact_width("64") + Font.compact_width("%100")
    + Font.compact_width("E100") + 9
  equal(total <= 60, true,
    "compact values fit at rate " .. Core.RATES[rate].name)
end

local pixels = {}
local fills = 0
local screen = {
  rect = function(x, y, width, height)
    equal(height, 1, "glyph runs use one pixel rows")
    for dx = 0, width - 1 do pixels[(x + dx) .. ":" .. y] = true end
  end,
  fill = function() fills = fills + 1 end,
}

Font.left(screen, 2, 9, "5")
equal(fills, 1, "text is filled in one batch")
for row, bits in ipairs(Font.glyph_rows("5")) do
  for column = 1, #bits do
    equal(pixels[(column + 1) .. ":" .. (row + 2)] == true,
      bits:sub(column, column) == "#", "5 pixel " .. row .. "/" .. column)
  end
end

equal(Font.right(screen, 127, 9, "L64"), 111, "right-aligned length starts at 111")
local clipped = Font.trim("MAJOR PENTATONIC", 70)
equal(Font.width(clipped) <= 70, true, "long values remain in their field")
equal(clipped:sub(-1), ".", "long values show truncation")

print(string.format("ok - %d pixel-font assertions", checks))
