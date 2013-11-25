module(..., package.seeall)

function _complete_external_command(env, context, command)
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

	result = {}

	for command in _external_commands:completions(command) do
		table.insert(result, command)
	end

	return result
end

function _complete_command_argument(env, context, word)
	return {}
end

function load_defaults(env)
	local setc = env.set_completer
	local addt = env.add_completion_transition
	
	addt(env, 'start', 9, [[[^/]+\b]], 'external-command')
	addt(env, 'external-command', 5, [[ ]], 'command-argument')

	setc(env, 'command-argument', _complete_command_argument)
	setc(env, 'external-command', _complete_external_command)
end
