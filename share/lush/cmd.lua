module(..., package.seeall)

inspect = require "lush.inspect"
require "lush.fmt"
require "lush.trie"
require "lush.vals"

Env = {}

function Env:new()
	obj = setmetatable({
		charm_trie = lush.trie.new(Env.charms),
		lua_env = setmetatable({
			cmd_env = self,
		}, {__index = _G}),
		finished = false
	}, {__index = self})

	obj.vals = lush.vals.Vals:new(obj)
	return obj
end

Env.charms = {}
function Env.charms:exit(args)
	self.finished = true
end

function Env.charms:cd(args)
	if args == '' then args = '~' end

	success, error = pcall(lush.posix.chdir, self:expand(args))

	if not success then
		print(".cd: " .. error)
	end
end

function Env.charms:rc_reload(args)
	self:run_file('~/.lushrc')
end

function Env:charm_runner(command)
	space_idx = command:find(' ')

	if space_idx then
		charm, args = command:sub(1, space_idx-1), command:sub(space_idx+1)
	else
		charm, args = command, ''
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

function Env:external_runner(full_command)
	lush.term.setcanon(true)
	lush.term.setecho(true)
	
	commands = {}
	for command in full_command:gmatch('[^|]+') do
		args = {}
		for arg in command:gmatch('[^ ]+') do
			args[#args + 1] = arg
		end

		commands[#commands + 1] = args
	end

	pipes = { {0, -1} }
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

			lush.posix.exec(unpack(commands[i]))
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

_external_commands = lush.trie.new()

for dir in os.getenv('PATH'):gmatch('[^:]+') do
	pcall(function()
		for entry in lush.posix.diriter(dir) do
			if not (entry == '.' or entry == '..') then
				_external_commands:set(entry, dir .. '/' .. entry)
			end
		end
	end)
end

function Env:external_completer(command)
	result = {}

	for command in _external_commands:completions(command) do
		table.insert(result, command)
	end

	return result
end

function Env:lua_runner(command)
	chunk, message = loadstring(command)
	if not chunk then
		print(message)
		return
	end

	setfenv(chunk, self.lua_env)
	success, result = pcall(chunk)

	if success then
		if result ~= nil then print(inspect(result)) end
	else
		print(result)
	end
end

Env.runners = {
	{'^%.(.*)', Env.charm_runner},
	{'^=(.*)', function(self, command) self:lua_runner('return ' .. (command or '')) end},
	{'^!(.*)', Env.lua_runner},
	{'^.*', Env.external_runner},
}

Env.completers = {
	{'^([^%.=! ][^ ]*)', Env.external_completer},
}

function Env:get_context(kind, command)
	if command == '' then return end

	for i, processor in ipairs(self[kind]) do
		pattern, func = unpack(processor)
		result = {command:match(pattern)}

		if result[1] then
			return func, result
		end
	end
end

function Env:run(command)
	if command == '' then return end

	runner, result = self:get_context('runners', command)

	runner(self, unpack(result))
end

function Env:expand(filename)
	return (filename:gsub(
		'^~',
		os.getenv('HOME')
	))
end

function Env:run_file(filename)
	chunk, message = loadfile(self:expand(filename))
	if not chunk then
		print("Could not run " .. filename .. ": " .. message)
		return
	end

	setfenv(chunk, self.lua_env)
	chunk()
end

--> User changeable methods
function Env:prompt()
	return self.vals.cwd .. '> '
end
