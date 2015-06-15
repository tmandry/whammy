local controller = {}

local fnutils       = require 'wm.fnutils'
local os            = require 'wm.os'
local screenlayout  = require 'wm.screenlayout'
local spacetracker  = require 'wm.spacetracker'
local windowtracker = require 'wm.windowtracker'

function controller:new()
  local obj = {}
  setmetatable(obj, {__index = self})

  -- The root of our WM tree; all commands are routed here.
  obj.screenLayout = screenlayout:new(os.allScreens())

  -- Tracks events on windows.
  obj.windowTracker = windowtracker:new(
    {windowtracker.windowCreated, windowtracker.windowDestroyed, windowtracker.mainWindowChanged},
    function(...) obj:_handleWindowEvent(...) end)
  obj.windowTracker:start()

  -- Tracks space changes.
  obj.spaceTracker = spacetracker:new(
    function() return obj.screenLayout:workspaces() end,
    function(...) obj:_handleSpaceChange(...) end)

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

function controller:_handleSpaceChange(screenInfos)
  -- Called by spacetracker with the info on each screen (including which workspace is on it.)
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
  local allScreens = os.allScreens()
  self.screenLayout:updateScreenLayout(allScreens)
end

return controller
