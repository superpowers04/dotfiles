



function spawn_shell(cmd,a,...)
	if(type(a) == "tbl") then
		local args = {}
		for i,v in pairs(a) do
			if(type(i) == "string") then
				if(v == true) then
					args[#args+1] = ('-%s'):format(#i ==1 and i or '-'..i)
				else
					args[#args+1] = ('-%s=%q'):format(#i ==1 and i or '-'..i,tostring(v))
				end

			end
		end
		for i,v in ipairs(a) do
			args[#args+1] = ('%q'):format(v)
		end
		cwc.spawn_with_shell(('%s %s'):format(cmd,table.concat(args,' ')))

		return
	end
	local args = {...}
	table.insert(args,1,a)
	cwc.spawn_with_shell((cmd..(' %q'):rep(#args)):format(unpack(args)))

end

notifySend = function(...)
	spawn_shell('notify-send',...)
end
notifyPrint = function(...)
	local e = {}
	local input = {...}
	for i=1,#input do
		e[i] = tostring(input[i]):gsub('[`${}]','\\%1')
	end
	notifySend('',table.concat(e,'\n'))
	print(...)
end

local gears = require("gears")

local home = os.getenv('HOME').. '/.config/cwc/modules'
_G.extras = {}

-- awful.spawn.easy_async_with_shell('ls -1N '..home,function(out)
local ls = io.popen('ls -1N '..home,'r')
local out = ls:read('*a')
ls:close()
local succ,err = pcall(function()
	local scriptList = {}
	for path in out:gmatch('[^\n]+') do
		if(path:sub(-4)==".lua" or gears.filesystem.dir_readable(path)) then
			scriptList[#scriptList+1]='modules.'..path:gsub('%.lua$','')
		end
	end
	table.sort(scriptList)
	for _,path in ipairs(scriptList) do
		local succ,err,e = pcall(function() return require(path) end)
		-- naughty.notify({preset = naughty.config.presets.critical,
		-- title = "Loaded "..path..tostring(succ),
		-- text = err })
		if(succ) then
			_G.extras[#_G.extras+1] = err or e
		else
			notifyPrint("Error while trying to load "..path,err)
		end
	end
end)
if not succ then
	notifyPrint('Unable to load extensions',err)
end
-- 	-- end
-- end)
