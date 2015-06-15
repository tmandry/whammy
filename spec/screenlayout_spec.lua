require 'spec.support.spec_helper'

local screenlayout = require 'wm.screenlayout'
local workspace    = require 'wm.workspace'

local FakeScreen    = require 'spec.support.FakeScreen'
local FakeWorkspace = require 'spec.support.FakeWorkspace'
local FakeWindow    = require 'spec.support.FakeWindow'

describe("screenlayout", function()
  local old, workspaces

  before_each(function()
    old = {}
    workspaces = {}

    old.workspace_new = workspace.new
    workspace.new     = spy.new(function(self, ...)
      local ws = FakeWorkspace:new(...)
      table.insert(workspaces, ws)
      return ws
    end)
  end)

  after_each(function()
    workspace.new = old.workspace_new
  end)

  it("creates a workspace for one screen on startup", function()
    local screens = {FakeScreen:new(1)}
    local sl = screenlayout:new(screens)

    assert.are.equal(1, #sl:workspaces())
    assert.spy(workspace.new).was.called(1)
    assert.spy(workspace.new).was.called_with(workspace, screens[1])
  end)

  it("creates a workspace for two screens on startup", function()
    local screens = {FakeScreen:new(1), FakeScreen:new(2)}
    local sl = screenlayout:new(screens)

    assert.are.equal(2, #sl:workspaces())
    assert.spy(workspace.new).was.called(2)
    assert.spy(workspace.new).was.called_with(workspace, screens[1])
    assert.spy(workspace.new).was.called_with(workspace, screens[2])
  end)

  it("selects a workspace and screen on startup", function()
    local screens = {FakeScreen:new(1)}
    local sl = screenlayout:new(screens)

    assert.are.equal(sl:workspaces()[1], sl:selectedWorkspace())
    assert.are.equal(screens[1], sl:selectedScreen())
  end)

  describe("setWorkspaceForScreen", function()
    it("accepts nil as a workspace and creates a new one on that screen", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})

      local ws = sl:workspaces()[1]
      sl:setWorkspaceForScreen(screen, nil)

      assert.spy(workspace.new).was.called(2)  -- once at creation, once at setWorkspaceForScreen
      local newWs = sl:workspaces()[#sl:workspaces()]
      assert.are_not.equal(ws, newWs)
      assert.are.equal(screen, newWs:screen())
    end)

    it("selects the new workspace if that screen was already selected", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})

      local ws = sl:workspaces()[1]
      assert.are.equal(screen, sl:selectedScreen())
      sl:setWorkspaceForScreen(screen, nil)
      assert.are.equal(sl:workspaces()[1], sl:selectedWorkspace())
    end)

    it("removes the currently selected workspace, if it's empty", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})

      local workspace = sl:workspaces()[1]
      sl:setWorkspaceForScreen(screen, nil)
      assert.is_not.in_array(sl:workspaces(), workspace)
    end)

    it("doesn't remove the currently selected workspace if it isn't empty", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})

      sl:addWindow(FakeWindow:new(1), screen)
      local workspace = sl:workspaces()[1]
      sl:setWorkspaceForScreen(screen, nil)
      assert.is.in_array(sl:workspaces(), workspace)
    end)

    it("changes the screen of the workspace", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local sl = screenlayout:new(screens)

      -- TODO: ws needs to be added to sl already
      local ws = FakeWorkspace:new(screens[1])
      sl:setWorkspaceForScreen(screens[2], ws)
      assert.are.equal(screens[2], ws:screen())
    end)

    it("throws an error if the screen is not recognized", function()
      local screen = FakeScreen:new(1)
      local otherScreen = FakeScreen:new(2)
      local sl = screenlayout:new({screen})

      assert.has_error(function()
        sl:setWorkspaceForScreen(otherScreen, nil)
      end)
    end)
  end)

  describe("addWindow", function()
    it("adds the window to the selected workspace", function()
      local sl = screenlayout:new({FakeScreen:new(1)})

      local window = FakeWindow:new(1, screen)
      sl:addWindow(window)
      assert.is.in_array(sl:workspaces()[1]:allWindows(), window)
    end)
  end)

  describe("removeWindow", function()
    it("removes the window from the correct workspace when active", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})
      local ws = sl:workspaces()[1]

      local window = FakeWindow:new(1, screen)
      sl:addWindow(window)
      sl:removeWindow(window)

      assert.is_not.in_array(ws:allWindows(), window)
    end)

    it("removes the window from the correct workspace when not active", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})
      local ws = sl:workspaces()[1]

      local window = FakeWindow:new(1, screen)
      sl:addWindow(window)
      sl:setWorkspaceForScreen(screen, nil)
      sl:removeWindow(window)

      assert.is_not.in_array(ws:allWindows(), window)
    end)

    it("does nothing if the window is not recognized", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})

      local window = FakeWindow:new(1, screen)
      assert.has_no.errors(function()
        sl:removeWindow(window)
      end)
    end)
  end)

  describe("selectScreen", function()
    it("selects the right screen", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local sl = screenlayout:new(screens)

      sl:selectScreen(screens[1])
      assert.are.equal(screens[1], sl:selectedScreen())
      sl:selectScreen(screens[2])
      assert.are.equal(screens[2], sl:selectedScreen())
    end)

    it("selects the right workspace", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local sl = screenlayout:new(screens)

      sl:selectScreen(screens[1])
      assert.are.equal(screens[1], sl:selectedWorkspace():screen())
      sl:selectScreen(screens[2])
      assert.are.equal(screens[2], sl:selectedWorkspace():screen())
    end)

    it("throws an error if the screen is not recognized", function()
      local screen = FakeScreen:new(1)
      local otherScreen = FakeScreen:new(2)
      local sl = screenlayout:new({screen})

      assert.has_error(function()
        sl:selectScreen(otherScreen)
      end)
    end)
  end)

  describe("selectWindow", function()
    it("selects the screen that corresponds to the window's workspace", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local sl = screenlayout:new(screens)
      local window = FakeWindow:new(1, screens[2])

      sl:selectScreen(screens[2])
      sl:addWindow(window)  -- will be added to screen 2
      sl:selectScreen(screens[1])
      sl:selectWindow(window)

      assert.are.equal(screens[2], sl:selectedWorkspace():screen())
    end)

    it("selects the window in the workspace", function()
      local screen = FakeScreen:new(1)
      local sl = screenlayout:new({screen})
      local window1 = FakeWindow:new(1, screen)
      local window2 = FakeWindow:new(2, screen)

      sl:addWindow(window1)
      sl:addWindow(window2)

      sl:selectWindow(window1)
      assert.equals(window1, sl:selectedWorkspace().selection)
      sl:selectWindow(window2)
      assert.equals(window2, sl:selectedWorkspace().selection)
    end)

    it("does nothing if the window is not in a workspace", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local sl = screenlayout:new(screens)
      local window = FakeWindow:new(1, screens[2])

      assert.has_no_errors(function()
        sl:selectWindow(window)
      end)
      assert.equals(screens[1], sl:selectedScreen())
    end)
  end)
end)
