cmake_minimum_required(VERSION 2.8)
project(lush)

find_package(Lua51 REQUIRED)
set(CMAKE_C_FLAGS "-std=gnu99")

add_executable(lush
	src/lush.c
	src/term/term.c
	src/term/strings.c
	src/posix/posix.c
	src/posix/queue.c
	src/posix/signames.c
)
include_directories(${LUA_INCLUDE_DIR})
target_link_libraries(lush curses ${LUA_LIBRARIES})
