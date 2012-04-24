module(..., package.seeall)

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

Editor = {}

function Editor:new()
	new_obj = setmetatable({
		content = '',
		handlers = {},
		history = {},
		position = 1,
		ready = false,
	}, {__index = self})

	new_obj:bind_defaults()

	return new_obj
end

function Editor:bind_defaults()
	k = lush.term.tigetstr

	self:bind(k('kbs'), function(line)
		if line.position == 1 then return end
		
		line.content = line.content:sub(1, line.position - 2) .. line.content:sub(line.position)
		line.position = line.position - 1
		line:refresh()
	end)

	self:bind(k('cr'), self.key_enter)
	self:bind('\n', self.key_enter)

	-- The gsub is because terminfo is a _filthy_ liar
	-- More specifically, the termcap for xterm only contains the key sequences
	-- for the numpad versions of the arrow keys.
	-- Why? Because your mother dresses you funny, that's why.
	self:bind(k('kcub1'):gsub('O', '['), function(line)
		-- Handle left arrow key
		if line.position == 1 then return end

		line.position = line.position - 1
		line:move_cur()
	end)

	self:bind(k('kcuf1'):gsub('O', '['), function(line)
		-- Handle right arrow key
		if line.position == #line.content + 1 then return end

		line.position = line.position + 1
		line:move_cur()
	end)

	-- Map the up and down arrow keys to null handlers
	self:bind(k('kcuu1'):gsub('O', '['), function(line)
		if line.history_pos == 1 then return end

		line:switch_history(line.history_pos - 1)
	end)

	self:bind(k('kcud1'):gsub('O', '['), function(line)
		if line.history_pos == #line.act_history then return end

		line:switch_history(line.history_pos + 1)
	end)

	self:bind(k('khome'), function(line)
		line.position = 1
		line:move_cur()
	end)

	self:bind(k('kend'), function(line)
		line.position = #line.content + 1
		line:move_cur()
	end)
end

function Editor:bind(seq, func)
	self.handlers[seq] = func
end

-- Checks to see if the current sequence is the prefix of a handled string
-- Useful for seeing if we should wait for more characters or just output the sequence
function Editor:handler_prefix(seq)
	for k, v in pairs(self.handlers) do
		if k:sub(1, #seq) == seq then return true end
	end

	return false
end

function Editor:key_enter()
	self.ready = true
	self:move_cur(#self.content + 1)
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

function Editor:prompt(env)
	local ps1 = env.get_ps1()
	io.write(ps1)

	return self:getline(#ps1 + 1)
end

function init()
	lush.term.init()
	lush.term.setcanon(false)
	lush.term.setecho(false)

	lush.proc.signal("INT", cleanup)
	lush.proc.signal("TERM", cleanup)
end

function cleanup(sig)
	lush.term.setcanon(true)
	lush.term.setecho(true)
end
