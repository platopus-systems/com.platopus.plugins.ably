#import <Foundation/Foundation.h>
#import "AblySolar.h"
#import <Ably/Ably.h>
#import <CoronaLua.h>
#import <CoronaMacros.h>

// Global reference to the Ably client
static ARTRealtime *gAblyClient = nil;

// Global dictionary to manage subscriptions
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *subscriptionRegistry;

// Helper function to ensure the subscription registry is initialized
static void ensureSubscriptionRegistry() {
    if (!subscriptionRegistry) {
        subscriptionRegistry = [NSMutableDictionary new];
    }
}

// Helper function to convert ARTRealtimeConnectionState to string
static const char *ARTRealtimeConnectionStateToString(ARTRealtimeConnectionState state) {
    switch (state) {
        case ARTRealtimeInitialized: return "Initialized";
        case ARTRealtimeConnecting: return "Connecting";
        case ARTRealtimeConnected: return "Connected";
        case ARTRealtimeDisconnected: return "Disconnected";
        case ARTRealtimeSuspended: return "Suspended";
        case ARTRealtimeClosing: return "Closing";
        case ARTRealtimeClosed: return "Closed";
        case ARTRealtimeFailed: return "Failed";
        default: return "Unknown";
    }
}

// Listener for connection state changes
static void onConnectionStateChange(ARTConnectionStateChange *stateChange, lua_State *L, int listenerRef) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, listenerRef); // Push the listener callback onto the stack
    if (lua_isfunction(L, -1)) {
        lua_newtable(L); // Create a Lua table

        lua_pushstring(L, "state");
        lua_pushstring(L, ARTRealtimeConnectionStateToString(stateChange.current));
        lua_settable(L, -3); // Add "state" to the table

        if (stateChange.reason) {
            lua_pushstring(L, "reason");
            lua_pushstring(L, [stateChange.reason.message UTF8String]);
            lua_settable(L, -3); // Add "reason" if available
        }

        lua_pcall(L, 1, 0, 0); // Call the Lua function with one argument (the table)
    } else {
        lua_pop(L, 1); // Pop the invalid listener
    }
}

// initWithKey: Initialize Ably client with API key
static int initWithKey(lua_State *L) {
    const char *apiKey = luaL_checkstring(L, 1);

    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    ARTClientOptions *options = [[ARTClientOptions alloc] initWithKey:[NSString stringWithUTF8String:apiKey]];
    options.autoConnect = YES;

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

    lua_pushboolean(L, 1); // Success
    return 1;
}

// connectionClose: Close the Ably connection
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

// connectionReconnect: Reconnect the Ably connection
static int connectionReconnect(lua_State *L) {
    if (gAblyClient) {
        [gAblyClient.connection connect];
        NSLog(@"Ably connection reconnected.");
        lua_pushboolean(L, 1); // Success
        return 1;
    } else {
        lua_pushnil(L);
        lua_pushstring(L, "Ably client is not initialized.");
        return 2;
    }
}

// getChannel: Retrieve an Ably channel by name
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
    return 1; // Return the channel as a light userdata to Lua
}

// subscribeAll: Subscribe to all messages on a channel
static int subscribeAll(lua_State *L) {
    ARTRealtimeChannel *channel = (__bridge ARTRealtimeChannel *)lua_touserdata(L, 1);
    NSString *channelName = channel.name;

    ensureSubscriptionRegistry();

    // Unsubscribe previous listener, if any
    NSMutableDictionary *eventListeners = subscriptionRegistry[channelName];
    if (eventListeners && eventListeners[@"all"]) {
        [channel unsubscribe:eventListeners[@"all"]];
        [eventListeners removeObjectForKey:@"all"];
    }

    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    // Subscribe and store the listener
    id listener = [channel subscribe:^(ARTMessage *message) {
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

    // Store the listener in the registry
    if (!eventListeners) {
        eventListeners = [NSMutableDictionary new];
        subscriptionRegistry[channelName] = eventListeners;
    }
    eventListeners[@"all"] = listener;

    lua_pushboolean(L, 1);
    return 1;
}

// subscribeEvent: Subscribe to specific events on a channel
static int subscribeEvent(lua_State *L) {
    ARTRealtimeChannel *channel = (__bridge ARTRealtimeChannel *)lua_touserdata(L, 1);
    NSString *channelName = channel.name;
    const char *eventName = luaL_checkstring(L, 2);

    ensureSubscriptionRegistry();

    NSString *eventNameStr = [NSString stringWithUTF8String:eventName];
    NSMutableDictionary *eventListeners = subscriptionRegistry[channelName];
    if (eventListeners && eventListeners[eventNameStr]) {
        [channel unsubscribe:eventListeners[eventNameStr]];
        [eventListeners removeObjectForKey:eventNameStr];
    }

    luaL_checktype(L, 3, LUA_TFUNCTION);
    lua_pushvalue(L, 3);
    int listenerRef = luaL_ref(L, LUA_REGISTRYINDEX);

    id listener = [channel subscribe:eventNameStr callback:^(ARTMessage *message) {
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

    if (!eventListeners) {
        eventListeners = [NSMutableDictionary new];
        subscriptionRegistry[channelName] = eventListeners;
    }
    eventListeners[eventNameStr] = listener;

    lua_pushboolean(L, 1);
    return 1;
}

// publish: Publish a message to a channel
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

    lua_pushboolean(L, 1); // Success
    return 1;
}

// Lua plugin loader
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

    lua_pushcfunction(L, subscribeEvent);
    lua_setfield(L, -2, "subscribeEvent");

    lua_pushcfunction(L, publish);
    lua_setfield(L, -2, "publish");

    return 1;
}
