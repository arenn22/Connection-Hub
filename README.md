# ConnectionHub

A small Roblox/Luau module that gives you one shared place to connect to events, so that multiple scripts listening to the same event (for example, several systems all wanting `Players.PlayerAdded`) share a single underlying `RBXScriptConnection` instead of each creating their own.

## Why

It's common in a growing Roblox project for several unrelated systems to each do something like:

```lua
Players.PlayerAdded:Connect(function(player)
	-- system-specific logic
end)
```

Every one of these is a separate connection to the same event. That's wasted overhead, and it gets harder to reason about as a project grows: there's no single place to see who's listening to what, and no easy way to share setup/teardown logic across listeners.

ConnectionHub fixes this by acting as a single point of contact for any event: the first subscriber creates the real connection, every subsequent subscriber reuses it, and the connection is automatically torn down once the last subscriber unsubscribes.

## Usage

```lua
local ConnectionHub = require(path.to.ConnectionHub)
local Players = game:GetService("Players")

local unsubscribe = ConnectionHub.Subscribe(Players, "PlayerAdded", function(player)
	print(player.Name .. " joined!")
end)

-- later, if you no longer want to listen:
unsubscribe()
```

Note that `Subscribe` takes the **instance** and the **event's name as a string**, not the event object itself (e.g. `Players, "PlayerAdded"`, not `Players.PlayerAdded`). See [Why instance + event name instead of the event itself](#why-instance--event-name-instead-of-the-event-itself) for the reason.

### Subscribing to a custom event

This works with any `Instance` and any of its events, not just built-in ones:

```lua
local bindable = Instance.new("BindableEvent")

ConnectionHub.Subscribe(bindable, "Event", function(...)
	print("fired with:", ...)
end)

bindable:Fire("hello")
```

### Listening only once

`SubscribeOnce` behaves like `Subscribe`, but automatically unsubscribes itself after the first time the event fires:

```lua
ConnectionHub.SubscribeOnce(workspace, "ChildAdded", function(child)
	print("first child added:", child.Name)
end)
```

It still returns an unsubscribe function, in case you want to cancel before it has a chance to fire:

```lua
local cancel = ConnectionHub.SubscribeOnce(somePart, "Touched", function(other)
	print("touched by", other.Name)
end)

-- changed your mind, the event hasn't fired yet:
cancel()
```

### Checking how many listeners are registered

```lua
local count = ConnectionHub.GetListenerCount(Players, "PlayerAdded")
```

Returns `0` if nothing is currently subscribed to that event. This is the only way to inspect ConnectionHub's internal state from outside the module — there is no public registry table to read or write directly.

## API

### `ConnectionHub.Subscribe(instance: Instance, eventName: string, callback: (...any) -> ()): () -> ()`

Subscribes `callback` to the named event on `instance`. If this is the first subscriber for that `(instance, eventName)` pair, ConnectionHub connects to the real event; otherwise it reuses the existing connection.

Returns an unsubscribe function. Calling it removes this specific listener. Once the last listener for an event unsubscribes, the underlying connection is disconnected and all related bookkeeping is cleaned up automatically.

Calling the returned unsubscribe function more than once is safe and has no effect after the first call.

### `ConnectionHub.SubscribeOnce(instance: Instance, eventName: string, callback: (...any) -> ()): () -> ()`

Same as `Subscribe`, except `callback` is automatically unsubscribed right after it runs for the first time. Returns an unsubscribe function you can call to cancel early, before the event has fired.

### `ConnectionHub.GetListenerCount(instance: Instance, eventName: string): number`

Returns the number of listeners currently subscribed to `eventName` on `instance` through ConnectionHub. Returns `0` if there are no listeners, including for events nothing has ever subscribed to.

## Behavior and guarantees

- **One connection per `(instance, eventName)` pair.** No matter how many times `Subscribe` is called for the same event, only one real `RBXScriptConnection` is created.
- **Automatic cleanup.** Once every listener for an event has unsubscribed, the connection is disconnected and the internal bookkeeping for that event (and, if applicable, the instance) is removed.
- **Safe to subscribe or unsubscribe from within a listener.** Adding a new subscriber while an event is currently dispatching will not run that new subscriber until the next time the event fires. Removing a listener (including a listener removing itself) while the event is dispatching will not cause other listeners in that same dispatch to be skipped.
- **Arguments are passed through as-is**, including multiple arguments and falsy values (`false`, `nil`), exactly as the underlying event provides them.

## Design notes

### Why instance + event name instead of the event itself

An earlier version of this module keyed its internal registry directly by the `RBXScriptSignal` object (e.g. `Players.PlayerAdded`). This turned out to be unreliable: in Luau, two accesses of the same event can compare equal with `==`, but do not reliably hash to the same slot when used as a table key. In practice this meant calling `Subscribe` on the same event multiple times could silently create multiple separate connections instead of sharing one, defeating the entire purpose of the module.

The fix is to key the internal registry by the owning `Instance` and the event's name as a `string` instead. Both of these hash reliably as table keys in Luau. The actual event object is only ever read once, at the moment a connection needs to be created, and is never used as a key.
