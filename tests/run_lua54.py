# Offline fallback runner for Linux hosts with liblua5.4. No game/native FFI execution.
# Run from repository root: python3 tests/run_lua54.py
import ctypes,sys
L=ctypes.CDLL('liblua5.4.so.0')
L.luaL_newstate.restype=ctypes.c_void_p
state=L.luaL_newstate()
L.luaL_openlibs.argtypes=[ctypes.c_void_p];L.luaL_openlibs(state)
L.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p];L.luaL_loadstring.restype=ctypes.c_int
L.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
L.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];L.lua_tolstring.restype=ctypes.c_char_p
src="loadstring=load; local execute=os.execute; os.execute=function(c) local ok,why,n=execute(c);return ok and 0 or n end; arg={[1]='.'}; dofile('tests/regression.lua')"
r=L.luaL_loadstring(state,src.encode()) or L.lua_pcallk(state,0,-1,0,0,None)
if r: print(L.lua_tolstring(state,-1,None).decode());sys.exit(1)
