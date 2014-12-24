local wm = {}

local windowtracker = require('wm.windowtracker')
local layout = require('wm.layout')

wm.layout = layout:new(hs.window.focusedWindow():screen())

wm.tracker = windowtracker:new({}, function(win, event)
  if event == hs.uielement.watcher.windowCreated then
    wm.layout:addWindow(win)
  elseif event == hs.uielement.watcher.elementDestroyed then
    wm.layout:removeWindowById(win:id())
  end
end)
wm.tracker:start()

return wm