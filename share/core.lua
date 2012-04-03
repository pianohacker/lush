package.path = lush.runtime_path .. "/?.lua;" .. package.path

require "lush.prompt"
require "lush.cmd"

lush.prompt.init()
local cmd_env = lush.cmd.Env:new()

repeat
	command = lush.prompt.prompt(cmd_env)
	if command == nil then break end

	if command ~= '' then
		cmd_env:run(command)
	end
until cmd_env.finished

lush.prompt.cleanup()

print ""
