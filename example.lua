local @class MyClass : LuaObject @static
	function (subclassWithClassInstantiator:static andObjectInstantiator:instance)
		local c = |super subclassWithClassInstantiator:static andObjectInstantiator:instance|
		return c
	end
end
	function (init)
		-- initialize
		self = |super init|
		return self
	end
	function (methodWithAParam:a)
		print(a)
	end
end

|||MyClass new| init| methodWithAParam:1|