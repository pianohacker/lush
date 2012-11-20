#include "queue.h"
#include "signames.h"
#include <lua.h>
#include <lauxlib.h>
#include <dirent.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define REG_TABLE "lush_posix"
#define CHECKED_SYSCALL(expr) if((expr) == -1) return luaL_error(L, strerror(errno))

static lua_State* gL = NULL;
static lua_Hook old_hook = NULL;
static int old_mask = 0;
static int old_count = 0;
static queue q;
/* hardcoding 256 here is not great... is there a better way to get the highest
 * numbered signal? */
static struct sigaction lua_handlers[256];

static void lua_signal_handler(lua_State* L, lua_Debug* D)
{
	sigset_t sset, oldset;
	int sig;

	lua_sethook(gL, old_hook, old_mask, old_count);

	sigfillset(&sset);
	sigprocmask(SIG_BLOCK, &sset, &oldset);

	while ((sig = dequeue(&q)) != -1) {
		const char* signame;

		signame = sig_to_name(sig);
		lua_getfield(gL, LUA_REGISTRYINDEX, REG_TABLE);
		lua_getfield(gL, -1, signame);
		lua_pushstring(gL, signame);
		sigprocmask(SIG_SETMASK, &oldset, NULL);
		lua_call(gL, 1, 0);
		sigprocmask(SIG_BLOCK, &sset, &oldset);
	}

	sigprocmask(SIG_SETMASK, &oldset, NULL);
}

static void signal_handler(int sig)
{
	if (q.size == 0) {
		old_hook  = lua_gethook(gL);
		old_mask  = lua_gethookmask(gL);
		old_count = lua_gethookcount(gL);
		lua_sethook(gL, lua_signal_handler,
					LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
	}

	enqueue(&q, sig);
}

static int l_signal(lua_State* L)
{
	const char* signame;
	int sig;
	struct sigaction sa;
	sigset_t sset;
	void (*handler)(int) = NULL;

	gL = L;

	luaL_checktype(L, 1, LUA_TSTRING);
	signame = lua_tostring(L, 1);
	sig = name_to_sig(signame);
	if (sig == -1) {
		lua_pushfstring(L, "signal() called with invalid signal name: %s", signame);
		lua_error(L);
	}

	if (lua_isfunction(L, 2)) {
		handler = signal_handler;
		lua_getfield(L, LUA_REGISTRYINDEX, REG_TABLE);
		lua_pushvalue(L, 2);
		lua_setfield(L, -2, signame);
	}
	else if (lua_isstring(L, 2)) {
		const char* pseudo_handler;

		pseudo_handler = lua_tostring(L, 2);
		if (strcmp(pseudo_handler, "ignore") == 0) {
			handler = SIG_IGN;
		}
		else if (strcmp(pseudo_handler, "cdefault") == 0) {
			handler = SIG_DFL;
		}
		else if (strcmp(pseudo_handler, "default") == 0) {
			if (lua_handlers[sig].sa_handler != NULL) {
				handler = lua_handlers[sig].sa_handler;
			}
			else {
				return 0;
			}
		}
		else {
			lua_pushstring(L, "Must pass a valid handler to signal()");
			lua_error(L);
		}
	}
	else {
		lua_pushstring(L, "Must pass a handler to signal()");
		lua_error(L);
	}
	sa.sa_handler = handler;
	sigfillset(&sset);
	sa.sa_mask = sset;
	sa.sa_flags = 0;
	if (lua_handlers[sig].sa_handler == NULL) {
		sigaction(sig, &sa, &(lua_handlers[sig]));
	}
	else {
		sigaction(sig, &sa, NULL);
	}

	return 0;
}

static int l_alarm(lua_State* L)
{
	int time;

	time = luaL_checkint(L, 1);
	lua_pushinteger(L, alarm(time));

	return 1;
}

static int l_kill(lua_State* L)
{
	const char* signame;
	int pid, sig;

	pid = luaL_checkint(L, 1);
	luaL_checktype(L, 2, LUA_TSTRING);
	signame = lua_tostring(L, 2);
	if ((sig = name_to_sig(signame)) == -1) {
		if (strcmp(signame, "test") == 0) {
			sig = 0;
		}
		else {
			lua_pushstring(L, "kill(): invalid signal name");
			lua_error(L);
		}
	}

	lua_pushinteger(L, kill(pid, sig));

	return 1;
}

static int l_raise(lua_State* L)
{
	const char* signame;
	int sig;

	luaL_checktype(L, 1, LUA_TSTRING);
	signame = lua_tostring(L, 1);
	if ((sig = name_to_sig(signame)) == -1) {
		if (strcmp(signame, "test") == 0) {
			sig = 0;
		}
		else {
			lua_pushfstring(L, "raise(): invalid signal name: %s", signame);
			lua_error(L);
		}
	}

	lua_pushinteger(L, raise(sig));

	return 1;
}

static int l_suspend(lua_State* L)
{
	sigset_t sset;
	int first_arg = 1;

	/* XXX: this should be moved out into a function so that mask() can also
	 * use it */
	sigprocmask(0, NULL, &sset);
	if (lua_isstring(L, 1)) {
		const char* init;

		init = lua_tostring(L, 1);
		if (strcmp(init, "all") == 0) {
			sigfillset(&sset);
		}
		else if (strcmp(init, "none") == 0) {
			sigemptyset(&sset);
		}
		else if (strcmp(init, "cur") != 0) {
			lua_pushfstring(L, "suspend(): invalid sigset initializer: %s", init);
			lua_error(L);
		}
		first_arg = 2;
	}

	luaL_checktype(L, first_arg,	 LUA_TTABLE);
	luaL_checktype(L, first_arg + 1, LUA_TTABLE);

	lua_pushnil(L);
	while (lua_next(L, first_arg) != 0) {
		if (lua_isstring(L, -1)) {
			int sig;

			sig = name_to_sig(lua_tostring(L, -1));
			if (sig != -1) {
				sigaddset(&sset, sig);
			}
		}
		lua_pop(L, 1);
	}
	lua_pushnil(L);
	while (lua_next(L, first_arg + 1) != 0) {
		if (lua_isstring(L, -1)) {
			int sig;

			sig = name_to_sig(lua_tostring(L, -1));
			if (sig != -1) {
				sigdelset(&sset, sig);
			}
		}
		lua_pop(L, 1);
	}

	sigsuspend(&sset);

	return 0;
}

static int l_mask(lua_State* L)
{
	const char* str_how = NULL;
	int how = SIG_BLOCK, first_arg = 2;
	sigset_t sset;

	luaL_checktype(L, 1, LUA_TSTRING);
	str_how = lua_tostring(L, 1);
	if (strcmp(str_how, "block") == 0) {
		how = SIG_BLOCK;
	}
	else if (strcmp(str_how, "unblock") == 0) {
		how = SIG_UNBLOCK;
	}
	else if (strcmp(str_how, "set") == 0) {
		how = SIG_SETMASK;
	}
	else {
		lua_pushfstring(L, "mask(): invalid masking method: %s", str_how);
		lua_error(L);
	}

	sigprocmask(0, NULL, &sset);
	if (lua_isstring(L, 2)) {
		const char* init;

		init = lua_tostring(L, 2);
		if (strcmp(init, "all") == 0) {
			sigfillset(&sset);
		}
		else if (strcmp(init, "none") == 0) {
			sigemptyset(&sset);
		}
		else if (strcmp(init, "cur") != 0) {
			lua_pushfstring(L, "suspend(): invalid sigset initializer: %s", init);
			lua_error(L);
		}
		first_arg = 3;
	}

	luaL_checktype(L, first_arg,	 LUA_TTABLE);
	luaL_checktype(L, first_arg + 1, LUA_TTABLE);

	lua_pushnil(L);
	while (lua_next(L, first_arg) != 0) {
		if (lua_isstring(L, -1)) {
			int sig;

			sig = name_to_sig(lua_tostring(L, -1));
			if (sig != -1) {
				sigaddset(&sset, sig);
			}
		}
		lua_pop(L, 1);
	}
	lua_pushnil(L);
	while (lua_next(L, first_arg + 1) != 0) {
		if (lua_isstring(L, -1)) {
			int sig;

			sig = name_to_sig(lua_tostring(L, -1));
			if (sig != -1) {
				sigdelset(&sset, sig);
			}
		}
		lua_pop(L, 1);
	}

	/* XXX: we should return oldset here rather than ignoring it */
	sigprocmask(how, &sset, NULL);

	return 0;
}

static int l_getcwd(lua_State *L) {
	lua_pushstring(L, getcwd(NULL, 0));

	return 1;
}

static int l_chdir(lua_State *L) {
	if (chdir(luaL_checkstring(L, 1)) == -1) {
		return luaL_error(L, strerror(errno));
	}

	return 0;
}

static int l_file_exists(lua_State *L) {
	struct stat result;

	return stat(luaL_checkstring(L, 1), &result) == 0 && S_IFREG & result.st_mode;
}

static int l_gethostname(lua_State *L) {
	char result[256];
	gethostname(result, 256);

	lua_pushstring(L, result);

	return 1;
}

static int l_diriter_iter(lua_State *L) {
	DIR *dir = *(DIR**) lua_touserdata(L, lua_upvalueindex(1));
	struct dirent *entry;

	if ((entry = readdir(dir)) == NULL) return 0;

	lua_pushstring(L, entry->d_name);
	return 1;
}

static int l_diriter_gc(lua_State *L) {
	DIR *dir = *(DIR**) lua_touserdata(L, 1);
	if (dir) closedir(dir);

	return 0;
}

static int l_diriter(lua_State *L) {
	DIR **dir = (DIR**) lua_newuserdata(L, sizeof(DIR*));

	luaL_getmetatable(L, "lush.posix.diriter_m");
	lua_setmetatable(L, -2);

	*dir = opendir(luaL_checkstring(L, 1));

	if (*dir == NULL) {
		return luaL_error(L, strerror(errno));
	}

	lua_pushcclosure(L, l_diriter_iter, 1);

	return 1;
}

static int l_fork(lua_State *L) {
	int pid;

	CHECKED_SYSCALL(pid = fork());
	lua_pushinteger(L, pid);

	return 1;
}

static int l_dup2(lua_State *L) {
	CHECKED_SYSCALL(dup2(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2)));

	return 0;
}

static int l_waitpid(lua_State *L) {
	int pid;
	int status;

	CHECKED_SYSCALL(pid = waitpid(luaL_optint(L, 1, -1), &status, 0));

	lua_pushinteger(L, pid);
	
	if (WIFEXITED(status)) {
		lua_pushboolean(L, 0);
		lua_pushinteger(L, WEXITSTATUS(status));
		return 3;
	} else if (WIFSIGNALED(status)) {
		lua_pushboolean(L, 1);
		lua_pushinteger(L, WTERMSIG(status));
		return 3;
	} else {
		return 1;
	}
}

static int l_exec(lua_State *L) {
	const char *file = luaL_checkstring(L, 1);
	const char **args = calloc(sizeof(char*), lua_gettop(L));	

	for (int i = 1; i <= lua_gettop(L); i++) {
		args[i - 1] = luaL_checkstring(L, i);
	}

	CHECKED_SYSCALL(execvp(file, (char *const *) args));

	return 0;
}

static int l_pipe(lua_State *L) {
	int fds[2];

	CHECKED_SYSCALL(pipe(fds));

	lua_pushinteger(L, fds[0]);
	lua_pushinteger(L, fds[1]);

	return 2;
}

static int l_close(lua_State *L) {
	CHECKED_SYSCALL(close(luaL_checkint(L, 1)));

	return 0;
}

const luaL_Reg posix_reg[] = {
	{ "alarm",   l_alarm   },
	{ "chdir",	l_chdir	},
	{ "close", l_close },
	{ "diriter", l_diriter },
	{ "dup2", l_dup2 },
	{ "exec", l_exec },
	{ "file_exists", l_file_exists },
	{ "fork", l_fork },
	{ "getcwd",	l_getcwd	},
	{ "gethostname", l_gethostname },
	{ "kill",	l_kill	},
	{ "pipe", l_pipe },
	{ "raise",   l_raise   },
	{ "sigmask",	l_mask	},
	{ "signal",  l_signal  },
	{ "sigsuspend", l_suspend },
	{ "waitpid", l_waitpid },
	{  NULL,	 NULL	  },
};

int luaopen_l_posix(lua_State* L)
{
	queue_init(&q, 4);

	luaL_newmetatable(L, "lush.posix.diriter_m");
	lua_pushstring(L, "__gc");
	lua_pushcfunction(L, l_diriter_gc);
	lua_settable(L, -3);

	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, REG_TABLE);

	luaL_register(L, "lush.posix", posix_reg);

	return 1;
}
