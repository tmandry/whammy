local controller = {}

local fnutils         = require 'wm.fnutils'
local os              = require 'wm.os'
local screenlayout    = require 'wm.screenlayout'
local windowtracker   = require 'wm.windowtracker'
local workspacefinder = require 'wm.workspacefinder'

function controller:new()
  local obj = {}
  setmetatable(obj, {__index = self})

  -- The root of our WM tree; all commands are routed through here.
  obj.screenLayout = screenlayout:new(os.allScreens())

  -- Tracks events on windows.
  obj.windowTracker = windowtracker:new(
    {windowtracker.windowCreated, windowtracker.windowDestroyed, windowtracker.mainWindowChanged},
    function(...) obj:_handleWindowEvent(...) end)
  obj.windowTracker:start()

  -- Tracks space changes.
  obj.spaceWatcher = hs.spaces.watcher.new(function() obj:_handleSpaceChange() end)
  obj.spaceWatcher:start()

  -- Tracks screen layout changes.
  obj.screenWatcher = hs.screen.watcher.new(function(...) obj:_handleScreenLayoutChange(...) end)
  obj.screenWatcher:start()

  return obj
end

function controller:_handleWindowEvent(win, event)
  print(event.." on win "..(win and win:title() or "NIL WINDOW"))

  local  e = os.uiEvents
  if     e.windowCreated     == event then
    self.screenLayout:addWindow(win)
  elseif e.elementDestroyed  == event then
    self.screenLayout:removeWindow(win)
  elseif e.mainWindowChanged == event then
    self.screenLayout:selectWindow(win)
  end
end

function controller:_handleSpaceChange()
  -- Get the workspace on each screen and update the screenLayout.
  local screenInfos =
    workspacefinder.find(self.screenLayout:workspaces(), os.allScreens(), os.allVisibleWindows())
  fnutils.each(screenInfos, function(info)
    self.screenLayout:setWorkspaceForScreen(info.screen, info.workspace)
  end)

  -- Use the OS behavior to determine which screen should be focused. Default to the last focused screen.
  -- The workspace selection will be updated by a later window event.
  local focusedWindow = os.focusedWindow()
  if focusedWindow then
    self.screenLayout:selectScreen(focusedWindow:screen())
  end
end

function controller:_handleScreenLayoutChange()
  -- Prep screenLayout with the new set of screens.
  self.screenLayout:updateScreenLayout(os.allScreens())

  -- After that, handle as if it were a space change.
  self:_handleSpaceChange()
end

return controller
