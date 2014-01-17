cmake_minimum_required(VERSION 2.8)
project(lush)

find_package(PkgConfig REQUIRED)
pkg_check_modules(LUAJIT luajit)
set(CMAKE_C_FLAGS "-std=gnu99")
set(CMAKE_C_FLAGS_DEBUG "-ggdb3")

add_executable(lush
	src/lush.c
	src/term/term.c
	src/term/strings.c
	src/pcre.c
	src/posix/posix.c
	src/posix/queue.c
	src/posix/signames.c
)
include_directories(${LUAJIT_INCLUDE_DIRS})
target_link_libraries(lush curses pcre ${LUAJIT_LDFLAGS})
