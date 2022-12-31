require "lovelistener"
local controls = require "controlactions"

local ctrl

love.run = love.listeners.run

function love.load()
	controls.registerEvents()
	ctrl = controls.new(nil,
		-- Action names
		{"up", "down", "left", "right", "wheel", "move", "look", "attack"},
		-- Mapping from buttons/axes to action names
		{
			keyboard = {w = "up", a = "left", s = "down", d = "right", space = "attack"},
			mouse = {delta = "look", wheel = "wheel"},
			gamepad = {dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", leftxy = "move", a = "attack"},
		}, 1, {min = 0.3, max = 1.0})
end

local msg = {}
local removetimes = {}
function love.update(dt)
	while true do
		local removetime = removetimes[1]
		if removetime and love.timer.getTime() > removetime then
			table.remove(removetimes, 1)
			table.remove(msg, 1)
		else break end
	end
end

function love.draw()
	love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
	love.graphics.setColor(1, 1, 1)
	
	local move = ctrl:deadzone("move", 0.25, 0.95)
	love.graphics.circle("line", 200, 200, 50)
	love.graphics.circle("fill", 200 + move.x*25, 200 + move.y*25, 25)
	love.graphics.print(move.x, 300, 200)
	love.graphics.print(move.y, 300, 220)
	
	local offset = 0
	local function nextLine() offset = offset + 20 end
	
	local joysticks = love.joystick.getJoysticks()
    for i, joystick in ipairs(joysticks) do
		love.graphics.print("Connected ("..i.."):" .. joystick:getName(), 0, offset)
		nextLine()
    end
	
	if ctrl:getaction("attack").buttonpressed then controls.clearlisten() end
	
	local inputtype, device, inputkey = controls.listen("button")
	inputtype = inputtype or ""
	device = device or ""
	inputkey = inputkey or ""
	love.graphics.print("Last button: "..inputtype..", "..device..", "..inputkey, 0, offset)
	nextLine()
	inputtype, device, inputkey = controls.listen("axis")
	inputtype = inputtype or ""
	device = device or ""
	inputkey = inputkey or ""
	love.graphics.print("Last 1d axis: "..inputtype..", "..device..", "..inputkey, 0, offset)
	nextLine()
	inputtype, device, inputkey = controls.listen("axis2d")
	inputtype = inputtype or ""
	device = device or ""
	inputkey = inputkey or ""
	love.graphics.print("Last 2d axis: "..inputtype..", "..device..", "..inputkey, 0, offset)
	nextLine()
	inputtype, device, inputkey = controls.listen(nil, "gamepad", 1)
	inputtype = inputtype or ""
	device = device or ""
	inputkey = inputkey or ""
	love.graphics.print("Last gamepad input: "..inputtype..", "..device..", "..inputkey, 0, offset)
	nextLine()
	
	local look = ctrl:getaction("look")
	love.graphics.print("Mouse delta:\t"..look.x..",\t"..look.y, 0, offset)
	nextLine()
	
	local a = ctrl:getaction("wheel")
	love.graphics.print("Mouse wheel\t"..a.x..",\t"..a.y, 0, offset)
	nextLine()
	
	for i, v in ipairs(msg) do
		love.graphics.print(v, 0, offset)
		nextLine()
	end
end

function love.actionpressed(ctrl, actionname, action)
	table.insert(msg, actionname.." action pressed")
	table.insert(removetimes, love.timer.getTime() + 5)
end

function love.gamepadaxis(j, a, v)
	--table.insert(msg, j:getName().." moved axis "..a.." to "..v)
	--table.insert(removetimes, love.timer.getTime() + 5)
end