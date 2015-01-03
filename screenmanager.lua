local layout = require('wm.layout')
local windowtracker = require('wm.windowtracker')

local screenmanager = {}

function screenmanager:new()
  local obj = {
    layouts = {}
  }

  setmetatable(obj, self)
  self.__index = self

  obj.tracker = windowtracker:new({}, function(...) screenmanager._handleWindowEvent(obj, ...) end)
  obj.tracker:start()
  obj.watcher = hs.spaces.watcher.new(function() screenmanager._handleSpaceChange(obj) end)
  obj.watcher:start()

  return obj
end

local function allWindows()
  return hs.window.allWindows()
end

-- Returns the index of the current space layout, or nil if none could be matched.
function screenmanager:_detectSpace()
  -- Detect which space we're in by looking at the windows currently on screen.

  -- Get list of windows for each layout.
  local layoutInfo = {}
  for i, layout in pairs(self.layouts) do
    layoutInfo[i] = {windows = layout:allWindows(), matches = 0}
  end

  -- Match each window to a layout if possible.
  for i, win in pairs(allWindows()) do
    for j, info in pairs(layoutInfo) do
      if hs.fnutils.contains(info.windows, win) then
        info.matches = info.matches + 1
        break
      end
    end
  end

  -- Pick the best match. Must see more than half of windows in the layout to be a match.
  local bestMatch = nil
  for i, info in pairs(layoutInfo) do
    if info.matches > #info.windows/2 then
      if not bestMatch or info.matches > matches[bestMatch].matches then
        bestMatch = i
      end
    end
  end

  return bestMatch
end

function screenmanager:_handleSpaceChange()
  local space = self:_detectSpace()
  self.currentLayout = self.layouts[space]
end

function screenmanager:_handleWindowEvent(win, event)
  if event == hs.uielement.watcher.windowCreated then
    if not self.currentLayout then
      -- Create layout on this screen for the first time.
      self.currentLayout = layout:new(win:screen())
      table.insert(self.layouts, self.currentLayout)
    end
    self.currentLayout:addWindow(win)
  elseif event == hs.uielement.watcher.elementDestroyed and self.currentLayout then
    self.currentLayout:removeWindowById(win:id())
  end
end

return screenmanager
