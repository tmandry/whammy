-- screenlayout keeps track of the OS screen layout as well as the workspace visible on each screen
-- (the current space). It directs events to the active workspace and handles moves of focus and
-- windows bewteen screens.
--
-- screenlayout differs from the window layout in that it is not tree-based and it is not in our
-- control. Moves between screens are handled in a geometric fashion rather than via tree traversal.

local screenlayout = {}

local workspace = require 'wm.workspace'
local spacetracker = require 'wm.spacetracker'
local windowtracker = require 'wm.windowtracker'

function screenlayout:new()
  local obj = {
    screenInfos = {},  -- Keeps the screen object and visible workspace for each screen.
    workspaces = {},   -- A list of all workspace objects.
    selectedScreenInfo = nil
  }
  setmetatable(obj, {__index = self})

  for i, screen in pairs(hs.screen.allScreens()) do
    table.insert(obj.screenInfos, {screen = screen, workspace = nil})
  end

  obj.windowtracker = windowtracker:new(
    {windowtracker.windowCreated, windowtracker.windowDestroyed, windowtracker.mainWindowChanged},
    function(...) obj:_handleWindowEvent(...) end)
  obj.windowtracker:start()

  obj.spacetracker = spacetracker:new(obj.workspaces, function(...) obj:_handleSpaceChange(...) end)

  -- Create initial workspaces for the current space.
  obj:_handleSpaceChange({length = #obj.screenInfos})

  return obj
end

function screenlayout:_handleSpaceChange(visibleWorkspaces)
  -- visibleWorkspaces uses same screen indexes as us, but may contain some nil values.
  assert(visibleWorkspaces.length == #self.screenInfos, "spacetracker returned unexpected number of screens")

  local oldSelectedScreenIdx = self:_getScreenInfoIndex(self.selectedScreenInfo)

  for i = 1, visibleWorkspaces.length do
    -- Remove empty and non-visible workspaces.
    if self.screenInfos[i].workspace and self.screenInfos[i].workspace:isEmpty() then
      self:_removeWorkspace(i)
    end

    -- Update each screen with the visible workspace.
    if visibleWorkspaces[i] then
      self.screenInfos[i].workspace = visibleWorkspaces[i]
    else
      self:_createWorkspace(i)
    end
  end

  -- Use the OS behavior to determine which screen should be focused. Default to the last focused screen.
  -- The workspace will be updated by a window event.
  local focusedWindow = hs.window.focusedWindow()
  local screenIdx = focusedWindow and self:_getScreenInfoIndex(focusedWindow:screen()) or nil
  if screenIdx then
    self.selectedScreenInfo = self.screenInfos[screenIdx]
    -- TODO set workspace selection to match focused window
  else
    self.selectedScreenInfo = self.screenInfos[oldSelectedScreenIdx or 1]
    self.selectedScreenInfo.workspace:focusSelection()
  end
  assert(self.selectedScreenInfo, "selectedScreenInfo is nil")
end

function screenlayout:_handleWindowEvent(win, event)
  local e = hs.uielement.watcher
  print(event.." on win "..(win and win:title() or "NIL WINDOW"))

  if     e.windowCreated     == event then
    self.selectedScreenInfo.workspace:addWindow(win)
  elseif e.elementDestroyed  == event then
    local workspace = self:_getWorkspaceForWindow(win)
    if workspace then workspace:removeWindowById(win:id()) end
  elseif e.mainWindowChanged == event then
    -- Select the correct workspace and tell it to select this window.
    local workspace = self:_getWorkspaceForWindow(win)
    if workspace then
      self.selectedScreenInfo = self.screenInfos[self:_getWorkspaceIndex(workspace)]
      print("selecting window in workspace: "..win:title())
      workspace:selectWindow(win)
    end
  end
end

-- Called when the user requests to move focus past the end of the current workspace.
function screenlayout:_onFocusPastEnd(workspace, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  local workspace = self.screenInfos[newIdx].workspace
  if workspace then
    self.selectedScreenInfo = self.screenInfos[self:_getWorkspaceIndex(workspace)]
    workspace:selectWindowGoingInDirection(direction)
    workspace:focusSelection()
  end
end

-- Called when the user requests to move a node past the end of the current workspace.
function screenlayout:_onMovePastEnd(workspace, node, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)

  node:removeFromParent()

  -- Keep current screen selected, unless it's empty
  if not self.screenInfos[curIdx].workspace:focusSelection() then
    self.selectedScreenInfo = self.screenInfos[newIdx]
  end

  self.screenInfos[newIdx].workspace:addNodeGoingInDirection(node, direction)
end

function screenlayout:_getScreenInDirection(curIdx, direction)
  -- TODO actually implement
  local newIdx = curIdx + 1
  if newIdx > #self.screenInfos then newIdx = 1 end
  return newIdx
end

function screenlayout:_createWorkspace(screenIdx)
  local workspace = workspace:new(self.screenInfos[screenIdx].screen)
  workspace.onFocusPastEnd = function(...) self:_onFocusPastEnd(...) end
  workspace.onMovePastEnd = function(...) self:_onMovePastEnd(...) end

  self.screenInfos[screenIdx].workspace = workspace
  table.insert(self.workspaces, workspace)
  return workspace
end

function screenlayout:_removeWorkspace(screenIdx)
  table.remove(self.workspaces, hs.fnutils.indexOf(self.workspaces, self.screenInfos[screenIdx].workspace))
  self.screenInfos[screenIdx].workspace = nil
end

function screenlayout:_getWorkspaceForWindow(win)
  -- TODO add some bookkeeping to speed this up
  for i, workspace in pairs(self.workspaces) do
    if hs.fnutils.contains(workspace:allWindows(), win) then
      return workspace
    end
  end
end

function screenlayout:_getScreenInfoIndex(screen)
  for i, info in pairs(self.screenInfos) do
    if info.screen == screen then
      return i
    end
  end
end

function screenlayout:_getWorkspaceIndex(workspace)
  for i, info in pairs(self.screenInfos) do
    if info.workspace == workspace then
      return i
    end
  end
end

return screenlayout
