asyn = require("asyn")

IdlePollPeriod = 1.0
MovingPollPeriod = 0.25
ForcedFastPolls = 2

InTerminator = "\n"
OutTerminator = "\n"

homed = false
rotation = false
holdtime = 0

err_table = {}
err_table["1"] = "The command could not be processed due to a syntactical error."
err_table["2"] = "The command given is not known to the system."
err_table["3"] = "This error occurs if a parameter given is too large and therefore cannot be processed."
err_table["4"] = "The command could not be processed due to a parse error."
err_table["5"] = "The specified command requires more parameters in order to be executed."
err_table["6"] = "There were too many parameters given for the specified command."
err_table["7"] = "A parameter given exceeds the valid range. Please see the command description for valid ranges of the parameters."
err_table["8"] = "This error is generated if the specified command is not available in the current communication mode."
err_table["129"] = "No Sensor Present Error"
err_table["140"] = "Sensor Disabled Error"
err_table["141"] = "Command Overridden Error"
err_table["142"] = "End Stop Reached Error"
err_table["143"] = "Wrong Sensor Type Error"
err_table["144"] = "Could Not Find Reference Mark Error"
err_table["145"] = "Wrong End Effector Type Error"
err_table["146"] = "Movement Locked Error"
err_table["147"] = "Range Limit Reached Error"
err_table["148"] = "Physical Position Unknown Error"
err_table["150"] = "Command Not Processable Error"
err_table["151"] = "Waiting For Trigger Error"
err_table["152"] = "Command Not Triggerable Error"

function errorhandle(readback)
	err_code = readback:match(":E-?%d+,([0-9]+)")
	
	print("Error: " .. err_code)
	print(err_table[err_code])
end

function getSingleVal(command)
	local readback = asyn.writeread( string.format(":%s%d", command, CHANNEL), PORT )

	if (readback:sub(0,1) == "E") then
		error(readback)
	end
	
	return tonumber( string.match(readback, ":[A-Z]+-?%d+,(-?%d+)"))
end

function home(minVel, maxVel, accel, forwards)
	local success, data = pcall(getSingleVal, "GST")
	
	if not success then
		errorhandle(data)
		return
	end
	
	local typeID = data
	
	if ((typeID == 2) or (typeID == 8) or (typeID == 14) or (typeID == 16) or (typeID == 20) or (typeID == 22) or (typeID == 23) or ((typeID >= 25) and (typeID <= 29))) then
		rotation = true
	end

	if (CHANNEL > 0) then
		asyn.writeread( string.format(":SCLS%d,%d" ,CHANNEL, maxVel), PORT)
	end

	if (forwards) then
		asyn.writeread( string.format(":FRM%d,1,%d", CHANNEL, holdtime), PORT)
	else
		asyn.writeread( string.format(":FRM%d,0,%d", CHANNEL, holdtime), PORT)
	end
	
	homed = true
end


function getAngle()
	local readback = asyn.writeread( string.format(":GA%d", CHANNEL), PORT)

	if (readback:sub(0,1) == "E") then
		error(readback)
	end
	
	local match1, match2 = string.match(readback, ":[A-Z]+-?%d+,(-?%d+),(-?%d+)")

	return tonumber(match1), tonumber(match2)
end

function move(position, relative, minVel, maxVel, accel)
	local mres = asyn.getDoubleParam(DRIVER, AXIS, "MOTOR_REC_RESOLUTION")

	local command = ""

	if relative and rotation then
		command = ":MAR%d,%d,%d,%d"
	elseif relative and not rotation then
		command = ":MPR%d,%d,%d"
	elseif not relative and rotation then
		command = ":MAA%d,%d,%d,%d"
	elseif not relative and not rotation then
		command = ":MPA%d,%d,%d"
	end

	local rpos = math.floor(position + 0.5)

	if rotation then
		local angle = rpos % 360000000
		local rev   = math.floor(rpos / 360000000)

		if angle < 0 then
			angle = angle + 360000000
			rev = rev - 1
		end

		asyn.writeread( string.format(command, CHANNEL, angle, rev, holdtime), PORT)
	else
		asyn.writeread( string.format(command, CHANNEL, math.floor(position), holdtime), PORT)
	end
end


function moveVelocity(minVel, maxVel, accel)
	local speed = math.floor(math.abs(maxVel))

	if speed == 0 then
		asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STOP", 1)
		asyn.callParamCallbacks(DRIVER, AXIS)
		return
	end

	local target_pos = 1000000000

	if maxVel < 0 then
		target_pos = - target_pos
	end

	asyn.writeread( string.format(":SCLS%d,%d", CHANNEL, maxVel), PORT)
	asyn.writeread( string.format(":MPR%d,%d,0", CHANNEL, target_pos), PORT)
end


function setPosition(position)
	local rpos = math.floor(position + 0.5)

	if rotation then
		if (rpos < 0.0) or (rpos >= 360000000) then
			return
		end
	end

	asyn.writeread( string.format(":SP%d,%d", CHANNEL ,rpos), PORT)
end


function poll()
	if (homed ~= true) then
		return false
	end
	
	local mres = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_REC_RESOLUTION")

	local pos = 0

	if rotation then
		local success, data1, data2 = pcall(getAngle)
		
		if not success then
			errorhandle(data1)
			return false
		end
	
		local angle = data1
		local rev = data2

		pos = (rev * 360000000 + angle)
	else
		local success, data = pcall(getSingleVal, "GP")
		
		if not success then
			errorhandle(data)
			return false
		end
		
		pos = data
	end

	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_POSITION", pos)
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_ENCODER_POSITION", pos)

	local status = getSingleVal("GS")

	local moving = 0

	--Holding
	if status == 3 then
		if holdtime ~= 60000 then
			moving = 1
		end
	elseif (status > 0) and (status <= 9) then
		moving = 1
	end

	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_DONE",       moving ~ 1)
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_MOVING",     moving)

	success, data = pcall(getSingleVal, "GPPK")
	
	if not success then
		errorhandle(data)
		return false
	end
	
	local know_pos = data

	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_HOMED", know_pos)

	asyn.callParamCallbacks(DRIVER, AXIS)

	return (moving == 1)
end


function stop(acceleration)
	asyn.writeread( string.format(":S%d", CHANNEL), PORT)
end
