lpeg = require("lpeg")
pprint = require("pprint")

P   = lpeg.P
C   = lpeg.C
G   = lpeg.Cg
S   = lpeg.S
T   = lpeg.Ct
I   = lpeg.Cp
Cmt = lpeg.Cmt
Cc  = lpeg.Cc

local stream = {}
stream.inputs = {}
stream.outputs = {}

local patt = {}
lpeg.locale(patt)

function patt.opt(pattern)
	return pattern^-1
end

patt.sign = S("+-")
patt.max_width = patt.max_width
patt.check = {
	optsign = function ()
		if (hash) then   return patt.opt(patt.sign) * patt.space^0
		else             return patt.opt(patt.sign) end
	end,
	
	uint = function ()            return patt.digit^1 end,
	decimal = function ()         return patt.uint * patt.opt(P'.' * patt.uint) end,
	signed_int = function ()      return patt.optsign * patt.uint end,
	signed_decimal = function ()  return patt.optsign * patt.decimal end,
	floating_point = function ()  return patt.signed_decimal * patt.opt(S("eE") * patt.signed_int) end
}

local patt_meta = {
	__index = function(self, key)
		if (self.check[key] ~= nil) then
			return self.check[key]()
		end

		return nil
	end
}

setmetatable(patt, patt_meta)


function patt.max_width(pattern, max_width, exact_width)
	if (max_width == nil) then
		return pattern
	end

	if (exact_width == nil or exact_width == false) then
		return Cmt(P(true),
			function(s, i)
				local match = nil
				local last_match = nil
				local last_offset = 0
				local extract
				local offset

				for index = 1, max_width do
					extract, offset = lpeg.match(C(P(index)) * I(), s, i)

					if (not offset) then
						return last_offset or false
					end

					match = lpeg.match(C(pattern), extract)

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

	return Cmt(P(true),
		function(s, i)
			local extract, offset = lpeg.match(C(P(max_width)) + I(), s, i)

			if (not offset) then  return false end

			if (lpeg.match(C(pattern), extract)) then
				return offset
			else
				return false
			end
		end)
end

function patt.read (datatable)
	if (datatable.defaultvalue == nil) then
		datatable.defaultvalue = datatable.conversion("") or datatable.conversion("0")
	end

	return function(flags)

		local e = {}
		e.patt = patt
		e.lpeg = lpeg
		e.hash = flags.hash

		local output = load("return (" .. datatable.pattern .. ")", "=(load)", "t", e)()

		output = patt.max_width(output, flags.width, flags.exact_width)

		if      (not flags.ignore and flags.strict) then
			output = C(output) / datatable.conversion
		elseif  (not flags.ignore and not flags.strict) then
			output = (C(output) + Cc(datatable.defaultvalue)) / datatable.conversion
		elseif  (flags.ignore and not flags.strict) then
			output = output + P(true)
		end

		return output
	end
end

function compile_input(format_specifier, format_function)
	local search = P'%'
	local flags = "*#+0-?=!"

	search = search * G(S(flags)^(-#flags), "flags")
	search = search * G(patt.digit^0 / tonumber, "width")
	search = search * G(patt.opt(P'.' * C(patt.digit^1)) / tonumber, "precision")
	search = search * P(format_specifier)

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

	return T(search) / parse_fields / format_function
end

function stream.add_format (cvt)
	if (cvt.read ~= nil) then
		stream.inputs[cvt.identifier] = cvt.read
	end

	if (cvt.write ~= nil) then
		stream.outputs[cvt.identifier] = cvt.write
	end
end

local function all_formats()
	local output = P(false)

	for key, value in pairs(stream.inputs) do
		output = output + compile_input(key, value)
	end

	return output
end

local function parse_in (to_parse)
	local converter = all_formats()
	local rawtext = (P(1) - '%')^1 / P
	local ctrl = P'%%' / "%%"
	local item = rawtext + converter + ctrl
	local line = T(item^1)

	local match_table = line:match(to_parse)

	if (match_table == nil) then
		error("Input line not parse-able")
	end

	local output = P(true)

	for key, value in pairs(match_table) do
		output = output * value
	end

	return T(C(output)) / table.unpack
end

local function tofloat(toparse)
	trimmed = toparse:gsub(" ", "")
	return tonumber(trimmed)
end

stream.add_format {
	identifier = "s",
	read = patt.read {
			pattern = [[(lpeg.P(1)-patt.space)^1]],
			conversion = tostring } }

stream.add_format {
	identifier = "c",
	read = patt.read {
			pattern = [[lpeg.P(1)^1]],
			conversion = tostring } }

stream.add_format {
	identifier = "d",
	read = patt.read {
			pattern    = [[patt.signed_int]],
			conversion = tonumber } }

stream.add_format {
	identifier = "f",
	read = patt.read {
			pattern      = [[patt.floating_point]],
			conversion   = tofloat } }
stream.add_format {
	identifier = "e",
	read = patt.read {
			pattern      = [[patt.floating_point]],
			conversion   = tofloat } }

stream.add_format {
	identifier = "g",
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
