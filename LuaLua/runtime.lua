---------------------------------------------------------------------------------------------
--[[ runtime.lua
---------------------------------------------------------------------------------------------
Implementation of the LuaLua runtime
Mostly about the OOP feature of LuaLua
There are three big points to be made:

1) Objects are instantiated via functions
Instead of having a table for a class and using metatables to __index to that,
a function has its environment set to a special table and is run to instantiate methods
This makes it easier for "super" to work
It also allows for private variables for an object
Plus an objects methods can be passed around and the receiver of it can call it without passing the self variable
And finally, from within a class, you don't have to use the self keyword to reference self's methods

2) Data in objects is kept in properties like in Objective C
Instead of having variables in the object itself, you use locals and setter/getter methods
The object's metatable allows for obj.a = 3 to automatically call obj.setA(3) and a similar effect for getters
From within the functions of the object, anything you do with "self" is done exactly the same with globals
No need for self.<everything>
LuaLua adds syntax for having the local, setter, and getter created all from one line
@property myVar [= _localName]

3) Classes are objects
Although objects are instantiated from functions, classes are objects that have properties for the instantiators
A class is an instance of its metaclass
Every class has one metaclass
The metaclass does nothing but hold the instantiator and supermetaclass both for the sake of instantiating the class
Classes hold the instantiator and superclass for the sake of instantiating the object
But classes also have their own class methods, unlike metaclasses
This is what allows the @[@[Class new] init] way of doing things



-- Structure of the class chain
It's identical to Objective C
Every object is instantiated from a class
Classes are objects, so they are instantiated from their metaclass
The metaclass is instantiated from the base class's metaclass
The base class is an instance of its metaclass
That metaclass's superclass is the base class
That makes for some complicated code in the newBaseClass function
But the result is that every class is both an instance of the base class, and a subclass of it, which is useful



-- USAGE
USING LUALUA:
local @class MyClass : SuperClass @static
	function @[myClassMethod]

	end
end
	function @[myMethod:someVar]

	end
end

The same can be done "anonymously"

someVar = @class : MySuper
	function @[method]

	end
end

Note that the static section is optional
LuaLua does not have syntax for base classes, as that should not be common

WITHOUT @CLASS SYNTAX:
local MyClass = @[SuperClass subclassWithInstantiator:function()
	-- instance
	function @[myInstanceMethod]

	end
end andClassInstantiator:function()
	-- static
	function @[myClassMethod]

	end
end]

]]

------- Utility stuff

local function setObjectProperty(obj, propName, getter, setter, methodsTable)
	local tMethods = methodsTable or obj.methods
	tMethods["get"..propName:sub(1,1):upper()..propName:sub(2)] = getter or function() error(propName .. " is not readable", 3) end
	tMethods["set"..propName:sub(1,1):upper()..propName:sub(2)..":"] = setter or function() error(propName .. " is not writable", 3) end
end

function _G.assert(condition, errMsg, level)
	if condition then return condition end
	if type(level) ~= "number" then
		level = 2
	elseif level <= 0 then
		level = 0
	else
		level = level + 1
	end
	error(errMsg or "Assertion failed!", level)
end

function fs.getDir(_sPath)
	return fs.combine("", _sPath:sub(1, -1 - #(fs.getName(_sPath))))
end

------- Instantiation stuff

local function createMethods(class, obj)
	local superMethods
	if class.superClass then
		superMethods = createMethods(class.superClass, obj)
	end

	local methods = setmetatable({}, {__index = superMethods, __newindex = function(t,k,v)
		assert(type(v) == "function", "Only functions allowed in class body: " .. k .. " = " .. tostring(v))
		rawset(t,k,v)
	end})

	local oldEnv = getfenv(class.instantiator)
	local env = {}

	-- obj's metatable can't be made until after methods are created
	-- must therefore not reference it until after instantiation
	local mt = {
		__index = function() end,
		__newindex = methods
	}
	setmetatable(env, mt)

	setfenv(class.instantiator, env)
	class.instantiator(obj, superMethods)
	setfenv(class.instantiator, oldEnv)

	mt.__index = function(t,k)
		return obj[k] or oldEnv[k]
	end
	mt.__newindex = obj
	return methods
end

local function newObject(class)
	local obj = {}
	local methodsTable = createMethods(class, obj)
	setmetatable(obj, {
		__index = function(t,k)
			local getter = methodsTable["get"..k:sub(1,1):upper()..k:sub(2)]
			if type(getter) == "function" then
				return getter()
			end
			return methodsTable[k]
		end,
		__newindex = function(t,k,v)
			local setter = methodsTable["set"..k:sub(1,1):upper()..k:sub(2)..":"]
			if type(setter) == "function" then
				setter(v)
			end
		end
	})
	setObjectProperty(obj, "methods", function() return methodsTable end, nil, methodsTable) -- pass the methodstable because the property doesn't exist yet
	setObjectProperty(obj, "class", function() return class end)
	return obj
end



------- Class stuff

local function newBaseClass(instance, static)
	-- Metaclass is an instance of itself. static is all we know about it, so use that
	local metaclass = newObject({instantiator = static})
	-- It also instantiates class, so the instantiator is static
	setObjectProperty(metaclass, "instantiator", function() return static end)
	-- Class obviously is an instance of its metaclass
	local class = newObject(metaclass)
	
	-- Set the remaining properties for the two under-developed classes
	-- Class doesn't have a superclass, metaclass's superclass is class
	setObjectProperty(metaclass, "superClass", function() return class end)
	setObjectProperty(class, "instantiator", function() return instance end)
	
	-- reassign in order for both to have each other's methods
	metaclass = newObject(metaclass)
	setObjectProperty(metaclass, "superClass", function() return class end)
	setObjectProperty(metaclass, "instantiator", function() return static end)
	setObjectProperty(metaclass, "class", function() return metaclass end)

	class = newObject(metaclass)
	setObjectProperty(class, "superClass", function() end) -- There is no superclass!
	setObjectProperty(class, "instantiator", function() return instance end)
	setObjectProperty(class, "class", function() return metaclass end)

	return class
end

local function newClass(super, instance, static)
	-- super is instance of its metaclass, which is always an instance of base meta class
	local baseMetaclass = super.class.class
	
	-- All metaclasses are instances of the base metaclasses
	local metaclass = newObject(baseMetaclass)
	setObjectProperty(metaclass, "superClass", function() return super.class end)
	setObjectProperty(metaclass, "instantiator", function() return static end)
	-- Unlike when creating base classes, regular classes have their class properties properly created by newObject()

	local class = newObject(metaclass)
	setObjectProperty(class, "superClass", function() return super end)
	setObjectProperty(class, "instantiator", function() return instance end)

	return class
end



------- LuaObject

_G.LuaObject = newBaseClass(function(self, super)
	-- instance
	function @(init)
		return self
	end

	function @(setProperty:propName withGetter:getter andSetter:setter)
		setObjectProperty(self, propName, getter, setter)
	end
end, function(self, super)
	-- static
	function @(new)
		return newObject(self)
	end

	function @(subclassWithClassInstantiator:static andObjectInstantiator:instance)
		return newClass(self, instance, static)
	end
end)


------- Modules

local function @(createRequireForDir:dir withModules:modules)
	return function(file)
		assert(type(file) == "string", "Path expected", 2)
		if file:sub(1,1) == "/" or file:sub(1,1) == "\\" then
			dir = ""
		end
		file = fs.combine(dir, file)
		if modules[file] then
			return modules[file]
		end
		assert(fs.exists(file) and not fs.isDir(file), "Expected module", 2)
		local f, err = loadfile(file)
		assert(f, err, 2)
		local env = setmetatable({}, {__index = _G})
		env.require = @{createRequireForDir:fs.getDir(file) withModules:modules}
		setfenv(f, env)
		modules[file] = f()
		return modules[file]
	end
end

local oldRun = os.run
function os.run( _tEnv, _sPath, ... )
	local modules = {}
	_tEnv.require = @{createRequireForDir:fs.getDir(_sPath) withModules:modules}
	oldRun(_tEnv, _sPath, ...)
end