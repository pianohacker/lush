package.path = lush.runtime_path .. "/?.lua;" .. package.path

require "lush.prompt"
require "lush.cmd"

lush.prompt.init()
cmd_env = lush.cmd.Env:new()
line_editor = lush.prompt.Editor:new()

if lush.posix.file_exists(cmd_env:expand('~/.lushrc')) then cmd_env:run_file('~/.lushrc') end

repeat
	command = line_editor:prompt(cmd_env)
	if command == nil then
		print ""
		break
	end

	cmd_env:run(command)
until cmd_env.finished

lush.prompt.cleanup()
