//
//  AblySolar.h
//  TemplateApp
//
//  Copyright (c) 2024 Ably / Yousaf Shah. All rights reserved.
//

#ifndef _AblySolar_H__
#define _AblySolar_H__

#include <CoronaLua.h>
#include <CoronaMacros.h>

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
// where the '.' is replaced with '_'
CORONA_EXPORT int luaopen_plugin_AblySolar( lua_State *L );

#endif // _AblySolar_H__
