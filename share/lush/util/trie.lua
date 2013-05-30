module(..., package.seeall)

Trie = {}

-- Get the node for a given sequence, optionally creating it if necessary.
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

-- Create a new trie.
-- @param values An optional table, whose key-value pairs will be stored in the trie
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

-- Check to see if this trie has any nodes with the given prefix
function Trie:has_prefix(key)
	node, trail = _get_node(self, key)

	return node and true
end

-- Get the value for the best match to a key.
-- @param key The prefix to search for
-- @return The value for the found node, or nil if it was not found
-- @return Remaining text that was not matched by the node
function Trie:get(key)
	node, trail = _get_node(self, key)

	if not node then return end

	return node._val, trail
end

-- Get all entries within this trie that start with the given key
-- @param key The prefix to search for
-- @return An iterator over all possible completions
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

-- Add the given key/value pair to the trie.
function Trie:set(key, val)
	node = _get_node(self, key, true)

	node._key = key
	node._val = val
end
