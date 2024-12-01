-- This event is dispatched to the global Runtime object
-- by `didLoadMain:` in MyCoronaDelegate.mm
local function delegateListener(event)
    native.showAlert(
        "Event dispatched from `didLoadMain:`",
        "of type: " .. tostring(event.name),
        { "OK" })
end
Runtime:addEventListener("delegate", delegateListener)
-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

local apiKey = "your-ably-key"
local json = require( "json" )
local widget = require( "widget" )

-----------

local ably = require("plugin.AblySolar")

local square = display.newRect( display.contentCenterX*0.5, display.contentCenterY, 100, 100 )  --red square is at the bottom
square:setFillColor( 1, 0, 0 )
square.alpha = 0

local squareTwo = display.newRect( display.contentCenterX*1.5, display.contentCenterY, 100, 100 )  --red square is at the bottom
squareTwo:setFillColor( 0, 1, 0 )
squareTwo.alpha = 0

local squareThree = display.newRect( display.contentCenterX, display.contentCenterY, 100, 100 )  --red square is at the bottom
squareThree:setFillColor( 0, 0 , 1 )
squareThree.alpha = 1



function flash_red()
    square:setFillColor( 1, 0, 0 )
    square.alpha = 1
    transition.fadeOut( square, { time=200 } )
end

function flash_green()
    squareTwo:setFillColor( 0, 1, 0 )
    squareTwo.alpha = 1
    transition.fadeOut( squareTwo, { time=200 } )
end

function flash_blue()
    squareThree:setFillColor( 0, 0, 1 )
    squareThree.alpha = 1
    transition.fadeOut( squareThree, { time=200 } )
end

function buttonOneListener( event )
    if ( "ended" == event.phase ) then
        -- Publish a message upon successful connection
        local publishSuccess = ably.publish(ably.getChannel("testChannel"), "customEvent", "Hello")
        -- if publishSuccess then
        --     print("Message published after reconnection!")
        -- else
        --     print("Failed to publish message after reconnection.")
        -- end
    end
end

-- Create the widget
local buttonOne = widget.newButton(
    {
        label = "Send with Event",
        onEvent = buttonOneListener,
        emboss = false,
        -- Properties for a rounded rectangle button
        shape = "roundedRect",
        width = 300,
        height = 40,
        cornerRadius = 2,
        fillColor = { default={0,0,1}, over={0,0,1,0.4} },
        strokeWidth = 0
    }
)
 

function buttonTwoListener( event )
    if ( "ended" == event.phase ) then
        -- Publish a message upon successful connection
        local publishSuccess = ably.publish(ably.getChannel("testChannel"), "OtherEvent", "Hello")
        -- if publishSuccess then
        --     print("Message published after reconnection!")
        -- else
        --     print("Failed to publish message after reconnection.")
        -- end
    end
end

-- Create the widget
local buttonTwo = widget.newButton(
    {
        label = "Send with Other Event",
        onEvent = buttonTwoListener,
        emboss = false,
        -- Properties for a rounded rectangle button
        shape = "roundedRect",
        width = 300,
        height = 40,
        cornerRadius = 2,
        fillColor = { default={0,0,1}, over={0,0,1,0.4} },
        strokeWidth = 0
    }
)
 
-- Center the button
buttonOne.x = display.contentCenterX
buttonOne.y = (display.contentCenterY/8) * 2

buttonTwo.x = display.contentCenterX
buttonTwo.y = (display.contentCenterY/8) * 4

-- Registry to keep track of subscriptions
local subscriptionRegistry = {}

-- Helper function to add a subscription to the registry
local function addSubscription(channelName, eventName, listener)
    subscriptionRegistry[channelName] = subscriptionRegistry[channelName] or {}
    if eventName then
        print("Adding Subscription to eventName "..eventName)
        subscriptionRegistry[channelName][eventName] = listener
    else
        print("Adding Subscription to All")
        subscriptionRegistry[channelName].all = listener
    end
end

-- Helper function to restore subscriptions
local function restoreSubscriptions()

    print(json.encode( subscriptionRegistry ))

    for channelName, subscriptions in pairs(subscriptionRegistry) do
        -- Get the channel again
        local newChannel = ably.getChannel(channelName)
        if not newChannel then
            print("Failed to reacquire channel:", channelName)
        else
            -- Restore "all" subscription
            if subscriptions.all then
                ably.subscribeAll(newChannel, subscriptions.all)
                print("Restored subscription to all messages for channel:"..channelName)
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
    print("ABLY:"..event.state)
    flash_blue()
    if event.state == "Connected" then

        

        -- -- Publish a message upon successful connection
        -- local publishSuccess = ably.publish(ably.getChannel("testChannel"), "customEvent", "Reconnected!")
        -- if publishSuccess then
        --     print("Message published after reconnection!")
        -- else
        --     print("Failed to publish message after reconnection.")
        -- end
    end

end)

if not success then
    print("Failed to initialize Ably client")
end

-- Get a channel
local channelName = "testChannel"
local channel = ably.getChannel(channelName)

-- Subscribe to all messages on the channel
ably.subscribeAll(channel, flash_green)
addSubscription(channelName, nil, flash_green)

-- Subscribe to a specific event on the channel
ably.subscribeEvent(channel, "customEvent", flash_red)
addSubscription(channelName, "customEvent", flash_red)

-- -- Publish a message
-- local publishSuccess = ably.publish(channel, "customEvent", "Hello, World!")
-- if publishSuccess then
--     print("Message published successfully!")
-- else
--     print("Failed to publish message.")
-- end

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

