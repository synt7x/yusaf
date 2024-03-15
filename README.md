# Yet Another Slightly Useful Framework
A Roblox game framework designed to emphasize serverside control over the client, with a focus on speed, security, and safety.

## Installation
Installation and usage of YUSAF is fairly simple Just create a new ModuleScript with the contents of `framework.lua` and require it.
```lua
local Framework = require(...)
```

## Usage
YUSAF focuses on a primary game script that creates services to be used across the game. To instantiate the primary script, call `:Setup` when requiring the module. Here you can setup [Options](#options) to control your instance.
```lua
local Framework = require(...):Setup(<Options>)
```

### Services
When YUSAF is instantiated in the primary script, you can create `Services` which have functions called `Events`. When you create an event, you can control its `Context` and create more events that respond to it.

You can create services using the `:CreateService` method, which takes in a name for the new service.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')
```

On any non-primary script, you can get a service using `:GetService` after you `:Connect` to the framework.
```lua
local Framework = require(...):Connect()
local MyService = Framework:GetService('MyService')
```

### Events
Events can be created on a service whenever you call `:CreateService` in the primary script. You have access to two methods: `Client` and `Server`. Whether a method is accessed on the server or client is called its `Context`. The `Client` method creates a function that can only be called from the client.

```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

MyService:Client('Add', function(Client: Player, a, b)
	return a + b
end)
```
It is important to note that while this function is accessible on the client, the actual function is called on the server. Keep this in mind when designing security around these systems and remember that the client can provide any unsanitized input.

The `Server` method creates a function that can only be called on the server.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

MyService:Server('Add', function(a, b)
	return a + b
end)
```

Calling methods on other scripts is trivial. All you have to do is `:Connect`, call `:GetService`, and access the methods.
```lua
local Framework = require(...):Connect()
local MyService = Framework:GetService('MyService')

local Result = MyService:Add(1, 3) -- 4
```

### Extensions
When you create a client or server event, you can add additional listeners called `Extensions`. There is the `:Log` extension which logs all throughput in an event to the console.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

MyService:Server('Add', function(a, b)
	return a + b
end):Log()
```
The log extension can be added to both server and client contexts.

In client contexts, you can use the `:Validate` extension to bridge the gap between client and server events.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

MyService:Client('EvenNumbers', Framework.Pass):Validate(function(Client, Number)
	return Number % 2 == 0
end)

MyService:Server('EvenNumbers', function(Client, Number)
	print(Number, 'is even!')
end)
```
This example uses the [Framework.Pass](#utilities) utility to skip creating a callback for the client function. The invocation of the client event is ran through both the client and validate events. If the `:Validate` event's return value is truthy, the invocation is passed to the corresponding server event. Here is a LocalScript that utilizes the service created above.
```lua
local Framework = require(...):Connect()
local MyService = Framework:GetService('MyService')

MyService:EvenNumbers(3) -- Will not print on the server
MyService:EvenNumbers(2) -- Will print '2 is even!' on the server
```
The security of the `:Server` event is ensured due to the `:Validate` event occuring on the server, preventing unvalidated events from reaching the server function.

### Utilities
YUSAF provides some utilities to make usage slightly easier. These utilities wrap callbacks to help manage events.

`Framework.Pass` is an empty function that takes no arguments and returns nothing. It can be used when only needing to register extensions such as when using `:Validate`.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

MyService:Client('EvenNumbers', Framework.Pass):Validate(function(Client, Number)
	return Number % 2 == 0
end)
```

`Framework.Agnostic` is a function that removes the `Client: Player` argument for use in `:Client` events that do not depend on it. This can help when reusing functions between server and client.
```lua
local Framework = require(...):Setup()
local MyService = Framework:CreateService('MyService')

function Add(a, b)
    return a + b
end

MyService:Client('Add', Framework.Agnostic(Add))
MyService:Server('Add', Add)
```

## Options
YUSAF options are defined by a Lua table that uses the Options schema.
```lua
type Options = {
	RemoteName: string,
	RemoteBase: RemoteEvent?,
	RemoteParent: Instance,

	Logger: LoggerCallback
}
```
These values can be altered by providing a table with the altered values when calling `:Connect` and `:Setup`. It should be noted that you need to change the remote settings to match in all scripts connected to the same instance.
`RemoteName`: Name of the RemoteEvent created by the framework.
`RemoteBase`: Variable storing the RemoteEvent created by the framework.
`RemoteParent`: Instance that the RemoteEvent is parented to by the framework.
`Logger`: Function that is called when the `:Log` method is registered on a client or server event.