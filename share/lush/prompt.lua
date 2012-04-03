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

line = {
	handlers = {}
}

function line:add_handler(seq, func)
	line.handlers[seq] = func
end

function line:setup_handlers()
	k = lush.term.tigetstr

	line:add_handler(k('kbs'), function(line)
		if line.position == 1 then return end
		
		line.content = line.content:sub(1, line.position - 2) .. line.content:sub(line.position)
		line.position = line.position - 1
		line:refresh()
	end)

	line:add_handler(k('cr'), line.key_enter)
	line:add_handler('\n', line.key_enter)

	-- The gsub is because terminfo is a _filthy_ liar
	line:add_handler(k('kcub1'):gsub('O', '['), function(line)
		-- Handle left arrow key
		if line.position == 1 then return end

		line.position = line.position - 1
		line:move_cur()
	end)

	line:add_handler(k('kcuf1'):gsub('O', '['), function(line)
		-- Handle right arrow key
		if line.position == #line.content + 1 then return end

		line.position = line.position + 1
		line:move_cur()
	end)

	-- Map the up and down arrow keys to null handlers
	line:add_handler(k('kcuu1'):gsub('O', '['), function(line) end)
	line:add_handler(k('kcud1'):gsub('O', '['), function(line) end)

	line:add_handler(k('khome'), function(line)
		line.position = 1
		line:move_cur()
	end)

	line:add_handler(k('kend'), function(line)
		line.position = #line.content + 1
		line:move_cur()
	end)
end

-- Checks to see if the current sequence is the prefix of a handled string
-- Useful for seeing if we should wait for more characters or just output the sequence
function line:handler_prefix(seq)
	for k, v in pairs(line.handlers) do
		if k:sub(1, #seq) == seq then return true end
	end

	return false
end

function line:key_enter()
	line.ready = true
	line:move_cur(#line.content + 1)
end

-- Resets the state of the line editor
function line:reset()
	line.content = ''
	line.position = 1
	line.ready = false
end

-- Move the cursor to the following
function line:move_cur(position)
	lush.term.putcap('hpa', self.start_column - 1 + (position or line.position) - 1)
end

-- Clear the screen from the current cursor position to the end of the line
function line:clear_to_end()
	lush.term.putcap('el')
end

-- Output the current content of the line, with the cursor ending up in the right position
function line:refresh()
	line:move_cur(1)
	line:clear_to_end()
	io.write(line.content)
	line:move_cur()
end

function line:getline(start_column)
	line:reset()
	line.start_column = start_column
	seq = ''

	repeat
		char = io.read(1)
		if char == nil or char:byte() == 4 then return nil end
		seq = seq .. char

		if line.handlers[seq] then
			line.handlers[seq](line)
			seq = ''
		elseif not line:handler_prefix(seq) then
			line.content = line.content:sub(1, line.position - 1) .. seq .. line.content:sub(line.position)
			line.position = line.position + #seq
			line:refresh()
			seq = ''
		end
	until line.ready

	io.write('\n')

	return line.content
end

function init()
	lush.term.init()
	lush.term.setcanon(false)
	lush.term.setecho(false)
	line:setup_handlers()

	lush.proc.signal("INT", cleanup)
	lush.proc.signal("TERM", cleanup)
end

function prompt(env)
	local ps1 = env.get_ps1()
	io.write(ps1)

	return line:getline(#ps1 + 1)
end

function cleanup(sig)
	lush.term.setcanon(true)
	lush.term.setecho(true)
end
