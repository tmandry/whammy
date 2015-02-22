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

return utils
