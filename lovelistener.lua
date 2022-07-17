-- be sure to have love.run = love.listeners.run to use this library

love.listeners = {}

local listenermod = {}

local listenermt = {__newindex = function(t, k, v)
	if type(k) == "function" then
		rawset(t, k, v)
		return
	elseif type(k) == "number" and type(v) == "function" then
		rawset(t, v, true)
		return
	end
	assert(false, "cannot add or remove a non-function as a listener")
end}

function listenermod.add(callback, func)
	if type(callback) ~= "string" or type(func) ~= "function" then return end
	love.listeners = love.listeners or setmetatable({}, {__index = listenermod})
	-- if the table for the callback is not valid, recreate it
	love.listeners[callback] = getmetatable(love.listeners[callback]) == listenermt and love.listeners[callback] or setmetatable({}, listenermt)
	love.listeners[callback][func] = true
	return true
end

function listenermod.remove(callback, func)
	if love.listeners and type(love.listeners[callback]) == "table" then
		love.listeners[callback][func] = nil
	end
end

function listenermod.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Preprocessing events, helpful for libraries that want to reset state before processing events
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

setmetatable(love.listeners, {__index = listenermod})