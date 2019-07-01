asyn = require("asyn")

IdlePollPeriod   = 1.0
MovingPollPeriod = 0.25
ForcedFastPolls  = 2

InTerminator  = "\r\000\n"
OutTerminator = "\r\n"

homed = false

function move(position, relative, minVel, maxVel, accel)
	local MRES = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_REC_RESOLUTION")
	
	if (relative) then
		asyn.writeread( string.format( "%dPR%f", AXIS + 1, position * MRES ) , PORT)
	else
		asyn.writeread( string.format( "%dPA%f", AXIS + 1, position * MRES) , PORT)
	end
end

function poll()
	if (homed ~= true) then
		return false
	end	

	local MRES = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_REC_RESOLUTION")

	local readback = asyn.writeread( string.format( "%dTP", AXIS + 1) , PORT)
	
	local pos = tonumber( string.match(readback, "%dTP(%-?%d+%.?%d*)") )
	
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_POSITION", pos / MRES )
	
	readback = asyn.writeread( string.format( "%dTS", AXIS + 1) , PORT)

	local status = string.match(readback, "%dTS[0-9A-F][0-9A-F][0-9A-F][0-9A-F]([0-9A-F][0-9A-F])")
	
	local moving = 0

	if (status == "28") then
		moving = 1
	end
	
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_DONE",       moving ~ 1)
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_MOVING",     moving)
	
	asyn.callParamCallbacks(DRIVER, AXIS)
	
	return (moving == 1)
end	


function stop(acceleration)
	asyn.writeread( string.format( "%dST", AXIS + 1) , PORT)
end


function home(minVel, maxVel, accel, forwards)
	homed = true
	asyn.writeread( string.format( "%dOR", AXIS + 1) , PORT)
end
