-- LocalScript running somewhere on the client
local Framework = require(...):Connect() -- Require the framework and connect
local MathService = Framework:GetService('MathService') -- Get our MathService

local result = MathService:Add(1, 2) -- Let's call this method from the client
assert(result == 3, 'Add(1, 2) == 3') -- Assert that the result is 3

print(result) -- View the result

MathService:SayHiIfEven(2) -- This will be validated on the server
MathService:SayHiIfEven(5) -- This will fail to be validated on the server