-- This event is dispatched to the global Runtime object
-- by `didLoadMain:` in MyCoronaDelegate.mm
local function delegateListener( event )
	native.showAlert(
		"Event dispatched from `didLoadMain:`",
		"of type: " .. tostring( event.name ),
		{ "OK" } )
end
Runtime:addEventListener( "delegate", delegateListener )



local AblySolar = require("plugin.AblySolar")

-- Initialize the Ably client
local client = AblySolar.initWithKey("your-ably-api-key", function(event)
    if event.state == "Connected" then
        print("Ably Connected")
    elseif event.state == "Failed" then
        print("Ably Connection Failed - Reason: " .. (event.reason or "unknown"))
    else
        print("Ably State changed: " .. event.state)
    end
end)
