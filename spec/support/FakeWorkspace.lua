local FakeWorkspace = {}

-- windows is an optional parameter for testing purposes
function FakeWorkspace:new(screen, windows)
  windows = windows or {}
  local obj = {screen=screen, windows=windows}
  setmetatable(obj, {__index = self})
  return obj
end

function FakeWorkspace:allWindows()
  return self.windows
end

function FakeWorkspace:isEmpty()
  return #self.windows == 0
end

function FakeWorkspace:addWindow(window)
  table.insert(self.windows, window)
end

function FakeWorkspace:removeWindowById(id)
  for i, win in pairs(self.windows) do
    if win:id() == id then
      table.remove(self.windows, i)
      return true
    end
  end
  return false
end

function FakeWorkspace:setScreen(screen)
  self.screen = screen
end

function FakeWorkspace:selectWindow(window)
end

function FakeWorkspace:toggleFloating()
end

function FakeWorkspace:toggleFocusMode()
end

return FakeWorkspace
