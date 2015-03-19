-- Abstracts interaction with OS (via Hammerspoon). This is useful for stubbing out during tests.

local os = {}

function os.allScreens()
  return hs.screen.allScreens()
end

function os.allVisibleWindows()
  return hs.window.allWindows()
end

function os.focusedWindow()
  return hs.window.focusedWindow()
end

os.uiEvents = {}

-- Called at launch in production
function os.setup()
  os.uiEvents = hs.uielement.watcher
end

return os
