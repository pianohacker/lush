#include <curses.h>
#include <stdlib.h>
#include <string.h>
#include <term.h>
#include <termios.h>

#include <lauxlib.h>
#include "strings.h"

typedef struct {
    int x;
    int y;
} pos;

static int l_setupterm(lua_State* L) {
	// Exit on failure
	setupterm((char *) 0, 1, (int *) 0);

	return 0;
}

static int l_tigetflag(lua_State* L) {
	int result = tigetflag((char *) luaL_checkstring(L, 1));

	switch(result) {
		case -1:
			return luaL_error(L, "%s is not a boolean capability", luaL_checkstring(L, 1));
		case 0:
			return luaL_error(L, "capability %s not found", luaL_checkstring(L, 1));
		default:
			lua_pushboolean(L, result);
			return 1;
	}
}

static int l_tigetnum(lua_State* L) {
	int result = tigetnum((char *) luaL_checkstring(L, 1));

	switch(result) {
		case -2:
			return luaL_error(L, "%s is not a numeric capability", luaL_checkstring(L, 1));
		case -1:
			return luaL_error(L, "capability %s not found", luaL_checkstring(L, 1));
		default:
			lua_pushinteger(L, result);
			return 1;
	}
}

static int l_tigetstr(lua_State* L) {
	char *result = tigetstr((char *) luaL_checkstring(L, 1));

	switch((signed int) result) {
		case -1:
			return luaL_error(L, "%s is not a string capability", luaL_checkstring(L, 1));
		case 0:
			return luaL_error(L, "capability %s not found", luaL_checkstring(L, 1));
		default:
			lua_pushstring(L, result);
			return 1;
	}
}

static int l_putcap(lua_State* L) {
	char *cap = tigetstr((char *) luaL_checkstring(L, 1));

	switch((signed int) cap) {
		case -1:
			return luaL_error(L, "%s is not a string capability", luaL_checkstring(L, 1));
		case 0:
			return luaL_error(L, "capability %s not found", luaL_checkstring(L, 1));
	}

	int args[9] = { 0, 0, 0, 0, 0, 0, 0, 0, 0 };

	for (int i = 0, argnum = 2; argnum <= lua_gettop(L); i++, argnum++) {
		args[i] = luaL_checkint(L, argnum);
	}

	putp((char *) tparm(cap, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]));

	return 0;
}

static void tcsetlflag(lua_State *L, tcflag_t flag) {
	struct termios term;
	tcgetattr(1, &term);

	if (lua_toboolean(L, 1)) {
		term.c_lflag |= flag;
	} else {
		term.c_lflag &= ~flag;
	}

	tcsetattr(1, TCSADRAIN, &term);
}

static int l_setcanon(lua_State* L) {
	tcsetlflag(L, ICANON);

	return 0;
}

static int l_setecho(lua_State* L) {
	tcsetlflag(L, ECHO);

	return 0;
}

const luaL_Reg term_reg[] = {
	{ "init", l_setupterm },
	{ "tigetflag", l_tigetflag },
	{ "tigetnum", l_tigetnum },
	{ "tigetstr", l_tigetstr },
	{ "putcap", l_putcap },
	{ "setcanon", l_setcanon },
	{ "setecho", l_setecho },
    { NULL, NULL },
};

extern int luaopen_l_term(lua_State* L) {
    luaL_register(L, "lush.term", term_reg);

    return 1;
}
