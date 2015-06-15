require 'spec.support.spec_helper'

local windowregistry = require 'wm.windowregistry'

local FakeScreen    = require 'spec.support.FakeScreen'
local FakeWorkspace = require 'spec.support.FakeWorkspace'
local FakeWindow    = require 'spec.support.FakeWindow'

describe("windowregistry", function()
  local windowRegistry
  before_each(function()
    windowRegistry = windowregistry:new()
  end)

  describe("putWindowInWorkspace", function()
    it("adds a window to the given workspace", function()
      local ws  = FakeWorkspace:new(FakeScreen:new())
      local win = FakeWindow:new(1, ws:screen())

      windowRegistry:putWindowInWorkspace(win, ws)

      assert.is.in_array(ws:allWindows(), win)
    end)

    it("removes the window from workspace it's currently in", function()
      local screen = FakeScreen:new()
      local ws1 = FakeWorkspace:new(screen)
      local ws2 = FakeWorkspace:new(screen)
      local win = FakeWindow:new(1, screen)

      windowRegistry:putWindowInWorkspace(win, ws1)
      windowRegistry:putWindowInWorkspace(win, ws2)

      assert.is.in_array(ws2:allWindows(), win)
      assert.is_not.in_array(ws1:allWindows(), win)
    end)
  end)

  describe("removeWindow", function()
    it("removes a window from the correct workspace", function()
      local ws  = FakeWorkspace:new(FakeScreen:new())
      local win = FakeWindow:new(1, ws:screen())

      windowRegistry:putWindowInWorkspace(win, ws)
      windowRegistry:removeWindow(win)

      assert.is_not.in_array(ws:allWindows(), win)
    end)

    it("does nothing if the window is not in a workspace", function()
      local win = FakeWindow:new(1, FakeScreen:new())

      assert.has_no.errors(function()
        windowRegistry:removeWindow(win)
      end)
    end)
  end)

  describe("getWorkspaceForWindow", function()
    it("returns the workspace for a window that has been added", function()
      local ws  = FakeWorkspace:new(FakeScreen:new())
      local win = FakeWindow:new(1, ws:screen())

      windowRegistry:putWindowInWorkspace(win, ws)

      assert.equals(ws, windowRegistry:getWorkspaceForWindow(win))
    end)

    it("returns nil for a window that has never been added", function()
      local win = FakeWindow:new(1, FakeScreen:new())

      assert.equals(nil, windowRegistry:getWorkspaceForWindow(win))
    end)

    it("returns nil for a window that has been added and then removed", function()
      local ws  = FakeWorkspace:new(FakeScreen:new())
      local win = FakeWindow:new(1, ws:screen())

      windowRegistry:putWindowInWorkspace(win, ws)
      windowRegistry:removeWindow(win)

      assert.equals(nil, windowRegistry:getWorkspaceForWindow(win))
    end)
  end)
end)
