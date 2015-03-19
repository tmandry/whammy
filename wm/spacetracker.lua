-- spacetracker watches for space changes and reports the workspaces that are currently visible when
-- a change occurs. It treats every screen as having a separate space. This means that a screen
-- configuration change (adding, moving, or removing a screen) is considered a space change.

local layout  = require 'wm.layout'
local fnutils = require 'wm.fnutils'
local os      = require 'wm.os'

local spacetracker = {}

-- Creates a new space tracker.
--
-- workspaces is a table of all workspaces, which you may change.
--
-- onSpaceChange is a function that will be called with the list of
-- {screen=<screen>, workspace=<workspace|nil>}
-- objects.
function spacetracker:new(workspaces, onSpaceChange)
  local obj = {
    workspaces = workspaces,
    onSpaceChange = onSpaceChange
  }
  setmetatable(obj, {__index = self})

  obj:_setupWatchers()
  return obj
end

function spacetracker:_setupWatchers()
  self.spaceWatcher = hs.spaces.watcher.new(function() spacetracker._handleSpaceChange(self) end)
  self.spaceWatcher:start()
  self.screenWatcher = hs.screen.watcher.new(function() spacetracker._handleSpaceChange(self) end)
  self.spaceWatcher:start()
end

local function times(x, num)
  local list = {}
  for i = 1, num do
    table.insert(list, x)
  end
  return list
end

-- Returns the current workspace for each screen, or nil if none could be matched.
-- Results are returns as an array of {screen, workspace} tables.
function spacetracker:_detectWorkspaces()
  -- Detect which space we're in by looking at the windows currently on screen.

  local screens = os.allScreens()

  -- Get list of windows for each workspace.
  local workspaceInfo = {}
  for i, workspace in pairs(self.workspaces) do
    workspaceInfo[i] = {windows = workspace:allWindows(), matches = times(0, #screens)}
  end

  -- Match each window to a workspace if possible.
  for i, win in pairs(os.allVisibleWindows()) do
    for j, info in pairs(workspaceInfo) do
      if fnutils.contains(info.windows, win) then
        local screenIdx = fnutils.indexOf(screens, win:screen())
        info.matches[screenIdx] = info.matches[screenIdx] + 1
        break
      end
    end
  end

  -- Pick the best match for each screen. Must see more than half of windows in the workspace to be a match.
  local bestMatches = {}
  for i, info in pairs(workspaceInfo) do
    for j, matches in pairs(info.matches) do
      if matches > #info.windows/2 then
        if not bestMatches[j] or matches > workspaceInfo[bestMatches[j]].matches[j] then
          bestMatches[j] = i
        end
      end
    end
  end

  -- Assemble data into an array of screenInfo tables.
  screenInfos = {}
  for i, screen in pairs(screens) do
    local idx = bestMatches[i]
    local workspace = (idx and self.workspaces[idx] or nil)
    screenInfos[i] = {screen=screen, workspace=workspace}
  end

  return screenInfos
end

function spacetracker:_handleSpaceChange()
  local screenInfos = self:_detectWorkspaces()
  self.onSpaceChange(screenInfos)
end

return spacetracker
