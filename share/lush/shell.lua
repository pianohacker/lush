module(..., package.seeall)

inspect = require "lush.inspect"
require "lush.completion"
require "lush.fmt"
require "lush.util.table"
require "lush.util.trie"
require "lush.vals"

Shell = {}

function Shell:new()
	obj = setmetatable({
		charm_trie = lush.util.trie.new(Shell.charms),
		lua_env = setmetatable({}, {__index = _G}),
		completion_cache = {},
		completion_transitions = {},
		completers = {},
		finished = false
	}, {__index = self})

	lush.completion.load_defaults(obj)

	obj.vals = lush.vals.Vals:new(obj)
	obj.lua_env.sh = obj
	return obj
end

Shell.charms = {}
function Shell.charms:exit(args)
	self.finished = true
end

function Shell.charms:cd(args)
	if args == '' then args = '~' end

	success, error = pcall(lush.posix.chdir, self:expand(args))

	if not success then
		io.stderr:write(".cd: " .. error .. "\n")
	end
end

function Shell.charms:rc_reload(args)
	self:reload_config()
	self:run_file('~/.lushrc')
end

function Shell:charm_runner(command)
	local space_idx = command:find(' ')

	if space_idx then
		local charm, args = command:sub(1, space_idx-1), command:sub(space_idx+1)
	else
		local charm, args = command, ''
	end

	if not self.charms[charm] then
		completion, chunk = self.charm_trie:completions(charm)()

		if completion then charm = completion end
	end

	if self.charms[charm] then
		self.charms[charm](self, args)
	else
		io.stderr:write("Unknown charm: ." .. charm .. "\n")
	end
end

function Shell:external_runner(full_command)
	lush.term.setcanon(true)
	lush.term.setecho(true)
	
	local commands = {}
	for command in full_command:gmatch('[^|]+') do
		args = {}
		for arg in command:gmatch('[^ ]+') do
			args[#args + 1] = arg
		end

		commands[#commands + 1] = args
	end

	local pipes = { {0, -1} }
	for i = 2, #commands do
		pipes[i] = { lush.posix.pipe() }
	end
	pipes[#pipes + 1] = {-1, 1}

	for i, command in ipairs(commands) do
		input = pipes[i]
		output = pipes[i + 1]

		if lush.posix.fork() == 0 then
			if input[1] ~= 0 then
				lush.posix.dup2(input[1], 0)
			end

			if output[2] ~= 1 then
				lush.posix.dup2(output[2], 1)
			end

			for i = 2, #commands do
				if (pipes[i][1] > 2) then lush.posix.close(pipes[i][1]) end
				if (pipes[i][2] > 2) then lush.posix.close(pipes[i][2]) end
			end

			result, error = pcall(lush.posix.exec, unpack(commands[i]))

			-- If we were here, we failed
			io.stderr:write(commands[i][1] .. ": " .. error .. "\n")
			os.exit()
		end
	end

	for i = 2, #commands do
		lush.posix.close(pipes[i][1])
		lush.posix.close(pipes[i][2])
	end

	while pcall(lush.posix.waitpid) do end

	lush.term.setcanon(false)
	lush.term.setecho(false)
end

function Shell:lua_runner(command)
	local chunk, message = loadstring(command)
	if not chunk then
		print(message)
		return
	end

	setfenv(chunk, self.lua_env)
	local success, result = pcall(chunk)

	if success then
		if result ~= nil then print(inspect(result)) end
	else
		print(result)
	end
end

Shell.runners = {
	{'^./.*', Shell.external_runner},
	{'^%.(.*)', Shell.charm_runner},
	{'^=(.*)', function(self, command) self:lua_runner('return ' .. (command or '')) end},
	{'^!(.*)', Shell.lua_runner},
	{'^.*', Shell.external_runner},
}

function Shell:get_context(kind, command)
	if command == '' then return end

	for i, processor in ipairs(self[kind]) do
		local pattern, func = unpack(processor)
		local result = {command:match(pattern)}

		if result[1] then
			return func, result
		end
	end
end

function Shell:set_completer(state, completer)
	self.completers[state] = completer
end

function Shell:add_completion_transition(state, priority, pattern, new_state)
	if not self.completion_transitions[state] then
		self.completion_transitions[state] = {}
	end

	lush.util.table.insort(self.completion_transitions[state],
		{
			priority = priority,
			pattern = lush.pcre.compile(pattern, lush.pcre.ANCHORED),
			new_state = new_state,
		},
		function(a, b)
			return a.priority < b.priority
		end
	)
end

function Shell:run(command)
	if command == '' then return end

	local runner, result = self:get_context('runners', command)

	runner(self, unpack(result))
end

function Shell:complete(context, word)
	local state = 'start'
	local position = 1
	local match
	
	while position <= #context do
		for i, transition in ipairs(self.completion_transitions[state]) do
			match = transition.pattern:match(context, position)

			if match ~= nil then 
				assert(transition.new_state ~= state or #match, 'pointless transition')
				state = transition.new_state
				position = position + #match
				break
			end
		end

		if match == nil then break end
		match = nil
	end

	assert(state ~= 'start', 'no completions found')
	assert(self.completers[state], 'unknown completer `' .. state .. '`')

	return self.completers[state](self, context, word)
end

function Shell:expand(filename)
	return (filename:gsub(
		'^~',
		os.getenv('HOME')
	))
end

function Shell:run_file(filename)
	local chunk, message = loadfile(self:expand(filename))
	if not chunk then
		print("Could not run " .. filename .. ": " .. message)
		return
	end

	setfenv(chunk, self.lua_env)
	chunk()
end

function Shell:reload_config()
	for i, filename in ipairs({'~/.lushrc', '~/.lush/rc', '~/.lush/lushrc'}) do
		if lush.posix.file_exists(self:expand(filename)) then self:run_file(filename) end
	end
end

--> User changeable methods
function Shell:prompt()
	return self.vals.cwd .. '> '
end
