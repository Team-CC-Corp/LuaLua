local classes = {}

for i=1,10 do
	classes[i] = @class : LuaObject
		function getI()
			return i
		end
	end
end

assert(||classes[3] new| init|.getI() == 3)

@class classes.A : classes[4]
	@property a
	@property(readonly) b = _b
	@property(writeonly) c = _c
	@property(setter=getD,getter=@"getD:") d = _d

	function init()
		_b = 5
		return self
	end

	function (getD:__d)
		if __d then
			_d = __d
		else
			return _d
		end
	end

	function getI()
		return super.getI() + 2
	end

	function cc()
		return _c
	end
end

local aObj = ||classes.A new| init|
assert(aObj.getI() == 6)
aObj.a = 3
assert(aObj.a == 3)
assert(aObj.b == 5)
assert(not pcall(function() aObj.b = 8 end))
aObj.c = 1
assert(aObj.cc() == 1)
assert(not pcall(function() return aObj.c end))
aObj.d = 6
|aObj getD:7|
assert(|aObj getD:nil| == aObj.d and aObj.d == 7)


local @class LocalClass : LuaObject
	function init()
		return self
	end
end

local localObj = ||LocalClass new| init|
assert(localObj)