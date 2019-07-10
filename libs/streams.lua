lpeg = require("lpeg")
pprint = require("pprint")

local stream = {}
stream.inputs = {}
stream.outputs = {}

local patt = {}
lpeg.locale(patt)

patt.P = lpeg.P
patt.C = lpeg.C
patt.G = lpeg.Cg
patt.S = lpeg.S
patt.T = lpeg.Ct
patt.I = lpeg.Cp
patt.Cmt = lpeg.Cmt
patt.Cc = lpeg.Cc

patt.match = lpeg.match

function patt.max_width(pattern, max_width, exact_width)
	if (max_width == nil) then
		return pattern
	end

	if (exact_width == nil or exact_width == false) then
		return lpeg.Cmt(lpeg.P(true),
			function(s, i)
				local match = nil
				local last_match = nil
				local last_offset = 0
				local extract
				local offset

				for index = 1, max_width do
					extract, offset = patt.match(patt.C(patt.P(index)) * patt.I(), s, i)

					if (not offset) then
						return last_offset or false
					end

					match = patt.match(patt.C(pattern), extract)

					if (match) then
						last_match = match

						if (#match == #extract) then
							last_offset = offset
						end
					end
				end

				return last_offset
			end)
	end

	return patt.Cmt(patt.P(true),
		function(s, i)
			local extract, offset = patt.match(patt.C(patt.P(max_width)) + patt.I(), s, i)

			if (not offset) then  return false end

			if (patt.match(patt.C(pattern), extract)) then
				return offset
			else
				return false
			end
		end)
end

function patt.opt(pattern)
	return pattern^-1
end

function patt.if_hash(pattern, hash)
	if (hash) then
		return pattern
	else
		return patt.P(true)
	end
end

function patt.read (datatable)
	if (datatable.defaultvalue == nil) then
		datatable.defaultvalue = datatable.conversion("") or datatable.conversion("0")
	end

	return function(flags)

		local e = {}
		e.patt = {}
		e.lpeg = lpeg

		lpeg.locale(e.patt)

		e.patt.P = lpeg.P
		e.patt.C = lpeg.C
		e.patt.G = lpeg.Cg
		e.patt.S = lpeg.S
		e.patt.T = lpeg.Ct
		e.patt.I = lpeg.Cp
		e.patt.Cmt = lpeg.Cmt
		e.patt.Cc = lpeg.Cc

		e.patt.match = lpeg.match

		e.patt.opt = patt.opt
		e.patt.if_hash = patt.if_hash
		e.patt.max_width = patt.max_width
		e.patt.sign = patt.S("+-")
		e.patt.optsign = e.patt.opt(e.patt.sign) * e.patt.if_hash(e.patt.space^0, flags.hash)
		e.patt.uint = e.patt.digit^1
		e.patt.decimal = e.patt.uint * e.patt.opt(patt.P'.' * e.patt.uint)
		e.patt.signed_int = e.patt.optsign * e.patt.uint
		e.patt.signed_decimal = e.patt.optsign * e.patt.decimal
		e.patt.floating_point = e.patt.signed_decimal * e.patt.opt(patt.S("eE") * e.patt.signed_int)

		local output = load("return (" .. datatable.pattern .. ")", "=(load)", "t", e)()

		output = patt.max_width(output, flags.width, flags.exact_width)

		if      (not flags.ignore and flags.strict) then
			output = patt.C(output) / datatable.conversion
		elseif  (not flags.ignore and not flags.strict) then
			output = (patt.C(output) + patt.Cc(datatable.defaultvalue)) / datatable.conversion
		elseif  (flags.ignore and not flags.strict) then
			output = output + patt.P(true)
		end

		return output
	end
end

function compile_input(format_specifier, format_function)
	local search = patt.P'%'
	local flags = "*#+0-?=!"

	search = search * patt.G(patt.S(flags)^(-#flags), "flags")
	search = search * patt.G(patt.digit^0 / tonumber, "width")
	search = search * patt.G(patt.opt(patt.P'.' * patt.C(patt.digit^1)) / tonumber, "precision")
	search = search * patt.P(format_specifier)

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

	return patt.T(search) / parse_fields / format_function
end

function stream.add_format (cvt)
	if (cvt.read ~= nil) then
		stream.inputs[cvt.format] = cvt.read
	end

	if (cvt.write ~= nil) then
		stream.outputs[cvt.format] = cvt.write
	end
end

local function all_formats()
	local output = patt.P(false)

	for key, value in pairs(stream.inputs) do
		output = output + compile_input(key, value)
	end

	return output
end

local function parse_in (to_parse)
	local converter = all_formats()
	local rawtext = (patt.P(1) - '%')^1 / patt.P
	local ctrl = patt.P'%%' / "%%"
	local item = rawtext + converter + ctrl
	local line = patt.T(item^1)

	local match_table = line:match(to_parse)

	if (match_table == nil) then
		error("Input line not parse-able")
	end

	local output = patt.P(true)

	for key, value in pairs(match_table) do
		output = output * value
	end

	return patt.T(patt.C(output)) / table.unpack
end

local function tofloat(toparse)
	trimmed = toparse:gsub(" ", "")
	return tonumber(trimmed)
end

stream.add_format {
	format = "s",
	read = patt.read {
			pattern = [[(patt.P(1)-patt.space)^1]],
			conversion = tostring } }

stream.add_format {
	format = "c",
	read = patt.read {
			pattern = [[patt.P(1)^1]],
			conversion = tostring } }

stream.add_format {
	format = "d",
	read = patt.read {
			pattern    = [[patt.signed_int]],
			conversion = tonumber } }

stream.add_format {
	format = "f",
	read = patt.read {
			pattern      = [[patt.floating_point]],
			conversion   = tofloat } }
stream.add_format {
	format = "e",
	read = patt.read {
			pattern      = [[patt.floating_point]],
			conversion   = tofloat } }

stream.add_format {
	format = "g",
	read = patt.read {
			pattern      = [[patt.floating_point]],
			conversion   = tofloat } }


check = parse_in("%5f%d%s")
matched, a, b, c = check:match("41e17123hello")

if (matched) then
	print(a,b,c)

	-- for key, value in pairs(test) do
		-- print(tostring(value) .. " -> " .. type(value))
	-- end
else
	print("Did not match")
end
