lpeg = require("lpeg")
pprint = require("pprint")

P   = lpeg.P
C   = lpeg.C
G   = lpeg.Cg
S   = lpeg.S
R   = lpeg.R
T   = lpeg.Ct
I   = lpeg.Cp
Cmt = lpeg.Cmt
Cc  = lpeg.Cc

local stream = {}
stream.inputs = {}
stream.outputs = {}

function stream.generate_patterns(flags, dest)
	local out = dest or {}

	lpeg.locale(out)
	
	out.L = lpeg.P
	out.R = lpeg.R
	out.S = lpeg.S

	out.opt = function (pattern)
		return pattern^-1
	end
	
	out.if_hash = function(pattern)
		if (flags.hash) then return pattern
		else                 return lpeg.P(true)
		end
	end 
	
	out.if_neg = function(pattern)
		if (flags.left_pad) then return pattern
		else                     return lpeg.P(true)
		end
	end
	
	out.sign =           out.S("+-")
	out.optsign =        out.opt(out.sign) * out.if_hash(out.space^0)
	out.uint =           out.digit^1
	out.decimal =        out.uint * out.opt(out.L'.' * out.uint)
	out.signed_int =     out.optsign * out.uint
	out.signed_decimal = out.optsign * out.decimal
	out.floating_point = out.signed_decimal * out.opt(out.S'eE' * out.signed_int)
	out.octal =          out.if_neg(out.optsign) * out.R'07'^1
	out.hexadecimal =    out.if_neg(out.optsign) * out.opt(out.L'0' * out.S'xX') * (out.digit + out.R'af' + out.R'AF')^1
	
	out.max_width = function(pattern, max_width, exact_width)
		if (max_width == nil) then return pattern end
		
		local min_width = 1
		
		if (exact_width == true) then min_width = max_width end
	
		return Cmt(P(true),
			function(s, i)
				local match, last_match
				local last_offset = nil
				local extract, offset
	
				for index = min_width, max_width do
					local extract, offset = lpeg.match(C(P(index)) * I(), s, i)
	
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
	
	return out
end

function stream.basic_reader (datatable)
	if (datatable.defaultvalue == nil) then
		datatable.defaultvalue = datatable.conversion("") or datatable.conversion("0")
	end

	return function(flags)
		local e = {}
		
		stream.generate_patterns(flags, e)
		e.lpeg = lpeg
		e.flags = flags
		
		local output = load("return (" .. datatable.pattern .. ")", "=(load)", "t", e)()

		output = C(e.max_width(output, flags.width, flags.exact_width))

		if (not flags.strict) then
			output = output + Cc(datatable.defaultvalue)
		end
		
		output = output / datatable.conversion
		
		if (flags.ignore) then
			output = G(output, "ignore")
		end
		
		return output
	end
end

function compile_input(format_specifier, format_function)
	local search = P'%'
	local flags = "*#+0-?=!"
	
	search = search * G(S(flags)^(-#flags), "flags")
	search = search * G(lpeg.locale().digit^0 / tonumber, "width")
	search = search * G((P'.' * C(lpeg.locale().digit^1))^-1 / tonumber, "precision")
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
	local line = lpeg.Cf(item^1, function(x,y) return x*y end)

	local compiled_pattern = line:match(to_parse)
	
	if (not compiled_pattern) then  error("Input line not parse-able") end

	return T(C(compiled_pattern)) / table.unpack
end

local function strip(toparse, characters)
	return table.pack(toparse:gsub(characters, ""))[1]
end

local function tofloat(toparse)
	return tonumber(strip(toparse, " "))
end

local function octtonumber(toparse)
	return tonumber(strip(toparse, " "), 8)
end

local function hextonumber(toparse, b)
	return tonumber(strip(strip(strip(toparse, " "), "0x"), "0X"), 16)
end

-- String Formats
stream.add_format {
	identifier = "s",
	read = stream.basic_reader {
			pattern = [[(lpeg.P(1)-space)^1]],
			conversion = tostring } }

stream.add_format {
	identifier = "c",
	read = stream.basic_reader {
			pattern = [[lpeg.P(1)^1]],
			conversion = tostring } }

			
-- Integer Formats
stream.add_format {
	identifier = "d",
	read = stream.basic_reader {
			pattern    = [[signed_int]],
			conversion = tonumber } }

stream.add_format {
	identifier = "u",
	read = stream.basic_reader {
			pattern    = [[uint]],
			conversion = tonumber } }			
			
stream.add_format {
	identifier = "o",
	read = stream.basic_reader {
			pattern    = [[octal]],
			conversion = octtonumber } }

stream.add_format {
	identifier = "x",
	read = stream.basic_reader {
			pattern    = [[hexadecimal]],
			conversion = hextonumber } }
			
-- Double Formats
stream.add_format {
	identifier = "f",
	read = stream.basic_reader {
			pattern      = [[floating_point]],
			conversion   = tofloat } }
			
stream.add_format {
	identifier = "e",
	read = stream.basic_reader {
			pattern      = [[floating_point]],
			conversion   = tofloat } }

stream.add_format {
	identifier = "g",
	read = stream.basic_reader {
			pattern      = [[floating_point]],
			conversion   = tofloat } }

stream.add_format {
	identifier = "E",
	read = stream.basic_reader {
			pattern      = [[floating_point]],
			conversion   = tofloat } }

stream.add_format {
	identifier = "G",
	read = stream.basic_reader {
			pattern      = [[floating_point]],
			conversion   = tofloat } }

--check = parse_in("%fabc%*d%s")
--matched, a, b, c = check:match("41e14abc123hello")

check = parse_in("%#-x")
matched, a, b, c = check:match("- 0xABC")

if (matched) then
	print(a,b,c)
else
	print("Did not match")
end
