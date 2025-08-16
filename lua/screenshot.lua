#!/bin/lua

-- TODO Add custom execute commands
-- TODO Add x11 support
local args= arg or args

local flags={
	dont_run_exec=false,
	wayland=false,
	forcex11=false,
	exec="aseprite --oneframe %q",
	cmd=nil,
	type="full",
	use_flameshot=false,
}
local qf = {
	w='wayland',
	r='dont_run_exec',
	x='forcex11',
	f='use_flameshot',
}


for i,v in ipairs(args) do
	if(v:sub(1,2) == "--") then
		local key,value = v:match('%-%-(.-)=(.+)')
		if key and value then
			flags[key:lower()] = value
		else
			flags[k:sub(2):lower()] = true
		end
	elseif(v:sub(1,1) == "-") then
		v:gsub('.',function(a) flags[qf[a:lower()] or a:lower()]=true return "" end)
	end
end



local time = os.date('/tmp/%Y-%m-%d_%Hx%M.%S.png')
if(flags.cmd) then
	os.execute(cmd:gsub('%%FILE%%',time))
	return
end
if(flags.use_flameshot) then
	os.execute(('flameshot %q -p %q; %s &'):format(flags.type,time,flags.exec:format(time)))
	return

end

local using_wayland = not flags.forcex11 and (os.getenv('WAYLAND_DISPLAY') or os.getenv('XDG_SESSION_TYPE') == "wayland")

if(using_wayland) then
	os.execute((''):format())
	return
end
