local FakeWindow = {}

function FakeWindow:new(id, screen)
  local obj = {
    attrs = {
      id       = id,
      screen   = screen,
      title    = "my window",
      visible  = true,
      standard = true
    }
  }
  setmetatable(obj, self)
  return obj
end

function FakeWindow.makeWindows(n, screen)
  local ret = {}
  for i = 1,n do
    table.insert(ret, FakeWindow:new(i, screen))
  end
  return ret
end

function FakeWindow:id()
  return self.attrs.id
end

function FakeWindow:screen()
  return self.attrs.screen
end

function FakeWindow:title()
  return self.attrs.title
end

function FakeWindow:isVisible()
  return self.attrs.visible
end

function FakeWindow:isStandard()
  return self.attrs.standard
end

FakeWindow.__index = FakeWindow
FakeWindow.__eq = function(a, b) return a.attrs.id == b.attrs.id end

return FakeWindow
