-- There is one active workspace per screen at a time, and a workspace has both a tiling and a
-- floating layout. The job of this class is to coordinate and abstract over the two kinds of
-- layouts.

local workspace = {}

local layout = require 'wm.layout'
local floatinglayout = require 'wm.floatinglayout'

function workspace:new(screen)
  local obj = {
    tilingLayout = layout:new(screen),
    floatingLayout = floatinglayout:new(),
    selection = nil,

    -- Handler functions
    onFocusPastEnd = nil,
    onMovePastEnd  = nil
  }
  obj.selection = obj.tilingLayout

  -- Set up handler functions
  obj.tilingLayout.onFocusPastEnd = function(...) obj:_onFocusPastEnd(false, ...) end
  obj.tilingLayout.onMovePastEnd  = function(...) obj:_onMovePastEnd(false, ...) end
  obj.floatingLayout.onFocusPastEnd = function(...) obj:_onFocusPastEnd(true, ...) end
  obj.floatingLayout.onMovePastEnd  = function(...) obj:_onMovePastEnd(true, ...) end

  setmetatable(obj, {__index = self})
  return obj
end

function workspace:allWindows()
  return hs.fnutils.concat(self.tilingLayout:allWindows(), self.floatingLayout:allWindows())
end

function workspace:isEmpty()
  return self.tilingLayout:isEmpty() and self.floatingLayout:isEmpty()
end

function workspace:selectWindow(win)
  if     self.tilingLayout:selectWindow(win) then
    self.selection = self.tilingLayout
    return true
  elseif self.floatingLayout:selectWindow(win) then
    self.selection = self.floatingLayout
    return true
  end
  return false
end

-- Toggles whether the selection is tiling or floating.
function workspace:toggleFloating()
  local windows = self.selection:removeSelectedWindows()
  local dstLayout = (self.selection == self.tilingLayout) and self.floatingLayout or self.tilingLayout

  for i, win in pairs(windows) do
    dstLayout:addWindow(win)
  end

  self.selection = dstLayout
  self.selection:bringToFrontAndFocusSelection()
end

-- Toggle whether the tiling or floating layout is selected.
function workspace:toggleFocusMode()
  local oldSelection = self.selection
  self.selection = (self.selection == self.tilingLayout) and self.floatingLayout or self.tilingLayout
  if self.selection:isEmpty() and not oldSelection:isEmpty() then
    -- Revert change
    print("No windows on this layer, not toggling")
    self.selection = oldSelection
  else
    self.selection:bringToFrontAndFocusSelection()
  end
end

function workspace:_onFocusPastEnd(floating, layout, direction)
  if self.onFocusPastEnd then
    self.onFocusPastEnd(self, direction, floating)
  end
end

function workspace:_onMovePastEnd(floating, layout, node, direction)
  print(tostring(self)..' '..tostring(layout)..' '..tostring(node)..' '..tostring(direction)..' '..tostring(floating))
  if self.onMovePastEnd then
    self.onMovePastEnd(self, node, direction, floating)
  end
end

-- Forward calls to the selected layout.
function workspace:_lookupFunction(funcName)
  return function(ws, ...)
    if not ws.selection then
      print('No active workspace; cannot send '..funcName)
      return nil
    end

    local func = ws.selection[funcName]
    if type(func) == 'function' then
      return func(ws.selection, ...)
    end
  end
end

setmetatable(workspace, {__index = workspace._lookupFunction})

return workspace
