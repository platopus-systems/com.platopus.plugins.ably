// ----------------------------------------------------------------------------
//
// AblySimulatorPlugin.mm
//
// ----------------------------------------------------------------------------

#include "SimulatorPluginLibrary.h"
#include <CoronaAssert.h>
#include <CoronaLibrary.h>
#include <CoronaLua.h>
#include <CoronaMacros.h>
#import <Ably/Ably.h>

// Global reference to the Ably client
static ARTRealtime *gAblyClient = nil;

// ----------------------------------------------------------------------------

// Utility function to convert ARTRealtimeConnectionState enum to a const char *
static const char *ARTRealtimeConnectionStateToString(ARTRealtimeConnectionState state) {
    switch (state) {
        case ARTRealtimeInitialized:
            return "Initialized";
        case ARTRealtimeConnecting:
            return "Connecting";
        case ARTRealtimeConnected:
            return "Connected";
        case ARTRealtimeDisconnected:
            return "Disconnected";
        case ARTRealtimeSuspended:
            return "Suspended";
        case ARTRealtimeClosing:
            return "Closing";
        case ARTRealtimeClosed:
            return "Closed";
        case ARTRealtimeFailed:
            return "Failed";
        default:
            return "Unknown";
    }
}

// Helper function to initialize the Ably client with an API key
static int initWithKey(lua_State *L) {
    // Get the API key from Lua
    const char *apiKey = luaL_checkstring(L, 1);
    
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    ARTClientOptions *options = [[ARTClientOptions alloc] initWithKey:[NSString stringWithUTF8String:apiKey]];
    options.autoConnect = YES;

    gAblyClient = [[ARTRealtime alloc] initWithOptions:options];
    if (!gAblyClient) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to initialize Ably client.");
        return 2;
    }

    [gAblyClient.connection on:^(ARTConnectionStateChange *stateChange) {
        if (stateChange) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, listenerRef);
            if (lua_isfunction(L, -1)) {
                lua_newtable(L);

                lua_pushstring(L, "state");
                lua_pushstring(L, ARTRealtimeConnectionStateToString(stateChange.current));
                lua_settable(L, -3);

                if (stateChange.reason) {
                    lua_pushstring(L, "reason");
                    lua_pushstring(L, [stateChange.reason.message UTF8String]);
                    lua_settable(L, -3);
                }

                lua_pcall(L, 1, 0, 0);
            } else {
                lua_pop(L, 1);
            }
        }
    }];

    lua_pushboolean(L, 1); // Success
    return 1;
}

// Helper function to close the Ably connection
static int connectionClose(lua_State *L) {
    if (gAblyClient) {
        [gAblyClient.connection close];
        [gAblyClient.connection on:ARTRealtimeConnectionEventClosed callback:^(ARTConnectionStateChange *stateChange) {
            NSLog(@"Ably connection explicitly closed.");
        }];
        lua_pushboolean(L, 1); // Success
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, "Ably client is not initialized.");
        return 2;
    }
}

// Helper function to reconnect the Ably connection
static int connectionReconnect(lua_State *L) {
    if (gAblyClient) {
        [gAblyClient.connection connect];
        lua_pushboolean(L, 1); // Success
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, "Ably client is not initialized.");
        return 2;
    }
}

// Helper function to get a channel by name
static int getChannel(lua_State *L) {
    const char *channelName = luaL_checkstring(L, 1);

    if (!gAblyClient) {
        lua_pushnil(L);
        lua_pushstring(L, "Ably client not initialized. Call initWithKey first.");
        return 2;
    }

    ARTRealtimeChannel *channel = [gAblyClient.channels get:[NSString stringWithUTF8String:channelName]];
    if (!channel) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to get the Ably channel.");
        return 2;
    }

    lua_pushlightuserdata(L, (__bridge void *)channel);
    return 1;
}

// Subscribe to all messages on a channel
static int subscribeAll(lua_State *L) {
    ARTRealtimeChannel *channel = (__bridge ARTRealtimeChannel *)lua_touserdata(L, 1);
    if (!channel) {
        lua_pushnil(L);
        lua_pushstring(L, "Invalid channel.");
        return 2;
    }

    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    [channel subscribe:^(ARTMessage *message) {
        if (message) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, listenerRef);
            if (lua_isfunction(L, -1)) {
                lua_newtable(L);

                lua_pushstring(L, "name");
                lua_pushstring(L, [message.name UTF8String]);
                lua_settable(L, -3);

                lua_pushstring(L, "data");
                lua_pushstring(L, [[message.data description] UTF8String]);
                lua_settable(L, -3);

                lua_pcall(L, 1, 0, 0);
            } else {
                lua_pop(L, 1);
            }
        }
    }];

    lua_pushboolean(L, 1);
    return 1;
}

// Publish a message to a channel
static int publish(lua_State *L) {
    ARTRealtimeChannel *channel = (__bridge ARTRealtimeChannel *)lua_touserdata(L, 1);
    const char *eventName = luaL_checkstring(L, 2);
    const char *messageData = luaL_checkstring(L, 3);

    [channel publish:[NSString stringWithUTF8String:eventName]
                data:[NSString stringWithUTF8String:messageData]
            callback:^(ARTErrorInfo *error) {
                if (error) {
                    NSLog(@"Failed to publish message: %@", error.message);
                } else {
                    NSLog(@"Message published successfully.");
                }
            }];

    lua_pushboolean(L, 1);
    return 1;
}

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_AblySolar(lua_State *L) {
    lua_newtable(L);

    lua_pushcfunction(L, initWithKey);
    lua_setfield(L, -2, "initWithKey");

    lua_pushcfunction(L, connectionClose);
    lua_setfield(L, -2, "connectionClose");

    lua_pushcfunction(L, connectionReconnect);
    lua_setfield(L, -2, "connectionReconnect");

    lua_pushcfunction(L, getChannel);
    lua_setfield(L, -2, "getChannel");

    lua_pushcfunction(L, subscribeAll);
    lua_setfield(L, -2, "subscribeAll");

    lua_pushcfunction(L, publish);
    lua_setfield(L, -2, "publish");

    return 1;
}


// ----------------------------------------------------------------------------

