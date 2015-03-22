-- screenlayout keeps track of the OS screen layout as well as the workspace visible on each screen
-- (the current space). It directs events to the active workspace and handles moves of focus and
-- windows bewteen screens.
--
-- screenlayout differs from the window layout in that it is not tree-based and it is not in our
-- control. Moves between screens are handled in a geometric fashion rather than via tree traversal.

local screenlayout = {}

local fnutils       = require 'wm.fnutils'
local os            = require 'wm.os'
local spacetracker  = require 'wm.spacetracker'
local utils         = require 'wm.utils'
local windowtracker = require 'wm.windowtracker'
local workspace     = require 'wm.workspace'

function screenlayout:new()
  local obj = {
    screenInfos = {},  -- Keeps the screen object and visible workspace for each screen.
    workspaces = {},   -- A list of all workspace objects.
    selectedScreenInfo = nil
  }
  setmetatable(obj, {__index = self})

  obj.windowtracker = windowtracker:new(
    {windowtracker.windowCreated, windowtracker.windowDestroyed, windowtracker.mainWindowChanged},
    function(...) obj:_handleWindowEvent(...) end)
  obj.windowtracker:start()

  obj.spacetracker = spacetracker:new(obj.workspaces, function(...) obj:_handleSpaceChange(...) end)

  -- Create initial workspaces for the current space.
  for i, screen in pairs(os.allScreens()) do
    table.insert(obj.screenInfos, {screen=screen})
  end
  obj:_populateWorkspaces()
  obj.selectedScreenInfo = obj.screenInfos[1]

  return obj
end

-- Called by spacetracker with the info on each screen (including which workspace is on it.)
function screenlayout:_handleSpaceChange(screenInfos)
  print("space changed")
  local oldSelectedScreenIdx = self:_getScreenInfoIndex(self.selectedScreenInfo)

  self.screenInfos = screenInfos
  self:_cullWorkspaces()
  self:_populateWorkspaces()

  -- Use the OS behavior to determine which screen should be focused. Default to the last focused screen.
  -- The workspace selection will be updated by a later window event.
  local focusedWindow = os.focusedWindow()
  local screenIdx = focusedWindow and self:_getScreenInfoIndex(focusedWindow:screen()) or nil
  if screenIdx then
    self.selectedScreenInfo = self.screenInfos[screenIdx]
    self.selectedScreenInfo.workspace:selectWindow(focusedWindow)
  else
    self.selectedScreenInfo = self.screenInfos[oldSelectedScreenIdx] or self.screenInfos[1]
    self.selectedScreenInfo.workspace:focusSelection()
  end
  assert(self.selectedScreenInfo, "selectedScreenInfo is nil")

  fnutils.each(self.screenInfos, function(info) info.workspace:setScreen(info.screen) end)
end

-- Remove workspaces that are empty and not visible.
function screenlayout:_cullWorkspaces()
  utils.removeIf(self.workspaces, function(workspace)
    if not workspace:isEmpty() then
      -- Non-empty
      return false
    else
      for j, info in pairs(self.screenInfos) do
        if info.workspace == workspace then
          -- Visible
          return false
        end
      end
      return true
    end
  end)
end

-- Create empty workspaces on screens that don't have one.
function screenlayout:_populateWorkspaces()
  for i, info in pairs(self.screenInfos) do
    if not info.workspace then
      info.workspace = self:_createWorkspace(info.screen)
    end
  end
end

function screenlayout:_handleWindowEvent(win, event)
  local e = os.uiEvents
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
      print("selecting window in workspace: "..win:title())
      self.selectedScreenInfo = self.screenInfos[self:_getWorkspaceIndex(workspace)]
      assert(self.selectedScreenInfo, "selectedScreenInfo is nil")
      workspace:selectWindow(win)
    end
  end
end

-- Called when the user requests to move focus past the end of the current workspace.
function screenlayout:_onFocusPastEnd(workspace, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  local newWorkspace = self.screenInfos[newIdx].workspace
  if newWorkspace then
    self.selectedScreenInfo = self.screenInfos[newIdx]
    newWorkspace:selectWindowGoingInDirection(direction)
    newWorkspace:focusSelection()
  end
  assert(self.selectedScreenInfo, "selectedScreenInfo is nil")
end

-- Called when the user requests to move a node past the end of the current workspace.
function screenlayout:_onMovePastEnd(workspace, node, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)

  node:removeFromParent()

  -- Keep current screen selected, unless it's empty
  if not self.screenInfos[curIdx].workspace:focusSelection() then
    self.selectedScreenInfo = self.screenInfos[newIdx]
    assert(self.selectedScreenInfo, "selectedScreenInfo is nil")
  end

  self.screenInfos[newIdx].workspace:addNodeGoingInDirection(node, direction)
end

function screenlayout:_getScreenInDirection(curIdx, direction)
  -- TODO actually implement
  local newIdx = curIdx + 1
  if newIdx > #self.screenInfos then newIdx = 1 end
  return newIdx
end

function screenlayout:_createWorkspace(screen)
  local workspace = workspace:new(screen)
  workspace.onFocusPastEnd = function(...) self:_onFocusPastEnd(...) end
  workspace.onMovePastEnd = function(...) self:_onMovePastEnd(...) end

  table.insert(self.workspaces, workspace)
  return workspace
end

function screenlayout:_removeWorkspace(screenIdx)
  table.remove(self.workspaces, fnutils.indexOf(self.workspaces, self.screenInfos[screenIdx].workspace))
  self.screenInfos[screenIdx].workspace = nil
end

function screenlayout:_getWorkspaceForWindow(win)
  -- TODO add some bookkeeping to speed this up
  for i, workspace in pairs(self.workspaces) do
    if fnutils.contains(workspace:allWindows(), win) then
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
