lpeg = require("lpeg")

function anywhere (p)
	return lpeg.P{ p + 1 * lpeg.V(1) }
end

function anywhere_limited (p, num)
	return (1 - lpeg.P(p))^-num * p
end

function numchars (num)
	local output = lpeg.P(true)

	for i = 1, num do
		output = output * (lpeg.P(1) - lpeg.P(" "))
	end

	return output
end

test_replace = lpeg.Ct(anywhere(lpeg.Cp() * lpeg.P("%") * lpeg.Cg(lpeg.R("09")^0, "width") * lpeg.P("s") * lpeg.Cp()))

text = "This is %5s in the middle"

match_table = test_replace:match(text)

new_match = lpeg.C(lpeg.P(text:sub(1, match_table[1] - 1)) * numchars(match_table["width"]) * lpeg.P(text:sub(match_table[2])))

print( new_match:match "This is aword in the middle")
