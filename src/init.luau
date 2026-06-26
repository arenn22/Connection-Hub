--!strict
local ConnectionHub = {}

type Entry = {
	listeners: { (...any) -> () },
	connection: RBXScriptConnection,
}

local Registry: { [Instance]: { [string]: Entry } } = {}

function ConnectionHub.Subscribe(instance: Instance, eventName: string, callback: (...any) -> ()): () -> ()
	local instanceEntries = Registry[instance]

	if not instanceEntries then
		instanceEntries = {}
		Registry[instance] = instanceEntries
	end

	local entry = instanceEntries[eventName]

	if not entry then
		local signal = (instance :: any)[eventName]

		if typeof(signal) ~= "RBXScriptSignal" then
			error(`ConnectionHub.Subscribe: "{eventName}" is not an event on {instance.Name}`)
		end

		local newEntry = {} :: Entry
		newEntry.listeners = {}
		newEntry.connection = signal:Connect(function(...)
			local listeners = table.clone(newEntry.listeners)

			for _, listener in listeners do
				task.spawn(listener, ...)
			end
		end)

		instanceEntries[eventName] = newEntry
		entry = newEntry
	end

	table.insert(entry.listeners, callback)

	return function()
		local index = table.find(entry.listeners, callback)
		if not index then
			return
		end

		table.remove(entry.listeners, index)

		if #entry.listeners > 0 then
			return
		end

		entry.connection:Disconnect()
		instanceEntries[eventName] = nil

		if next(instanceEntries) ~= nil then
			return
		end

		Registry[instance] = nil
	end
end

function ConnectionHub.SubscribeOnce(instance: Instance, eventName: string, callback: (...any) -> ()): () -> ()
	local unsubscribe: () -> ()

	unsubscribe = ConnectionHub.Subscribe(instance, eventName, function(...)
		unsubscribe()
		callback(...)
	end)

	return unsubscribe
end

-- Debug function
function ConnectionHub.GetListenerCount(instance: Instance, eventName: string): number
	local instanceEntries = Registry[instance]
	if not instanceEntries then
		return 0
	end

	local entry = instanceEntries[eventName]
	if not entry then
		return 0
	end

	return #entry.listeners
end

return ConnectionHub
