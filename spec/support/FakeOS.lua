local FakeOS = {}

local os = require 'wm.os'

function FakeOS.setup()
  os.uiEvents.applicationActivated   = "AXApplicationActivated"
  os.uiEvents.applicationDeactivated = "AXApplicationDeactivated"
  os.uiEvents.applicationHidden      = "AXApplicationHidden"
  os.uiEvents.applicationShown       = "AXApplicationShown"

  os.uiEvents.mainWindowChanged     = "AXMainWindowChanged"
  os.uiEvents.focusedWindowChanged  = "AXFocusedWindowChanged"
  os.uiEvents.focusedElementChanged = "AXFocusedUIElementChanged"

  os.uiEvents.windowCreated     = "AXWindowCreated"
  os.uiEvents.windowMoved       = "AXWindowMoved"
  os.uiEvents.windowResized     = "AXWindowResized"
  os.uiEvents.windowMinimized   = "AXWindowMiniaturized"
  os.uiEvents.windowUnminimized = "AXWindowDeminiaturized"

  os.uiEvents.elementDestroyed = "AXUIElementDestroyed"
  os.uiEvents.titleChanged     = "AXTitleChanged"
end

return FakeOS
