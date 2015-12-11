--[[
by xiaohong 12/1/2015
----------WHAT THIS IS----------

This is a script for factorio 0.12.17
It adds pseudo closure function behavior that persists across save/loads

By default, the global table will NOT work with functions with closures across saves as seen here: http://www.factorioforums.com/wiki/index.php?title=Lua/Data_Lifecycle#global

With this script you can have behavior almost identical to real closures.

The differences are that the upvalues are not linked, so if you have two pClosures sharing the same upvalue, changing the upvalue in one will not affect the other, if you want to link them, you can save and access that value directly from the global table

Also upvalues are not saved if they have their value changed in the function, after a save load they revert to their "initial" state, which is when the function was saved, there is a workaround that will look weird, see section below

----------HOW TO USE----------
--require module
pClosure = require "pClosure"

to initialize call the following in the first tick of the game, see control.lua on how to do that, namespace is optional:
closure = pClosure.new(namespace) 

to add a function:

closure.someFunc = someFunc

to call the function:

closure.someFunc(arg1,arg2,...)

to delete the function:

closure.someFunc = nil

to update the upvalues if you changed them in the function and want them to be saved:

closure.someFunc = closure.someFunc

yes the above line actually works, there will be warnings that can be turned off 

to turn off warnings
pClosure.printMessages = false

----------IMPORTANT----------
also note that since the global and game table are not accessible (i may be wrong) in script.on_load() you should only use this script after pClosure.new() is called in the first tick of the game

----------BAD EXAMPLE----------

--This is an example of what not to do, b is a function with a normal closure, this will not work for save/loads, it will raise an error---
function SomeFunction()
	local upval = "_world"
	function b(arg1)
		game.player.print(arg1 .. upval)
	end
	global.b = b --save the function to global
end

--call b before save/load
SomeFunction()
global.b("hello")

--result: "hello_world"

--save/load game then call b()
global.b("hello")

--result: error

--if you save b in global and call it after a load, it will say something like attempting to access nil value upval, or discard upval, so it will either crash or print out "hello" instead of the expected "hello_world"

----------GOOD EXAMPLE----------

see control.lua

--]]


-- funcCache = {} this table stores the fNames of the functions that have been called this session

-- pClosureData.namespace = {} where the functions and upvalues are stored, will point to global table

local pClosure = {} --module table

pClosure.printMessages = true --set this to false to suppress warnings

local function print(str,trace)
	if not pClosure.printMessages then return end
	game.players[1].print(str)
	if trace then 
		game.players[1].print(debug.traceback())
	end
end

function pClosure.init()
	if not global.pClosureData then return end
	for k,t in pairs(global.pClosureData) do
		local _proxy = t._proxy
		if _proxy then 
			_proxy.funcCache = {}
			setmetatable(_proxy,pClosure)
		end
	end		
end

function pClosure.new (namespace)
	if not global then error("error: global is not available, you should call pClosure.new() in on_load \r\n" .. debug.traceback() ) 
	end
	global.pClosureData = global.pClosureData or {}
	if not namespace then namespace = "global" end
	global.pClosureData[namespace] = global.pClosureData[namespace] or {}
	-- this is where the functions and upvalues are stored
	global.pClosureData[namespace]._proxy = global.pClosureData[namespace]._proxy or {}
	-- _proxy is also stored in global so it is not lost
	local _proxy = global.pClosureData[namespace]._proxy
	_proxy.funcCache = _proxy.funcCache or {}
	_proxy.namespace = namespace 
	_proxy._pClosureProxy = true
	-- _proxy is mostly empty so that everything goes to the metamethods
	setmetatable(_proxy,pClosure)
	return _proxy
end

pClosure.__index = function (t,fName)
	local funcData = global.pClosureData[t.namespace][fName]
	if not funcData then print("error: function not found", true) return end
	local func = funcData.func
	if t.funcCache[fName] then 
		--function already called this session so no need to load
		--print("calling from cache") 
		return func 
	end --]]
	--print("not calling from cache") 
	--restore the upvalues
	local upvals = funcData.upvals or {}
	local ENVindex = funcData.ENVindex
	for i, value in ipairs(upvals) do
		if ENVindex and i == ENVindex then 
			debug.setupvalue(func, i, _G) 
		else 
			debug.setupvalue(func, i, value) 
		end --Skip _ENV

	end
	
	t.funcCache[fName] = true
	return func
end
    
pClosure.__newindex = function (t,fName,func)
	local funcNamespace = global.pClosureData[t.namespace]
	if func == nil then
		funcNamespace[fName] = nil
		t.funcCache[fName] = nil
		return
	end
	if funcNamespace[fName] then
		print("Warning: attempting to overwrite a function, to prevent this warning set it to nil first", true)
	end
	local i = 1
	local upvals = {}
	local ENVindex = false
	--skip upvalue _ENV since it will change across sessions
	while true do
		local name, value = debug.getupvalue(func, i)
		if not name then break end
		if name == "_ENV" then
			print ("skipping _ENV for " .. fName)
			upvals[i] = {}
			ENVindex = i
		else
			upvals[i] = value
		end
		i = i + 1
	end
	funcNamespace[fName] = {func = func,upvals = upvals, ENVindex = ENVindex}
	t.funcCache[fName] = true
end

return pClosure