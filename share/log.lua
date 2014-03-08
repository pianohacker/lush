module(..., package.seeall)

inspect = require "lush.inspect"

DEBUG = 1
INTERNAL = 2
INFO = 3
WARN = 4
ERROR = 5

local _levelnames = {'DEBUG', 'INTERNAL', 'INFO', 'WARN', 'ERROR'}
local _output = nil
local _level = WARN
date_format = '%Y/%m/%d %H:%M:%S'
line_format = ' (%s, line %d)'
entry_format = '[%s, %s] %s%s'

function open(filename, level)
	_output = io.open(filename, 'a')
	_output:setvbuf('no')
	_level = level
end

function _log(level, format, ...)
	if level < _level then return end
	local lineinfo = ''
	if level <= INTERNAL then
		local frame = _G.debug.getinfo(3, 'Sl')
		lineinfo = line_format:format(frame.source:gsub('@', ''):gsub(lush.runtime_path, '...'), frame.currentline)
	end

	if type(format) == 'string' then
		args = {...}
	else
		args = {format, ...}
		format = '%s'
		for i, arg in ipairs({...}) do
			format = format .. ' %s'
		end
	end

	for i, arg in ipairs(args) do
		if type(arg) == 'table' then
			args[i] = inspect(arg)
		end
	end

	_output:write(entry_format:format(os.date(date_format), _levelnames[level], format:format(unpack(args)), lineinfo) .. '\n')
end

function debug(format, ...) _log(DEBUG, format, ...) end
function internal(format, ...) _log(INTERNAL, format, ...) end
function info(format, ...) _log(INFO, format, ...) end
function warn(format, ...) _log(WARN, format, ...) end
function error(format, ...) _log(ERROR, format, ...) end
