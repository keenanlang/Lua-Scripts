--[[
	Library to play around with freeboard (http://freeboard.io/)
		
	Takes in a set of PV's and some bindings of fields to names,
	Then writes a JSON file of the values of those fields on a 
	repeated basis for freeboard to use as a dataset. For example:
	
	test = encode.list {
		["xxx:yyy:test"] = {value=".VAL", units=".EGU"}
	}
	
	test:write_every("./test.json", 1.0)
  ]]

json = require("json")
epics = require("epics")

local encode = {}

local function write(filename, pvlist)
	local output = {}
	
	for key, fields in pairs(pvlist) do
		local entry = {}
		
		for index, value in pairs(fields) do
			local val = epics.get(key .. value)
			
			if (val == nil) then val = "" end
			
			entry[index] = val
		end
		
		output[key] = entry
	end
	
	outfile = io.open(filename, "w+")
	outfile:write(json.encode(output))
	outfile.close()
end

local function write_every(self, filename, tick)
	while true do 
		write(filename, self.data)
		epics.sleep(tick)
	end
end

function encode.list(data)
	local output = {write_every=write_ever)
	
	output.data = data
	
	return output
