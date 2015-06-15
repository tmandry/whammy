local FakeWorkspace = {}

-- windows is an optional parameter for testing purposes
function FakeWorkspace:new(screen, windows)
  windows = windows or {}
  local obj = {_screen=screen, _windows=windows}
  setmetatable(obj, {__index = self})
  return obj
end

function FakeWorkspace:allWindows()
  return self._windows
end

function FakeWorkspace:isEmpty()
  return #self._windows == 0
end

function FakeWorkspace:addWindow(window)
  table.insert(self._windows, window)
end

function FakeWorkspace:removeWindowById(id)
  for i, win in pairs(self._windows) do
    if win:id() == id then
      table.remove(self._windows, i)
      return true
    end
  end
  return false
end

function FakeWorkspace:setScreen(screen)
  self._screen = screen
end

function FakeWorkspace:screen()
  return self._screen
end

function FakeWorkspace:selectWindow(window)
  self.selection = window
end

function FakeWorkspace:toggleFloating()
end

function FakeWorkspace:toggleFocusMode()
end

return FakeWorkspace
