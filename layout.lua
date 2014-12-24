local fnutils = require "hs.fnutils"

local layout = {}

layout.orientation = {
  horizontal = 0,
  vertical = 1
}

layout.direction = {
  left = 0, right = 1, up = 2, down = 3
}

function layout:new(screen)
  obj = layout:_new()
  obj.screen = screen
  obj.frame = screen:frame()
  return obj
end

function layout:_newChild(parent)
  obj = layout:_new()
  obj.parent = parent
  return obj
end

function layout:_new()
  obj = {
    parent = nil,
    children = {},
    frame = nil,
    screen = nil,  -- top level only
    window = nil,  -- bottom level only

    orientation = layout.orientation.horizontal,
    selection = nil,
    previousSelection = nil,
    splitNext = false
  }

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function layout:setDirection(dir)
  self.orientation = dir
  self:_update(self.frame)
end

function layout:addWindow(win)
  if self.selection then
    self.selection:addWindow(win)
  else
    -- If split flag is true, we split this cell. Otherwise, we add the window to the parent.
    if self.splitNext then
      self:_split(win)
    else
      if self.parent then
        self.parent:_addWindow(win)
      else
        -- top-level
        self:_addWindow(win)
      end
    end
  end
  self:_focusSelection()
end

function layout:splitCurrent(orientation)
  local selection = self:_getSelectedNode()
  selection.orientation = orientation
  if #selection.children > 0 then
    selection:_update(selection.frame)
  else
    selection.splitNext = true
  end
end

local function findIdx(t, f)
  for k, v in pairs(t) do
    if f(v) then return k end
  end
  return nil
end

function layout:_split(win)
  local newParent = layout:_newChild(self.parent)
  local parentIdx = fnutils.indexOf(self.parent.children, self)
  self.parent.children[parentIdx] = newParent
  self.parent:_setSelection(newParent)
  self.parent = newParent

  local sibling = layout:_newChild(newParent)
  sibling.window = win

  newParent.children = {self, sibling}
  newParent.orientation = self.orientation
  newParent:_setSelection(sibling)
  newParent:_update(self.frame)

  self.splitNext = false
end

function layout:_addWindow(win)
  local child = layout:_newChild(self)
  child.window = win
  local selectedIdx = fnutils.indexOf(self.children, self.selection) or #self.children
  table.insert(self.children, selectedIdx+1, child)
  self:_update(self.frame)
  self:_setSelection(child)
end

function layout:removeWindowById(id)
  local result = self:_removeWindowById(id)
  self:_focusSelection()
  return result
end

function layout:_removeWindowById(id)
  if self.window and self.window:id() == id then
    self:_remove()
    return true
  end

  for idx, child in pairs(self.children) do
    if child:_removeWindowById(id) then
      return true
    end
  end
  return false
end

function layout:_focusSelection()
  local sel = self:_getSelectedNode()
  if sel.window then sel.window:focus() end
end

-- Moves a node from its current location to a new index in a new parent.
-- The new parent can be the same as the old parent, or nil, in which case the node is removed.
-- The new index should refer to an accurate location in the newParent BEFORE the call. So
-- if you are moving a node to a higher index in the same parent, the effective index after the
-- call will be one less than newIdx.
local function _moveNode(node, newParent, newIdx)
  local oldParent = node.parent

  -- Move the node
  local oldIdx = fnutils.indexOf(oldParent.children, node)
  table.remove(oldParent.children, oldIdx)
  if newParent == oldParent and oldIdx < newIdx then newIdx = newIdx - 1 end
  if newParent then
    table.insert(newParent.children, newIdx, node)
  end
  if newParent == oldParent and newIdx < oldIdx then oldIdx = oldIdx + 1 end  -- used for selection
  node.parent = newParent

  -- Fix selection
  if oldParent ~= newParent and oldParent.selection == node then
    local defaultSelection = oldParent.children[math.min(oldIdx, #oldParent.children)]
    oldParent:_restoreSelection(defaultSelection)
  end

  -- Update state
  if newParent then
    newParent:_update(newParent.frame)
  end
  if #oldParent.children == 0 and not oldParent.screen then
    oldParent:_remove()
  elseif oldParent ~= newParent then
    oldParent:_update(oldParent.frame)
  end
end

function layout:_remove()
  _moveNode(self, nil, nil)
end

function layout:update()
  -- This is only called on the top-level node.
  self:_update(self.screen:frame())
end

-- Recalculates the frames of this node and its descendants, moves windows into place.
function layout:_update(frame)
  self.frame = frame

  if #self.children == 0 then
    -- Bottom-level node
    if self.window then
      self.window:setFrame(frame, 0)
    end
  else
    local cursor = (self.orientation == layout.orientation.horizontal) and frame.x or frame.y
    for idx, child in pairs(self.children) do
      local childFrame
      if self.orientation == layout.orientation.horizontal then
        childFrame = {x=cursor, y=frame.y, w=frame.w/#self.children, h=frame.h}
        cursor = cursor + childFrame.w
      else
        childFrame = {x=frame.x, y=cursor, w=frame.w, h=frame.h/#self.children}
        cursor = cursor + childFrame.h
      end
      child:_update(childFrame)
    end
  end
end

local function orientationForDirection(d)
  if d == layout.direction.left or d == layout.direction.right then
    return layout.orientation.horizontal
  else
    return layout.orientation.vertical
  end
end

local function incrementForDirection(d)
  if d == layout.direction.left or d == layout.direction.up then
    return -1
  else
    return  1
  end
end

-- Returns the container that is in a certain direction of this one. This could either be a sibling
-- (if direction is in the same orientation as the parent) or a sibling of one of our ancestors (if not).
-- If the top-level node is reached and there is no container in that direction, returns the top-level
-- node with an index out-of-bounds on the side we're trying to go to.
function layout:_moveInDirection(direction)
  if not self.selection then
    if self.parent then return self.parent:_moveInDirection(direction) end
    return nil
  end

  local orientation = orientationForDirection(direction)
  local idx = fnutils.indexOf(self.children, self.selection)
  local increment = incrementForDirection(direction)
  if self.orientation == orientation then idx = idx + increment end

  if self.orientation ~= orientation or self.children[idx] == nil then
    -- Can't go this way; move up one level and try again.
    if self.parent then
      return self.parent:_moveInDirection(direction)
    else
      -- If we're already at the top, return an out-of-bounds index.
      return self, idx
    end
  else
    -- Set new focus.
    return self, idx
  end
end

function layout:focus(direction)
  local node, idx = self:_getSelectedNode():_moveInDirection(direction)
  if node and node.children[idx] then
    node:_setSelection(node.children[idx])
    self:_focusSelection()
  end
end

function layout:move(direction)
  local node = self:_getSelectedNode()
  local newAncestor, idx = node:_moveInDirection(direction)
  if newAncestor and newAncestor.children[idx] then
    -- Descend down selection path to find final destination
    local newSibling = newAncestor.children[idx]:_getSelectedNode()
    local newParent  = newSibling.parent
    local newIdx     = fnutils.indexOf(newParent.children, newSibling)
    if incrementForDirection(direction) > 0 or newParent ~= node.parent then
      newIdx = newIdx + 1
    end

    _moveNode(node, newParent, newIdx)
  elseif newAncestor then
    -- Add node to outer edge of ancestor
    -- TODO handle auto-creation of a new parent
    if idx < 1 then return end
    _moveNode(node, newAncestor, idx)
  end
  node:_select()
end

function layout:_select()
  local node = self
  while node and node.parent do
    node.parent:_setSelection(node)
    node = node.parent
  end
end

function layout:_getSelectedNode()
  local node = self
  while node.selection do
    node = node.selection
  end
  return node
end

-- Set the current selection, remembering the previous one.
function layout:_setSelection(selection)
  if selection ~= self.selection then
    if fnutils.contains(self.children, self.selection) then  -- don't overwrite previousSelection with not-a-child
      self.previousSelection = self.selection
    end
    self.selection = selection
  end
end

-- Pick a different selection now that the old one is gone.
function layout:_restoreSelection(default)
  if self.previousSelection and
     fnutils.contains(self.children, self.previousSelection) then
    self.selection = self.previousSelection
  elseif default then
    self.selection = default
  else
    self.selection = self.children[#self.children]
  end
end

function layout:_containsPoint(point)
  return point.x >= rect.x and point.x < (rect.x+rect.w) and point.y >= rect.y and point.y < (rect.y+rect.h)
end

function layout:__tostring()
  -- return '[x='..self.frame.x..',y='..self.frame.y..',w='..self.frame.w..',h='..self.frame.h..']'
  if self.window then
    return self.window:title()
  else
    str = '['..((self.orientation == layout.orientation.horizontal) and 'H' or 'V')
    for i, c in pairs(self.children) do
      str = str..' '
      if c == self.selection then str = str..'*' end
      str = str..'<'..tostring(c)..'>'
    end
    str = str..']'
    return str
  end
end

return layout