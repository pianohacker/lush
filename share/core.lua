package.path = lush.runtime_path .. "/?.lua;" .. package.path

require "lush.prompt"
require "lush.cmd"

lush.prompt.init()
cmd_env = lush.cmd.Env:new()
line_editor = lush.prompt.Editor:new()

repeat
	command = line_editor:prompt(cmd_env)
	if command == nil then break end

	if command ~= '' then
		cmd_env:run(command)
	end
until cmd_env.finished

lush.prompt.cleanup()

print ""
