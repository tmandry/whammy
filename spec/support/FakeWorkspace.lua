local FakeWorkspace = {}

function FakeWorkspace:new(windows)
  local obj = {windows=windows}
  setmetatable(obj, {__index = self})
  return obj
end

function FakeWorkspace:allWindows()
  return self.windows
end

return FakeWorkspace
