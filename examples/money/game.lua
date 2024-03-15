-- The primary game script, which instantiates the framework
local Framework = require(...):Setup() -- Require the framework and instantiate
local EconomyService = Framework:CreateService('EconomyService') -- Get our service

-- A list of all players and their balances
local Balances = {}

------------------------------------------------------------------
-- TODO: Implement instantiating a player's balance when they join
------------------------------------------------------------------

-- Allow the client to request their balance
EconomyService:Client('GetBalance', function(Client: Player)
    return Balances[Client] or 0
end)

-- Allow the server to add to a player's balance
EconomyService:Server('AddBalance', function(Client: Player, Amount: number)
    Balances[Client] += Amount
end)

-- Allow the player to pickup money on the ground
EconomyService:Client('Pickup', Framework.Pass):Validate(function(Client: Player, MoneyObject)
    -- TODO: Implement ValidateMoney and DistanceFromPlayer
    local Money = ValidateMoney(MoneyObject) -- Get the MoneyObject on the server
    return Money and DistanceFromPlayer(Client, Position) < 5
end)

EconomyService:Server('Pickup', function(Client: Player, MoneyObject)
    EconomyService:AddBalance(Player, MoneyObject.Amount)
    MoneyObject:Destroy()
end)