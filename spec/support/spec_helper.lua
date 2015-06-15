local assert = require 'luassert.assert'
local say    = require 'say'

local function in_array(state, arguments)
  if not type(arguments[1]) == "table" or #arguments ~= 2 then
    return false
  end

  for k, v in pairs(arguments[1]) do
    if v == arguments[2] then
      return true
    end
  end
  return false
end

say:set("assertion.in_array.positive", "Expected %s \nto have value: %s")
say:set("assertion.in_array.negative", "Expected %s \nto not have value: %s")
assert:register("assertion", "in_array", in_array, "assertion.in_array.positive", "assertion.in_array.negative")
