module(..., package.seeall)

DEBUG = 1
INTERNAL = 2
INFO = 3
WARN = 4
ERROR = 5

local _output = nil
local _level = ERROR

function open(filename, level)
	_output = io.open(filename, 'a')
	_level = level
end

function _log(level, format, ...)
	if level < _level then return end

	_output:write(format:format(...) .. '\n')
end

function debug(format, ...) _log(DEBUG, format, ...) end
function internal(format, ...) _log(INTERNAL, format, ...) end
function info(format, ...) _log(INFO, format, ...) end
function warn(format, ...) _log(WARN, format, ...) end
function error(format, ...) _log(ERROR, format, ...) end
