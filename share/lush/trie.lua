module(..., package.seeall)

Trie = {}

function _get_node(node, key, vivify)
	if #key == 0 then return node, '' end

	if not node[key:byte()] then
		if vivify then
			node[key:byte()] = {}
		else
			return nil, key
		end
	end

	return _get_node(node[key:byte()], key:sub(2), vivify)
end

function new(values)
	new_trie = setmetatable({}, {
		__index = Trie
	})

	if values then
		for key, value in pairs(values) do
			new_trie:set(key, value)
		end
	end

	return new_trie
end

function Trie:has_prefix(key)
	node, trail = _get_node(self, key)

	return node and true
end

function Trie:get(key)
	node, trail = _get_node(self, key)

	if not node then return end

	return node._val, trail
end

function Trie:completions(key)
	start_node, trail = _get_node(self, key)

	waiting = {start_node}
	checked = {}

	return function()
		if not start_node then return end

		while #waiting ~= 0 do
			node = table.remove(waiting)

			if node._val then
				return node._key, node._val
			else
				for key = 0, 255 do
					val = node[key]
					if val and not checked[val] then
						table.insert(waiting, 1, val)
						checked[val] = true
					end
				end
			end
		end

		return nil
	end
end

function Trie:set(key, val)
	node = _get_node(self, key, true)

	node._key = key
	node._val = val
end
