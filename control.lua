require "defines"
require "util"

local pClosure = require "pClosure"
local pClosure1
local pClosure2

local onTickFunctions = { }

local function on_first_tick(key)
	if not game.players[1].gui.left.flow then 
		game.players[1].gui.left.add {type = "flow", name = "flow", direction = "horizontal"} 
		flow = game.players[1].gui.left.flow
		flow.add{type = "button", name = "Save", caption = "Save func"} 
		flow.add{type = "button", name = "Call", caption = "Call func"} 
		flow.add{type = "button", name = "Delete", caption = "Delete func"}
		flow.add{type = "button", name = "SaveDiff", caption = "Save, diff namespace"} 
		flow.add{type = "button", name = "CallDiff", caption = "Call, diff namespace"} 
		flow.add{type = "button", name = "SaveUp", caption = "Save dif upval"} 
		flow.add{type = "button", name = "CallUp", caption = "Call dif upval"} 
		
		flow.add{type = "button", name = "SaveAdv", caption = "Save adv func"} 
		flow.add{type = "button", name = "CallAdv", caption = "Call adv func"} 
	end
	onTickFunctions[key] = nil
end

local function init()
	pClosure.init()
	pClosure1 = pClosure.new("Namespace1") --namespace is optional but you need to make sure you "save" functions into different names
	pClosure2 = pClosure.new("Namespace2")
end

onTickFunctions.on_first_tick = on_first_tick

local function on_gui_click(event)
	local name = event.element.name
	
--------------EXAMPLES STARTS HERE--------------
	local upval = {42,45}
	local upval2 = 88
	--the actual function with a closure/upvalue, saving this to global will not work when save/loading as the global serialization does not handle closures
	local func = function (arg1)  
		--local upval = upval 
		--TODO: this line still causes env problems
		game.player.print(tostring(pClosure2._pClosureProxy))
		game.player.print( upval[1] .. ", ".. upval2 )
		upval[1] = upval[1] + 1 
		upval2 = upval2 + 1
		--increment the upval so you can see how it behaves across save/loads, by default the upvalue that is changed in a function is not saved across save/loads, but there is a way around this, see last section
	end
	if name == "Save" then 

		pClosure1.func = func
		--pClosure2.func = func
		
		game.player.print( "func has been saved, you can save/load the game and see that Calling it still works" )
		game.player.print(tostring(pClosure1._pClosureProxy))
	end
	if name == "Call" then 
		pClosure1.func(" And I'm a argument")
	end
	if name == "Delete" then 
		pClosure1.func = nil
		game.player.print( "func has been deleted, calls to it will not work" )
	end
	if name == "SaveDiff" then
		pClosure2.func = func
		--pClosure1.func2 = func
		game.player.print( "func saved to different namespace, delete the first one and this one will not be affected" )
	end
	if name == "CallDiff" then
		pClosure2.func("And I'm a argument")
		--pClosure1.func2("fun2")
		--pClosure1.func2 = pClosure1.func2
	end
	--you can also change the upvalue after the function body, and it will save the new value
	if name == "SaveUp" then
		upval = {1000,45} --a different upvalue
		pClosure1.funcUp = func --notice that funcUp is named diffent from line 41, if not it will overwrite that function
		game.player.print( "differnt upvalue saved" )
	end
	
	if name == "CallUp" then
		pClosure1.funcUp("And I'm a argument")
		pClosure.printMessages = false
		pClosure1.funcUp = pClosure1.funcUp 
		-- This line allows you to save the changed upvalues. Without it, after a load, the upvalues will be reset to the inital value. This line will produce a warning by default to warn you that you are overwriting an existing function, you can suppress it by setting printMessages = false.
		pClosure.printMessages = true
		
		--you can also write it this way that will prevent warnings
		--[[ 
		f = pClosure1.funcUp
		pClosure1.funcUp = nil
		pClosure1.funcUp = f
		--]]
	end
	
	--if you want a upvalue that is also a function with a closure in you function you should save it to pClosure and call it from there in you function
	if name == "SaveAdv" then
		local upval = "an upval"
		local upvalFunc = function() game.player.print( upval ) end
		
		pClosure1.upvalFunc = upvalFunc
		--don't write this:
		--local advancedFunc = function() upvalFunc() end
		--instead write this:
		local advancedFunc = function() 
			--pClosure1.upvalFunc()
			pClosure1.upvalFunc()
		end

		pClosure1.advancedFunc = advancedFunc
	end
	if name == "CallAdv" then
		pClosure1.advancedFunc()
	end
		
	
end

script.on_init(init)
script.on_load(init)

script.on_event(defines.events.on_gui_click, on_gui_click)

script.on_event(defines.events.on_tick, 
	function(event) 
		for key,fun in pairs(onTickFunctions) do
			--we pass the key to the function so it can delete itself if it wants to, the function does not remember its own key to prevent closures
			if type(fun) == "function" then fun(key) end
		end
	end)

	