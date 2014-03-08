module(..., package.seeall)

require "log"

default_actions = {}

function default_actions:insert_text(seq)
	if #seq > 1 or seq:match('^%c$') then log.internal('Unrecognized sequence: %s', dumpstr(seq)) end
	seq = seq:gsub('%c', '')
	self.content = self.content:sub(1, self.position - 1) .. seq .. self.content:sub(self.position)
	self.position = self.position + #seq
	self:refresh()
end

function default_actions:complete()
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
	if self.last_action == 'complete' then
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

function default_actions:delete_left()
	if self.position == 1 then return end
	
	self.content = self.content:sub(1, self.position - 2) .. self.content:sub(self.position)
	self.position = self.position - 1
	self:refresh()
end

function default_actions:delete_right()
	self.content = self.content:sub(1, self.position - 1) .. self.content:sub(self.position + 1)
	self:refresh()
end

function default_actions:finish()
	self.ready = true
	self:move_cur(#self.content + 1)
end

function default_actions:history_show_prev()
	if self.history_pos == 1 then return end

	self:switch_history(self.history_pos - 1)
end

function default_actions:history_show_next()
	if self.history_pos == #self.act_history then return end

	self:switch_history(self.history_pos + 1)
end

function default_actions:move_left()
	-- Handle left arrow key
	if self.position == 1 then return end

	self.position = self.position - 1
	self:move_cur()
end

function default_actions:move_right()
	-- Handle right arrow key
	if self.position == #self.content + 1 then return end

	self.position = self.position + 1
	self:move_cur()
end

function default_actions:move_to_start()
	self.position = 1
	self:move_cur()
end

function default_actions:move_to_end()
	self.position = #self.content + 1
	self:move_cur()
end
