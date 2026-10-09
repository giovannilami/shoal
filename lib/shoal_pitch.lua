-- Optional norns pitch window. This transforms output events only; it never
-- changes Shoal's seed, hash, playhead, scale, or original event in the core.

local Pitch = {}

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

-- Spread 100 leaves the original note intact. Below 100 contracts toward the
-- root; above 100 expands away from it. Then choose the nearest allowed note
-- in the requested range, preserving the selected Shoal scale where possible.
function Pitch.map(note, root, low, high, spread, scale_pcs)
  assert(low <= high, "minimum note must not exceed maximum note")
  local target = clamp(root + (note - root) * spread / 100, low, high)
  local allowed = {}
  for _, pc in ipairs(scale_pcs) do allowed[pc] = true end

  local best, best_distance, best_root_distance
  for candidate = low, high do
    if allowed[(candidate - root) % 12] then
      local distance = math.abs(candidate - target)
      local root_distance = math.abs(candidate - root)
      if not best or distance < best_distance
          or (distance == best_distance and root_distance < best_root_distance) then
        best, best_distance, best_root_distance = candidate, distance, root_distance
      end
    end
  end
  -- A one-note window may contain no pitch in the selected scale. Honour the
  -- requested hard range in that case instead of emitting a note outside it.
  return best or clamp(math.floor(target + 0.5), low, high)
end

function Pitch.event(event, root, low, high, spread, scale_pcs)
  if not event.audible then return event end
  local result = {}
  for key, value in pairs(event) do result[key] = value end
  result.raw_note = event.note
  result.note = Pitch.map(event.note, root, low, high, spread, scale_pcs)
  return result
end

return Pitch
