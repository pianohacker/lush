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
	success, error = pcall(lush.proc.chdir, args)

	if not success then
		print(".cd: " .. error)
	end
end

function Env.charms:require(args)
	require(args)
end

function Env:run_charm(command)
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

function Env:run_external(command)
	lush.term.setcanon(true)
	lush.term.setecho(true)
	os.execute(command)
	lush.term.setcanon(false)
	lush.term.setecho(false)
end

function Env:run_lua(command)
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

Env.processors = {
	{'^%.(.*)', Env.run_charm},
	{'^=(.*)', function(self, command) Env.run_lua(self, 'return ' .. (command or '')) end},
	{'^!(.*)', Env.run_lua},
	{'^.*', Env.run_external},
}

function Env:run(command)
	for i, processor in ipairs(self.processors) do
		pattern, func = unpack(processor)
		result = command:match(pattern)

		if result then
			func(self, result)
			break
		end
	end
end

function Env:run_file(filename)
	chunk = loadfile(filename)
	setfenv(chunk, self.lua_env)
end

--> User changeable methods
function Env:prompt()
	return lush.fmt.bold(self.vals.cwd) .. '> '
end
