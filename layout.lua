-- layout is the tree-based layout of a screen. This is where all the focus and movement commands
-- are implemented, except moving windows across screens.
--
-- layout publishes two events:
-- onFocusPastEnd(layout, direction) and onMovePastEnd(layout, node, direction)
-- To use them, set the corresponding attribute on the layout root to your handler function.
--
-- layout is a recursive data structure. The root node (created with :new()) has one child which is
-- the actual top level of the layout tree. This top level node can change.

local fnutils = require 'hs.fnutils'
local utils = require 'wm.utils'

local layout = {}

local direction   = utils.direction
local orientation = utils.orientation
local incrementForDirection   = utils.incrementForDirection
local orientationForDirection = utils.orientationForDirection

local mode = {
  default = 0, stacked = 1, tabbed = 2
}
layout.mode = mode

local function orientationForDirection(d)
  if d == direction.left or d == direction.right then
    return orientation.horizontal
  else
    return orientation.vertical
  end
end

local function incrementForDirection(d)
  if d == direction.left or d == direction.up then
    return -1
  else
    return  1
  end
end

function layout:_new()
  local obj = {
    root = nil,
    parent = nil,
    children = {},
    frame = nil,
    size = 1.0,
    mode = mode.default,

    window = nil,  -- bottom level only
    fullscreen = false,

    orientation = orientation.horizontal,
    selection = nil,
    previousSelection = nil
  }

  setmetatable(obj, {__index = self, __tostring = layout.__tostring})
  return obj
end

-- Creates a new root layout node.
function layout:new(screen)
  -- The root is tied to a screen and is never replaced.
  local root = layout:_new()
  root.screen = screen
  root.selectedParent = nil  -- used to select parent nodes instead of bottom-level nodes
  root.fullscreenNode = nil
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
  parent.size = child.size

  local grandparent = parent.parent or parent.root
  local idx = fnutils.indexOf(grandparent.children, child)
  table.remove(grandparent.children, idx)
  table.insert(grandparent.children, idx, parent)
  if grandparent.selection == child then grandparent.selection = parent end

  child.parent = parent
  child.size = 1.0

  return parent
end

function layout:setDirection(dir)
  self.orientation = dir
  self:_update(self.frame)
end

function layout:addWindow(win)
  -- Only called on root
  self.children[1]:_addWindow(win, nil)
  print("focus window: "..self:_getSelectedNode().window:title())
  self:focusSelection()
end

-- Adds a node to this layout that is moving in the given direction.
-- For example, if the node is moving to the right (from somewhere on the left), pass right as the
-- direction and the node will be added to the left side of the layout.
function layout:addNodeGoingInDirection(node, direction)
  local topLevel = self.children[1]
  local idx
  if incrementForDirection(direction) > 0 then
    idx = 1
  else
    idx = #topLevel.children + 1
  end
  node:_foreachNode(function(node) node.root = self.root end)
  topLevel:_addNode(node, idx)
end

-- Selects a window, coming into this layout from the given direction.
function layout:selectWindowGoingInDirection(direction)
  if self.root.fullscreenNode then
    -- Keep fullscreen node selected
    return
  end
  self.root.selectParent = nil

  if orientationForDirection(direction) == self.orientation then
    if incrementForDirection(direction) > 0 then
      self:_setSelection(self.children[1])
    else
      self:_setSelection(self.children[#self.children])
    end
  end  -- else, keep current selection

  if self.selection then
    self.selection:selectWindowGoingInDirection(direction)
  end
end

-- Toggles the fullscreen state of the selected node. If another node is fullscreen, the selected
-- node will replace that node.
function layout:toggleFullscreen()
  local oldNode = self.root.fullscreenNode
  if oldNode then
    self.root.fullscreenNode = nil
    oldNode:update()
  end
  local selection = self:_getSelectedNode()
  if selection ~= oldNode then
    self.root.fullscreenNode = selection
    selection:update()
  end
end

function layout:splitCurrent(orientation)
  self:_getSelectedNode():_split(orientation)
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

function layout:setMode(mode)
  self:_getSelectedNode().parent:_setMode(mode)
end

function layout:_setMode(newMode)
  if self.mode == newMode then return end

  if newMode == mode.default then
    if self.oldOrientation then
      self.orientation = self.oldOrientation
    end
  else
    if self.mode == mode.default then
      self.oldOrientation = self.orientation
    end

    if     newMode == mode.stacked then
      self.orientation = orientation.vertical
    elseif newMode == mode.tabbed then
      self.orientation = orientation.horizontal
    end
  end

  self.mode = newMode
  self:update()
end

function layout:isEmpty()
  -- called on root
  return #self.children[1].children == 0
end

function layout:allWindows()
  if self.window then
    return {self.window}
  end

  local windows = {}
  for i, c in pairs(self.children) do
    fnutils.concat(windows, c:allWindows())
  end
  return windows
end

function layout:allVisibleWindows()
  if self.window then
    return {self.window}
  end

  local windows = {}
  if self.mode == mode.default then
    for i, c in pairs(self.children) do
      fnutils.concat(windows, c:allVisibleWindows())
    end
  else
    windows = self.selection:allVisibleWindows()
  end
  return windows
end

function layout:removeSelectedWindows()
  local selection = self:_getSelectedNode()
  selection:removeFromParent()
  return selection:allWindows()
end

-- Called on root node to bring all visible windows of the layout to the front.
function layout:bringToFrontAndFocusSelection()
  local selection = self:_getSelectedNode(true)
  local windows = self:allVisibleWindows()

  -- Focus selection first (for user visual identification)
  if selection.window then selection.window:focus() end
  -- Focus other windows
  fnutils.each(windows, function(win)
    if win ~= selection.window then
      win:focus()
    end
  end)
  -- Focus selection last (for final focus)
  if selection.window then selection.window:focus() end
end

function layout:_foreachNode(f)
  f(self)
  for i, child in pairs(self.children) do
    child:_foreachNode(f)
  end
end

local function findIdx(t, f)
  for k, v in pairs(t) do
    if f(v) then return k end
  end
  return nil
end

-- Creates a single-child parent of this node with the given orientation. If a single-child parent
-- already exists, sets its orientation.
function layout:_split(orientation)
  if #self.parent.children == 1 then
    self.parent.orientation = orientation
  else
    local newParent = layout:_newParent(self)
    newParent.orientation = orientation
  end
end

function layout:_addWindow(win)
  if self:_selection() then
    -- Descend down selection path
    self:_selection():_addWindow(win)
  else
    print("adding window: "..win:title())
    if self.parent ~= self.root then
      self.parent:_addWindowToNode(win)
    else
      -- top-level
      self:_addWindowToNode(win)
    end
  end
end

function layout:_addWindowToNode(win)
  local child = layout:_newChild(self)
  child.window = win
  local selectedIdx = fnutils.indexOf(self.children, self.selection) or #self.children
  self:_addNode(child, selectedIdx + 1)
end

-- Adds the given node as a child at the given index.
function layout:_addNode(node, idx)
  if self.root.fullscreenNode then
    self.root.fullscreenNode = nil
  end

  table.insert(self.children, idx, node)
  node.parent = self
  self:_onChildAdded(node, idx)
  self:_setSelection(node)
end

function layout:removeWindowById(id)
  local result = self:_removeWindowById(id)
  self:focusSelection()
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

function layout:removeFromParent()
  if self.parent == self.root then
    -- Top-level node must be replaced
    layout:_newParent(self)
  end
  self:_remove()
end

function layout:focusSelection()
  local sel = self:_getSelectedNode()
  if sel.window then
    sel.window:focus()
    return true
  end
  return false
end

function layout:selectWindow(win)
  if self.window then
    if win == self.window then
      self:_select()
      return true
    end
  else
    for i, child in pairs(self.children) do
      if child:selectWindow(win) then
        return true
      end
    end
  end
  return false
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

  -- Call event callbacks
  if oldParent ~= newParent then
    oldParent:_onChildRemoved(node, oldIdx)
    if newParent then
      newParent:_onChildAdded(node, newIdx)
    else
      node.root:_onNodeRemovedFromLayout(node)
    end
  else
    oldParent:_onChildrenRearranged()
  end
end

function layout:_remove()
  if self.parent == self.root then return end  -- don't delete the top-level node
  if self.root.fullscreenNode == self then
    self.root.fullscreenNode = nil
  end
  _moveNode(self, nil, nil)
end

function layout:_removeLink()
  if self.parent == self.root then return end  -- don't delete the top-level node
  _moveNode(self.children[1], self.parent, fnutils.indexOf(self.parent.children, self))
  -- _moveNode calls _remove automatically
end

function layout:_onChildRemoved(oldChild, oldIdx)
  if self.parent ~= self.root then
    -- Cull self if no children
    if #self.children == 0 then
      self:_remove()
      return
    end

    -- Cull self if only has one child container. This has no effect on window position.
    if #self.children == 1 and #self.children[1].children > 0 then
      self:_removeLink()
      return
    end
  end

  -- Fix selection
  if self.selection == oldChild then
    local defaultSelection = self.children[math.min(oldIdx, #self.children)]
    self:_restoreSelection(defaultSelection)
  end

  -- Fix sizes
  self:_rebalanceChildren(1, #self.children, 1.0, false)

  self:update()
end

function layout:_onChildAdded(newChild, newIdx)
  -- Give the new child the size it would have been if it was previously a child and all children
  -- were equally sized. After calling _rebalanceChildren it will have the size equal to
  -- 1/numChildren, and all windows will have shrunk proportionally to accommodate it.
  if #self.children > 1 then
    newChild.size = 1.0 / (#self.children-1)
  end
  self:_rebalanceChildren(1, #self.children, 1.0, false)

  self:update()
end

function layout:_onChildrenRearranged()
  self:update()
end

function layout:_onNodeRemovedFromLayout(oldNode)
  -- Called on root
  if self.selectParent == oldNode then
    self.selectParent = nil
  end
  if self.fullscreenNode == oldNode then
    self.fullscreenNode = nil
  end
end

function layout:setScreen(screen)
  if self.root.screen ~= screen then
    self.root.screen = screen
    -- Update internal node sizes. Could be faster if we use something that doesn't resize windows.
    self.root:update()
  end
end

function layout:update()
  if self.root == self then
    self:_update(self.screen:frame())
  else
    self:_update(self.frame)
  end
end

-- Recalculates the frames of this node and its descendants, moves windows into place.
function layout:_update(frame)
  if self.root.fullscreenNode == self then
    -- Ignore frame, use screen frame
    frame = self.root.screen:frame()
  else
    self.frame = frame
  end

  if #self.children == 0 then
    -- Bottom-level node
    if self.window then
      self.window:setFrame(frame, 0)
    end
  else
    if self.mode == mode.stacked or self.mode == mode.tabbed then
      -- Children of stacked nodes share the same frame.
      for idx, child in pairs(self.children) do
        child:_update(frame)
      end
    else
      local cursor = (self.orientation == orientation.horizontal) and frame.x or frame.y
      for idx, child in pairs(self.children) do
        local childFrame
        if self.orientation == orientation.horizontal then
          childFrame = {x=cursor, y=frame.y, w=frame.w*child.size, h=frame.h}
          cursor = cursor + childFrame.w
        else
          childFrame = {x=frame.x, y=cursor, w=frame.w, h=frame.h*child.size}
          cursor = cursor + childFrame.h
        end
        child:_update(childFrame)
      end
    end
  end
end

-- Returns the parent and index of the node that is in a certain direction of this one. This could
-- either be a sibling (if direction is in the same orientation as the parent) or a sibling of one
-- of our ancestors (if not). If the top-level node is reached and there is no container in that
-- direction, returns the top-level node with an index out-of-bounds on the side we're trying to go
-- to. Treats the fullscreen node like the top-level node.
function layout:_moveInDirection(direction)
  if not self:_selection() then
    -- Bottom of tree, go up.
    if self.parent and self.parent ~= self.root and self ~= self.root.fullscreenNode then
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
    if self.parent and self.parent ~= self.root and self ~= self.root.fullscreenNode then
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

-- Selects the window in the specified direction of the current selection.
function layout:focus(direction)
  local node, idx = self:_getSelectedNode():_moveInDirection(direction)
  if node and node.children[idx] then
    node:_setSelection(node.children[idx])
    self:focusSelection()
  else
    -- Trying to focus past the end of the top-level container; there is an event for this.
    if self.root.onFocusPastEnd then
      self.root.onFocusPastEnd(self.root, direction)
    end
  end
end

-- Moves the selection in the specified direction.
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
    -- idx is out of bounds; newAncestor is the top-level or fullscreen container.
    if newAncestor.parent ~= self.root then
      -- Fullscreen container; do nothing.
    elseif orientationForDirection(direction) ~= newAncestor.orientation then
      -- The user wants to move perpendicular to the direction of the top-level container.
      -- Create a new top-level container.
      local parent = layout:_newParent(newAncestor)
      parent.orientation = orientationForDirection(direction)
      _moveNode(node, parent, (incrementForDirection(direction) < 0) and 1 or 2)
    elseif node.parent == newAncestor then
      -- Trying to move something past the end of the top-level container; there is an event for this.
      if node ~= self.root.fullscreenNode and self.root.onMovePastEnd then
        self.root.onMovePastEnd(self.root, node, direction)
      end
    else
      -- Move something out of a lower level to the end of the top-level container.
      _moveNode(node, newAncestor, math.max(idx, 1))
    end
  end
  node:_select()
end

-- Gets the lowest-level ancestor that has the orientation. Returns that and the index of the
-- ancestor right below it.
function layout:_findAncestorWithOrientation(orientation)
  if     self.parent == self.root then
    return nil
  elseif self.parent.orientation == orientation then
    local idx = fnutils.indexOf(self.parent.children, self)
    return self.parent, idx
  else
    return self.parent:_findAncestorWithOrientation(orientation)
  end
end

function layout:resize(direction, pct)
  local function isIndexOnEnd(increment, idx, parent)
    return (increment < 0 and idx == 1) or (increment > 0 and idx == #parent.children)
  end

  local orientation = orientationForDirection(direction)
  local increment = incrementForDirection(direction)
  local screenFrame = self.root.screen:frame()

  -- Find the ancestor of the current selection that has the given orientation.
  -- We will resize its child (also an ancestor) by the given amount.
  -- Keep going up if we are at the end of the container.
  local parent = self:_getSelectedNode(), idx
  repeat
    parent, idx = parent:_findAncestorWithOrientation(orientation)
    if parent == nil then return end  -- no such ancestor exists
  until not isIndexOnEnd(increment, idx, parent)
  local child = parent.children[idx]

  -- Child will get all of pct; all siblings in the direction of the resize will share the cut.
  child.size = child.size + pct
  if increment > 0 then
    parent:_rebalanceChildren(idx+1, #parent.children, -pct, true)
  else
    parent:_rebalanceChildren(1, idx-1, -pct, true)
  end

  parent:update()
end

-- Proportionally rebalance the sizes of all children between startIdx and endIdx inclusive to fit
-- in the given size. If relative is true, grow/shrink the current size by size.
function layout:_rebalanceChildren(startIdx, endIdx, size, relative)
  local curSize = 0
  for i = startIdx, endIdx do
    curSize = curSize + self.children[i].size
  end

  local newSize = relative and (curSize + size) or size
  for i = startIdx, endIdx do
    local pct = self.children[i].size / curSize
    self.children[i].size = newSize * pct
  end
end

-- Use this method to get the selection of a node, unless you are deciding where to place a
-- new window inside this node.
function layout:_selection()
  if self.root.selectedParent == self then
    return nil  -- terminate selection path early
  else
    return self.selection
  end
end

-- Gets the bottom-level node that is selected from this node. Takes selectedParent into
-- consideration, if it is a child node.
function layout:_getSelectedNode(ignoreSelectedParent)
  local node = self
  while node.selection and (ignoreSelectedParent or node.root.selectedParent ~= node) do
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

    selection:_onSelected()
  end
end

-- Called when a node is newly selected by its parent (not necessarily the global selection).
function layout:_onSelected()
  print("onSelected: "..tostring(self))
  if self.parent.mode == mode.stacked or self.parent.mode == mode.tabbed then
    -- Bring all windows to front.
    for i, node in pairs(self.children) do
      if node ~= self.selection then
        for j, win in pairs(node:allVisibleWindows()) do
          print("onSelected: focusing "..win:title())
          win:focus()
        end
      end
    end
    if self.selection then
      for j, win in pairs(self.selection:allVisibleWindows()) do
        print("onSelected: focusing "..win:title())
        win:focus()
      end
    end
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

function layout:__tostring()
  if self.window then
    return '<'..self.window:title()..'>'
  else
    str = '['
    if     self.root == self then
      str = str..'R'
    elseif self.mode == mode.default then
      str = str..((self.orientation == orientation.horizontal) and 'H' or 'V')
    elseif self.mode == mode.stacked then
      str = str..'S'
    elseif self.mode == mode.tabbed then
      str = str..'T'
    end

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
