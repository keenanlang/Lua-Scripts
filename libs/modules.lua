--[[
	Lua library to get informaton from an IOC's envPaths or
	cdCommands file.

	parseEnvPaths / parseCdCommands - Takes in a path to the
		type of file, parses the file to figure out which
		EPICS modules are included in the IOC. Sets global vars
		for all the modules with their provided directory paths.
		Builds package.path and package.cpath (for windows/linux)
		from each module's lib/<arch>/ directory.

	found - A table of all the defined modules. Only available once
		the correct parse function is called. Useful for iterating
		over all modules in an IOC.

	is_included - Checks if a module name is contained in the 'found'
		table.
  ]]

local modules = { found = {} }

function modules.parseEnvPaths(filepath)
	local arch = os.getenv("ARCH")
	local separator = package.config:sub(1,1)

	local path = "." .. separator .. "?.lua"
	local cpath = ""

	if (arch:find("linux")) then
		cpath = "." .. separator .. "?.so"
	elseif (arch:find("win")) then
		cpath = "." .. separator .. "?.dll"
	end

	for line in io.lines(filepath) do
		local name, value = line:match('epicsEnvSet%("([a-zA-Z0-9_]+)","(.+)"%)')

		table.insert(modules.found, name)
		epicsEnvSet(name, value)

		if (arch:find("linux")) then
			cpath = cpath .. ";" .. value .. separator ..  "lib" .. separator .. arch .. separator .. "?.so"
		elseif (arch:find("win")) then
			cpath = cpath .. ";" .. value .. separator ..  "lib" .. separator .. arch .. separator .. "?.dll"
		end

		path  = path  .. ";" .. value .. separator .. "lib" .. separator .. arch .. separator .. "?.lua"
	end

	package.cpath = cpath
	package.path = path
end

function modules.parseCdCommands(filepath)
	local arch = os.getenv("ARCH")
	local separator = package.config:sub(1,1)

	local path = "." .. separator .. "?.lua"

	for line in io.lines(filepath) do
		local name, value = line:match('putenv%("([a-zA-Z0-9_]+)=(.+)%)')

		if (name ~= nil) then
			table.insert(modules.found, name)
			_G[name] = value

			path = path .. ";" .. value .. separator .. "lib" .. separator .. arch .. separator .. "?.lua"
		end
	end

	package.path = path
end

function modules.is_included(module_name)
	local checkname = module_name:upper()

	for key, value in pairs(modules.found) do
		if (value == checkname) then
			return true
		end
	end

	return false
end

return modules
