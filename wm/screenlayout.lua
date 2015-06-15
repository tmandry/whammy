-- screenlayout keeps track of the OS screen layout as well as the workspace visible on each screen
-- (the current space). It directs events to the active workspace and handles moves of focus and
-- windows bewteen screens.
--
-- screenlayout differs from the window layout in that it is not tree-based and it is not in our
-- control. Moves between screens are handled in a geometric fashion rather than via tree traversal.

local screenlayout = {}

local fnutils        = require 'wm.fnutils'
local utils          = require 'wm.utils'
local workspace      = require 'wm.workspace'
local windowregistry = require 'wm.windowregistry'

function screenlayout:new(screens)
  local obj = {
    _screenInfos = {},  -- Keeps the screen object and visible workspace for each screen.
    _workspaces  = {},  -- A list of all workspace objects.
    _selectedScreenInfo = nil,
    _windowRegistry = windowregistry:new()
  }
  setmetatable(obj, {__index = self})

  -- Create initial workspaces for the current spaces.
  for i, screen in pairs(screens) do
    table.insert(obj._screenInfos, {screen=screen})
  end
  obj:_populateWorkspaces()
  obj._selectedScreenInfo = obj._screenInfos[1]

  return obj
end

function screenlayout:workspaces()
  return self._workspaces
end

-- Selects the given screen.
function screenlayout:selectScreen(screen)
  local info = self._screenInfos[self:_getScreenInfoIndex(screen)]
  print("screen index "..self:_getScreenInfoIndex(screen).." selected")
  assert(info, "screen not recognized. Was updateScreenLayout not called?")
  self._selectedScreenInfo = info
end

function screenlayout:selectedWorkspace()
  return self._selectedScreenInfo.workspace
end

function screenlayout:selectedScreen()
  return self._selectedScreenInfo.screen
end

-- Forces the selected window to be focused.
function screenlayout:focusSelection()
  self._selectedScreenInfo.workspace:focusSelection()
end

function screenlayout:setWorkspaceForScreen(screen, ws)
  local idx = self:_getScreenInfoIndex(screen)
  assert(idx, "screen not recognized. Was updateScreenLayout not called?")

  local oldWorkspace = self._screenInfos[idx].workspace
  if ws ~= oldWorkspace then
    -- Cull old workspace if it's empty.
    if oldWorkspace:isEmpty() then
      utils.remove(self._workspaces, oldWorkspace)
    end

    if ws == nil then
      ws = self:_createWorkspace(screen)
    else
      ws:setScreen(screen)
    end
    self._screenInfos[idx].workspace = ws
  end
end

-- Remove workspaces that are empty and not visible.
function screenlayout:_cullWorkspaces()
  utils.removeIf(self._workspaces, function(workspace)
    if not workspace:isEmpty() then
      -- Non-empty
      return false
    else
      for j, info in pairs(self._screenInfos) do
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
  for i, info in pairs(self._screenInfos) do
    if not info.workspace then
      info.workspace = self:_createWorkspace(info.screen)
    end
  end
end

-- Adds the window to the currently selected workspace.
function screenlayout:addWindow(win)
  self._windowRegistry:putWindowInWorkspace(win, self._selectedScreenInfo.workspace)
end

-- Removes the window from whatever workspace it is in.
function screenlayout:removeWindow(win)
  self._windowRegistry:removeWindow(win)
end

-- Called when the user requests to move focus past the end of the current workspace.
function screenlayout:_onFocusPastEnd(workspace, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)
  local newWorkspace = self._screenInfos[newIdx].workspace
  if newWorkspace then
    self._selectedScreenInfo = self._screenInfos[newIdx]
    newWorkspace:selectWindowGoingInDirection(direction)
    newWorkspace:focusSelection()
  end
  assert(self._selectedScreenInfo, "selectedScreenInfo is nil")
end

-- Called when the user requests to move a node past the end of the current workspace.
function screenlayout:_onMovePastEnd(workspace, node, direction)
  local curIdx = self:_getWorkspaceIndex(workspace)
  local newIdx = self:_getScreenInDirection(curIdx, direction)

  node:removeFromParent()

  -- Keep current screen selected, unless it's empty
  if not self._screenInfos[curIdx].workspace:focusSelection() then
    self._selectedScreenInfo = self._screenInfos[newIdx]
    assert(self._selectedScreenInfo, "selectedScreenInfo is nil")
  end

  self._windowRegistry:moveNodeGoingInDirection(node, direction, self._screenInfos[newIdx].workspace)
end

function screenlayout:_getScreenInDirection(curIdx, direction)
  -- TODO actually implement
  local newIdx = curIdx + 1
  if newIdx > #self._screenInfos then newIdx = 1 end
  return newIdx
end

function screenlayout:_createWorkspace(screen)
  local workspace = workspace:new(screen)
  workspace.onFocusPastEnd = function(...) self:_onFocusPastEnd(...) end
  workspace.onMovePastEnd = function(...) self:_onMovePastEnd(...) end

  table.insert(self._workspaces, workspace)
  return workspace
end

function screenlayout:_removeWorkspace(screenIdx)
  table.remove(self._workspaces, fnutils.indexOf(self._workspaces, self._screenInfos[screenIdx].workspace))
  self._screenInfos[screenIdx].workspace = nil
end

function screenlayout:_getScreenInfoIndex(screen)
  for i, info in pairs(self._screenInfos) do
    if info.screen == screen then
      return i
    end
  end
end

function screenlayout:_getWorkspaceIndex(workspace)
  for i, info in pairs(self._screenInfos) do
    if info.workspace == workspace then
      return i
    end
  end
end

return screenlayout
