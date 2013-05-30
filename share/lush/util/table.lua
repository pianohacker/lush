module(..., package.seeall)

function insort(tbl, val, comp)
	if #tbl == 0 then
		table.insert(tbl, val)
		return
	end

	comp = comp or function(a, b) return a < b end
	local start = 1
	local fin = #tbl
	local idx

	repeat
		idx = math.floor((fin + start) / 2)
		if comp(val, tbl[idx]) then
			fin = idx
		else
			start = idx
		end
	until math.abs(start - fin) <= 1

	while idx <= #tbl and not comp(val, tbl[idx]) do
		idx = idx + 1
	end

	table.insert(tbl, idx, val)
end
