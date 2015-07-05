-- floatinglayout is a layer of the screen layout that has no tiling or tree-based structure; it is
-- simply a collection of windows that can overlap and be moved and resized.

local utils = require 'wm.utils'

local floatinglayout = {}

local direction   = utils.direction
local orientation = utils.orientation
local incrementForDirection   = utils.incrementForDirection
local orientationForDirection = utils.orientationForDirection

function floatinglayout:new()
  local obj = {
    windows = {},
    selection = nil
  }

  setmetatable(obj, {__index = self})
  return obj
end

function floatinglayout:addWindow(win)
  table.insert(self.windows, win)
  if not self.selection then self.selection = win end
end

function floatinglayout:allWindows()
  return self.windows
end

function floatinglayout:selectWindow(win)
  if hs.fnutils.contains(self.windows, win) then
    self.selection = win
    return true
  end
  return false
end

function floatinglayout:focusSelection()
  if self.selection then
    self.selection:focus()
    return true
  end
  return false
end

function floatinglayout:bringToFrontAndFocusSelection()
  -- Focus selection first (for user visual identification)
  if self.selection then self.selection:focus() end
  -- Focus other windows
  hs.fnutils.each(self.windows, function(win)
    if win ~= self.selection then
      win:focus()
    end
  end)
  -- Focus selection last (for final focus)
  if self.selection then self.selection:focus() end
end

function floatinglayout:removeSelectedWindows()
  local win = self.selection
  local idx = hs.fnutils.indexOf(self.windows, win)
  table.remove(self.windows, idx)
  return {win}
end

function floatinglayout:removeWindowById(id)
  local idx = utils.findIdx(self.windows, function(w) return w:id() == id end)
  if idx then
    table.remove(self.windows, idx)
    return true
  else
    return false
  end
end

function floatinglayout:isEmpty()
  return #self.windows == 0
end

function floatinglayout:isTiling()
  return false
end

function floatinglayout:move(dir)
  if not self.selection then return end

  local topLeft = self.selection:topLeft()
  local increment = incrementForDirection(dir)
  local o = orientationForDirection(dir)

  if     o == orientation.horizontal then
    topLeft.x = topLeft.x + increment * 10
  elseif o == orientation.vertical then
    topLeft.y = topLeft.y + increment * 10
  end

  self.selection:setTopLeft(topLeft)
end

function floatinglayout:focus(dir)
  local o = orientationForDirection(dir)
  local function midpoint(rect)
    if o == orientation.horizontal then
      return (rect.x + rect.w)/2
    else
      return (rect.y + rect.h)/2
    end
  end

  -- Find closest window in specified direction.
  local increment = incrementForDirection(dir)
  local start = midpoint(self.selection:frame())
  local best, bestDistance
  for i, win in pairs(self.windows) do
    local point = midpoint(win:frame())
    local diff = point - start
    if (increment > 0 and diff > 0) or (increment < 0 and diff < 0) then
      local distance = math.abs(diff)
      if not bestMidpoint or distance < bestDistance then
        best = win
        bestDistance = distance
      end
    end
  end

  if best then
    best:focus()
  end
end

function floatinglayout:resize(dir, pct)
  if not self.selection then return end

  local screenFrame = self.selection:screen():frame()
  local frame = self.selection:frame()

  if     dir == direction.up then
    frame.y = frame.y - pct*screenFrame.h
    frame.h = frame.h + pct*screenFrame.h
  elseif dir == direction.down then
    frame.h = frame.h + pct*screenFrame.h
  elseif dir == direction.left then
    frame.x = frame.x - pct*screenFrame.w
    frame.w = frame.w + pct*screenFrame.w
  elseif dir == direction.right then
    frame.w = frame.w + pct*screenFrame.w
  end

  self.selection:setFrame(frame, 0)
end

return floatinglayout
