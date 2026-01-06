#!/bin/lua
help=
[[Usage: "gmrun.lua (ARGUMENTS) -- (COMMAND)" 
A wrapper for the gamemoderun wrapper to add support for supplying environment variables and some other utilities without needing to supply the same command to a bunch of games and keep said commands up to date
CLI Options:
 -v                Be verbose
 -d                Dryrun, don't actually run anything. Implies -v
 -x --xwayland     (Requires xwayland-run) Runs with xwayland. 
     Will prepend 'xwayland_command', 'xwayland_native_command' or 'xwayland_wine_command' options in the gamemode.ini. If those options don't exist, 'xwayland 5:' will be used instead
 --no-xwayland     The inverse of the above
 -w --wine         Forces wine/proton specific options. Useful if the automatic detection doesn't work
 -n --native       Forces native specific options. Useful if the automatic detection things you're using a proton/wine program
 --no_gamemode     Don't use gamemoderun
 --pre="(PRESET)"  Prepend text specified by the INI
 --app="(PRESET)"  Append text specified by the INI
INI Options:
 xwayland_command       =(cmd)   #The command used for xwayland. '--' is automatically added if omitted
 xwayland_wine_command  =(cmd)   #The command used for xwayland if wine is detected
 xwayland_native_command=(cmd)   #The command used for xwayland if wine is not detected
 env_(VAR)              =(VALUE) #Environment options
 prepend_(PRESET)       =(CMD)   #Text to prepend to command. Used with --pre="(PRESET)"
 append_(PRESET)        =(CMD)   #Text to append to command. Used with --app="(PRESET)"

Reads directly from gamemode.ini files
 Expects env_VAR=VALUE, examples: 'env_MESA_VK_DEVICE_SELECT="1002:7340!"' or 'env_WINEDLLOVERRIDES="version=n,b"' Environment variables cannot span across lines
To use in steam, it's recommended to install this somewhere in your PATH and then use "gmrun.lua -- %command%" for your launch options
]]





local paths = {
	'/usr/share/gamemode/gamemode.ini',
	'/etc/gamemode.ini',
	(os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME').."/.config"))..'/gamemode.ini',
	os.getenv('PWD')..'/gamemode.ini',
}
help = help .. '\nWill read gamemode.ini files from in reverse order: '..table.concat(paths,', ')

local _print = print
local function vprint(...) end
local function wprint(...) _print('[ WARN ] ',...) end

-- CLI switch parsing
local flag_chars = {
	x="xwayland",
}
local flags = {}
local arguments = {}
local acceptArgs = false
for i,arg in ipairs(arg or args) do
	if     (acceptArgs)           then arguments[#arguments+1] = ('%q'):format(arg)
	elseif (arg == "--")          then acceptArgs = true
	elseif (arg:sub(1,2) == "--") then 
		local i,v = arg:match('%-%-(.-)=(.+)')
		if i and v then
			flags[i] = v
		else
			flags[arg:sub(2)] = true
		end
	elseif (arg:sub(1,1) == "-")  then 
		for char in arg:sub(1):gmatch('.') do 
			flags[flag_chars[char] or char] = true
		end
	end
end


if(flags.d) then flags.v = true end
if(flags.v) then
	function vprint(...) 
		_print('[VERBOSE]',...)
	end
	function print(...)
		_print('[ PRINT ]',...)
	end
end

if #arguments == 0 then
	vprint('No arguments')
	print('Invalid usage! '..help)
	return -1
end
if not flags.native and not flags.wine then
	for i,v in ipairs(arguments) do
		v=v:sub(2,-2) -- Removes the quotes added earlier
		if(v=="proton" or v:find('/proton.-/'))      then
			flags.wine = "proton"
			break
		elseif(v == "wine" or v:find('/wine'))       then
			flags.wine = "wine"
			break
		elseif(v:find('%.exe ') or v:find('%.exe$')) then
			flags.wine = ".exe"
			break
		end
	end
	if flags.wine then 
		vprint('Found wine/proton/exe, detected as '..flags.wine)
	else
		flags.native = true
		vprint('No wine/proton/exe found, detected as native')
	end
end

local ini = {}
local valid_files,ini_count = 0,0
for _,path in ipairs(paths) do
	local file = io.open(path,'r')
	if file then
		valid_files=valid_files+1
		local iniContents = file:read('*a'):gsub('\n;[^\n]+','')
		file:close()
		local count = 0
		for i,v in iniContents:gmatch('([^\n=]+)=([^\n]+)') do
			count = count+1
			ini_count=ini_count+1
			local value = v:gsub('^%s+',''):gsub('%s+$','')
			-- local value_lower = value:lower()
			-- if    (value_lower == "true"  or value_lower == "1") then value = true
			-- elseif(value_lower == "false" or value_lower == "0") then value = false
			-- end
			ini[i:gsub('^%s+',''):gsub('%s+$','')] = value
		end
		vprint('Read '..count..' options from '..path)
	else
		vprint('Ignoring '..path..' (File not found)')
	end
end
vprint('Read '..ini_count..' options from '..valid_files..' files')
if ini_count == 0 then wprint('No options found, do you have any gamemode.ini files?') end

local env = {}
for i,v in pairs(ini) do
	if(i:sub(1,4) == "env_") then
		env[#env+1] = i:sub(5).."="..tostring(v)
	end
end

if not os.execute('which gamemoderun > /dev/null') then
	wprint('gamemoderun NOT found, running WITHOUT it!')
	flags.no_gamemoderun = true
	vprint('Set no_gamemoderun to true')
end

if(flags.no_gamemoderun) then vprint('Not using gamemoderun')
else table.insert(arguments,1,'gamemoderun')
end

if(flags.pre and ini['prepend_'..flags.pre]) then
	table.insert(arguments,1,ini['prepend_'..flags.pre])
end
if(flags.app and ini['append_'..flags.app]) then
	arguments[#arguments+1] = ini['append_'..flags.app]
end

if(flags.xwayland) then
	local cmd = (
		flags.wine and ini.xwayland_proton_command
		or flags.native and ini.xwayland_native_command
		or ini.xwayland_command
		or 'xwayland-run :5'
	)
	table.insert(arguments,1,cmd .. (cmd:sub(-2) == "--" and "" or ' --'))
end
table.insert(arguments,1,'env ' .. table.concat(env, " "))

local cmd = table.concat(arguments,' ')

if(flags.v) then vprint('Command:',cmd) end
if(flags.d) then print('Dryrun, exiting!') return -2 end
return os.execute(cmd)