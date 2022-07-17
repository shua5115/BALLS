# controlactions
A flexible controls library for love

# Dependencies
- lovelistener:	a change to love.run to allow libraries to quietly run code with love callbacks

# Features
- Supports keyboard, mouse, gamepad, and joystick
- Ability to listen for inputs for remappable controls
- Control preprocessing (deadzones, scaling)

# Limitations
- No gesture support
- No touchscreen/multitouch support
- It is not easy to use keyboard and controller mappings for the same action, it is generally better to separate by device, despite the abstractions used

# Usage

```
local controls = require "controlactions"
love.run = love.listeners.run  -- modified version of love's default run function to allow libraries to run code with callbacks
```

## Library Functions

`ctrl = controls.new([table], [actions], [mapping], [Joystick])`
- creates or modifies a table to store information about controls and respond to input events
- table (optional): a table which will be modified to store the controls information
	- NOTE: this function sets the metatable of the output table, so any previously set metatable will be overwritten
		- this is the case because, for some reason, love.event.push only allows tables to be passed as arguments if they have metatables with an __index key defined
- actions (optional): a set or array of names which represent the available actions
	- note: if #actions > 0, ipairs will be used instead of pairs
- mapping (optional): a table that follows the following structure:
```
mapping = {
	keyboard = {
		-- this key will activate the action "actionname", this mapping of input to action is the basis for the library
		KeyConstant	= "actionname"	-- see https://love2d.org/wiki/KeyConstant for possible values
		OR
		KeyConstant = {"action1", "action2"}	-- all inputs can map to multiple actions if the name is replaced with an array of names
	},
	mouse = {
		number	= "name"	-- number is the mouse button number
		"pos"	= "name"	-- the mouse position as a 2d axis
		"delta"	= "name"	-- the change in mouse position as a 2d axis
		"wheel"	= "name"	-- the mouse wheel scroll as a 2d axis
	},
	gamepad = {
		GamepadButton	= "name"	-- see https://love2d.org/wiki/GamepadButton for possible values
		GamepadAxis		= "name"	-- see https://love2d.org/wiki/GamepadAxis for possible values
		"leftstick"		= "name"	-- macro that combines the values from leftx and lefty into a 2d axis
		"rightstick"	= "name"	-- same as leftstick, but for rightx and righty
	},
	joystickbutton = {
		number	= "name"	-- number is the joystick button number
	},
	joystickaxis = {
		number	= "name"	-- number is the joystick axis number
	}
}
```
- Joystick (optional): a joystick to associate with this control table.
	Only this joystick will be used to update the actions.
	If no joystick is provided when a control is created, its gamepad or joystick mappings
	will be inactive until a Joystick is bound after the fact

action: a table that is automatically created for every action key in ctrl.actions
- an action typically contains this information (default value):
```
{
	button		= boolean(false)-- if a button associated with this action is pressed
	value		= number (0)	-- the value associated with this action as a 1d axis (all gamepad axes)
	x		= number (0)	-- the x axis of this action as a 2d axis (like mouse.pos or mouse.vel)
	y		= number (0)	-- the y axis of this action as a 2d axis
	buttonpressed	= boolean(false)	-- if the button was pressed this frame
	buttonreleased	= boolean(false)	-- if the button was released this frame
}
```
- because the names above are exclusive, you can mix an action's purpose between a
	button, 1d axis, and 2d axis without issue

`controls.registerEvents(dontcreatecallbacks)`
- starts listening to love callbacks such as love.keypressed
- creates new love events for when an action is changed, only if dontcreatecallbacks resolves to nil or false:
	- `love.actionpressed(ctrl, actionname, action)	-- for button presses`
	- `love.actionreleased(ctrl, actionname, action)	-- for button releases`
	- `love.actionaxis(ctrl, actionname, action)		-- for 1d axis change`
	- `love.actionaxis2d(ctrl, actionname, action)	-- for 2d axis change`
- best called in love.load() before any other libraries that depend on knowing love callbacks (like hump.gamestate)
- it is safe to call this function multiple times, but you likely only need to call it once

`controls.listen([inputtype], [device])`
- always returns values: 	`inputtype, device, input` 	or nil if no input is found
- if no args are passed, this function returns the previous input detected from any device with any type
- if inputtype is passed (button, axis, axis2d), the recent input of that type will be returned
- if device is passed (keyboard, mouse, gamepad, joystickbutton, joystickaxis),
	the function will only return previous inputs from that type of device
- you can mix passing inputtype and device for more specific checks

`controls.clearlisten()`
- clears all previous inputs to allow easier detection when using controls.listen

## Instance Functions

`ctrl:setactive(bool)`
- sets whether a control is active
- controls which are inactive will not be updated by the library
- controls are active by default

`ctrl:getactive()`
- returns if the control is active

`ctrl:getaction(actionname)`
- gets the action associated with the name from the ctrl or returns a default action
- performs the equivalent of ctrl.actions[actionname] if successful
- alleviates writing nil checks for actions

`ctrl:getinputs(actionname)`
- returns a table containing all inputs that reference the actionname
- the table contains arrays which describe how to index ctrl.mapping
	As an example, this function may return an equivalent to:
	{"gamepad", "dpdown"}, {"keyboard", "down"}, {"keyboard", "s"}
	when searching for an action named "down" for a controls using common mappings

`ctrl:newaction(actionname)`
- creates a new action with name actionname in ctrl.actions

`ctrl:addmapping(actionname, device, ...) -- the last value in ... is the input to append to`
- adds the action to the ctrl.mapping table, appending it to any existing actions for that input
  - For example, ctrl:addmapping("attack", "keyboard", "space") will map the keyboard space button to the "attack" action
- will create new tables if they don't exist
- will throw an error if the path to get from device to input is occupied by a non-nil, non-table value
- path from device to input may vary in length for custom devices, so the path is defined as varargs

`ctrl:setuniquemapping(actionname, device, ...)`
- first removes all actions associated with actionname using getinputs()
- then adds the action back using addmapping()

`ctrl:buttonsToAxis([actionname], leftname, rightname, [downname, upname, [normalize] ])`
- creates a 1d or 2d axis action from two or four button actions
- if actionname is a valid action in ctrl, then that action will be updated with the result of this function
- if there are two button arguments, an action is returned where value ranges from -1 to 1
- if there are four button arguments, an action is returned where x and y range from -1 to 1 based on each argument
- if there are four button arguments and normalize is true, the output will be normalized
	- this prevents the common bug of moving faster diagonally

`ctrl:toAxis2d([actionname], axis1, axis2, [normalize])`
- takes two 1d axis action names and creates a 2d axis with their values
- if actionname is a valid action in ctrl, then that action will be updated with the result of this function
- option to normalize the input

## Additional Love Callbacks
- made a part of the love table to interface with libraries such as hump.gamestate

`love.actionpressed(ctrl, actionname, action)`
- callback that handles when an action associated with a button is pressed
- ctrl: a control table from controls.new()
- actionname: the name of the action
- action: other info about the action if needed

`love.actionreleased(ctrl, actionname, action)`
- callback that handles when an action associated with a button is released
- all args are the same as actionpressed

`love.actionaxis(ctrl, actionname, action)`
- called when a 1d axis is changed

`love.actionaxis2d(ctrl, actionname, action)`
- called when a 2d axis is changed
