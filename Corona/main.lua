-- This event is dispatched to the global Runtime object
-- by `didLoadMain:` in MyCoronaDelegate.mm
local function delegateListener(event)
    native.showAlert(
        "Event dispatched from `didLoadMain:`",
        "of type: " .. tostring(event.name),
        { "OK" })
end
Runtime:addEventListener("delegate", delegateListener)

local apiKey = "your-ably-api-key"

local ably = require("plugin.AblySolar")

-- Connection states to handle the startup logic better
local isConnected = false
local isAppInitialized = false

-- Queue for publishing messages while waiting for the connection
local messageQueue = {}

-- Helper function to publish a message
local function publishMessage(channelName, eventName, messageData)
    local channel = ably.getChannel(channelName)
    if not isConnected then
        print("Connection not ready. Queuing message:", eventName, messageData)
        table.insert(messageQueue, {channel = channel, event = eventName, data = messageData})
        return false
    end

    local success = ably.publish(channel, eventName, messageData)
    if success then
        print("Message published successfully:", eventName, messageData)
    else
        print("Failed to publish message:", eventName, messageData)
    end
    return success
end

-- Process the queued messages
local function processMessageQueue()
    if not isConnected then return end
    for _, message in ipairs(messageQueue) do
        ably.publish(message.channel, message.event, message.data)
    end
    print("Processed queued messages.")
    messageQueue = {}
end

-- Initialize the Ably client
local success = ably.initWithKey(apiKey, function(event)
    print("Connection state changed:", event.state)

    -- Handle different connection states
    if event.state == "Connecting" then
        print("Connecting to Ably...")
    elseif event.state == "Connected" then
        isConnected = true
        print("Ably connection established.")
        processMessageQueue() -- Process any queued messages

        -- Publish a message upon successful connection
        publishMessage("testChannel", "customEvent", "App successfully connected!")
    elseif event.state == "Disconnected" then
        isConnected = false
        print("Ably connection temporarily disconnected.")
    elseif event.state == "Suspended" then
        isConnected = false
        print("Ably connection suspended. Retrying...")
    elseif event.state == "Failed" then
        isConnected = false
        print("Ably connection failed. Please check your API key or network connection.")
    elseif event.state == "Closed" then
        isConnected = false
        print("Ably connection closed.")
    end
end)

if not success then
    print("Failed to initialize Ably client")
end

-- Get a channel
local channelName = "testChannel"
local channel = ably.getChannel(channelName)

-- Subscribe to all messages on the channel
ably.subscribeAll(channel, function(event)
    print("Received message:", event.name, event.data)
end)

-- Subscribe to a specific event on the channel
ably.subscribeEvent(channel, "customEvent", function(event)
    print("Received event:", event.name, event.data)
end)

-- Publish a message (will be queued if not connected)
if channel then
    local success = ably.publish(channel, "customEvent", "Hello, World!")
    if success then
        print("Message published successfully!")
    else
        print("Failed to publish message.")
    end
else
    print("Failed to get channel.")
end

------------

-- Function to close the Ably connection
local function closeAblyConnection()
    print("Closing Ably connection...")
    local success, errorMessage = pcall(function()
        ably.connectionClose()
    end)
    if not success then
        print("Error closing Ably connection:", errorMessage)
    end
end

-- Function to reconnect Ably (if needed)
local function reconnectAbly()
    print("Reconnecting Ably...")
    local success, errorMessage = pcall(function()
        ably.connectionReconnect()
    end)
    if not success then
        print("Error reconnecting Ably:", errorMessage)
    else
        print("Reconnection successful!")
    end
end

-- Handle app lifecycle events
local function onSystemEvent(event)
    if event.type == "applicationSuspend" then
        -- App is going into the background
        closeAblyConnection()
    elseif event.type == "applicationResume" then
        -- App is coming to the foreground
        reconnectAbly()
    elseif event.type == "applicationExit" then
        -- App is being closed
        closeAblyConnection()
    end
end

-- Add system event listener
Runtime:addEventListener("system", onSystemEvent)

-- Mark app as initialized after a delay
timer.performWithDelay(1000, function()
    isAppInitialized = true
    print("App initialization complete.")
end)
