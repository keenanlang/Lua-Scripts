asyn = require('asyn')

package.path='./scripts/?.lua'

json = require('json')

IdlePollPeriod = 1.0
MovingPollPeriod = 0.25
ForcedFastPolls = 2

ReadTimeout = 1.0

InTerminator = ''
OutTermintator = ''

function send(request)
	local readback_str = asyn.writeread( json.encode(request), PORT)
	
	--print(readback_str)
	
	local readback = json.decode(readback_str)
	
	if (readback == nil) then
		error("Received no readback")
	end
	
	if (readback.result[1] ~= 0) then
		error(string.format("Error code: %d", readback.result[1]))
	end
	
	return readback
	
end


function move(position, relative, minVel, maxVel, accel)
	local new_pos = position
	
	if (relative) then
		local old_pos = asyn.getDoubleParam( DRIVER, AXIS, "MOTOR_POSITION")
		new_pos = new_pos + old_pos
	end
	
	local request = { 
		jsonrpc = "2.0",
		method = "com.attocube.amc.move.setControlTargetPosition",
		params = { AXIS, new_pos },
		id = AXIS,
		api = 2 }

	send(request)
end

function home(forward)
	local request = { 
		jsonrpc = "2.0",
		method = "com.attocube.amc.move.moveReference",
		params = { AXIS },
		id = AXIS,
		api = 2 }

	send(request)
end

function stop(acceleration)
	local request = { 
		jsonrpc = "2.0",
		method = "com.attocube.amc.move.setControlContinuousBkwd",
		params = { AXIS, 0},
		id = AXIS,
		api = 2 }

	send(request)
end

function poll()
	local request = { 
		jsonrpc = "2.0",
		method = "com.attocube.amc.move.getPosition",
		params = { AXIS },
		id = AXIS,
		api = 2 }
		

	local readback = send(request)
	
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_POSITION", readback.result[2] );
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_ENCODER_POSITION", readback.result[2] );
	
	request.method = "com.attocube.amc.status.getFullCombinedStatus"
	
	readback = send(request)
	
	local status = readback.result[2]
	
	--print(status)
	
	local moving = 0
	local low_lim = 0
	local high_lim = 0

	if (status == "moving") then moving = 1 end
	if (status == "backward limit reached") then low_lim = 1 end
	if (status == "forward limit reached") then high_lim = 1 end
	
	asyn.setIntegerParam(DRIVER, AXIS, "MOTOR_STATUS_DONE", moving ~ 1)
	asyn.setIntegerParam(DRIVER, AXIS, "MOTOR_STATUS_MOVING", moving)
	
	asyn.setIntegerParam(DRIVER, AXIS, "MOTOR_STATUS_LOW_LIMIT", low_lim)
	asyn.setIntegerParam(DRIVER, AXIS, "MOTOR_STATUS_HIGH_LIMIT", high_lim)
	
	return (moving == 1)	
end
