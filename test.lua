local mystuff = {}

@class mystuff.Class : LuaObject @static
	function @(test)
		print('test')
	end
end
	function @(itest)
		print('itest')
	end
end

@[mystuff.Class test]
local obj = @[mystuff.Class new]
@[obj itest]