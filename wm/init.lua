local wm = {}

require('wm.os').setup()

local controller = require('wm.controller')

wm.controller = controller:new()

return wm
