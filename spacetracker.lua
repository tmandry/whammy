-- spacetracker watches for space changes and reports the workspaces that are currently visible when a
-- change occurs.

local layout = require 'wm.layout'

local spacetracker = {}

-- Creates a new space tracker.
--
-- workspaces is a table of all workspaces, which you may change.
--
-- onSpaceChange is a function that will be called with the list of currently visible workspaces for
-- each screen. Note that some entries may be nil, if no workspaces were detected on that screen. The
-- table passed to onSpaceChange will have a .length index that contains the actual length of the
-- list; you should use this instead of the # operator or the pairs() function for iterating.
function spacetracker:new(workspaces, onSpaceChange)
  local obj = {
    workspaces = workspaces,
    onSpaceChange = onSpaceChange
  }
  setmetatable(obj, {__index = self})

  obj.watcher = hs.spaces.watcher.new(function() spacetracker._handleSpaceChange(obj) end)
  obj.watcher:start()

  return obj
end

local function allVisibleWindows()
  return hs.window.allWindows()
end

local function times(x, num)
  local list = {}
  for i = 1, num do
    table.insert(list, x)
  end
  return list
end

-- Returns the workspace index of the current workspace for each screen, or nil if none could be matched.
function spacetracker:_detectWorkspaces()
  -- Detect which space we're in by looking at the windows currently on screen.

  local screens = hs.screen.allScreens()

  -- Get list of windows for each workspace.
  local workspaceInfo = {}
  for i, workspace in pairs(self.workspaces) do
    workspaceInfo[i] = {windows = workspace:allWindows(), matches = times(0, #screens)}
  end

  -- Match each window to a workspace if possible.
  for i, win in pairs(allVisibleWindows()) do
    for j, info in pairs(workspaceInfo) do
      if hs.fnutils.contains(info.windows, win) then
        local screenIdx = hs.fnutils.indexOf(screens, win:screen())
        info.matches[screenIdx] = info.matches[screenIdx] + 1
        break
      end
    end
  end

  -- Pick the best match for each screen. Must see more than half of windows in the workspace to be a match.
  local bestMatches = {length = #screens}
  for i, info in pairs(workspaceInfo) do
    for j, matches in pairs(info.matches) do
      if matches > #info.windows/2 then
        if not bestMatches[j] or matches > workspaceInfo[bestMatches[j]].matches[j] then
          bestMatches[j] = i
        end
      end
    end
  end

  return bestMatches
end

function spacetracker:_handleSpaceChange()
  local workspaceIdxs = self:_detectWorkspaces()
  local workspaces = {length = workspaceIdxs.length}
  for i = 1, workspaceIdxs.length do
    local idx = workspaceIdxs[i]
    workspaces[i] = idx and self.workspaces[idx] or nil
  end

  self.onSpaceChange(workspaces)
end

return spacetracker
