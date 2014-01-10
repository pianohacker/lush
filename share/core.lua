package.path = lush.runtime_path .. "/?.lua;" .. package.path

require "lush.prompt"
require "lush.shell"

lush.prompt.init()
local sh = lush.shell.Shell:new()
local editor = lush.prompt.Editor:new(sh)

if lush.posix.file_exists(sh:expand('~/.lushrc')) then sh:run_file('~/.lushrc') end

repeat
	command = editor:prompt(sh)
	if command == nil then
		print ""
		break
	end

	sh:run(command)
until sh.finished

lush.prompt.cleanup()
