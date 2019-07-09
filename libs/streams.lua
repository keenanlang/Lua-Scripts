lpeg = require("lpeg")
pprint = require("pprint")

local patt = {}
lpeg.locale(patt)

patt.inputs = {}
patt.outputs = {}
patt.hash = {}

local P = lpeg.P
local C = lpeg.C
local G = lpeg.Cg
local S = lpeg.S

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
					extract, offset = lpeg.match(C(P(index)) * lpeg.Cp(), s, i)
	
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
	
	return lpeg.Cmt(lpeg.P(true),
		function(s, i)
			local extract, offset = lpeg.match(C(P(max_width)) + lpeg.Cp(), s, i)
			
			if (not offset) then  return false end
			
			if (lpeg.match(C(pattern), extract)) then
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
		return lpeg.P(true)
	end
end

function patt.basic_read (datatable)
	return function(flags)
	
		local e = {}
		e.patt = {}
		e.lpeg = lpeg
		
		lpeg.locale(e.patt)
		
		e.patt.opt = patt.opt
		e.patt.if_hash = patt.if_hash
		e.patt.sign = S("+-")
		e.patt.optsign = e.patt.opt(e.patt.sign) * e.patt.if_hash(e.patt.space^0, flags.hash)
		e.patt.uint = e.patt.digit^1
		e.patt.decimal = e.patt.uint * e.patt.opt(P'.' * e.patt.uint)
		e.patt.signed_int = e.patt.optsign * e.patt.uint
		e.patt.signed_decimal = e.patt.optsign * e.patt.decimal
		e.patt.floating_point = e.patt.signed_decimal * e.patt.opt(S("eE") * e.patt.signed_int)
	
		local output = load("return (" .. datatable.pattern .. ")", "=(load)", "t", e)()
		
		output = patt.max_width(output, flags.width, flags.exact_width)
		
		if      (not flags.ignore and flags.strict) then
			output = C(output) / datatable.conversion
		elseif  (not flags.ignore and not flags.strict) then
			output = (C(output) + lpeg.Cc(datatable.defaultvalue)) / datatable.conversion
		elseif  (flags.ignore and not flags.strict) then
			output = output + lpeg.P(true)
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

	return lpeg.Ct(search) / parse_fields / format_function
end

function patt.add (cvt)
	if (cvt.read ~= nil) then
		patt.inputs[cvt.format] = cvt.read
	end

	if (cvt.write ~= nil) then
		patt.outputs[cvt.format] = cvt.write
	end
end

local function all_formats()
	local output = P(false)

	for key, value in pairs(patt.inputs) do
		output = output + compile_input(key, value)
	end

	return output
end

local function parse_in (to_parse)
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

	return lpeg.Ct(C(output)) / table.unpack
end

local function tofloat(toparse)
	trimmed = toparse:gsub(" ", "")
	return tonumber(trimmed)
end

patt.add { format = "s", read = patt.basic_read {pattern = [[(lpeg.P(1)-patt.space)^1]], conversion = tostring, defaultvalue=""} }
patt.add { format = "c", read = patt.basic_read {pattern = [[lpeg.P(1)^1]], conversion = tostring, defaultvalue="" } }

patt.add { 
	format = "d",
	read = patt.basic_read {
			pattern      = [[patt.signed_int]],
			conversion = tonumber,
			defaultvalue = 0 } }
			
patt.add { 
	format = "f", 
	read = patt.basic_read { 
			pattern      = [[patt.floating_point]],
			conversion   = tofloat,
			defaultvalue = 0.0} }
patt.add { 
	format = "e",
	read = patt.basic_read { 
			pattern      = [[patt.floating_point]],
			conversion   = tofloat,
			defaultvalue = 0.0} }
			
patt.add { 
	format = "g",
	read = patt.basic_read { 
			pattern      = [[patt.floating_point]],
			conversion   = tofloat,
			defaultvalue = 0.0} }

			
check = parse_in("%#?f %d %s")
matched, a, b, c = check:match("+ 41e17 123 hello")

if (matched) then
	print(a,b,c)

	-- for key, value in pairs(test) do
		-- print(tostring(value) .. " -> " .. type(value))
	-- end
else
	print("Did not match")
end
