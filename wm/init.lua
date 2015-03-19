local wm = {}

require('wm.os').setup()

local screenlayout = require('wm.screenlayout')

wm.screenlayout = screenlayout:new()

return wm
