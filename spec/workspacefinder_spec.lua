local workspacefinder = require 'wm.workspacefinder'

local FakeScreen    = require 'spec.support.FakeScreen'
local FakeWorkspace = require 'spec.support.FakeWorkspace'
local FakeWindow    = require 'spec.support.FakeWindow'

describe("workspacefinder", function()
  describe("find", function()
    it("returns a screenInfos object for each screen", function()
      local screens = {FakeScreen:new(1), FakeScreen:new(2)}
      local screenInfos = workspacefinder.find({}, screens, {})

      assert.are.equal(#screenInfos, 2)
      assert.are.equal(screenInfos[1].screen, screens[1])
      assert.are.equal(screenInfos[2].screen, screens[2])
    end)

    it("passes a single screenInfos object for one screen", function()
      local screens = {FakeScreen:new(1)}
      local screenInfos = workspacefinder.find({}, screens, {})

      assert.are.equal(#screenInfos, 1)
      assert.are.equal(screenInfos[1].screen, screens[1])
    end)

    it("matches existing workspaces with matching windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(2, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], windows)}
      local screenInfos = workspacefinder.find(workspaces, screens, windows)

      assert.are.equal(screenInfos[1].workspace, workspaces[1])
    end)

    it("doesn't match existing workspaces with no matching windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(2, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], {})}
      local screenInfos = workspacefinder.find(workspaces, screens, windows)

      assert.are.equal(screenInfos[1].workspace, nil)
    end)

    it("doesn't match existing workspaces with fewer than half of known windows", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(3, screens[1])
      local workspaces = {FakeWorkspace:new(screens[1], windows)}
      local screenInfos = workspacefinder.find(workspaces, screens, {windows[1]})

      assert.are.equal(screenInfos[1].workspace, nil)
    end)

    it("picks the best match when multiple workspaces partially match", function()
      local screens = {FakeScreen:new(1)}
      local windows = FakeWindow.makeWindows(3, screens[1])
      local workspaces = {
        FakeWorkspace:new(screens[1], {windows[1]}),
        FakeWorkspace:new(screens[1], {windows[2], windows[3]})
      }
      local screenInfos = workspacefinder.find(workspaces, screens, windows)

      assert.are.equal(screenInfos[1].workspace, workspaces[2])
    end)

    it("handles windows which return nil for :screen()", function()
      -- This is a problem during screen layout changes. The actual behavior doesn't matter, because
      -- everything will be redone when the layout change is complete, but workspacefinder must not
      -- raise an error.

      local screens = {FakeScreen:new(1)}
      local windows = {FakeWindow:new(1, nil)}
      local workspaces = { FakeWorkspace:new(screens[1], {windows[1]}) }

      assert.has_no.errors(function()
        local screenInfos = workspacefinder.find(workspaces, screens, windows)
      end)
    end)
  end)
end)
