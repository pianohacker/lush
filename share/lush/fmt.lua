module(..., package.seeall)

Format = {}

function Format:new(content, display_len)
	return setmetatable({
		content = content,
		display_len = display_len or #content,
	}, {
		__index = self,
		__concat = make,
		__len = self.__len,
		__tostring = self.__tostring
	})
end

function Format:__tostring()
	return self.content
end

function make(...)
	content = ''
	display_len = 0

	for i, arg in ipairs{...} do
		if type(arg) == 'string' then
			content = content .. arg
			display_len = display_len + #arg
		else
			content = content .. arg.content
			display_len = display_len + arg.display_len
		end
	end

	return Format:new(content, display_len)
end

function _surrounder(start, finish)
	return function(text)
		return Format:new(start .. text .. finish, #text)
	end
end

bold = _surrounder('\27[1m', '\27[22m')
