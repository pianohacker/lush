cmake_minimum_required(VERSION 2.8)
project(lush)

find_package(PkgConfig REQUIRED)
pkg_check_modules(LUAJIT luajit)
set(CMAKE_C_FLAGS "-std=gnu99")

add_executable(lush
	src/lush.c
	src/term/term.c
	src/term/strings.c
	src/posix/posix.c
	src/posix/queue.c
	src/posix/signames.c
)
message(${LUAJIT_CFLAGS})
include_directories(${LUAJIT_INCLUDE_DIRS})
get_property(dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
foreach(dir ${dirs})
  message(STATUS "dir='${dir}'")
endforeach()
target_link_libraries(lush curses ${LUAJIT_LDFLAGS})
