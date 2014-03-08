module(..., package.seeall)

require "log"
require "lush.completion"
require "lush.fmt"
require "lush.prompt.actions"
require "lush.prompt.bindings"

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

function Editor:new(sh)
	obj = setmetatable({
		content = '',
		sh = sh,
		actions = {},
		bindings = {},
		history = {},
		position = 1,
		ready = false,
	}, {__index = self})

	for action, handler in pairs(lush.prompt.actions.default_actions) do
		obj.actions[action] = handler
	end

	obj:load_bindings(lush.prompt.bindings.emacs)

	return obj
end

function Editor:bind(seq, action)
	if #seq == 0 then return end
	if type(seq) == 'table' then return Editor:load_bindings(seq) end

	self.bindings[seq] = action
end

function Editor:bind_keys(keys, action)
end

function Editor:load_bindings(bindings)
	for i, binding in ipairs(bindings) do
		if binding.terminfo then
			local success = pcall(function()
				self:bind(lush.term.tigetstr(binding.terminfo), binding[1])
			end)
			if not (success or binding.fallback) then
				log.warn('Could not bind terminfo `%s` to %s')
			end

			if binding.fallback and not self.bindings[binding.fallback] then
				self:bind(binding.fallback, binding[1])
			end
		elseif binding.keys then
			success, error = pcall(function()
				self:bind_keys(binding.keys, binding[1])
			end)

			if not success then log.error(error) end
		elseif binding.text then
			self:bind(binding.text, binding[1])
		end
	end
end

-- Checks to see if the current sequence is the prefix of a handled string
-- Useful for seeing if we should wait for more characters or just output the sequence
function Editor:handler_prefix(seq)
	for k, v in pairs(self.bindings) do
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

		action = nil

		if self.bindings[seq] then
			action = self.bindings[seq]
		elseif not self:handler_prefix(seq) then
			action = self.bindings['_default']
		end

		if action then
			self.actions[action](self, seq)
			self.last_action = action
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
