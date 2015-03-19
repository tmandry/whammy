local FakeWindowTracker = {}

function FakeWindowTracker:new(watchEvents, handler)
  obj = {
    watchEvents = watchEvents,
    handler = handler,
    started = false
  }

  setmetatable(obj, self)
  return obj
end

function FakeWindowTracker:start()
  self.started = true
end

function FakeWindowTracker:stop()
  self.started = false
end

local function contains(t, el)
  for k, v in pairs(t) do
    if v == el then
      return true
    end
  end
  return false
end

-- To be called in test
function FakeWindowTracker:postEvent(window, event)
  if self.started and contains(self.watchEvents, event) then
    self.handler(window, event)
  end
end

FakeWindowTracker.__index = FakeWindowTracker

return FakeWindowTracker
