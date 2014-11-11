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

local function setObjectProperty(obj, propName, getter, getterName, setter, setterName, methodsTable, propMap)
	local tMethods = methodsTable or obj.methods
	local propertyMap = propMap or obj.propertyMap
	propertyMap[propName] = {setter=setterName,getter=getterName}
	tMethods[getterName] = getter or \() error(propName .. " is not readable", 3) end
	tMethods[setterName..":"] = setter or \() error(propName .. " is not writable", 3) end
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

------- Instantiation stuff

local function createMethods(class, obj)
	local superMethods, superProperties
	if class.superClass then
		superMethods, superProperties = createMethods(class.superClass, obj)
	end

	local methods = setmetatable({}, {__index = superMethods, __newindex = \(t,k,v)
		assert(type(v) == "function", "Only functions allowed in class body: " .. k .. " = " .. tostring(v))
		rawset(t,k,v)
	end})

	local propertyMap = setmetatable({}, {__index = superProperties})



	setmetatable(obj, {
		__index = \(t,k)
			if propertyMap[k] then
				local ret = methods[propertyMap[k].getter]()
				return ret
			end
			return methods[k]
		end,
		__newindex = \(t,k,v)
			if propertyMap[k] then
				methods[propertyMap[k].setter..":"](v)
			else
				error("No such property: " .. k, 2)
			end
		end
	})
	setObjectProperty(obj, "methods", \() return methods end, "getMethods", nil, "setMethods", methods, propertyMap) -- pass the methodstable because the property doesn't exist yet
	setObjectProperty(obj, "propertyMap", \() return propertyMap end, "getPropertyMap", nil, "setPropertyMap", methods, propertyMap)
	setObjectProperty(obj, "class", \() return class end, "getClass", nil, "setClass")




	local oldEnv = getfenv(class.instantiator)
	local env = {}

	-- obj's metatable can't be made until after methods are created
	-- must therefore not reference it until after instantiation
	local mt = {
		__index = \(t,k)
			return methods[k] or oldEnv[k]
		end,
		__newindex = methods
	}
	setmetatable(env, mt)

	setfenv(class.instantiator, env)
	class.instantiator(obj, superMethods)
	setfenv(class.instantiator, oldEnv)

	mt.__index = \(t,k)
		return obj[k] or oldEnv[k]
	end
	mt.__newindex = obj
	return methods, propertyMap
end

local function newObject(class)
	local obj = {}
	createMethods(class, obj)
	
	return obj
end



------- Class stuff

local function newBaseClass(instance, static)
	-- Metaclass is an instance of itself. static is all we know about it, so use that
	local metaclass = newObject({instantiator = static})
	-- It also instantiates class, so the instantiator is static
	setObjectProperty(metaclass, "instantiator", \() return static end, "getInstantiator", nil, "setInstantiator")
	-- Class obviously is an instance of its metaclass
	local class = newObject(metaclass)
	
	-- Set the remaining properties for the two under-developed classes
	-- Class doesn't have a superclass, metaclass's superclass is class
	setObjectProperty(metaclass, "superClass", \() return class end, "getSuperClass", nil, "setSuperClass")
	setObjectProperty(class, "instantiator", \() return instance end, "getInstantiator", nil, "setInstantiator")
	
	-- reassign in order for both to have each other's methods
	metaclass = newObject(metaclass)
	setObjectProperty(metaclass, "superClass", \() return class end, "getSuperClass", nil, "setSuperClass")
	setObjectProperty(metaclass, "instantiator", \() return static end, "getInstantiator", nil, "setInstantiator")
	setObjectProperty(metaclass, "class", \() return metaclass end, "getClass", nil, "setClass")

	class = newObject(metaclass)
	setObjectProperty(class, "superClass", \() end, "getSuperClass", nil, "setSuperClass") -- There is no superclass!
	setObjectProperty(class, "instantiator", \() return instance end, "getInstantiator", nil, "setInstantiator")
	setObjectProperty(class, "class", \() return metaclass end, "getClass", nil, "setClass")

	return class
end

local function newClass(super, instance, static)
	-- super is instance of its metaclass, which is always an instance of base meta class
	local baseMetaclass = super.class.class
	
	-- All metaclasses are instances of the base metaclasses
	local metaclass = newObject(baseMetaclass)
	setObjectProperty(metaclass, "superClass", \() return super.class end, "getSuperClass", nil, "setSuperClass")
	setObjectProperty(metaclass, "instantiator", \() return static end, "getInstantiator", nil, "setInstantiator")
	-- Unlike when creating base classes, regular classes have their class properties properly created by newObject()

	local class = newObject(metaclass)
	setObjectProperty(class, "superClass", \() return super end, "getSuperClass", nil, "setSuperClass")
	setObjectProperty(class, "instantiator", \() return instance end, "getInstantiator", nil, "setInstantiator")

	return class
end



------- LuaObject

_G.LuaObject = newBaseClass(\(self, super)
	-- instance
	function (init)
		return self
	end

	function (setProperty:propName withGetter:getter named:getterName andSetter:setter named:setterName)
		setObjectProperty(self, propName, getter, getterName, setter, setterName)
	end
end, \(self, super)
	-- static
	function (new)
		local obj = newObject(self)
		return obj
	end

	function (subclassWithClassInstantiator:static andObjectInstantiator:instance)
		return newClass(self, instance, static)
	end

	function (isSubclassOf:superClass)
		local test = self
		while true do
			if superClass == test then
				return true
			end
			if test.superClass then
				test = test.superClass
			else
				return false
			end
		end
	end
end)


------- Modules

local function (createRequireForDir:dir withModules:modules)
	return \(file)
		assert(type(file) == "string", "Path expected", 2)
		local dir = dir
		if file:sub(1,1) == "/" or file:sub(1,1) == "\\" then
			dir = ""
		end
		file = fs.combine(dir, file)
		if not modules[file] then
			assert(fs.exists(file) and not fs.isDir(file), "Expected module", 2)
			local f, err = loadfile(file)
			assert(f, err, 2)
			local env = setmetatable({}, {__index = _G})
			env.require = |@ createRequireForDir:fs.getDir(file) withModules:modules|
			setfenv(f, env)
			modules[file] = f()
		end
		
		return modules[file]
	end
end

local oldRun = os.run
function os.run(_tEnv, _sPath, ...)
	assert(type(_tEnv) == "table" and type(_sPath) == "string", "Expected table, string", 2)

	local modules = {}
	_tEnv.require = |@ createRequireForDir:fs.getDir(_sPath) withModules:modules|
	return oldRun(_tEnv, _sPath, ...)
end

-- Let APIs use require()
local tAPIsLoading = {}
function os.loadAPI(path)
    assert(type(path) == "string", "Expected string", 2)

    local sName = fs.getName(path):gsub("%.lua$", "")

    if tAPIsLoading[sName] == true then
        printError( "API "..sName.." is already being loaded" )
        return false
    end
    tAPIsLoading[sName] = true
        
    local tEnv = {}
    if not os.run(tEnv, path) then
        tAPIsLoading[sName] = nil
        return false
    end
    
    local tAPI = {}
    for k,v in pairs( tEnv ) do
        tAPI[k] =  v
    end
    
    _G[sName] = tAPI    
    tAPIsLoading[sName] = nil
    return true
end