local FakeScreen = {}

function FakeScreen:new(id)
  local obj = {id=id}
  setmetatable(obj, self)
  return obj
end

function FakeScreen:id()
  return self.id
end

FakeScreen.__index = FakeScreen
FakeScreen.__eq = function(a, b) return a.id == b.id end

return FakeScreen
