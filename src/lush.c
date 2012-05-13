#include <lauxlib.h>
#include <lualib.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char* lush_get_runtime_path(char *argv0) {
	char* dir = realpath(dirname(argv0), NULL);

	if (strlen(dir) >= 4 && strcmp(dir + strlen(dir) - 4, "/bin") == 0) {
		dir[strlen(dir) - 4] = 0;
	}

	return dir;
}

extern int luaopen_l_term(lua_State* L);
extern int luaopen_l_posix(lua_State* L);

int main(int argc, char *argv[]) {
	char* runtime_path = strcat(strcat(malloc(PATH_MAX), lush_get_runtime_path(argv[0])), "/share");

	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	lua_newtable(L);
	lua_pushstring(L, runtime_path);
	lua_setfield(L, -2, "runtime_path");
	lua_setglobal(L, "lush");

	luaopen_l_term(L);
	luaopen_l_posix(L);

	char* core_file = strcat(strcat(malloc(PATH_MAX), runtime_path), "/core.lua");

	if (luaL_loadfile(L, core_file) == LUA_ERRFILE) {
		fprintf(stderr, "Could not open core.lua\n");
	}

	if (lua_pcall(L, 0, LUA_MULTRET, 0)) {
		fprintf(stderr, "Error running core.lua: %s\n", lua_tostring(L, -1));
	}
}
