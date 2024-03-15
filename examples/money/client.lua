-- LocalScript running somewhere on the client
local Framework = require(...):Connect() -- Require the framework and connect
local EconomyService = Framework:GetService('EconomyService') -- Get our EconomyService

-- Get the player's money
local money = EconomyService:GetBalance()
print('You have $' .. money)

-- Pickup some money on an event
SomeTrigger.OnPickup:Connect(function(MoneyObject)
    EconomyService:Pickup(MoneyObject)
end)