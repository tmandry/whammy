local spacetracker = require 'wm.spacetracker'
local os           = require 'wm.os'

local FakeScreen    = require 'spec.support.FakeScreen'
local FakeWorkspace = require 'spec.support.FakeWorkspace'
local FakeWindow    = require 'spec.support.FakeWindow'

describe("spacetracker", function()
  before_each(function()
    stub(spacetracker, '_setupWatchers')
  end)

  local function setup(screens, visibleWindows)
    stub(os, 'allScreens', screens)
    stub(os, 'allVisibleWindows', visibleWindows)
  end

  -- spacetracker expects a function that always returns the current list of workspaces; this builds
  -- such a function with a static table of workspaces.
  local function workspaceFn(val)
    local function f() return val end
    return f
  end

  describe("on space change", function()
    local screenInfos = nil
    local handler = nil
    before_each(function()
      screenInfos = nil
      handler = spy.new(function(x) screenInfos = x end)
    end)

    it("calls the given handler function", function()
      setup({}, {})
      local t = spacetracker:new(workspaceFn({}), handler)

      t:_handleSpaceChange()

      assert.spy(handler).was.called()
    end)

    it("passes a screenInfo object for each screen", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      setup(screens, {})
      local t = spacetracker:new(workspaceFn({}), handler)

      t:_handleSpaceChange()

      assert.spy(handler).was.called()
      assert.are.equal(#screenInfos, 2)
      assert.are.equal(screenInfos[1].screen, screens[1])
      assert.are.equal(screenInfos[2].screen, screens[2])
    end)

    it("passes a single screenInfo object for one screen", function()
      local screens = {FakeScreen:new(1)}
      setup(screens, {})
      local t = spacetracker:new(workspaceFn({}), handler)

      t:_handleSpaceChange()

      assert.spy(handler).was.called()
      assert.are.equal(#screenInfos, 1)
      assert.are.equal(screenInfos[1].screen, screens[1])
    end)

    it("matches existing workspaces with matching windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(2, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], windows)}
      setup(screens, windows)
      local t = spacetracker:new(workspaceFn(workspaces), handler)

      t:_handleSpaceChange()

      assert.are.equal(screenInfos[1].workspace, workspaces[1])
    end)

    it("doesn't match existing workspaces with no matching windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(2, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], {})}
      setup(screens, windows)
      local t = spacetracker:new(workspaceFn(workspaces), handler)

      t:_handleSpaceChange()

      assert.are.equal(screenInfos[1].workspace, nil)
    end)

    it("doesn't match existing workspaces with fewer than half of known windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(3, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], windows)}
      setup(screens, {windows[1]})
      local t = spacetracker:new(workspaceFn(workspaces), handler)

      t:_handleSpaceChange()

      assert.are.equal(screenInfos[1].workspace, nil)
    end)

    it("picks the best match when multiple workspaces partially match", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(3, screens[1])
      local workspaces = {
        FakeWorkspace:new(screens[1], {windows[1]}),
        FakeWorkspace:new(screens[1], {windows[2], windows[3]})
      }
      setup(screens, windows)
      local t = spacetracker:new(workspaceFn(workspaces), handler)

      t:_handleSpaceChange()

      assert.are.equal(screenInfos[1].workspace, workspaces[2])
    end)
  end)
end)
