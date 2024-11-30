-- This event is dispatched to the global Runtime object
-- by `didLoadMain:` in MyCoronaDelegate.mm
local function delegateListener(event)
    native.showAlert(
        "Event dispatched from `didLoadMain:`",
        "of type: " .. tostring(event.name),
        { "OK" })
end
Runtime:addEventListener("delegate", delegateListener)

local ably = require("plugin.AblySolar")

-- Initialize the Ably connection
local client = ably.initWithKey("your-ably-api-key", function(event)
    print("Connection state changed:", event.state)
end)

-- Flag to prevent lifecycle actions during startup
local isAppInitialized = false

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
    
    -- Always call initWithKey to reconnect
    local success, errorMessage = pcall(function()
        client = ably.initWithKey("your-ably-api-key", function(event)
            print("Connection state changed:", event.state)
        end)
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

