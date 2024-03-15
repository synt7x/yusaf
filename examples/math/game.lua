-- The primary game script, which instantiates the framework
local Framework = require(...):Setup() -- Require the framework and instantiate
local MathService = Framework:CreateService('MathService') -- Create our service

-- A shared `Add` function
function Add(a, b)
    return a + b
end

-- Register the `Add` function as a method
MathService:Server('Add', Add)
MathService:Client('Add', Framework.Agnostic(Add))

-- Create a `Power` method for the server
MathService:Server('Power', function(a: number, b: number)
    return a ^ b
end)

-- Create a `SayHiIfEven` method for the client that is validated on the server
MathService:Client('SayHiIfEven', Framework.Pass):Validate(function(Client: Player, Number: number)
    return Number % 2 == 0
end)

-- When the `SayHiIfEven` method is validated, this function will be called
MathService:Server('SayHiIfEven', function(Client: Player, Number: number)
    print('Hi!')
end)