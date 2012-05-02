module(..., package.seeall)

Vals = {}

function Vals:new(cmd_env)
	return setmetatable({
		cmd_env = cmd_env,
	}, {
		__index = Vals.__index,
	})
end

function Vals:__index(key)
	return Vals[key](self)
end

function Vals:raw_cwd()
	return lush.proc.getcwd()
end

function Vals:cwd()
	return self.raw_cwd:gsub('^' .. os.getenv('HOME'), '~')
end
