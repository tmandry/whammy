require('spec.support.FakeOS').setup()

local screenlayout  = require 'wm.screenlayout'
local workspace     = require 'wm.workspace'
local windowtracker = require 'wm.windowtracker'
local spacetracker  = require 'wm.spacetracker'
local os            = require 'wm.os'

local FakeScreen        = require 'spec.support.FakeScreen'
local FakeWorkspace     = require 'spec.support.FakeWorkspace'
local FakeWindow        = require 'spec.support.FakeWindow'
local FakeWindowTracker = require 'spec.support.FakeWindowTracker'

describe("screenlayout", function()
  local old, windowTracker, workspaces

  before_each(function()
    old = {}
    windowTracker = nil
    workspaces = {}

    old.workspace_new = workspace.new
    workspace.new     = spy.new(function(screen)
      local ws = FakeWorkspace:new(screen, {})
      table.insert(workspaces, ws)
      return ws
    end)

    old.windowtracker_new = windowtracker.new
    windowtracker.new     = spy.new(function(self, ...)
      windowTracker = FakeWindowTracker:new(...)
      return windowTracker
    end)

    stub(spacetracker, '_setupWatchers')
  end)

  after_each(function()
    workspace.new     = old.workspace_new
    windowtracker.new = old.windowtracker_new
  end)

  local function setup(screens, visibleWindows)
    stub(os, 'allScreens', screens)
    stub(os, 'allVisibleWindows', visibleWindows)
  end

  it("creates a workspace for one screen on startup", function()
    local screens = {FakeScreen:new(1)}
    setup(screens, {})
    screenlayout:new()
    assert.spy(workspace.new).was.called(1)
    assert.spy(workspace.new).was.called_with(workspace, screens[1])
  end)

  it("creates a workspace for two screens on startup", function()
    local screens = {FakeScreen:new(1), FakeScreen:new(2)}
    setup(screens, {})
    screenlayout:new()
    assert.spy(workspace.new).was.called(2)
    assert.spy(workspace.new).was.called_with(workspace, screens[1])
    assert.spy(workspace.new).was.called_with(workspace, screens[2])
  end)

  it("adds new windows to workspace", function()
    local screen = FakeScreen:new(1)
    setup({screen}, {})
    screenlayout:new()

    local window = FakeWindow:new(1, screen)
    windowTracker:postEvent(window, windowtracker.windowCreated)
    assert.are.same({window}, workspaces[1]:allWindows())
  end)

  it("removes destroyed windows from workspace", function()
    local screen = FakeScreen:new(1)
    setup({screen}, {})
    screenlayout:new()

    local window = FakeWindow:new(1, screen)
    windowTracker:postEvent(window, windowtracker.windowCreated)
    windowTracker:postEvent(window, windowtracker.windowDestroyed)
    assert.are.same({}, workspaces[1]:allWindows())
  end)
end)
