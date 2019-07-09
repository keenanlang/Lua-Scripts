lpeg = require("lpeg")
pprint = require("pprint")

local patt = {}
lpeg.locale(patt)

patt.inputs = {}
patt.outputs = {}

local P = lpeg.P
local C = lpeg.C
local G = lpeg.Cg
local S = lpeg.S

function patt.max_width(pattern, max_width)
	if (max_width == nil) then
		return pattern
	end

    return lpeg.Cmt(lpeg.P(true),
        function(s, i)
			local match = nil
			local last_match = nil
			local last_offset = 0
			local extract
			local offset

			for index = 1, max_width do
				extract, offset = lpeg.match(C(P(index)) * lpeg.Cp(), s, i)

				if (offset == nil) then
					if (last_match == nil) then
						return false
					else
						return last_offset
					end
				end

				match = lpeg.match(C(pattern), extract)

				if (match ~= nil) then
					last_match = match

					if (#match == #extract) then
						last_offset = offset
					end
				end
			end

			return last_offset
        end)
end

function patt.opt(pattern)
	return pattern^-1
end

patt.sign = S("+-")
patt.optsign = patt.opt(patt.sign)

patt.uint = patt.digit^1
patt.signed_int = patt.optsign * patt.uint
patt.decimal = patt.uint * patt.opt(P'.' * patt.uint)
patt.signed_decimal = patt.optsign * patt.decimal
patt.floating_point = patt.signed_decimal * patt.opt(S("eE") * patt.signed_int)

function patt.basic_read (pattern, to_apply)
	return function(flags)
		return C(patt.max_width(pattern, flags.width)) / to_apply
	end
end

function compile_input(format_specifier, format_function)
	local search = P'%'
	local flags = "*#+0-?=!"

	search = search * G(S(flags)^(-#flags), "flags")
	search = search * G(patt.digit^0 / tonumber, "width")
	search = search * G(patt.opt(P'.' * C(patt.digit^1)) / tonumber, "precision")
	search = search * P(format_specifier) * #(-patt.alpha)

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

function patt.add (cvt)
	if (cvt.read ~= nil) then
		patt.inputs[cvt.format] = cvt.read
	end

	if (cvt.write ~= nil) then
		patt.outputs[cvt.format] = cvt.write
	end
end

function all_formats()
	local output = P(false)

	for key, value in pairs(patt.inputs) do
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

patt.add { format = "s", read = patt.basic_read((P(1)-patt.space)^1, tostring) }
patt.add { format = "c", read = patt.basic_read(P(1)^1, tostring) }
patt.add { format = "d", read = patt.basic_read(patt.signed_int, tonumber) }
patt.add { format = "f", read = patt.basic_read(patt.floating_point, tonumber) }
patt.add { format = "e", read = patt.basic_read(patt.floating_point, tonumber) }
patt.add { format = "g", read = patt.basic_read(patt.floating_point, tonumber) }

check = parse_in("%d) %4s %4f%d")
test = check:match("1) Num: 3.1415")


if (test ~= nil) then
	for key, value in pairs(test) do
		print(tostring(value) .. " -> " .. type(value))
	end
else
	print("Did not match")
end
