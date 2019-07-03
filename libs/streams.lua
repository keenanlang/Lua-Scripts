lpeg = require("lpeg")

local stream = { char = {} }
lpeg.locale(stream.char)

local l = stream.char

local P = lpeg.P
local G = lpeg.Cg
local S = lpeg.S

function stream.repeat_exactly(pattern, times)
	local output = P(true)
	
	for i = 1, times do
		output = output * pattern
	end
	
	return output
end

function stream.basic_bind (pattern)
	return function(width)
		if (width == nil) then
			return pattern^1
		else
			return stream.repeat_exactly(pattern, width)
		end
	end
end

local function floating_point (width)
	local function maybe(p) return p^-1 end
	local mpm = maybe(S("+-"))
	local digits = l.digit^1
	local dot = P(".")
	local exp = S("eE")
	
	local float = mpm * digits * maybe(dot * digits) * maybe(exp * mpm * digits)
	
	return float
end

function all_formats()
	local output = lpeg.P(false)
	
	for key, value in pairs(converters) do
		local temp = G(P'%' * (l.digit^0 / tonumber / value.bind) * P(value.format) * #(-l.alpha))
		output = output + build_replace(value)
	end
	
	return output
end

converters = {
	characters = { format = "s", type = "input", bind = stream.basic_bind(P(1) - l.space) },
	digits     = { format = "d", type = "input", bind = stream.basic_bind(l.digit) },
	float      = { format = "f", type = "input", bind = floating_point }
}

converter = all_formats()
rawtext = (P(1) - '%')^1 / P
ctrl = P'%%' / "%%"
item = rawtext + converter + ctrl
line = lpeg.Ct(item^1)

text = "This is %f"

match_table = line:match(text)

new_match = P(true)

for key, value in pairs(match_table) do
	new_match = new_match * value
end

new_match = lpeg.C(new_match)

--new_match = lpeg.C(lpeg.P(text:sub(1, match_table[1] - 1)) * match_table.replace * lpeg.P(text:sub(match_table[2])))

print(new_match:match "This is 3.14e15")
