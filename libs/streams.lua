lpeg = require("lpeg")

local I = lpeg.Cp()

function anywhere (p, num)
	return (1 - lpeg.P(p))^-num * p
end

function numchars (num)
	return lpeg.P(num) - anywhere(" ", num);
end

print( lpeg.C(numchars(20)):match "Thisisthetarget sentence that I am writing")
