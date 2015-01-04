-- screenlayout keeps track of the OS screen layout as well as the layout visible on each screen
-- (the current space). It directs events to the active layout and handles moves of focus and
-- windows bewteen screens.
--
-- screenlayout differs from the window layout in that it is not tree-based and it is not in our
-- control. Moves between screens are handled in a geometric fashion rather than via tree traversal.

local screenlayout = {}

local windowtracker = require('wm.windowtracker')
local screenmanager = require('wm.screenmanager')

function screenlayout:new()
  local obj = {
    screens = {}
  }

  setmetatable(obj, self)
  self.__index = self

  for i, screen in pairs(hs.screen.allScreens()) do
    table.insert(obj.screens, {screen = screen})
  end
  obj.tracker = windowtracker:new({}, function(...) obj:_handleWindowEvent(...) end)
  obj.tracker:start()

  return obj
end

function screenlayout:_handleWindowEvent(win, event)
  if event == hs.uielement.watcher.windowCreated then
    self:_ensureCurrentLayoutExists(win:screen())
    self.currentLayout:addWindow(win)
  elseif event == hs.uielement.watcher.elementDestroyed and self.currentLayout then
    local layout = self:_getLayoutForWindow(win)
    if layout then
      layout:removeWindowById(win:id())
    end
  end
end

function screenlayout:_onFocusPastEnd(layout, direction)
  local curIdx = self:_getLayoutIndex(layout)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  local layout = self.screens[newIdx].layout
  if layout then
    self.currentLayout = layout
    layout:selectWindowGoingInDirection(direction)
    layout:focusSelection()
  end
end

function screenlayout:_onMovePastEnd(layout, node, direction)
  local curIdx = self:_getLayoutIndex(layout)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  self:_ensureLayoutExistsForScreenIdx(newIdx)

  self.screens[curIdx].layout:removeWindowById(node.window:id())
  self.screens[newIdx].layout:addWindowGoingInDirection(node.window, direction)
  self.currentLayout = self.screens[newIdx].layout
end

function screenlayout:_ensureCurrentLayoutExists(defaultScreen)
  if not self.currentLayout then
    local idx = self:_getScreenIndex(defaultScreen)
    self:_ensureLayoutExistsForScreenIdx(idx)
    self.currentLayout = self.screens[idx].layout
  end
end

function screenlayout:_ensureLayoutExistsForScreenIdx(idx)
  if not self.screens[idx].layout then
    -- Create layout on this screen for the first time.
    local layout = layout:new(self.screens[idx].screen)
    layout.onFocusPastEnd = function(...) self:_onFocusPastEnd(...) end
    layout.onMovePastEnd = function(...) self:_onMovePastEnd(...) end
    self.screens[idx].layout = layout
  end
end

function screenlayout:_getScreenInDirection(curIdx, direction)
  -- TODO actually implement
  local newIdx = curIdx + 1
  if newIdx > #self.screens then newIdx = 1 end
  return newIdx
end

function screenlayout:_getLayoutForWindow(win)
  -- TODO add some bookkeeping to speed this up
  for i, info in pairs(self.screens) do
    if hs.fnutils.contains(info.layout:allWindows(), win) then
      return info.layout
    end
  end
end

function screenlayout:_getScreenIndex(screen)
  for i, info in pairs(self.screens) do
    if info.screen == screen then
      return i
    end
  end
end

function screenlayout:_getLayoutIndex(layout)
  for i, info in pairs(self.screens) do
    if info.layout == layout then
      return i
    end
  end
end

return screenlayout
