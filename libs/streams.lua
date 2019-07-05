lpeg = require("lpeg")
pprint = require("pprint")

local stream = { char = {}, inputs = {}, outputs = {} }
lpeg.locale(stream.char)

local l = stream.char

local P = lpeg.P
local C = lpeg.C
local G = lpeg.Cg
local S = lpeg.S

function stream.maybe(pattern)
	return pattern^-1
end

function stream.repeat_exactly(pattern, times)
	local output = P(true)

	for i = 1, times do
		output = output * pattern
	end

	return output
end

function stream.basic_read (pattern, to_apply)
	return function(flags)
		if (flags.width == nil) then
			return C(pattern^1) / to_apply
		else
			return C(stream.repeat_exactly(pattern, flags.width)) / to_apply
		end
	end
end

function compile_input(format_specifier, format_function)
	local search = P'%'
	local flags = "*#+0-?=!"

	search = search * G(S(flags)^(-#flags), "flags")
	search = search * G(l.digit^0 / tonumber, "width")
	search = search * G(stream.maybe(P'.' * C(l.digit^1)) / tonumber, "precision")
	search = search * P(format_specifier) * #(-l.alpha)

	local function parse_fields(data)
		local function exists(x) return (x ~= nil) end

		local output = {}

		output.width = data.width
		output.precision = data.precision

		output.strict = not exists(data.flags:find("?"))
		output.ignore = exists(data.flags:find("*"))
		output.exact_width = exists(data.flags:find("!"))
		output.left_pad = exists(data.flags:find("-"))
		output.pad_zeroes = exists(data.flags:find("0"))
		output.compare = exists(data.flags:find("="))
		output.hash = exists(data.flags:find("#"))

		return output
	end

	search = lpeg.Ct(search) / parse_fields / format_function

	return search
end

function stream.add_converter (cvt)
	if (cvt.read ~= nil) then
		stream.inputs[cvt.format] = cvt.read
	end

	if (cvt.write ~= nil) then
		stream.outputs[cvt.format] = cvt.write
	end
end

local function floating_point (flags)
	pprint(flags)

	local mpm = stream.maybe(S("+-"))
	local digits = l.digit^1
	local dot = P(".")
	local exp = S("eE")

	local float = mpm * digits * stream.maybe(dot * digits) * stream.maybe(exp * mpm * digits)

	return C(float) / tonumber
end

function all_formats()
	local output = P(false)

	for key, value in pairs(stream.inputs) do
		output = output + compile_input(key, value)
	end

	return output
end

function parse_in (to_parse)
	local converter = all_formats()
	local rawtext = (P(1) - '%')^1 / P
	local ctrl = P'%%' / "%%"
	local item = rawtext + converter + ctrl
	local line = lpeg.Ct(item^1)

	local match_table = line:match(to_parse)

	if (match_table == nil) then
		error("Input line not parse-able")
	end

	local output = P(true)

	for key, value in pairs(match_table) do
		output = output * value
	end

	return lpeg.Ct(C(output))
end

stream.add_converter { format = "s", read = stream.basic_read(P(1) - l.space, tostring) }
stream.add_converter { format = "d", read = stream.basic_read(l.digit, tonumber) }
stream.add_converter { format = "f", read = floating_point }

check = parse_in("%d) %4s %5.4f")
test = check:match("1) Num: 3.14e15")

if (test ~= nil) then
	for key, value in pairs(test) do
		print(tostring(value) .. " -> " .. type(value))
	end
else
	print("Did not match")
end
