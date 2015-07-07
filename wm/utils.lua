local utils = {}

local orientation = {
  horizontal = 0, vertical = 1
}
utils.orientation = orientation

local direction = {
  left = 0, right = 1, up = 2, down = 3
}
utils.direction = direction

function utils.orientationForDirection(d)
  if d == direction.left or d == direction.right then
    return orientation.horizontal
  else
    return orientation.vertical
  end
end

function utils.incrementForDirection(d)
  if d == direction.left or d == direction.up then
    return -1
  else
    return  1
  end
end

function utils.rectEquals(a, b)
  return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

-- Removes elements from an array if the provided function returns true on them.
function utils.removeIf(t, fn)
  local i     = 1
  local count = #t
  while i <= count do
    if fn(t[i]) then
      table.remove(t, i)
      count = count - 1
    else
      i = i + 1
    end
  end
  return t
end

function utils.remove(t, x)
  return utils.removeIf(t, function(y) return (x==y) end)
end

--- Returns the first element index where fn(el) is truthy.
function utils.findIdx(t, fn)
  for i, v in pairs(t) do
    if fn(v) then return i end
  end
  return nil
end

return utils
