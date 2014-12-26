--- === windowtracker ===
--- Track all windows on the screen.

local windowtracker = {}

local fnutils = require "hs.fnutils"
local uielement = require "hs.uielement"
local events = uielement.watcher

--- windowtracker:new(events, handler) -> windowtracker
--- Constructor
--- Creates a new tracker for the given events.
---
--- Note that the events windowCreated and elementDestroyed are ALWAYS tracked. You should not specify
--- them in events, only the additional events you want to receive. See hs.uielement.watcher for a
--- list of events. You can only use window events.
---
--- handler receives two arguments: the window object and the event name.
function windowtracker:new(watchEvents, handler)
  obj = {
    appsWatcher = nil,
    watchers = {},
    handler = handler,
    winWatchEvents = watchEvents
  }
  table.insert(obj.winWatchEvents, events.elementDestroyed)

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

  -- TODO we could handle focusedWindowChanged here, if the user wants it
  watcher:start({events.windowCreated})

  -- Watch any windows that already exist
  for i, window in pairs(app:allWindows()) do
    self:_watchWindow(window, starting)
  end
  local wins = app:allWindows()
end

function windowtracker:_handleAppEvent(element, event)
  if event == events.windowCreated then
    self:_watchWindow(element)  -- will call handler and ensure no duplicates
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
    if not starting then
      self.handler(win, events.windowCreated)
    end
  end
end

function windowtracker:_handleWindowEvent(win, event, watcher)
  if win ~= watcher:element() then return end
  if event == events.elementDestroyed then
    self.watchers[win:pid()][win:id()] = nil
  end
  self.handler(watcher:element(), event)
end

return windowtracker