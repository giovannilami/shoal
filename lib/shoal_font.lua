-- Sharp 5 x 7 display font for Shoal's 128 x 64 screen.
-- The glyphs are drawn on integer pixel boundaries: no system font scaling.
-- Narrow punctuation and I/1 keep the overview and editor readable.

local Font = {}

local patterns = {
  [" "] = {"..", "..", "..", "..", "..", "..", ".."},
  A = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
  B = {"####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."},
  C = {".####", "#....", "#....", "#....", "#....", "#....", ".####"},
  D = {"###..", "#..#.", "#...#", "#...#", "#...#", "#..#.", "###.."},
  E = {"#####", "#....", "#....", "####.", "#....", "#....", "#####"},
  F = {"#####", "#....", "#....", "####.", "#....", "#....", "#...."},
  G = {".####", "#....", "#....", "#.###", "#...#", "#...#", ".###."},
  H = {"#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"},
  I = {"###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"},
  J = {"..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."},
  K = {"#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"},
  L = {"#....", "#....", "#....", "#....", "#....", "#....", "#####"},
  M = {"#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"},
  N = {"#...#", "##..#", "##..#", "#.#.#", "#..##", "#..##", "#...#"},
  O = {".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."},
  P = {"####.", "#...#", "#...#", "####.", "#....", "#....", "#...."},
  Q = {".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"},
  R = {"####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"},
  S = {".####", "#....", "#....", ".###.", "....#", "....#", "####."},
  T = {"#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."},
  U = {"#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."},
  V = {"#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."},
  W = {"#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"},
  X = {"#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"},
  Y = {"#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."},
  Z = {"#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"},
  ["0"] = {".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."},
  ["1"] = {".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"},
  ["2"] = {".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"},
  ["3"] = {"####.", "....#", "...#.", "..##.", "....#", "#...#", ".###."},
  ["4"] = {"...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."},
  ["5"] = {"#####", "#....", "#....", "####.", "....#", "#...#", ".###."},
  ["6"] = {".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."},
  ["7"] = {"#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."},
  ["8"] = {".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."},
  ["9"] = {".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."},
  ["."] = {".", ".", ".", ".", ".", "#", "#"},
  [","] = {"..", "..", "..", "..", ".#", ".#", "#."},
  ["/"] = {"...#", "...#", "..#.", "..#.", ".#..", "#...", "#..."},
  ["+"] = {".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."},
  ["-"] = {"...", "...", "...", "###", "...", "...", "..."},
  ["*"] = {".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."},
  ["~"] = {".....", ".....", ".##..", "#..##", ".....", ".....", "....."},
  [">"] = {"#..", ".#.", "..#", "..#", "..#", ".#.", "#.."},
  ["<"] = {"..#", ".#.", "#..", "#..", "#..", ".#.", "..#"},
  ["%"] = {"#...#", "#..#.", "...#.", "..#..", ".#...", ".#..#", "#...#"},
  [":"] = {".", "#", "#", ".", "#", "#", "."},
  ["?"] = {".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."},
  ["("] = {"..#", ".#.", "#..", "#..", "#..", ".#.", "..#"},
  [")"] = {"#..", ".#.", "..#", "..#", "..#", ".#.", "#.."},
  ["="] = {".....", "#####", ".....", "#####", ".....", ".....", "....."},
  ["_"] = {".....", ".....", ".....", ".....", ".....", ".....", "#####"},
}

local glyphs = {}
for character, rows in pairs(patterns) do
  local width = #rows[1]
  local runs = {}
  assert(#rows == 7, "font glyph height: " .. character)
  for row = 1, 7 do
    assert(#rows[row] == width, "font glyph width: " .. character)
    local start = nil
    for column = 1, width + 1 do
      if column <= width and rows[row]:sub(column, column) == "#" then
        if not start then start = column end
      elseif start then
        runs[#runs + 1] = { start - 1, row - 1, column - start }
        start = nil
      end
    end
  end
  glyphs[character] = { width = width, runs = runs, rows = rows }
end

local function normalize(value)
  return tostring(value or ""):upper()
end

function Font.width(value)
  local string_value = normalize(value)
  local width = 0
  for index = 1, #string_value do
    local glyph = glyphs[string_value:sub(index, index)] or glyphs["?"]
    width = width + glyph.width + 1
  end
  return math.max(0, width - 1)
end

function Font.trim(value, max_width)
  local string_value = normalize(value)
  if Font.width(string_value) <= max_width then return string_value end
  if max_width < Font.width(".") then return "" end
  repeat
    string_value = string_value:sub(1, -2)
  until #string_value == 0 or Font.width(string_value .. ".") <= max_width
  return string_value .. "."
end

function Font.left(screen, x, baseline, value)
  local string_value = normalize(value)
  local pen = x
  local any = false
  for index = 1, #string_value do
    local glyph = glyphs[string_value:sub(index, index)] or glyphs["?"]
    for _, run in ipairs(glyph.runs) do
      screen.rect(pen + run[1], baseline - 6 + run[2], run[3], 1)
      any = true
    end
    pen = pen + glyph.width + 1
  end
  if any then screen.fill() end
  return pen - 1
end

function Font.right(screen, right, baseline, value, max_width)
  local string_value = max_width and Font.trim(value, max_width) or normalize(value)
  local x = right - Font.width(string_value) + 1
  Font.left(screen, x, baseline, string_value)
  return x
end

function Font.glyph_rows(character)
  local glyph = glyphs[normalize(character)]
  return glyph and glyph.rows
end

-- Exact small numerals for the four-value overview when Particle is too wide.
-- Only the rate, length, chance and evolve vocabulary is needed here.
local compact_patterns = {
  ["0"] = {".#.", "#.#", "#.#", "#.#", ".#."},
  ["1"] = {".#", "##", ".#", ".#", "##"},
  ["2"] = {"##.", "..#", ".#.", "#..", "###"},
  ["3"] = {"##.", "..#", ".#.", "..#", "##."},
  ["4"] = {"#.#", "#.#", "###", "..#", "..#"},
  ["5"] = {"###", "#..", "##.", "..#", "##."},
  ["6"] = {".##", "#..", "##.", "#.#", ".#."},
  ["7"] = {"###", "..#", ".#.", ".#.", ".#."},
  ["8"] = {".#.", "#.#", ".#.", "#.#", ".#."},
  ["9"] = {".#.", "#.#", ".##", "..#", "##."},
  X = {"#.#", "#.#", ".#.", "#.#", "#.#"},
  E = {"###", "#..", "##.", "#..", "###"},
  ["%"] = {"#.#", "..#", ".#.", "#..", "#.#"},
  ["/"] = {"..#", "..#", ".#.", "#..", "#.."},
  ["."] = {".", ".", ".", ".", "#"},
  ["-"] = {"...", "...", "###", "...", "..."},
}

local compact = {}
for character, rows in pairs(compact_patterns) do
  local width = #rows[1]
  local runs = {}
  assert(#rows == 5, "compact glyph height: " .. character)
  for row = 1, 5 do
    assert(#rows[row] == width, "compact glyph width: " .. character)
    local start = nil
    for column = 1, width + 1 do
      if column <= width and rows[row]:sub(column, column) == "#" then
        if not start then start = column end
      elseif start then
        runs[#runs + 1] = { start - 1, row - 1, column - start }
        start = nil
      end
    end
  end
  compact[character] = { width = width, runs = runs }
end

function Font.compact_width(value)
  local string_value = normalize(value)
  local width = 0
  for index = 1, #string_value do
    local character = string_value:sub(index, index)
    local glyph = assert(compact[character], "unsupported compact glyph: " .. character)
    width = width + glyph.width + 1
  end
  return math.max(0, width - 1)
end

function Font.compact_left(screen, x, baseline, value)
  local string_value = normalize(value)
  local pen = x
  for index = 1, #string_value do
    local character = string_value:sub(index, index)
    local glyph = assert(compact[character], "unsupported compact glyph: " .. character)
    for _, run in ipairs(glyph.runs) do
      screen.rect(pen + run[1], baseline - 4 + run[2], run[3], 1)
    end
    pen = pen + glyph.width + 1
  end
  if #string_value > 0 then screen.fill() end
  return pen - 1
end

return Font
