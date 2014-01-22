module(..., package.seeall)

require "log"
require "lush.completion"
require "lush.fmt"

-- Output a string with special characters escaped
function dumpstr(str)
	result = ''

	for c in str:gmatch(".") do
		if c:byte() < 32 or c:byte() > 127 then
			result = result .. string.format('\\x%02x', c:byte())
		else
			result = result .. c
		end
	end

	return result
end

Editor = {
	actions = {},
}

function Editor:new(sh)
	new_obj = setmetatable({
		content = '',
		sh = sh,
		handlers = {},
		history = {},
		position = 1,
		ready = false,
	}, {__index = self})

	new_obj:bind_defaults()

	return new_obj
end

function Editor.actions:complete()
	local prev_space = self.position
	while prev_space > 0 and self.content:byte(prev_space) ~= 32 do
		prev_space = prev_space - 1
	end

	local completed
	local next_space = self.content:find(' ', self.position)
	if next_space then
		completed = self.content:sub(prev_space + 1, next_space - 1)
	else
		completed = self.content:sub(prev_space + 1)
	end

	if #completed == 0 then return end

	local result, results
	if self.last_complete == completed then
		print(#self.last_complete_results)
		print(self.last_complete_idx)
		self.last_complete_idx = self.last_complete_idx % #self.last_complete_results + 1
		result = self.last_complete_results[self.last_complete_idx]
	else
		results = self.sh:complete(self.content:sub(1, next_space or -1), completed)
		self.last_complete_results = results
		self.last_complete_idx = 1

		result = results[1]
		if not result then return end
		if #results == 1 then result = result .. ' ' end
		self.last_complete = completed
	end

	self.content = self.content:sub(1, prev_space) .. result .. self.content:sub(next_space or (#self.content + 1))

	self.position = prev_space + #result + 1
	self:refresh()
end

function Editor.actions:delete_left()
	if self.position == 1 then return end
	
	self.content = self.content:sub(1, self.position - 2) .. self.content:sub(self.position)
	self.position = self.position - 1
	self:refresh()
end

function Editor.actions:delete_right()
	self.content = self.content:sub(1, self.position - 1) .. self.content:sub(self.position + 1)
	self:refresh()
end

function Editor.actions:finish()
	self.ready = true
	self:move_cur(#self.content + 1)
end

function Editor.actions:history_show_prev()
	if self.history_pos == 1 then return end

	self:switch_history(self.history_pos - 1)
end

function Editor.actions:history_show_next()
	if self.history_pos == #self.act_history then return end

	self:switch_history(self.history_pos + 1)
end

function Editor.actions:move_left()
	-- Handle left arrow key
	if self.position == 1 then return end

	self.position = self.position - 1
	self:move_cur()
end

function Editor.actions:move_right()
	-- Handle right arrow key
	if self.position == #self.content + 1 then return end

	self.position = self.position + 1
	self:move_cur()
end

function Editor.actions:move_to_start()
	self.position = 1
	self:move_cur()
end

function Editor.actions:move_to_end()
	self.position = #self.content + 1
	self:move_cur()
end

function Editor:bind_defaults()
	k = lush.term.tigetstr

	self:bind(k('kbs'), 'delete_left')
	self:bind('\b', 'delete_left')
	self:bind(k('kdch1'), 'delete_right')

	self:bind(k('cr'), 'finish')
	self:bind('\n', 'finish')

	-- The gsub is because terminfo is a _filthy_ liar
	-- More specifically, the termcap for xterm only contains the key sequences
	-- for the numpad versions of the arrow keys.
	-- Why? Because your mother dresses you funny, that's why.
	self:bind(k('kcub1'):gsub('O', '['), 'move_left') -- Left arrow key
	self:bind(k('kcuf1'):gsub('O', '['), 'move_right') -- Right arrow key
	self:bind(k('kcuu1'):gsub('O', '['), 'history_show_prev') -- Up arrow key
	self:bind(k('kcud1'):gsub('O', '['), 'history_show_next') -- Down arrow key

	self:bind(k('khome'), 'move_to_start')
	self:bind(k('kend'), 'move_to_end')
	self:bind(k('ht'), 'complete')
end

function Editor:bind(seq, func)
	if #seq == 0 then return end

	if type(func) == 'string' then
		self.handlers[seq] = self.actions[func]
	else
		self.handlers[seq] = func
	end
end

-- Checks to see if the current sequence is the prefix of a handled string
-- Useful for seeing if we should wait for more characters or just output the sequence
function Editor:handler_prefix(seq)
	for k, v in pairs(self.handlers) do
		if k:sub(1, #seq) == seq then return true end
	end

	return false
end

-- Resets the state of the line editor
function Editor:reset()
	self.content = ''
	self.position = 1
	self.ready = false
end

-- Move the cursor to the following
function Editor:move_cur(position)
	lush.term.putcap('hpa', self.start_column - 1 + (position or self.position) - 1)
end

-- Clear the screen from the current cursor position to the end of the line
function Editor:clear_to_end()
	lush.term.putcap('el')
end

-- Output the current content of the line, with the cursor ending up in the right position
function Editor:refresh()
	self:move_cur(1)
	self:clear_to_end()
	io.write(self.content)
	self:move_cur()
end

function Editor:switch_history(new_pos)
	self.act_history[self.history_pos] = self.content
	self.history_pos = new_pos
	self.content = self.act_history[self.history_pos]
	self.position = #self.content + 1
	self:refresh()
end

function Editor:getline(start_column)
	self.act_history = {unpack(self.history)}
	self.act_history[#self.history + 1] = ''

	self.history_pos = #self.act_history
	self:reset()
	self.start_column = start_column
	seq = ''

	repeat
		char = io.read(1)
		if char == nil or char:byte() == 4 then return nil end
		seq = seq .. char

		if self.handlers[seq] then
			self.handlers[seq](self)
			seq = ''
		elseif not self:handler_prefix(seq) then
			if #seq > 1 or #seq.match('^%c$') then log.internal('Unrecognized sequence: %s', dumpstr(seq)) end
			seq = seq:gsub('%c', '')
			self.content = self.content:sub(1, self.position - 1) .. seq .. self.content:sub(self.position)
			self.position = self.position + #seq
			self:refresh()
			seq = ''
		end
	until self.ready

	io.write('\n')

	table.insert(self.history, self.content)
	return self.content
end

function Editor:prompt(sh)
	local ps1 = lush.fmt.make(sh:prompt())
	io.write(tostring(ps1))

	return self:getline(ps1.display_len + 1)
end

function init()
	lush.term.init()
	lush.term.setcanon(false)
	lush.term.setecho(false)

	lush.posix.signal("INT", cleanup)
	lush.posix.signal("TERM", cleanup)
end

function cleanup(sig)
	lush.term.setcanon(true)
	lush.term.setecho(true)
end
