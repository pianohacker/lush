module(..., package.seeall)

function load_defaults(env)
	local setc = env.set_completer
	local addt = env.add_completion_transition
	
	addt(env, 'start', 9, [[[^/]+\b]], 'external-command')
	addt(env, 'external-command', 5, [[ ]], 'command-argument')

	setc('external-command', _complete_external_command)
	setc('command-argument', _complete_command_argument)
end
