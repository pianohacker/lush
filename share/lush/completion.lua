module(..., package.seeall)

require "log"

local function _complete_command_argument(sh, context, word)
	return {}
end

local function _complete_external_command(sh, context, command)
	_external_commands = lush.util.trie.new()

	for dir in os.getenv('PATH'):gmatch('[^:]+') do
		pcall(function()
			for entry in lush.posix.diriter(dir) do
				if not (entry == '.' or entry == '..') then
					_external_commands:set(entry, dir .. '/' .. entry)
				end
			end
		end)
	end

	local result = {}

	for command in _external_commands:completions(command) do
		table.insert(result, command)
	end

	return result
end

function load_defaults(sh)
	local setc = sh.set_completer
	local addt = sh.add_completion_transition
	
	addt(sh, 'start', 5, [[[^/]+\b]], 'external-command')
	addt(sh, 'start', 6, [[\./]], 'external-command')
	addt(sh, 'start', 5, [[\.]], 'charm')

	addt(sh, 'external-command', 5, [[ ]], 'command-argument')
	addt(sh, 'charm', 5, [[ ]], 'command-argument')

	setc(sh, 'command-argument', _complete_command_argument)
	setc(sh, 'external-command', _complete_external_command)

	log.debug(_G)
end
