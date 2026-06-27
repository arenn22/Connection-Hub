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

Note that `Subscribe` takes the **instance** and the **event's name as a string**, not the event object itself (e.g. `Players, "PlayerAdded"`, not `Players.PlayerAdded`).

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

Returns `0` if nothing is currently subscribed to that event. This is the only way to inspect ConnectionHub's internal state from outside the module: there is no public registry table to read or write directly.

## API
 
| Method | Returns | Description |
|---|---|---|
| `Subscribe(instance, eventName, callback)` | `() -> ()` | Subscribe to an event of `eventName` on `instance` with `callback`. Reuses an existing connection if one is already shared for this event, otherwise creates one. Returns an `unsubscribe` function. |
| `SubscribeOnce(instance, eventName, callback)` | `() -> ()` | Like `Subscribe`, but automatically unsubscribes after the callback runs once. Returns an unsubscribe function you can call to cancel before it fires if needed. |
| `GetListenerCount(instance, eventName)` | `number` | Returns how many listeners are currently subscribed to this event through ConnectionHub. Returns `0` if there are none. Debug function |

## Behavior and guarantees

- **One connection per `(instance, eventName)` pair.** No matter how many times `Subscribe` is called for the same event, only one real `RBXScriptConnection` is created.
- **Automatic cleanup.** Once every listener for an event has unsubscribed, the connection is disconnected and the internal bookkeeping for that event (and, if applicable, the instance) is removed.
- **Safe to subscribe or unsubscribe from within a listener.** Adding a new subscriber while an event is currently dispatching will not run that new subscriber until the next time the event fires. Removing a listener (including a listener removing itself) while the event is dispatching will not cause other listeners in that same dispatch to be skipped.
- **Arguments are passed through as-is**, including multiple arguments and falsy values (`false`, `nil`), exactly as the underlying event provides them.

## Installation

Add the package in your dependencies with Wally:
`connection-hub = "arenn22/connection-hub@1.0.3"`

Or manually install the file and add to your desired location (suggested to be in ReplicatedStorage)
