-- Script running somewhere on the server
local Framework = require(...):Connect() -- Require the framework and connect
local MathService = Framework:GetService('MathService') -- Get our service

local result = MathService:Add(3, 4) -- Let's call this method on the server
assert(result == 7, 'Add(3, 4) == 7') -- Make sure the result is correct

local result2 = MathService:Power(2, 3) -- Let's call a method that is only on the server
assert(result2 == 8, 'Power(2, 3) == 8') -- Make sure the result is correct

print(result, result2) -- View the results