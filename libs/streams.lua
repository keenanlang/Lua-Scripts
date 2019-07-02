lpeg = require("lpeg")

local l = {}
lpeg.locale(l)

local I = lpeg.Cp()
local P = lpeg.P

function anywhere (p)
	return lpeg.P{ p + 1 * lpeg.V(1) }
end

function anywhere_limited (p, num)
	return (1 - lpeg.P(p))^-num * p
end

function chars (num)
	local output = lpeg.P(true)

	for i = 1, num do
		output = output * (lpeg.P(1) - lpeg.P(" "))
	end

	return output
end

function digs (num)
	local output = lpeg.P(true)

	for i = 1, num do
		output = output * l.digit
	end

	return output
end

converters = {
	characters = { format = "s", type = "input", bind = chars },
	digits     = { format = "d", type = "input", bind = digs }
}

function build_replace(data)
	return lpeg.Cg(P'%' * (l.digit^0 / data.bind) * P(data.format) * #(l.space + P(-1)))
end

function all_formats()
	local output = lpeg.P(false)
	
	for key, value in pairs(converters) do
		output = output + build_replace(value)
	end
	
	return output
end

converter = all_formats()
rawtext = (P(1) - '%')^1 / P
ctrl = P'%%' / "%%"
item = rawtext + converter + ctrl
line = lpeg.Ct(item^1)

text = "This is %5s in the middle %3d"

match_table = line:match(text)

new_match = P(true)

for key, value in pairs(match_table) do
	new_match = new_match * value
end

new_match = lpeg.C(new_match)

--new_match = lpeg.C(lpeg.P(text:sub(1, match_table[1] - 1)) * match_table.replace * lpeg.P(text:sub(match_table[2])))

print(new_match:match "This is stuff in the middle 123")
