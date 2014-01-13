package.path = lush.runtime_path .. "/?.lua;" .. package.path

require "log"
local log_filename
if lush.posix.dir_exists(os.getenv('HOME') .. '/.lush') then
	log_filename = os.getenv('HOME') .. '/.lush/log'
else
	log_filename = os.getenv('HOME') .. '/.lush.log'
end
if os.getenv('LUSH_DEBUG') then
	log.open(log_filename, log.DEBUG)
else
	log.open(log_filename, log.WARN)
end

require "lush.prompt"
require "lush.shell"

lush.prompt.init()
local sh = lush.shell.Shell:new()
local editor = lush.prompt.Editor:new(sh)

sh:reload_config()

repeat
	local command = editor:prompt(sh)
	if command == nil then
		print ""
		break
	end

	sh:run(command)
until sh.finished

lush.prompt.cleanup()
