-- workspacefinder takes a list of screens and a list of workspaces and attempts to match each
-- screen to a workspace, based on the windows on that screen.

local layout  = require 'wm.layout'
local fnutils = require 'wm.fnutils'

local workspacefinder = {}

local function times(x, num)
  local list = {}
  for i = 1, num do
    table.insert(list, x)
  end
  return list
end

-- Find the workspace on each screen.
--
-- Returns an array of {[screen], [workspace]} for each screen, where workspace is nil if none could
-- be matched.
function workspacefinder.find(workspaces, screens, windows)
  -- Get list of windows for each workspace.
  local workspaceInfo = {}
  for i, workspace in pairs(workspaces) do
    workspaceInfo[i] = {windows = workspace:allWindows(), matches = times(0, #screens)}
  end

  -- Match each window to a workspace if possible.
  for i, win in pairs(windows) do
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
  local screenInfos = {}
  for i, screen in pairs(screens) do
    local idx = bestMatches[i]
    local workspace = (idx and workspaces[idx] or nil)
    screenInfos[i] = {screen=screen, workspace=workspace}
  end

  return screenInfos
end

return workspacefinder
