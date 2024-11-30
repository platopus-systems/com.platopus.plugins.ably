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

-----------

local ably = require("plugin.AblySolar")

-- Registry to keep track of subscriptions
local subscriptionRegistry = {}

-- Helper function to add a subscription to the registry
local function addSubscription(channelName, eventName, listener)
    subscriptionRegistry[channelName] = subscriptionRegistry[channelName] or {}
    if eventName then
        subscriptionRegistry[channelName][eventName] = listener
    else
        subscriptionRegistry[channelName].all = listener
    end
end

-- Helper function to restore subscriptions
local function restoreSubscriptions()
    for channelName, subscriptions in pairs(subscriptionRegistry) do
        -- Get the channel again
        local newChannel = ably.getChannel(channelName)
        if not newChannel then
            print("Failed to reacquire channel:", channelName)
        else
            -- Restore "all" subscription
            if subscriptions.all then
                ably.subscribeAll(newChannel, subscriptions.all)
                print("Restored subscription to all messages for channel:", channelName)
            end

            -- Restore specific event subscriptions
            for eventName, listener in pairs(subscriptions) do
                if eventName ~= "all" then
                    ably.subscribeEvent(newChannel, eventName, listener)
                    print("Restored subscription to event:", eventName, "for channel:", channelName)
                end
            end
        end
    end
end

-- Initialize the Ably client
local success = ably.initWithKey(apiKey, function(event)
    print("Connection state changed:", event.state)

    if event.state == "Connected" then
        -- Publish a message upon successful connection
        local publishSuccess = ably.publish(ably.getChannel("testChannel"), "customEvent", "Reconnected!")
        if publishSuccess then
            print("Message published after reconnection!")
        else
            print("Failed to publish message after reconnection.")
        end
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
addSubscription(channelName, nil, function(event)
    print("Received message:", event.name, event.data)
end)

-- Subscribe to a specific event on the channel
ably.subscribeEvent(channel, "customEvent", function(event)
    print("Received event:", event.name, event.data)
end)
addSubscription(channelName, "customEvent", function(event)
    print("Received event:", event.name, event.data)
end)

-- Publish a message
local publishSuccess = ably.publish(channel, "customEvent", "Hello, World!")
if publishSuccess then
    print("Message published successfully!")
else
    print("Failed to publish message.")
end

------------

-- Function to close the Ably connection
local function closeAblyConnection()
    if not isAppInitialized then
        print("App not initialized. Skipping connection close.")
        return
    end

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
    if not isAppInitialized then
        print("App not initialized. Skipping reconnection.")
        return
    end

    print("Reconnecting Ably...")
    
    local success, errorMessage = pcall(function()
        -- Call the plugin's reconnection function
        ably.connectionReconnect()
    end)
    
    if not success then
        print("Error reconnecting Ably:", errorMessage)
    else
        print("Reconnection successful!")
        restoreSubscriptions() -- Restore subscriptions after reconnection
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

