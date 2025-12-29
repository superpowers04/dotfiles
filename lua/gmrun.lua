#!/bin/lua
--[[ 
A wrapper for the gamemoderun wrapper to add support for supplying environment variables
 Reads directly from gamemode.ini files
  Expects env_VAR=VALUE, examples: 'env_MESA_VK_DEVICE_SELECT="1002:7340!"' or 'env_WINEDLLOVERRIDES="version=n,b"' Environment variables cannot span across lines
 usage: "gmrun.lua -- COMMAND"
 To use in steam, it's recommended to install this somewhere in your PATH and then use "gmrun.lua -- %command%" for your launch options

--]] 


local paths = {
	'/usr/share/gamemode/gamemode.ini',
	'/etc/gamemode.ini',
	(os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME').."/.config"))..'/gamemode.ini',
	os.getenv('PWD')..'/gamemode.ini',
	os.getenv('PWD')..'/gamemode.ini',
}

local flags = {}

local arguments = {}
local acceptArgs = false
for i,arg in ipairs(arg or args) do
	if(acceptArgs) then
		arguments[#arguments+1] = ('%q'):format(arg)
	elseif(arg == "--") then
		acceptArgs = true
	elseif(arg:sub(1,1) == "-") then
		flags[arg:sub(1)] = true
		-- print(arg)
	end
end
if #arguments == 0 then
	print('Invalid usage! Usage: gmrun.lua -- (COMMAND)\n -v - Print command before running')
	return -1
end
local arguments = table.concat(arguments,' ')


local ini = {
}

for _,path in ipairs(paths) do
	local file = io.open(path,'r')
	if file then
		local iniContents = file:read('*a'):gsub('\n;[^\n]+','')
		file:close()
		for i,v in iniContents:gmatch('([^\n=]+)=([^\n]+)') do
			ini[i:gsub('^%s+',''):gsub('%s+$','')] = v:gsub('^%s+',''):gsub('%s+$','')
		end
	end
end

local env = {}
for i,v in pairs(ini) do
	if(i:find('^env_')) then
		env[#env+1] = i:sub(5).."="..v
	end
end
local cmd = ('env %s gamemoderun %s'):format(table.concat(env, " "),arguments)
if(flags.v) then
	print(cmd)
end
return os.execute(cmd)