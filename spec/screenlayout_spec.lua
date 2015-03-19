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
  local old = {}

  before_each(function()
    old.workspace_new     = workspace.new
    workspace.new         = spy.new(function() return FakeWorkspace:new({}) end)
    old.windowtracker_new = windowtracker.new
    windowtracker.new     = spy.new(function(self, ...) return FakeWindowTracker:new(...) end)
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

  it("works", function() pending("actual tests") end)
end)
