local ls = loadstring
local dir = fs.getDir(shell.getRunningProgram())
local files = {}



for i,v in ipairs({"lcode.lua", "ldump.lua", "llex.lua", "lopcodes.lua", "lparser.lua", "luac.lua", "lzio.lua"}) do
	local err
	files[v], err = loadfile(fs.combine(dir, v))
	if not files[v] then printError(err) end
end

function _G.loadstring(str, source)
	source = source or ""
	assert(type(source) == "string", "Expected string, got " .. type(source), 2)
	local header = 0
	if #str > 12 then -- header size is 12
		for i = 1, 4 do
			header = header + 2 ^ (8 * (4 - i)) * string.byte(str:sub(i,i))
		end
	end

	if header == 0x1B4C7561 then
		return ls(str, source)
	end

	local compileEnv = setmetatable({}, {__index=_G})
	function compileEnv.dofile(name)
		setfenv(files[name], compileEnv)
		files[name]()
	end

	setfenv(files["luac.lua"], compileEnv)
	local ok, str = pcall(files["luac.lua"], str, source)
	if not ok then return nil, str end
	--[[local file = fs.open("sample.out", "w")
	file.write(str)
	file.close()]]
	return ls(str, source)
end

assert(loadfile(fs.combine(dir, "runtime.lua")))()