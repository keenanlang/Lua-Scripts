--[[
	Simple library to emulate the EPICS sequencer.
	
	A seq program is just a table with two values; a
	program name (program_name) and a table of states
	(states). The keys for the table are the states'
	names and the values are just a list of seq
	transitions.
	
	Transitions have a conditional, a some code, and a
	next state. When a seq program is in a given state,
	it iterates through each of its transitions and 
	evaluates their conditional. When a conditional
	evaluates to true, that transition's code is run, 
	and the seq program moves to the indicated next state. 
	When a next state of "exit" is reached, the state machine
	stops running.
	
	Due to lua's syntactic sugar with functions that take
	in a single value, building a seq program can be done
	in a single statement. A simple example is given below:
	
	test = seq.program "test" {
		state1=
		{
			seq.transition("true", "print('Hello,')", "state2")
		},
		
		state2=
		{
			seq.transition("false", "print('Failed.')", "exit")
			seq.transition("true", "print('World.')", "exit")
		}
	}
	
	test:run("state1")
  ]]

local seq = {}

local function do_seq(mytable, start_state)
	local running_state = start_state
	
	repeat
		local state = mytable["states"][running_state]
		
		-- Check each transition
		for index = 1, #state do
			local transition = state[index]
			
			-- Call conditional code and evaluate as a boolean
			local condition_fulfilled = load("return (" .. transition["conditional"] .. ")")()
			
			if (condition_fulfilled) then
			
				-- Call any code the transition defines
				-- and allow it to modify the environment.
				-- Then, switch to the next state.
				load(transition["function"], "=(load)", "t", _ENV)()
				running_state = transition["next_state"]
				
				break
			end
		end
	until (running_state == "exit")
end

function seq.program(prog_name)
	local output = { program_name=prog_name }
	
	-- Allows the lua parser to chain space-separated data together
	local metatable = { __call = function(mytable, data)
		mytable.states = data
		return mytable
	end }
	
	setmetatable(output, metatable)
	
	output.run = do_seq;
	
	return output
end


-- All parameters are strings
function seq.transition(cond, func, nstate)
	local output = {}
	
	-- Code to evaluate to see if transition should happen
	output["conditional"] = cond
	
	-- Code to run if conditional is met
	output["function"] = func
	
	-- Name of next state to transition to
	output["next_state"] = nstate
	
	return output
end

return seq
