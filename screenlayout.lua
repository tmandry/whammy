-- screenlayout keeps track of the OS screen layout as well as the layout visible on each screen
-- (the current space). It directs events to the active layout and handles moves of focus and
-- windows bewteen screens.
--
-- screenlayout differs from the window layout in that it is not tree-based and it is not in our
-- control. Moves between screens are handled in a geometric fashion rather than via tree traversal.

local screenlayout = {}

local layout = require('wm.layout')
local spacetracker = require('wm.spacetracker')
local windowtracker = require('wm.windowtracker')

function screenlayout:new()
  local obj = {
    screens = {},  -- Keeps the screen object and the currently visible layout for each screen.
    layouts = {},  -- A list of all layout objects.
    selectedLayout = nil
  }
  setmetatable(obj, self)
  self.__index = self

  for i, screen in pairs(hs.screen.allScreens()) do
    table.insert(obj.screens, {screen = screen, layout = nil})
  end

  obj.windowtracker = windowtracker:new(
    {windowtracker.windowCreated, windowtracker.windowDestroyed, windowtracker.mainWindowChanged},
    function(...) obj:_handleWindowEvent(...) end)
  obj.windowtracker:start()

  obj.spacetracker = spacetracker:new(obj.layouts, function(...) obj:_handleSpaceChange(...) end)

  -- Create initial layouts for the current space.
  obj:_handleSpaceChange({length = #obj.screens})

  return obj
end

function screenlayout:_handleSpaceChange(visibleLayouts)
  -- visibleLayouts uses same screen indexes as us, but may contain some nil values.
  assert(visibleLayouts.length == #self.screens, "spacetracker returned unexpected number of screens")

  local oldSelectedScreenIdx = self:_getLayoutIndex(self.selectedLayout)

  for i = 1, visibleLayouts.length do
    -- Remove empty and non-visible layouts.
    if self.screens[i].layout and self.screens[i].layout:isEmpty() then
      self:_removeLayout(i)
    end

    if visibleLayouts[i] then
      self.screens[i].layout = visibleLayouts[i]
    else
      self:_createLayout(i)
    end
  end

  -- Use the OS behavior to determine which screen should be focused. Default to the last focused screen.
  local focusedWindow = hs.window.focusedWindow()
  local screenIdx = focusedWindow and self:_getScreenIndex(focusedWindow:screen()) or nil
  if screenIdx then
    self.selectedLayout = self.screens[screenIdx].layout
    -- TODO set layout selection to match focused window
  else
    self.selectedLayout = self.screens[oldSelectedScreenIdx or 1].layout
    self.selectedLayout:focusSelection()
  end
end

function screenlayout:_handleWindowEvent(win, event)
  if     event == hs.uielement.watcher.windowCreated then
    self.selectedLayout:addWindow(win)
  elseif event == hs.uielement.watcher.elementDestroyed then
    local layout = self:_getLayoutForWindow(win)
    if layout then layout:removeWindowById(win:id()) end
  elseif event == hs.uielement.watcher.mainWindowChanged then
    local layout = self:_getLayoutForWindow(win)
    if layout then
      self.selectedLayout = layout
      local result = layout:selectWindow(win)
    end
  end
end

function screenlayout:_onFocusPastEnd(layout, direction)
  local curIdx = self:_getLayoutIndex(layout)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  local layout = self.screens[newIdx].layout
  if layout then
    self.selectedLayout = layout
    layout:selectWindowGoingInDirection(direction)
    layout:focusSelection()
  end
end

function screenlayout:_onMovePastEnd(layout, node, direction)
  local curIdx = self:_getLayoutIndex(layout)
  local newIdx = self:_getScreenInDirection(curIdx, direction)

  self.screens[curIdx].layout:removeWindowById(node.window:id())
  self.screens[newIdx].layout:addWindowGoingInDirection(node.window, direction)
  self.selectedLayout = self.screens[newIdx].layout
end

function screenlayout:_getScreenInDirection(curIdx, direction)
  -- TODO actually implement
  local newIdx = curIdx + 1
  if newIdx > #self.screens then newIdx = 1 end
  return newIdx
end

function screenlayout:_createLayout(screenIdx)
  local layout = layout:new(self.screens[screenIdx].screen)
  layout.onFocusPastEnd = function(...) self:_onFocusPastEnd(...) end
  layout.onMovePastEnd = function(...) self:_onMovePastEnd(...) end

  self.screens[screenIdx].layout = layout
  table.insert(self.layouts, layout)
  return layout
end

function screenlayout:_removeLayout(screenIdx)
  table.remove(self.layouts, hs.fnutils.indexOf(self.layouts, self.screens[screenIdx].layout))
  self.screens[screenIdx].layout = nil
end

function screenlayout:_getLayoutForWindow(win)
  -- TODO add some bookkeeping to speed this up
  for i, layout in pairs(self.layouts) do
    if hs.fnutils.contains(layout:allWindows(), win) then
      return layout
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
