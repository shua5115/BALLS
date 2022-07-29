require "lovelistener"

-- allows you to deeply index a table safely, returning nil if any index is not found
local function safeget(t, ...)
	local arg = {...}
	local argc = #arg
	for i, v in ipairs(arg) do
		if not (type(t) == "table") then return nil end
		if i < argc then
			t = t[v]
		else
			return t[v]
		end
	end
	return nil
end

local function lerp(x, y, t)
	return x + t*(y - x)
end

local function ilerp(x, y, v)
	return (v - x)/(y - x)
end

local function map(v, x, y, z, w)
	return lerp(z, w, ilerp(x, y, v))
end

local buttonjustpressed = {}
local buttonjustreleased = {}

local function handlebutton(press, ctrl, ...)
	local function process(actionname)
		local action = safeget(ctrl.actions, actionname)
		if action then
			action.button = press
			if press then
				action.buttonpressed = true
				table.insert(buttonjustpressed, action)
			else
				action.buttonreleased = true
				table.insert(buttonjustreleased, action)
			end
			if (press and rawget(love.handlers, "actionpressed") or rawget(love.handlers, "actionreleased")) then
				pcall(love.event.push, press and "actionpressed" or "actionreleased", ctrl, actionname, action)
			end
		end
	end
	local actions = safeget(ctrl.mapping, ...)
	if type(actions) ~= "table" then
		process(actions)
	else
		for _, actionname in ipairs(actions) do
			process(actionname)
		end
	end
end

local function handleaxis(v, ctrl, ...)
	local function process(actionname)
		local action = safeget(ctrl.actions, actionname)
		if action then
			action.value = v
			if rawget(love.handlers, "actionaxis") then
				pcall(love.event.push, "actionaxis", ctrl, actionname, action)
			end
		end
	end
	local actions = safeget(ctrl.mapping, ...)
	if type(actions) ~= "table" then
		process(actions)
	else
		for _, actionname in ipairs(actions) do
			process(actionname)
		end
	end
end

local function handleaxis2d(x, y, ctrl, ...)
	local function process(actionname)
		local action = safeget(ctrl.actions, actionname)
		if action then
			action.x, action.y = x or action.x, y or action.y	-- allow only setting one axis at a time
			if rawget(love.handlers, "actionaxis2d") then
				pcall(love.event.push, "actionaxis2d", ctrl, actionname, action)
			end
		end
	end
	local actions = safeget(ctrl.mapping, ...)
	if type(actions) ~= "table" then
		process(actions)
	else
		for _, actionname in ipairs(actions) do
			process(actionname)
		end
	end
end

local wasleftxchanged = false
local wasleftychanged = false
local wasrightxchanged = false
local wasrightychanged = false

local function handlejoystickaxis(joystick, value, ctrl, device, key, ...)
	if type(ctrl.joystick) == "number" then
		if love.joystick.getJoysticks()[ctrl.joystick] ~= joystick then return end
	elseif ctrl.joystick ~= joystick then return end
	
	local function process(actionname)
		local action = safeget(ctrl.actions, actionname)
		if action then
			action.value = value
		end
		if rawget(love.handlers, "actionaxis") then
			pcall(love.event.push, "actionaxis", ctrl, actionname, action)
		end
		if key == "leftx" then
			wasleftxchanged = true
			handleaxis2d(value, nil, ctrl, device, "leftxy")
		end
		if key == "lefty" then
			wasleftychanged = true
			handleaxis2d(nil, value, ctrl, device, "leftxy")
		end
		if key == "rightx" then
			wasrightxchanged = true
			handleaxis2d(value, nil, ctrl, device, "rightxy")
		end
		if key == "righty" then
			wasrightychanged = true
			handleaxis2d(nil, value, ctrl, device, "rightxy")
		end
	end
	local actions = safeget(ctrl.mapping, device, key, ...)
	if type(actions) ~= "table" then
		process(actions)
	else
		for _, actionname in ipairs(actions) do
			process(actionname)
		end
	end
end

local lastinput = {}

local function setlastinput(inputtype, device, key, joystick)
	lastinput[inputtype] = lastinput[inputtype] or {}
	lastinput[inputtype][device] = key
	lastinput[inputtype][1] = device
	lastinput[inputtype][2] = key
	lastinput[device] = {inputtype, key}
	if joystick then
		lastinput[inputtype][joystick] = key
		lastinput[joystick] = {inputtype, key}
	end
	lastinput[1], lastinput[2], lastinput[3] = inputtype, device, key
end

-- only referenced control tables should recieve updates
local active = setmetatable({}, {__mode = "k"})

local callbacks = {}
function callbacks.keypressed(k)
	setlastinput("button", "keyboard", k)
	for ctrl in pairs(active) do
		handlebutton(true, ctrl, "keyboard", k)
	end
end

function callbacks.keyreleased(k)
	for ctrl in pairs(active) do
		handlebutton(false, ctrl, "keyboard", k)
	end
end

function callbacks.mousepressed(x, y, button)
	setlastinput("button", "mouse", button)
	for ctrl in pairs(active) do
		handlebutton(true, ctrl, "mouse", button)
	end
end

function callbacks.mousereleased(x, y, button)
	for ctrl in pairs(active) do
		handlebutton(false, ctrl, "mouse", button)
	end
end

local wasmousemoved = false

function callbacks.mousemoved(x, y, dx, dy)
	setlastinput("axis2d", "mouse", "delta")
	wasmousemoved = true
	for ctrl in pairs(active) do
		handleaxis2d(x, y, ctrl, "mouse", "pos")
		handleaxis2d(dx, dy, ctrl, "mouse", "delta")
	end
end

local waswheelmoved = false	-- used in callbacks.wheelmoved and callbacks.update

function callbacks.wheelmoved(x, y)
	setlastinput("axis2d", "mouse", "wheel")
	waswheelmoved = true
	for ctrl in pairs(active) do
		handleaxis2d(x, y, ctrl, "mouse", "wheel")
	end
end

function callbacks.gamepadpressed(j, b)
	setlastinput("button", "gamepad", b, j)
	for ctrl in pairs(active) do
		handlebutton(true, ctrl, "gamepad", b)
	end
end

function callbacks.gamepadreleased(j, b)
	for ctrl in pairs(active) do
		handlebutton(false, ctrl, "gamepad", b)
	end
end

function callbacks.gamepadaxis(j, a, v)
	if v > 0.5 or v < -0.5 then
		setlastinput("axis", "gamepad", a)
		if a == "leftx" or a == "lefty" then
			setlastinput("axis2d", "gamepad", "leftxy", j)
		end
		if a == "rightx" or a == "righty" then
			setlastinput("axis2d", "gamepad", "rightxy", j)
		end
	end
	for ctrl in pairs(active) do
		handlejoystickaxis(j, v, ctrl, "gamepad", a)
	end
end

function callbacks.joystickpressed(j, b)
	setlastinput("button", "joystickbutton", b, j)
	for ctrl in pairs(active) do
		handlebutton(true, ctrl, "joystickbutton", b)
	end
end

function callbacks.joystickreleased(j, b)
	for ctrl in pairs(active) do
		handlebutton(false, ctrl, "joystickbutton", b)
	end
end

function callbacks.joystickaxis(j, a, v)
	if v > 0.5 or v < -0.5 then
		setlastinput("axis", "joystickaxis", a, j)
	end
	for ctrl in pairs(active) do
		handlejoystickaxis(j, v, ctrl, "joystick", a)
	end
end

function callbacks.update(dt)
	for ctrl in pairs(active) do
		if not wasmousemoved then
			handleaxis2d(0, 0, ctrl, "mouse", "delta")
		end
		if not waswheelmoved then
			handleaxis2d(0, 0, ctrl, "mouse", "wheel")
		end
	end
	wasmousemoved = false
	waswheelmoved = false
end

function callbacks.pre()
	for _, action in ipairs(buttonjustpressed) do
		action.buttonpressed = false
	end
	for _, action in ipairs(buttonjustreleased) do
		action.buttonreleased = false
	end
	buttonjustpressed = {}
	buttonjustreleased = {}
end

function callbacks.draw()
	if love.listeners and love.listeners.pre[callbacks.pre] then return end
	for _, action in ipairs(buttonupdated) do
		action.buttonpressed = false
		action.buttonreleased = false
	end
end

local controls = {}

function controls.registerEvents(dontcreatecallbacks)
	for funcname, func in pairs(callbacks) do
		love.listeners.add(funcname, func)
	end
	if dontcreatecallbacks then return end
	love.handlers.actionpressed = function(ctrl, name, action) if love.actionpressed then return love.actionpressed(ctrl, name, action) end end
	love.handlers.actionreleased = function(ctrl, name, action)	if love.actionreleased then return love.actionreleased(ctrl, name, action) end end
	love.handlers.actionaxis = function(ctrl, name, action) if love.actionaxis then return love.actionaxis(ctrl, name, action) end end
	love.handlers.actionaxis2d = function(ctrl, name, action) if love.actionaxis2d then love.actionaxis2d(ctrl, name, action) end end
end

local function resetaction(action)
	action.button = false
	action.value = 0
	action.x = 0
	action.y = 0
	action.buttonpressed = false
	action.buttonreleased = false
	return action
end

local function newaction(src)
	local action = {}
	resetaction(action)
	if type(src) == "table" then
		for k, v in pairs(src) do
			action[k] = v
		end
	end
	return action
end

function controls.deadzone(action, deadmin, deadmax)
	assert(deadmin < deadmax, "deadzone min must be less than deadzone max")
	local x, y = action.x or 0, action.y or 0
	local mag = (x*x + y*y)^0.5
	if mag < deadmin then
		x, y = 0, 0
	else
		x, y = x/mag, y/mag	-- normalize
		local newmag = map(mag, deadmin, deadmax, 0, 1)
		if newmag < 0 then newmag = 0 end
		if newmag > 1 then newmag = 1 end
		x, y = x*newmag, y*newmag -- remap
	end
	local ret = newaction(action)
	ret.x, ret.y = x, y
	return ret
end

local ctrlhelper = {}

function ctrlhelper.setactive(ctrl, isactive)
	assert(isactive ~= nil, "in setactive expected boolean, found nil")
	if isactive then
		active[ctrl] = true
	else
		active[ctrl] = nil
		-- This may be a good idea for mouse.delta, but not for mouse.pos
		--for name, action in pairs(ctrl.actions) do
		--	resetaction(action)
		--end
	end
end

function ctrlhelper.isactive(ctrl)
	return (active[ctrl] ~= nil)
end

function ctrlhelper.getaction(ctrl, actionname)
	return safeget(ctrl.actions, actionname) or newaction()
end

function ctrlhelper.deadzone(ctrl, actionname, deadmin, deadmax)
	return controls.deadzone(ctrlhelper.getaction(ctrl, actionname), deadmin, deadmax)
end

function ctrlhelper.getinputs(ctrl, actionname)
	local mapping = ctrl.mapping
	if not mapping then return {} end
	local inputs = {}
	local seen = {}
	-- depth first search for any input that maps to action actionname
	local function search(t, path)
		if seen[t] then return end
		path = path or {}	-- array of table names/indexes
		local function addinput(key)
			local newpath = {}
			for i, p in ipairs(path) do
				newpath[i] = p
			end
			table.insert(newpath, key)
			table.insert(inputs, newpath)
		end
		for k, v in pairs(t) do
			if type(v) == "table" then
				if (#v) > 0 then	-- v is likely an array of names
					for _, name in ipairs(v) do
						if name == actionname then
							addinput(k)
							break
						end
					end
				else	-- v is likely a sub-table containing more mappings
					seen[t] = true
					local newpath = {}
					for i, p in ipairs(path) do
						newpath[i] = p
					end
					table.insert(newpath, k)
					search(v, newpath)
				end
			elseif v == actionname then	-- k is an input mapping to actionname
				addinput(k)
			end
		end
	end
	search(mapping)
	return inputs
end

function ctrlhelper.newaction(ctrl, actionname)
	ctrl.actions[actionname] = newaction()
end

function ctrlhelper.addmapping(ctrl, actionname, ...)
	if actionname == nil then return end
	local arg = {...}
	local argc = #arg
	if argc == 0 then return end
	local t = ctrl.mapping
	for i, k in ipairs(arg) do
		local v = t[k]
		if i == argc then
			if type(v) == "table" then
				table.insert(v, actionname)
			elseif v == nil then
				t[k] = actionname
			else
				t[k] = {t[k], actionname}
			end
		else
			if type(v) == "table" then
				t = v
			else
				if v ~= nil then
					local errormsg = "Tried to index a non-table when adding a mapping for \""..actionname.."\" following indices: "
					for index, name in ipairs(arg) do
						errormsg = errormsg..name..(index < argc and ", " or "")
					end
					error(errormsg, 2)
				end
				t[k] = {}
				t = t[k]
			end
		end
	end
end

-- code copied from https://stackoverflow.com/a/53038524, thank you, very cool
local function arrayremove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

function ctrlhelper.setuniquemapping(ctrl, actionname, ...)
	if actionname == nil then return end
	local inputs = ctrlhelper.getinputs(ctrl, actionname)
	-- first, remove all references to this actionname from the mapping
	for i, path in ipairs(inputs) do
		local map = safeget(ctrl.mapping, unpack(path))
		if type(map) == "table" then
			arrayremove(map, function(t, i)
				return t[i] == actionname
			end)
		else	-- remove mapping entirely
			local premap = safeget(ctrl.mapping, unpack(path, 1, #path - 1))
			if premap then premap[path[#path]] = nil end
		end
	end
	ctrlhelper.addmapping(ctrl, actionname, ...)
end

local isqrt2 = 2^-0.5
-- if four buttons, then buttons are ordered left, right, down, up
-- if a button does not exist, then it is assumed to be not pressed
function ctrlhelper.buttonsToAxis(ctrl, actionname, bt1, bt2, bt3, bt4, normalize)
	local bt1a = ctrlhelper.getaction(ctrl, bt1)
	local bt2a = ctrlhelper.getaction(ctrl, bt2)
	local action = ctrlhelper.getaction(ctrl, actionname)
	local exists = (action ~= nil)
	action = action or newaction()
	if bt1 and bt2 and bt3 and bt4 then	-- 2d axis
		local bt3a = ctrlhelper.getaction(ctrl, bt3)
		local bt4a = ctrlhelper.getaction(ctrl, bt4)
		action.x = 0 + (bt1a.button and -1 or 0) + (bt2a.button and 1 or 0)
		action.y = 0 + (bt3a.button and -1 or 0) + (bt4a.button and 1 or 0)
		if normalize and action.x ~= 0 and action.y ~= 0 then
			action.x, action.y = action.x * isqrt2, action.y * isqrt2
		end
		if exists then
			pcall(love.event.push, "actionaxis2d", ctrl, actionname, action)
		end
	elseif bt1 and bt2 then	-- 1d axis
		action.value = 0 + (bt1a.button and -1 or 0) + (bt2a.button and 1 or 0)
		if exists then
			pcall(love.event.push, "actionaxis", ctrl, actionname, action)
		end
	end
	return action
end

function ctrlhelper.toAxis2d(ctrl, actionname, ax1, ax2, normalize)
	local ax1a = ctrlhelper.getaction(ctrl, ax1)
	local ax2a = ctrlhelper.getaction(ctrl, ax2)
	local action = ctrlhelper.getaction(ctrl, actionname)
	local exists = (action ~= nil)
	action = action or newaction()
	action.x, action.y = ax1a.value, ax2a.value
	if normalize and (action.x ~= 0 or action.y ~= 0) then
		local mag = (action.x*action.x + action.y*action.y)^0.5	-- does fast inverse square root exist in love?
		action.x, action.y = action.x / mag, action.y / mag
	end
	if exists then
		pcall(love.event.push, "actionaxis2d", ctrl, actionname, action)
	end
end

function ctrlhelper.type(ctrl)
	return "Controls"
end

function ctrlhelper.typeOf(ctrl, t)
	return (t == "Controls")
end

function controls.new(t, actions, mapping, joystick)
	local ctrl = type(t) == "table" and t or {}
	ctrl.actions = {}
	if type(actions) == "table" then
		if (#actions) > 0 then
			for _, v in ipairs(actions) do
				ctrl.actions[v] = newaction()
			end
		else
			for k in pairs(actions) do
				ctrl.actions[k] = newaction()
			end
		end
	end
	ctrl.mapping = type(mapping) == "table" and mapping or {
		keyboard = {};
		mouse = {};
		joystick = {};
		gamepad = {};
	}
	-- only allow actual joystick objects (this is the best type check I can do for now)
	local joymt = getmetatable(joystick)
	if type(joystick) == "number" or (joymt and joymt.typeOf == "function" and joymt.typeOf("Joystick")) then
		ctrl.joystick = joystick
	end
	-- for some strange reason, the metatable member __index of the ctrl must be set for it to be an argument in a love event
	--for k, v in pairs(ctrlhelper) do
	--	ctrl[k] = v
	--end
	setmetatable(ctrl, {__index = ctrlhelper})
	active[ctrl] = true
	return ctrl
end

function controls.clearlisten()
	lastinput = {}
end

function controls.listen(inputtype, device)
	if inputtype then
		if device then
			local key = safeget(lastinput, inputtype, device)
			if key then
				if type(device) ~= "string" then
					-- must have been joystick, deduce what kind
					if type(key) == "number" then
						if inputtype == "axis" then device = "joystickaxis" end
						if inputtype == "button" then device = "joystickbutton" end
					elseif type(key) == "string" then
						device = "gamepad"
					end
				end
				return inputtype, device, key
			end
		else
			device = safeget(lastinput, inputtype, 1)
			local key = safeget(lastinput, inputtype, 2)
			if device and key then
				return inputtype, device, key
			end
		end
	else
		if device then
			local typekey = safeget(lastinput, device)
			if typekey then
				if type(device) ~= "string" then
					-- must have been joystick, deduce what kind
					if type(typekey[2]) == "number" then
						if typekey[1] == "axis" then device = "joystickaxis" end
						if typekey[1] == "button" then device = "joystickbutton" end
					elseif type(typekey[2]) == "string" then
						device = "gamepad"
					end
				end
				return typekey[1], device, typekey[2]
			end
			if lastinput[2] ~= device then return end
		end
		return lastinput[1], lastinput[2], lastinput[3]
	end
end

--[[
function controls.defaultrun()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Preprocessing events
		if love.listeners then
			for func in pairs(love.listeners.pre or {}) do
				func()
			end
		end
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
				if love.listeners then
					for func in pairs(love.listeners[name] or {}) do
						func(a,b,c,d,e,f)
					end
				end
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

		-- Call update and draw
		if love.listeners then
			for func in pairs(love.listeners.update or {}) do
				func(dt)
			end
		end
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			if love.listeners then
				for func in pairs(love.listeners.draw or {}) do
					func()
				end
			end
			if love.draw then love.draw() end

			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end
]]

return controls