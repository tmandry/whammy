--- === windowtracker ===
--- Track all windows on the screen.
---
--- You can watch for the following events:
--- * windowtracker.windowCreated: A window was created.
--- * windowtracker.windowDestroyed: A window was destroyed.
--- * windowtracker.mainWindowChanged: The main window was changed. This is usually the same as the
---   focused window, except for helper dialog boxes like file open windows and the like, which are
---   not reported by this event.
--- * windowtracker.windowMoved: A window was moved.
--- * windowtracker.windowResized: A window was resized.
--- * windowtracker.windowMinimized: A window was minimized.
--- * windowtracker.windowUnminimized: A window was unminimized.

local windowtracker = {}

local fnutils = require 'wm.fnutils'
local os      = require 'wm.os'

windowtracker.windowCreated     = os.uiEvents.windowCreated
windowtracker.windowDestroyed   = os.uiEvents.elementDestroyed
windowtracker.mainWindowChanged = os.uiEvents.mainWindowChanged
windowtracker.windowCreated     = os.uiEvents.windowCreated
windowtracker.windowMoved       = os.uiEvents.windowMoved
windowtracker.windowResized     = os.uiEvents.windowResized
windowtracker.windowMinimized   = os.uiEvents.windowMinimized
windowtracker.windowUnminimized = os.uiEvents.windowUnminimized

--- windowtracker:new(events, handler) -> windowtracker
--- Constructor
--- Creates a new tracker for the given events.
---
--- handler receives two arguments: the window object and the event name.
function windowtracker:new(watchEvents, handler)
  obj = {
    appsWatcher = nil,
    watchers = {},
    handler = handler,
    watchEvents = watchEvents,
    winWatchEvents = {}
  }

  -- Decide which events will be watched on new windows. Exclude events that are watched on the app.
  local nonWindowEvents = {windowtracker.windowCreated, windowtracker.mainWindowChanged}
  for i, event in pairs(watchEvents) do
    if not fnutils.contains(nonWindowEvents, event) then table.insert(obj.winWatchEvents, event) end
  end
  if not fnutils.contains(obj.winWatchEvents, windowtracker.windowDestroyed) then
    table.insert(obj.winWatchEvents, windowtracker.windowDestroyed)  -- always watch this event
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function windowtracker:start()
  self.appsWatcher = hs.application.watcher.new(function(...) self:_handleGlobalAppEvent(...) end)
  self.appsWatcher:start()

  -- Watch any apps that already exist
  local apps = hs.application.runningApplications()
  for i = 1, #apps do
    if apps[i]:title() ~= "Hammerspoon" then
      self:_watchApp(apps[i], true)
    end
  end
end

function windowtracker:stop()
  self.appsWatcher:stop()
  for pid, info in pairs(self.watchers) do
    self:_unwatchApp(pid)
  end
end

function windowtracker:_handleGlobalAppEvent(name, event, app)
  if     event == hs.application.watcher.launched then
    self:_watchApp(app)
  elseif event == hs.application.watcher.terminated then
    self.watchers[app:pid()] = nil
  end
end

function windowtracker:_watchApp(app, starting)
  if not app:isApplication() then return end
  if self.watchers[app:pid()] then return end

  local watcher = app:newWatcher(function(...) self:_handleAppEvent(...) end)
  self.watchers[app:pid()] = {}

  if fnutils.contains(self.watchEvents, windowtracker.mainWindowChanged) then
    watcher:start(
      {windowtracker.windowCreated, windowtracker.mainWindowChanged, os.uiEvents.applicationActivated})
  else
    watcher:start({windowtracker.windowCreated})
  end

  -- Watch any windows that already exist
  for i, window in pairs(app:allWindows()) do
    self:_watchWindow(window, starting)
  end
  local wins = app:allWindows()
end

function windowtracker:_handleAppEvent(element, event)
  print("wt app event: "..event)
  if     event == windowtracker.windowCreated then
    self:_watchWindow(element)  -- will call handler and ensure no duplicates
  elseif event == windowtracker.mainWindowChanged and element:isWindow()
         and element:application() == hs.application.frontmostApplication() then
    self.handler(element, windowtracker.mainWindowChanged)
  elseif event == os.uiEvents.applicationActivated then
    -- Generate a mainWindowChanged event since the application changed.
    self.handler(element:mainWindow(), windowtracker.mainWindowChanged)
  end
end

function windowtracker:_watchWindow(win, starting)
  if not win:isWindow() or not win:isStandard() then return end

  local appWindows = self.watchers[win:application():pid()]
  if not appWindows[win:id()] then
    local watcher = win:newWatcher(function(...) self:_handleWindowEvent(...) end)
    appWindows[win:id()] = true

    watcher:start(self.winWatchEvents)

    -- Track event
    if not starting and fnutils.contains(self.watchEvents, windowtracker.windowCreated) then
      self.handler(win, windowtracker.windowCreated)
    end
  end
end

function windowtracker:_handleWindowEvent(win, event, watcher)
  print("wt win event: "..event.." on "..win:title().." "..win:id())
  if win ~= watcher:element() then return end
  if event == windowtracker.windowDestroyed then
    self.watchers[win:pid()][win:id()] = nil
  end
  if fnutils.contains(self.watchEvents, event) then
    self.handler(watcher:element(), event)
  end
end

return windowtracker
