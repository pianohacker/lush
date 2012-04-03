module(..., package.seeall)

Env = {}

function Env:new()
	return setmetatable({
		finished = false
	}, {__index = self})
end

function Env:get_ps1()
	return lush.proc.getcwd():gsub('^' .. os.getenv('HOME'), '~') .. '> '
end

Env.charms = {}
function Env.charms:exit(args)
	self.finished = true
end

function Env.charms:cd(args)
	lush.proc.chdir(args)
end

function Env:run_charm(command)
	space_idx = command:find(' ')

	if self.charms[command] then
		self.charms[command](self, '')
	elseif space_idx and self.charms[command:sub(1, space_idx-1)] then
		self.charms[command:sub(1, space_idx-1)](self, command:sub(space_idx+1))
	else
		io.stderr:write("Unknown charm: ." .. command .. "\n")
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
	chunk, message = loadstring('return ' .. command)
	if chunk then
		cmd_env = self
		success, result = pcall(chunk)
		if success then
			if result ~= nil then print(result) end
		else
			print(result)
		end
	else
		print(message)
	end
end

Env.processors = {
	{'^%.(.*)', Env.run_charm},
	{'^=(.*)', Env.run_lua},
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
