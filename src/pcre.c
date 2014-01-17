#include <pcre.h>
#include <stdbool.h>

#include <lauxlib.h>

typedef struct {
	pcre *result;
	pcre_extra *study;
} _l_pcre_pattern;

static pcre* _try_compile(lua_State* L, const char *str, int options) {
	const char *error = NULL;
	int erroffset = 0;
	pcre *result = pcre_compile(luaL_checkstring(L, 1), options, &error, &erroffset, NULL);

	if (!result) {
		luaL_error(L, "could not compile RE: %s, position %d", error, erroffset);
	}

	return result;
}

static int l_compile(lua_State* L) {
	int options = 0;

	for (int argnum = 2; argnum <= lua_gettop(L); argnum++) {
		options |= luaL_checkint(L, argnum);
	}

	pcre *result = _try_compile(L, luaL_checkstring(L, 1), options);

	_l_pcre_pattern *pattern = lua_newuserdata(L, sizeof(_l_pcre_pattern));
	luaL_getmetatable(L, "lush.pcre.Pattern");
	lua_setmetatable(L, -2);

	pattern->result = result;
	const char *error;
	pattern->study = pcre_study(result, PCRE_STUDY_JIT_COMPILE, &error);

	return 1;
}

static int l___gc(lua_State* L) {
	_l_pcre_pattern *pattern = (_l_pcre_pattern *) luaL_checkudata(L, 1, "lush.pcre.Pattern");
	pcre_free(pattern->result);
	pcre_free_study(pattern->study);
	
	return 0;
}

static bool _get_pat(lua_State* L, pcre **result, pcre_extra **study) {
	if (lua_isstring(L, 1)) {
		*result = _try_compile(L, lua_tostring(L, 1), 0);
		*study = NULL;

		return true;
	} else {
		_l_pcre_pattern *pattern = (_l_pcre_pattern *) luaL_checkudata(L, 1, "lush.pcre.Pattern");
		*result = pattern->result;
		*study = pattern->study;

		return false;
	}
}

static int l_test(lua_State* L) {
	size_t len;
	luaL_checkstring(L, 2);
	const char *subject = lua_tolstring(L, 2, &len);

	pcre *pat;
	pcre_extra *study;
	bool should_free = _get_pat(L, &pat, &study);
	int result = pcre_exec(pat, study, subject, len, luaL_optint(L, 3, 0), 0, NULL, 0);

	if (should_free) {
		pcre_free(pat);
	}

	lua_pushboolean(L, result >= 0);

	return 1;
}

static int l_match(lua_State* L) {
	size_t len;
	luaL_checkstring(L, 2);
	const char *subject = lua_tolstring(L, 2, &len);

	int options = 0;

	for (int argnum = 4; argnum <= lua_gettop(L); argnum++) {
		options |= luaL_checkint(L, argnum);
	}

	pcre *pat;
	pcre_extra *study;
	bool should_free = _get_pat(L, &pat, &study);
	int numgroups = 10;
	if (study) pcre_fullinfo(pat, study, PCRE_INFO_CAPTURECOUNT, &numgroups);
	int ovecsize = (numgroups + 1) * 3;
	int ovector[ovecsize];
	int result = pcre_exec(pat, study, subject, len, luaL_optint(L, 3, 1) - 1, options, ovector, ovecsize);

	if (result == 0) return luaL_error(L, "Not enough space for uncompiled capture groups");

	if (result < 0) return 0;

	if (should_free) {
		pcre_free(pat);
	}

	for (int i = 0; i < result * 2; i += 2) {
		if (ovector[i] == -1) {
			lua_pushnil(L);
		} else {
			lua_pushlstring(L, subject + ovector[i], ovector[i + 1] - ovector[i]);
		}
	}

	return result;
}

const luaL_Reg pcre_reg[] = {
	{ "compile", l_compile },
	{ "match", l_match },
	{ "test", l_test },
    { NULL, NULL },
};

#define _ADD_CONSTANT(constant) lua_pushinteger(L, PCRE_ ## constant); lua_setfield(L, -2, #constant)
#define _ADD_METHOD(name) lua_pushcfunction(L, l_ ## name); lua_setfield(L, -2, #name)

extern int luaopen_l_pcre(lua_State* L) {
    luaL_register(L, "lush.pcre", pcre_reg);

	// Add PCRE_* constants
	_ADD_CONSTANT(ANCHORED);
	_ADD_CONSTANT(AUTO_CALLOUT);
	_ADD_CONSTANT(BSR_ANYCRLF);
	_ADD_CONSTANT(BSR_UNICODE);
	_ADD_CONSTANT(CASELESS);
	_ADD_CONSTANT(DOLLAR_ENDONLY);
	_ADD_CONSTANT(DOTALL);
	_ADD_CONSTANT(DUPNAMES);
	_ADD_CONSTANT(EXTENDED);
	_ADD_CONSTANT(EXTRA);
	_ADD_CONSTANT(FIRSTLINE);
	_ADD_CONSTANT(JAVASCRIPT_COMPAT);
	_ADD_CONSTANT(MULTILINE);
	_ADD_CONSTANT(NEWLINE_ANY);
	_ADD_CONSTANT(NEWLINE_ANYCRLF);
	_ADD_CONSTANT(NEWLINE_CR);
	_ADD_CONSTANT(NEWLINE_CRLF);
	_ADD_CONSTANT(NEWLINE_LF);
	_ADD_CONSTANT(NO_AUTO_CAPTURE);
	_ADD_CONSTANT(NO_START_OPTIMIZE);
	_ADD_CONSTANT(NOTBOL);
	_ADD_CONSTANT(NOTEMPTY);
	_ADD_CONSTANT(NOTEMPTY_ATSTART);
	_ADD_CONSTANT(NOTEOL);
	_ADD_CONSTANT(NO_UTF8_CHECK);
	_ADD_CONSTANT(PARTIAL_HARD);
	_ADD_CONSTANT(PARTIAL_SOFT);
	_ADD_CONSTANT(UCP);
	_ADD_CONSTANT(UNGREEDY);
	_ADD_CONSTANT(UTF8);

	// Add compiled regex type
	luaL_newmetatable(L, "lush.pcre.Pattern");
	_ADD_METHOD(match);
	_ADD_METHOD(test);
	_ADD_METHOD(__gc);

	// Add metatable as its own index
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);

    return 1;
}
