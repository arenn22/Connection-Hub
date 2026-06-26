--!strict
local ConnectionHub = {}

type Entry = {
	listeners: { (...any) -> () },
	connection: RBXScriptConnection,
}

local Registry: { [Instance]: { [string]: Entry } } = {}

--[[
	Subscribe to an event on a given Instance with a given callback.
 
	Example:
	```lua
		local unsubscribe = ConnectionHub.Subscribe(game:GetService("Players"), "PlayerAdded", function(player)
			print(player.Name .. " joined!")
		end)
 
		-- later, if needed:
		unsubscribe()
	```
 
	@param instance The Instance that owns the event (e.g. Players, a BasePart, a BindableEvent).
	@param eventName The string name of the event property on that instance (e.g. "PlayerAdded", "Touched").
	@param callback Function to run whenever the event fires. Receives whatever arguments the event fires with.
	@return An unsubscribe function. Call it with no arguments to remove this listener.
]]
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

--[[
	Subscribe to an event, but only run the callback the next time it fires,
	then automatically unsubscribe.
 
	Example:
	```lua
		ConnectionHub.SubscribeOnce(workspace, "ChildAdded", function(child)
			print("First child added:", child.Name)
		end)
	```	

	@param instance The Instance that owns the event.
	@param eventName The string name of the event property on that instance.
	@param callback Function to run the first time the event fires.
	@return An unsubscribe function, in case you want to cancel before it ever fires.
]]
function ConnectionHub.SubscribeOnce(instance: Instance, eventName: string, callback: (...any) -> ()): () -> ()
	local unsubscribe: () -> ()

	unsubscribe = ConnectionHub.Subscribe(instance, eventName, function(...)
		unsubscribe()
		callback(...)
	end)

	return unsubscribe
end

--[[
	Returns how many listeners are currently subscribed to a given event on
	a given instance, or 0 if there are none. Useful for debugging, tests,
	or sanity-checking cleanup without exposing the internal registry
	itself.
 
	@param instance The Instance to check.
	@param eventName The string name of the event to check.
	@return The number of active listeners for that event.
]]
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
