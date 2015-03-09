local FakeWindow = {}

function FakeWindow:new(id, screen)
  local obj = {id=id, scr=screen}
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
  return self.id
end

function FakeWindow:screen()
  return self.scr
end

FakeWindow.__index = FakeWindow
FakeWindow.__eq = function(a, b) return a.id == b.id end

return FakeWindow
