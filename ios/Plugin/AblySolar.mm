#import <Foundation/Foundation.h>
#import "AblySolar.h"
#import <Ably/Ably.h>
#import <CoronaLua.h>
#import <CoronaMacros.h>

// Keep a global reference to the Ably client to avoid it being deallocated
static ARTRealtime *gAblyClient = nil;

// Function prototypes
static void onConnectionStateChange(ARTConnectionStateChange *stateChange, lua_State *L, int listenerRef);
static int initWithKey(lua_State *L);
static const char *ARTRealtimeConnectionStateToString(ARTRealtimeConnectionState state);

// Helper function to convert ARTRealtimeConnectionState to string
static const char *ARTRealtimeConnectionStateToString(ARTRealtimeConnectionState state) {
    switch (state) {
        case ARTRealtimeConnecting:
            return "Connecting";
        case ARTRealtimeConnected:
            return "Connected";
        case ARTRealtimeDisconnected:
            return "Disconnected";
        case ARTRealtimeSuspended:
            return "Suspended";
        case ARTRealtimeClosed:
            return "Closed";
        case ARTRealtimeFailed:
            return "Failed";
        default:
            return "Unknown";
    }
}

// Listener function that will be triggered on connection state changes
static void onConnectionStateChange(ARTConnectionStateChange *stateChange, lua_State *L, int listenerRef) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, listenerRef); // Push the listener callback onto the stack

    if (lua_isfunction(L, -1)) {
        // Create a Lua table to pass the state and reason
        lua_newtable(L);

        // Add "state" to the table
        lua_pushstring(L, "state");
        lua_pushstring(L, ARTRealtimeConnectionStateToString(stateChange.current)); // Push the state as a string
        lua_settable(L, -3); // Set "state" in the table

        // Add "reason" to the table if available
        if (stateChange.reason) {
            lua_pushstring(L, "reason");
            lua_pushstring(L, [stateChange.reason.message UTF8String]); // Push the error reason
            lua_settable(L, -3); // Set "reason" in the table
        }

        lua_pcall(L, 1, 0, 0); // Call the listener with one argument (the table)
    } else {
        lua_pop(L, 1); // Pop the listener callback if it's not a function
    }
}

// initWithKey function implementation
static int initWithKey(lua_State *L) {
    // Get the 'key' parameter from Lua (at stack index 1)
    const char *apiKey = luaL_checkstring(L, 1);

    // Get the listener function from Lua (at stack index 2)
    luaL_checktype(L, 2, LUA_TFUNCTION); // Ensure the second argument is a function

    // Store the Lua listener reference in the registry
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    // Create the Ably client
    ARTRealtime *client = [[ARTRealtime alloc] initWithKey:[NSString stringWithUTF8String:apiKey]];

    if (!client) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to initialize Ably client.");
        return 2; // Return nil and an error message
    }

    gAblyClient = client; // Store globally to retain it

    // Set the connection state change callback
    [client.connection on:^(ARTConnectionStateChange *stateChange) {
        if (stateChange) {
            onConnectionStateChange(stateChange, L, listenerRef);
        }
    }];

    // Return the client reference to Lua (optional, for chaining further calls)
    lua_pushlightuserdata(L, (__bridge void *)client);
    return 1; // Return the client object
}

// Lua plugin loader
CORONA_EXPORT int luaopen_plugin_AblySolar(lua_State *L) {
    // Create a table to store the plugin functions
    lua_newtable(L);

    // Register the initWithKey function
    lua_pushcfunction(L, initWithKey);
    lua_setfield(L, -2, "initWithKey");

    return 1; // Return the table to Lua
}
