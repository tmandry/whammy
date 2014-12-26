local fnutils = require "hs.fnutils"

local layout = {}

layout.orientation = {
  horizontal = 0,
  vertical = 1
}

layout.direction = {
  left = 0, right = 1, up = 2, down = 3
}

function layout:_new()
  local obj = {
    root = nil,
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

-- Creates a new root layout node.
function layout:new(screen)
  -- The root is tied to a screen and is never replaced.
  local root = layout:_new()
  root.screen = screen
  root.selectedParent = nil  -- used to select parent nodes instead of bottom-level nodes
  root.orientation = nil
  root.root = root

  -- The top level node is where the actual layout tree begins.
  -- It may be replaced, but one will always exist.
  local topLevel = layout:_new()
  topLevel.root = root
  topLevel.parent = root
  topLevel.frame = screen:frame()

  root.children = {topLevel}
  root.selection = topLevel
  return root
end

function layout:_newChild(parent)
  local obj = layout:_new()
  obj.parent = parent
  obj.root = parent.root
  return obj
end

function layout:_newParent(child)
  local parent = layout:_new()
  parent.root = child.root
  parent.parent = child.parent
  parent.children = {child}
  parent.selection = child
  parent.frame = child.frame

  local grandparent = parent.parent or parent.root
  local idx = fnutils.indexOf(grandparent.children, child)
  table.remove(grandparent.children, idx)
  table.insert(grandparent.children, idx, parent)
  if grandparent.selection == child then grandparent.selection = parent end

  child.parent = parent

  return parent
end

function layout:setDirection(dir)
  self.orientation = dir
  self:_update(self.frame)
end

function layout:addWindow(win)
  if self:_selection() then
    -- Descend down selection path
    self:_selection():addWindow(win)
  else
    -- If split flag is true, we split this cell. Otherwise, we add the window to the parent.
    if self.splitNext then
      self:_split(win)
    else
      if self.parent ~= self.root then
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

function layout:selectParent()
  self.selectedParent = self:_getSelectedNode().parent
  if self.selectParent == self.root then
    -- Don't allow selecting root node
    self.selectParent = self.root.children[1]
  end
  hs.alert.show(self.selectedParent)
end

function layout:selectChild()
  local newSelection = self:_getSelectedNode().selection
  if newSelection and #newSelection.children > 0 then
    self.selectedParent = newSelection
  elseif newSelection then
    -- Erase the override and select it normally
    newSelection:_select()
  end
  self:showFocus()
end

function layout:showFocus()
  hs.alert.show(self:_getSelectedNode())
end

function layout:closeSelected()
  local windows = self:_getSelectedNode():allWindows()
  fnutils.each(windows, function(win) win:close() end)
end

function layout:allWindows()
  if self.window then
    return {self.window}
  end
  local windows = {}
  for i, c in pairs(self.children) do
    for j, w in pairs(c:allWindows()) do
      table.insert(windows, w)
    end
  end
  return windows
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
  self.root.selectedParent = nil
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
    newParent:update()
  end
  if oldParent.parent and #oldParent.children == 0 then
    oldParent:_remove()
  elseif oldParent.parent ~= node.root and #oldParent.children == 1 and #oldParent.children[1].children > 0 then
    -- Node now contains just a single container, so it can be culled.
    -- This has no effect on window position.
    oldParent:_removeLink()
  elseif oldParent ~= newParent then
    oldParent:update()
  end
end

function layout:_remove()
  if self.parent == self.root then return end  -- don't delete the top-level node
  _moveNode(self, nil, nil)
end

function layout:_removeLink()
  _moveNode(self.children[1], self.parent, fnutils.indexOf(self.parent.children, self))
  -- _moveNode calls _remove automatically
end

function layout:update()
  -- This is only called on the root node.
  if self.root == self then
    self:_update(self.screen:frame())
  else
    self:_update(self.frame)
  end
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
  if not self:_selection() then
    -- Bottom of tree, go up.
    if self.parent and self.parent ~= self.root then
      return self.parent:_moveInDirection(direction)
    end
    return nil
  end

  local orientation = orientationForDirection(direction)
  local idx = fnutils.indexOf(self.children, self:_selection()) + incrementForDirection(direction)

  if self.orientation == orientation and self.children[idx] then
    -- Set new focus.
    return self, idx
  else
    -- Can't go this way; move up one level and try again.
    if self.parent and self.parent ~= self.root then
      return self.parent:_moveInDirection(direction)
    else
      -- We're already at the top
      if self.orientation == orientation then
        -- Return an out-of-bounds index
        return self, idx
      else
        -- Signal that we tried to go a different direction
        return self, -1
      end
    end
  end
end

function layout:focus(direction)
  self.root.selectedParent = nil
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
    -- Descend down selection path to find final destination.
    local newSibling = newAncestor.children[idx]:_getSelectedNode()
    local newParent  = newSibling.parent
    local newIdx     = fnutils.indexOf(newParent.children, newSibling)
    if incrementForDirection(direction) > 0 or newParent ~= node.parent then
      -- put it to the right of newSibling
      newIdx = newIdx + 1
    end  -- otherwise, put it to the left

    _moveNode(node, newParent, newIdx)
  elseif newAncestor then
    -- newAncestor is the top-level container
    if orientationForDirection(direction) == newAncestor.orientation then
      -- Move something to the end of the top-level container.
      _moveNode(node, newAncestor, math.max(idx, 1))
    else
      -- The user wants to move perpendicular to the direction of the top-level container.
      -- Create a new top-level container.
      local parent = layout:_newParent(newAncestor)
      parent.orientation = orientationForDirection(direction)
      _moveNode(node, parent, (incrementForDirection(direction) < 0) and 1 or 2)
    end
  end
  node:_select()
end

-- Use this method to get the selection of a node, unless you are deciding where to place a new window inside this node.
function layout:_selection()
  if self.root.selectedParent == self then
    return nil  -- terminate selection path early
  else
    return self.selection
  end
end

-- Gets the bottom-level node that is selected from this node. Takes selectedParent into consideration, if it is a
-- child node.
function layout:_getSelectedNode()
  local node = self
  while node.selection and node.root.selectedParent ~= node do
    node = node.selection
  end
  return node
end

-- Ensure that this node is in the selection path.
function layout:_select()
  if self.root.selectedParent ~= self then
    self.root.selectedParent = nil
  end

  local node = self
  while node and node.parent do
    node.parent:_setSelection(node)
    node = node.parent
  end
end

-- Set the current selection path, remembering the previous one.
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
    return '<'..self.window:title()..'>'
  else
    str = '['..((self.orientation == layout.orientation.horizontal) and 'H' or 'V')
    for i, c in pairs(self.children) do
      str = str..' '
      if c == self.selection then str = str..'*' end
      str = str..tostring(c)
    end
    str = str..']'
    return str
  end
end

return layout