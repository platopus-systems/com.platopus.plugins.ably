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
static int connectionClose(lua_State *L);
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
    const char *apiKey = luaL_checkstring(L, 1);

    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    ARTClientOptions *options = [[ARTClientOptions alloc] initWithKey:[NSString stringWithUTF8String:apiKey]];
    options.autoConnect = YES; // Enable auto-connect

    ARTRealtime *client = [[ARTRealtime alloc] initWithOptions:options];
    if (!client) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to initialize Ably client.");
        return 2;
    }

    gAblyClient = client;

    [client.connection on:^(ARTConnectionStateChange *stateChange) {
        if (stateChange) {
            onConnectionStateChange(stateChange, L, listenerRef);
        }
    }];

    lua_pushlightuserdata(L, (__bridge void *)client);
    return 1;
}

// connectionClose function implementation
static int connectionClose(lua_State *L) {
    if (gAblyClient) {
        [gAblyClient.connection close];
        [gAblyClient.connection on:ARTRealtimeConnectionEventClosed callback:^(ARTConnectionStateChange *stateChange) {
            NSLog(@"Ably connection explicitly closed.");
        }];
        lua_pushboolean(L, 1); // Return true to Lua to indicate success
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, "Ably client is not initialized.");
        return 2; // Return nil and an error message
    }
}

// Lua plugin loader
CORONA_EXPORT int luaopen_plugin_AblySolar(lua_State *L) {
    // Create a table to store the plugin functions
    lua_newtable(L);

    // Register the initWithKey function
    lua_pushcfunction(L, initWithKey);
    lua_setfield(L, -2, "initWithKey");

    // Register the connectionClose function
    lua_pushcfunction(L, connectionClose);
    lua_setfield(L, -2, "connectionClose");

    return 1; // Return the table to Lua
}

