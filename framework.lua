--!strict
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Services: Record<string, ServiceInfo> = {}

type Options = {
	RemoteName: string,
	RemoteBase: RemoteEvent?,
	RemoteParent: Instance,

	Logger: LoggerCallback
}

-- Tables
local Framework = {}
local Internal = {}

type Record<K, V> = {[K]: V}

-- Result
type Ok<T> = { Type: "ok", Value: T }
type Err<E> = { Type: "err", Error: E }
type Result<T, E> = Ok<T> | Err<E>

function Okay<T>(Value: T): Ok<T>
	return { Type = 'ok', Value = Value }
end

function Error<T>(Error: T): Err<T>
	error(Error)
	return { Type = 'err', Error = Error }
end

-- Services
type Context = { Type: "Server" | "Client", ID: number }
type Event<T...> = (Client: Player?, T...) -> any
type Events<T...> = Record<string, Event<T...>>
type ValidationEvent<T...> = (T...) -> Result<string?, string?> | boolean

type RemoteData = {
	Event: string,
	Context: Context,
	Data: {any}
}

type RemoteCallback = (Name: string, Context: Context, ...any) -> ()
type LoggerCallback = RemoteCallback

type Remote = {
	Event: RemoteEvent,
	ClientListeners: Record<string, {RemoteCallback}>,
	ServerListeners: Record<string, {RemoteCallback}>,
	On: (Event: string, Context: Context, Callback: RemoteCallback) -> Result<string?, string?>,
	Once: (Event: string, Context: Context, Callback: RemoteCallback) -> Result<string?, string?>,
	Invoke: (Event: string, Context: Context, ...any) -> Result<string?, string?>,
	Fire: (Event: string, Context: Context, ...any) -> Result<string?, string?>
}

type ServerExtension<T...> = {
	Watch: (self: ServerExtension<T...>, Event<T...>) -> ServerExtension<T...>,
	Log: (self: ServerExtension<T...>) -> ServerExtension<T...>
}

type ClientExtension<T...> = {
	Validate: (self: ClientExtension<T...>, Event<T...>) -> ClientExtension<T...>,
	Log: (self: ClientExtension<T...>) -> ClientExtension<T...>
}

type Service<T...> = {
	Name: string,
	Server: (self: Service<T...>, string, Event<T...>) -> ServerExtension<T...>,
	Client: (self: Service<T...>, string, Event<T...>) -> ClientExtension<T...>
}

type ServiceInfo = {
	Name: string,
	Event: Remote,
	Client: Record<string, boolean>,
	Server: Events<...any>
}

local Options: Options = {
	RemoteName = 'Services',
	RemoteBase = nil,
	RemoteParent = ReplicatedStorage,

	Logger = function(Name: string, Context: Context, ...)
		print(string.format('[%s] Event %s ->', string.upper(Context.Type), Name), ...)
	end,
}

-- Instantiate an instance of the framework
function Framework:Setup(Options: Options?)
	if Options then
		for Index, Option in Options do
			self.Options[Index] = Option
		end
	end

	local Options: Options = self.Options
	local RemoteParent, RemoteName = Options.RemoteParent, Options.RemoteName

	assert(Internal:GetContext().Type == 'Server', 'You can only setup events on the server! Did you mean to call `Connect`?')

	if not RemoteParent:FindFirstChild(RemoteName) and not Options.RemoteBase then
		local RemoteBase = Instance.new('RemoteEvent', RemoteParent)
		local RemoteBinding = Instance.new('BindableEvent', RemoteBase)
		RemoteBase.Name = RemoteName

		RemoteBase.OnServerEvent:Connect(function(Client: Player)
			RemoteBase:FireClient(Client, Services)
		end)

		RemoteBinding.Event:Connect(function(Data: Record<string, ServiceInfo>?)
			if not Data then
				RemoteBinding:Fire(Services)
			end
		end)

		Options.RemoteBase = RemoteBase
	end

	return self
end

-- Connect to the framework
function Framework:Connect(Options: Options?)
	if Options then
		for Index, Option in Options do
			self.Options[Index] = Option
		end
	end

	local Options: Options = self.Options
	local RemoteParent, RemoteName = Options.RemoteParent, Options.RemoteName

	local RemoteBase = RemoteParent:WaitForChild(RemoteName)
	local RemoteBinding = RemoteBase:FindFirstChildOfClass('BindableEvent')

	assert(RemoteBase and RemoteBinding, 'Could not connect to events! Are the options configured correctly? Did you call `Setup`?')

	if Internal:GetContext().Type == 'Server' and RemoteBinding then
		local RequestingServices: boolean = true
		RemoteBinding:Fire()
		RemoteBinding.Event:Connect(function(Data: Record<string, ServiceInfo>?)
			if Data then
				Services = Data
				RequestingServices = false
			end
		end)

		repeat task.wait() until not RequestingServices
	end

	if Internal:GetContext().Type == 'Client' and RemoteBase and RemoteBase:IsA('RemoteEvent') then
		local RequestingServices: boolean = true
		RemoteBase:FireServer()
		RemoteBase.OnClientEvent:Connect(function(Data: Record<string, ServiceInfo>)
			Services = Data
			RequestingServices = false
		end)

		repeat task.wait() until not RequestingServices
	end

	return self
end

-- Create a new service
function Framework:CreateService(Name: string): Service<...any>
	assert(type(Name) == 'string', 'Expected a name when creating service')
	assert(Internal:GetContext().Type == 'Server', 'Services can only be created on the server!')

	Services[Name] = {
		Name = Name,
		Event = Internal:CreateRemote(Name),
		Client = {},
		Server = {}
	}

	return Internal:CreateWrapper(Services[Name])
end

-- Load a created service
function Framework:GetService<T...>(Name: string): Events<T...> | Err<string>
	local Context: Context = Internal:GetContext()
	if not Services[Name] then
		return Error('Service ' .. Name .. ' does not exist')
	end

	if Context.Type == 'Server' then
		return Services[Name].Server
	elseif Context.Type == 'Client' then
		local UnregisteredRemote: Remote = Services[Name].Event
		local Remote: Remote = Internal:RegisterRemote(Name, UnregisteredRemote.Event)
		local ClientEvents: Record<string, boolean> = Services[Name].Client
		local RemoteEvents: Events<T...> = {}

		for Name, Service in ClientEvents do
			RemoteEvents[Name] = function(self, ...)
				local ID: number = math.random(1, 10^8)

				local Request: Context = Internal:CreateContext('Client', ID)
				local Result: {any} = nil

				Remote.Fire(Name, Request, nil, ...)
				Remote.Once(Name, Request, function(Name: string, Context: Context, ...)
					if Request.ID ~= Context.ID then return true end
					Result = table.pack(...)
				end)

				repeat task.wait() until Result
				return table.unpack(Result)
			end
		end

		return RemoteEvents
	end

	return Error('Ambiguous running context when getting service ' .. Name)
end

-- Allow internal monkeypatching
function Framework:Patch(Replacement: Record<string, (...any) -> any>): Result<string?, string?>
	if type(Replacement) ~= 'table' then
		return Error('Expected a table to monkey-patch into `Internal`')
	end

	for Name, Patch in Replacement do
		Internal[Name] = Patch
	end

	return Okay('Successfully patched internal functions'), Internal
end

-- Internal Functions

-- Create a new remote
function Internal:CreateRemote(Name: string): Remote
	local RemoteEvent = Instance.new('RemoteEvent', Framework.Options.RemoteBase)
	RemoteEvent.Name = Name

	return Internal:RegisterRemote(Name, RemoteEvent)
end

-- Establish remote functions
function Internal:RegisterRemote(Name: string, RemoteEvent: RemoteEvent): Remote
	local Remote = {
		Event = RemoteEvent,
		ClientListeners = {},
		ServerListeners = {}
	}

	function Remote.On(Event: string, Context: Context, Callback: RemoteCallback): Result<string?, string?>
		if not Callback then return Error('Expected a callback to register') end
		local Listeners: Record<string, {RemoteCallback}> = Context.Type == 'Server' and Remote.ClientListeners or Remote.ServerListeners

		if not Listeners[Event] then
			Listeners[Event] = { Callback }
			return Okay('Instantiated new remote pipeline')
		end

		table.insert(Listeners[Event], Callback)
		return Okay('Appended to remote pipeline')
	end

	function Remote.Once(Event: string, Context: Context, Callback: RemoteCallback): Result<string?, string?>
		if not Callback then return Error('Expected a callback to register') end
		local Listeners: Record<string, {RemoteCallback}> = Context.Type == 'Server' and Remote.ClientListeners or Remote.ServerListeners

		if not Listeners[Event] then
			Listeners[Event] = {}
		end

		local Index: number = #Listeners[Event] + 1
		local Callback = function(...)
			if not Callback(...) then
				table.remove(Listeners[Event], Index)
			end
		end

		table.insert(Listeners[Event], Callback)
		return Okay('Appended to remote pipeline')
	end

	function Remote.Invoke(Event: string, Context: Context, ...): Result<string?, string?>
		local Listeners: Record<string, {RemoteCallback}> = Context.Type == 'Server' and Remote.ServerListeners or Remote.ClientListeners
		if not Listeners[Event] then
			return Error('Attempted to fire event that does not exist (' .. Event .. ')')
		end

		for i, Connection in Listeners[Event] do
			Connection(Event, Context, ...)
		end

		return Okay('Fired all connected events for ' .. Event)
	end

	function Remote.Fire(Event: string, Context: Context, Client: Player?, ...): Result<string?, string?>
		if Context.Type == 'Server' and Client then
			RemoteEvent:FireClient(Client, {
				Event = Event,
				Context = Context,
				Data = table.pack(...)
			})

			return Okay('Sent message to clients')
		elseif Context.Type == 'Client' then
			RemoteEvent:FireServer({
				Event = Event,
				Context = Context,
				Data = table.pack(...),
			})

			return Okay('Sent message to server')
		end

		return Error('Invalid context')
	end

	if Internal:GetContext().Type == 'Server' then
		RemoteEvent.OnServerEvent:Connect(function(Client: Player, Message: RemoteData)
			Remote.Invoke(Message.Event, Internal:CreateContext('Client', Message.Context.ID), Client, table.unpack(Message.Data))
		end)
	else
		RemoteEvent.OnClientEvent:Connect(function(Message: RemoteData)
			Remote.Invoke(Message.Event, Message.Context, table.unpack(Message.Data))
		end)
	end

	return Remote
end

-- Wrap a callback for use in an Event
function Internal:WrapEvent<T...>(Callback: Event<T...>): RemoteCallback
	return function(Name: string, Context: Context, ...)
		return Callback(...)
	end
end

-- Wrap a method for use in an Event
function Internal:WrapMethod<T...>(Callback: Event<T...>): Event<T...>
	return function(self: any, ...)
		return Callback(...)
	end
end

-- Create a context value from type or ID
function Internal:CreateContext(Type: "Server" | "Client", ID: number?): Context
	return { Type = Type, ID = ID or 0 }
end

-- Invert a context value for sending data back
function Internal:InvertContext(Context: Context): Context
	return {
		Type = if Context.Type == 'Server' then 'Client' else 'Server',
		ID = Context.ID
	}
end

-- Wrap a validation function for use in an Event
function Internal:WrapValidation<T...>(Remote: Remote, Callback: ValidationEvent<T...>): RemoteCallback
	local Context: Context = Internal:GetContext()
	if Context.Type ~= 'Server' then
		error('Validation can only occur on the server!')
	end

	return function(Name: string, Context: Context, ...)
		local Result: Result<string?, string?> | boolean = Callback(...)
		if type(Result) == 'table' and Result.Type or Result then
			Remote.Invoke(Name, Internal.Server, ...)
		end
	end
end

-- Create a wrapper for creating events on a service
function Internal:CreateWrapper<T...>(Info: ServiceInfo): Service<T...>
	local Service = {
		Name = Info.Name
	}

	-- Create a function that is called on the server
	function Service:Server(Name: string, Event: Event<T...>): ServerExtension<T...>
		local Remote: Remote = Info.Event
		local Extension = {}

        Service[Name] = Internal:WrapMethod(Event)
		Info.Server[Name] = Internal:WrapMethod(Event)
		Remote.On(Name, Internal.Client, Internal:WrapEvent(Event))

		-- Client -> Server -> Server
		-- Observe a server event from the server
		-- Invoked every time the event is called
		function Extension:Watch(Event: Event<T...>)
			Remote.On(Name, Internal.Client, Internal:WrapEvent(Event))
			return self
		end

		-- Server -> Server Console
		-- Log all invocations of this server event
		-- The logger function used is configurable under `Options.Logger`
		function Extension:Log()
			Remote.On(Name, Internal.Client, Framework.Options.Logger)
			return self
		end

		return Extension
	end

	-- Create a function that is called from the client
	function Service:Client(Name: string, Event: Event<T...>): ClientExtension<T...>
		local Remote: Remote = Info.Event
		local Extension = {}

		Info.Client[Name] = true
		Remote.On(Name, Internal.Server, function(Name: string, Context: Context, Client: Player, ...)
			Remote.Fire(Name, Internal:InvertContext(Context), Client, Event(Client, ...))
		end)

		-- Client -> Server
		-- Observe and validate a client event from the server
		-- Invoked every time the event crosses from Client -> Server
		-- Invokes the corresponding server event when returning true
		function Extension:Validate(Event: Event<T...>)
			Remote.On(Name, Internal.Server, Internal:WrapValidation(Remote, Event))
			return self
		end

		-- Client -> Server Console
		-- Log all invocations of this client event
		-- The logger configuration is configurable under `Options.Logger`
		function Extension:Log()
			Remote.On(Name, Internal.Server, Framework.Options.Logger)
			return self
		end

		return Extension
	end

	return Service
end

-- Get the current running context
function Internal:GetContext(): Context
	return if RunService:IsServer() then Internal.Server else Internal.Client
end

-- Builtin contexts
Internal.Client = Internal:CreateContext('Client')
Internal.Server = Internal:CreateContext('Server')

-- Utility and options
Framework.Options = Options
Framework.Pass = function() end
Framework.Agnostic = function(Callback: RemoteCallback)
	return function(Client: Player, ...)
		return Callback(...)
	end
end

-- Export framework, excluding internal functions
return Framework