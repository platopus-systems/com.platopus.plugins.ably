
# AblySolar Plugin Documentation

## Overview

The **AblySolar** plugin provides real-time messaging capabilities powered by the [Ably Realtime](https://ably.com/) service. This plugin enables easy integration of real-time features such as publishing, subscribing to events, and connection management in your Solar2D applications.

---

## Features

- **Real-time Messaging:** Publish and subscribe to messages on channels.
- **Connection Management:** Reconnect, close, and monitor connection state changes.
- **Event Subscriptions:** Listen to all events or specific events on a channel.

- **Multi Platform:** Works on iOS, tvOS and Mac Simulator.

---

## Installation

Include the `AblySolar` plugin in your Solar2D project.

Add the following to your `build.settings` file:

```lua
plugins = {
    ["plugin.AblySolar"] = {
        publisherId = "com.platopus.plugins",
    },
}
```

---

## Initialization

### `ably.initWithKey(apiKey, connectionCallback)`

Initializes the Ably client.

#### Parameters:
- `apiKey` (string): Your Ably API key.
- `connectionCallback` (function): A function called when the connection state changes.

#### Example:

```lua
local ably = require("plugin.AblySolar")

local function onConnectionStateChange(event)
    print("Connection state:", event.state)
end

local success = ably.initWithKey("your-ably-api-key", onConnectionStateChange)
if success then
    print("Ably initialized successfully!")
else
    print("Failed to initialize Ably.")
end
```

---

## Channels

### `ably.getChannel(channelName)`

Retrieves a channel by name.

#### Parameters:
- `channelName` (string): Name of the channel.

#### Returns:
- A channel object that can be used for publishing and subscribing.

#### Example:

```lua
local channel = ably.getChannel("testChannel")
```

---

## Publishing Messages

### `ably.publish(channel, eventName, message)`

Publishes a message to a channel.

#### Parameters:
- `channel` (userdata): The channel object.
- `eventName` (string): Name of the event.
- `message` (string): The message to publish.

#### Example:

```lua
local channel = ably.getChannel("testChannel")
local success = ably.publish(channel, "customEvent", "Hello, World!")
if success then
    print("Message published successfully!")
else
    print("Failed to publish message.")
end
```

---

## Subscribing to Messages

### `ably.subscribeAll(channel, callback)`

Subscribes to all messages on a channel.

#### Parameters:
- `channel` (userdata): The channel object.
- `callback` (function): A function that will be called when a message is received.

#### Example:

```lua
local channel = ably.getChannel("testChannel")

ably.subscribeAll(channel, function(event)
    print("Received message:", event.name, event.data)
end)
```

---

### `ably.subscribeEvent(channel, eventName, callback)`

Subscribes to a specific event on a channel.

#### Parameters:
- `channel` (userdata): The channel object.
- `eventName` (string): Name of the event to subscribe to.
- `callback` (function): A function that will be called when the specified event is received.

#### Example:

```lua
local channel = ably.getChannel("testChannel")

ably.subscribeEvent(channel, "customEvent", function(event)
    print("Received event:", event.name, event.data)
end)
```

---

## Connection Management

### `ably.connectionClose()`

Closes the Ably connection.

#### Example:

```lua
ably.connectionClose()
```

---

### `ably.connectionReconnect()`

Reconnects the Ably connection.

#### Example:

```lua
ably.connectionReconnect()
```

---

## Connection States

The connection state changes are passed as `event.state` in the callback provided to `initWithKey`. The possible states are:

- `Initialized`
- `Connecting`
- `Connected`
- `Disconnected`
- `Suspended`
- `Closing`
- `Closed`
- `Failed`

---

## Example Usage

Here’s a complete example to demonstrate the functionality:

```lua
local ably = require("plugin.AblySolar")

local function onConnectionStateChange(event)
    print("Connection state:", event.state)
    if event.state == "Connected" then
        print("Connection established.")
    elseif event.state == "Disconnected" then
        print("Disconnected. Reconnecting...")
        ably.connectionReconnect()
    end
end

local success = ably.initWithKey("your-ably-api-key", onConnectionStateChange)

if success then
    local channel = ably.getChannel("testChannel")

    -- Subscribe to all messages
    ably.subscribeAll(channel, function(event)
        print("Received message:", event.name, event.data)
    end)

    -- Subscribe to a specific event
    ably.subscribeEvent(channel, "customEvent", function(event)
        print("Received event:", event.name, event.data)
    end)

    -- Publish a message
    ably.publish(channel, "customEvent", "Hello, World!")
end
```

---

## Debugging Tips

- Ensure you use the correct Ably API key.
- Monitor the connection state changes using the `onConnectionStateChange` callback.
- Use logging to debug publishing and subscription callbacks.

---

## Version History

### 1.0
- Initial release.
- Supports connection management, publishing, and subscribing to channels.

---

For more information on Ably, visit the [Ably Documentation](https://ably.com/docs/).
