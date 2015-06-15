-- windowregistry keeps track of windows and which workspace they are in for screenlayout.

local windowregistry = {}

local fnutils = require 'wm.fnutils'

function windowregistry:new()
  local obj = {
    windowWorkspaces = {}  -- table of workspaces, keyed by window id
  }
  setmetatable(obj, {__index = self})

  return obj
end

-- Adds a window to a workspace, removing it from any other workspace it is in.
function windowregistry:putWindowInWorkspace(win, workspace)
  self:removeWindow(win)

  workspace:addWindow(win)
  self.windowWorkspaces[win:id()] = workspace
end

-- Removes a window from its workspace, if any.
function windowregistry:removeWindow(win)
  local id = win:id()
  local oldWorkspace = self.windowWorkspaces[id]

  if oldWorkspace then
    oldWorkspace:removeWindowById(id)
    self.windowWorkspaces[id] = nil
  end
end

-- Returns the workspace a window is in, or nil.
function windowregistry:getWorkspaceForWindow(win)
  return self.windowWorkspaces[win:id()]
end

-- Calls addNodeGoingInDirection on the new workspace, recording the windows that are moving.
function windowregistry:moveNodeGoingInDirection(node, direction, workspace)
  workspace:addNodeGoingInDirection(node, direction)

  fnutils.each(node:allWindows(), function(win)
    self.windowWorkspaces[win:id()] = workspace
  end)
end

return windowregistry
