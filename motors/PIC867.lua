asyn = require("asyn")

IdlePollPeriod   = 1.0
MovingPollPeriod = 0.25
ForcedFastPolls  = 2

InTerminator  = "\n"
OutTerminator = "\n"

homed = false

function move(position, relative, minVel, maxVel, accel)
	local MRES = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_REC_RESOLUTION")
	
	if (relative) then
		asyn.write( string.format( "MVR %d %f", AXIS + 1, position * MRES ) , PORT)
	else
		asyn.write( string.format( "MOV %d %f", AXIS + 1, position * MRES) , PORT)
	end
end

function poll()
	if (homed ~= true) then
		return false
	end	

	local MRES = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_REC_RESOLUTION")

	local readback = asyn.writeread("POS?", PORT)
	
	local pos = tonumber( string.match(readback, "1=(%-?%d+%.?%d*)") )
	
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_POSITION", pos / MRES )
	
	readback = asyn.writeread("MOV?", PORT)
	
	local targetpos = tonumber( string.match(readback, "1=(%-?%d+%.?%d*)") )
	
	local moving = 0
	
	if (math.abs(targetpos - pos) > MRES) then
		moving = 1
	end	
	
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_DONE",       moving ~ 1)
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_MOVING",     moving)
	
	asyn.callParamCallbacks(DRIVER, AXIS)
	
	return (moving == 1)
end	


function stop(acceleration)
	asyn.write("STP", PORT)
end


function home(minVel, maxVel, accel, forwards)
	homed = true
	
	asyn.write("SVO 1 1", PORT)
	asyn.write("RON 1 0", PORT)
	asyn.write("FRF 1", PORT)
	asyn.write("STP", PORT)
	asyn.writeread("ERR?", PORT)
	asyn.write("POS 1 0", PORT)
	asyn.write("VEL 1 2.0", PORT)
end
