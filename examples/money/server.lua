-- Script running somewhere on the server
local Framework = require(...):Connect() -- Require the framework and connect
local EconomyService = Framework:GetService('EconomyService') -- Get our service

-- Bind to an event
SomethingVerySpecial.Happens:Connect(function(Client: Player)
    EconomyService:AddBalance(Client, 1000) -- Give the player $1000
end)