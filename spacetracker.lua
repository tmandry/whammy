-- spacetracker watches for space changes and reports the layouts that are currently visible when a
-- change occurs.

local layout = require('wm.layout')

local spacetracker = {}

-- Creates a new space tracker.
--
-- layouts is a table of all layouts, which you may change.
--
-- onSpaceChange is a function that will be called with the list of currently visible layouts for
-- each screen. Note that some entries may be nil, if no layouts were detected on that screen. The
-- table passed to onSpaceChange will have a .length index that contains the actual length of the
-- list; you should use this instead of the # operator or the pairs() function for iterating.
function spacetracker:new(layouts, onSpaceChange)
  local obj = {
    layouts = layouts,
    onSpaceChange = onSpaceChange
  }

  setmetatable(obj, self)
  self.__index = self

  obj.watcher = hs.spaces.watcher.new(function() spacetracker._handleSpaceChange(obj) end)
  obj.watcher:start()

  return obj
end

local function allWindows()
  return hs.window.allWindows()
end

local function times(x, num)
  local list = {}
  for i = 1, num do
    table.insert(list, x)
  end
  return list
end

-- Returns the layout index of the current layout for each screen, or nil if none could be matched.
function spacetracker:_detectLayouts()
  -- Detect which space we're in by looking at the windows currently on screen.

  local screens = hs.screen.allScreens()

  -- Get list of windows for each layout.
  local layoutInfo = {}
  for i, layout in pairs(self.layouts) do
    layoutInfo[i] = {windows = layout:allWindows(), matches = times(0, #screens)}
  end

  -- Match each window to a layout if possible.
  for i, win in pairs(allWindows()) do
    for j, info in pairs(layoutInfo) do
      if hs.fnutils.contains(info.windows, win) then
        local screenIdx = hs.fnutils.indexOf(screens, win:screen())
        info.matches[screenIdx] = info.matches[screenIdx] + 1
        break
      end
    end
  end

  -- Pick the best match for each screen. Must see more than half of windows in the layout to be a match.
  local bestMatches = {length = #screens}
  for i, info in pairs(layoutInfo) do
    for j, matches in pairs(info.matches) do
      if matches > #info.windows/2 then
        if not bestMatches[j] or matches > layoutInfo[bestMatches[j]].matches[j] then
          bestMatches[j] = i
        end
      end
    end
  end

  return bestMatches
end

function spacetracker:_handleSpaceChange()
  local layoutIdxs = self:_detectLayouts()
  local layouts = {length = layoutIdxs.length}
  for i = 1, layoutIdxs.length do
    local idx = layoutIdxs[i]
    layouts[i] = idx and self.layouts[idx] or nil
  end

  self.onSpaceChange(layouts)
end

return spacetracker
