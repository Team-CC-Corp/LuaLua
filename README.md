###LuaLua
LuaLua is an extension of Lua. The compiler is based on the yueliang Lua compiler, which is written in Lua. LuaLua adds:

* A new function syntax
* A class system with runtime library for support
* A properties system for easily declaring setter/getter methods

LuaLua was built for ComputerCraft. That's the only Lua environment I've dealt with, and I don't expect to deal with many others. But the load.lua file is the only one that should need modification to run properly in any Lua 5.1 environment. LuaJIT will not work because of the differing bytecode.

#Usage

It's fairly simple. Download this as a zip, extract it, and copy the LuaLua directory to your ComputerCraft computer. As long as the files in that folder are in the same directory toghether, it will work. Run load.lua from the shell to enable LuaLua's many features. After running, the files will not be needed again until the computer reboots. Any other files run after loading LuaLua will be compiled with the LuaLua compiler instead of the standard LuaJ one.

#Functions

LuaLua brings a new (optional) syntax to writing and calling functions.

```
local function @(myFunction) -- Creates local function myFunction
	print("Hello, World!")
end

@{myFunction} -- Calls myFunction
```

This simplistic demonstration shows that your function name or call is encapsulated inside the brackets rather than followed by them. This is because the method name and parameters are mixed together.

```
local function @(doSomething:some withThing:thing)
	print(some, thing)
end

@{doSomething:"dog" withThing:"frisbee"}
```

This makes it a bit more clear why you would want this. Function names are more descriptive of their parameters this way. Every single parameter is named just by knowing the name of the function. It should be noted that you can still do vararg functions and calls with this. But only in the last named parameter.

```
local function @(thisIsA:vararg func: a,b,c, ... )
	print(...)
end

@{thisIsA:"vararg" func: 1,2,3,4,5,6,7,8,9}
```

So every parameter is named, and vararg is still possible. But how are the functions stored internally? That is, if this function were named globally, what would the global key be? For every parameter in the function, there is a colon in the name. The above example would have the name

```
thisIsA:func:
```

and that's the string you would have to use to reference it from the global table. In fact, LuaLua actually adds a way to name global variables with symbols like colons in their names by using another new syntax.

```
@"someGlobalName?can#have^anything)in*it." = 4
```

The compiler sees the @" symbols and parses the rest as a string, returns a name and uses it exactly like any other name. You can even do it with locals. And obviously LuaLua functions.

```
function @(someFunction:param secondParam:param2)
	return param + param2
end
local x = @"someFunction:secondParam:"(firstParam, secondParam)
```

#Classes

Classes in LuaLua are very Objective-C inspired. That's where the new function syntax came from! So let's jump right in.

```
local @class MyClass : LuaObject
	function @(init)
		@[super init]
		print("MyClass initializing")
		return self
	end
	function @(myMethod:param)
		print(param)
	end
end

local obj = @[@[MyClass new] init]
@[obj myMethod:"method!"]
```

Three things should be apparent from this.

1. Functions stored in a table can also be indexed and called using the new syntax. Just use square brackets instead and put the object at the opening of the bracket.
2. Classes are objects! They're just special in that they have code to create an instance of themselves, invoked by calling the "new" method on them.
3. The self variable is equivalent to the object returned by new and init.

But some of the details might be unapparent. For one, every class MUST have a superclass. LuaObject is the only class without one. The superclass is denoted by the expression after the colon after the class name. Classes can be local or global, and even be indexes of tables (@class tData.MyClass : tData.SuperClass). Classes really are just objects you can shuffle around just like anything else. You can even declare them anonymously like functions.

```
local t = {}
for i = 1, 100 do
	t[i] = @class : LuaObject
		function @(test)

		end
	end
end
```

Since classes are also objects, they can have their own instance methods (that's what the "new" method is, for example).

```
local @class MyClass : LuaObject @static
	-- static class stuff
	local numberOfInstances = 0
	function @(new)
		numberOfInstances = numberOfInstances + 1
		return @[super new]
	end

	function @(printNumInstances)
		print(numberOfInstances)
	end

end -- end static class

	-- instance object stuff
	function @(instanceMethod)
		print("instance!")
	end
end -- end instance class

@[MyClass printNumInstances] -- prints 0
local obj = @[MyClass new]
@[MyClass printNumInstances] -- prints 1
@[obj instanceMethod]
```

The least obvious thing about this implementation of OOP in Lua is exactly how it works. How is it that when @(test) is declared, it puts it in the method space of the object instead of the global space the class was declared in? In LuaLua, classes are implemented via closures, or functions. Here's an example which doesn't not use the syntactic sugar of @class to declare a class.

```
local MyClass = @[LuaObject subclassWithClassInstantiator:function(self, super)
	-- static class stuff
	local numberOfInstances = 0
	function @(new)
		numberOfInstances = numberOfInstances + 1
		return @[super new]
	end

	function @(printNumInstances)
		print(numberOfInstances)
	end
end andObjectInstantiator:function(self, super)
	-- instance object stuff
	function @(instanceMethod)
		print("instance!")
	end
end]
```

Notice that inside those closures, the static and instance class code are the exact same. When creating a class, you call the subclass method of the superclass. The first argument is a closure function for the static class. The second is for the instances. Before explaining exactly what the static class is (or rather, the metaclass), first it's important to know how these closures are instantiated.

A class has the object instantiator held inside itself. Whenever you call new, an object is created, and essentially the instantiator function has its global environment set to the object, then the function is called. Thus, any globals declared by the function are placed in the object. Of course it's much more complicated than that in reality in order to allow for some of the features of the LuaLua runtime and to allow the super parameter to those functions to work, but you get the gist.

What is this metaclass thing though? Well every object must have a class. And every class is an object. So what's the class for a class? The metaclass! The structure of classes and metaclasses in LuaLua is directly copied from Objective-C. An object of a unique type is instantiated from unique instantation details from its class. Since classes have unique details such as static methods, they have to be instantiated from some other class that is much less unique. The metaclass. All metaclasses are instances of LuaObject's metaclass, which is an instance of itself. Oh my... Worse, that base metaclass is a subclass of LuaObject, which is an instance of that metaclass. It's very complicated so you can research the Objective-C metaclass system if you want to know more. Or just read the runtime.lua file. But the point is, every single class is an instance of some class, and LuaObject is the only class without a superclass. No other exeptions to either rule.

#Properties

Just like Objective-C, an owner of a LuaLua object cannot access that object's data directly. All instance data is stored in local variables for the object. Everything available from the object is methods. You must use accessor methods. Fortunately, several details of LuaLua make this painless. First is the @property directive. This directs the compiler to create a local variable, a setter, and a getter. It does not have to be used inside a class.

```
@property myProp

@{setMyProp:3}
print(@{getMyProp}) -- prints 3
```

The name of the local variable used by the setter and getter is always an underscore followed by the property name. However, this doesn't matter because you can't even access the local variable. It's closed by the VM immediately after creating the methods, as if their declarations where in a do-end block. But if you want access to the local variable, no problem! It's easy to make that so.

```
@property myProp = myLocalName

@{setMyProp:3}
myLocalName = 4
print(@{getMyProp}) -- prints 4
```

It simply sets the name to whatever name is after the = sign, and doesn't close it after declaration.

The LuaLua runtime also adds some nice features for accessing properties in objects. Whenever accessing a key on an object that doesn't exist as a method, the getter function for that key is called. And whenever setting a key, the setter is called.

```
@class MyClass : LuaObject
	@property myData
	function @(init)
		@[super init]
		myData = 3
	end
end

local obj = @[@[MyClass new] init]
print(obj.myData) -- prints 3
obj.myData = 4
print(@[obj getMyData]) -- prints 4
```

As you can see, this works even when referencing the object by globals from inside the class, as shown in the init function.

Finally, you can overwrite the setter and getter methods. In fact, if you want to overwrite them both, you don't even need the @property declaration. Either way the obj.var syntax will work.


##Have fun!

I hope LuaLua is useful to some of you. I spent more time than I'd care to admit making the compiler work. Use it only for good! Or evil. Or whatever.