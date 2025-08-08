#!/usr/bin/amulet
local buffer = ""
local caret = 1
local caretCharacter = "_"
local output = ""


-- Generate list
local MenuFolder = os.getenv('HOME')..'/.config/SupersAppMenu/'





-- Actual display and stuff
local winInfo = {title="FUNNI LUA APPLICATION MENU",borderless=false,width=1000,height=300}
win = am.window(winInfo)
local module = dofile(os.getenv('HOME')..'/SRC/dotfiles/lua/appmenuBase.lua')
-- local ffi = require('ffi')

-- ffi.cdef(io.open('ffi_SDL.h', 'r'):read('*a')) -- https://gist.github.com/arkenidar/bc66711dd73b047a5995f97f4b019f38



TEXT = am.text('',nil,"LEFT","TOP")
-- CARETTEXT = am.text('|',nil,"LEFT","TOP")
local scale = 1

win.scene = am.scale(scale) ^ am.translate(-500/scale,150/scale) ^ am.group{TEXT}

function print(...)
	output = output .. "\n"
	local tbl = {...}
	for i,v in pairs(tbl) do tbl[i]=tostring(v) end
	output = output..table.concat(tbl,'\t')
end
local function moveCaret(c,isCtrl)
	if isCtrl then
		if(c > caret) then
			c = buffer:find('%s.-$',0,caret) or #buffer
			print(caret,'+')
		else
			c = buffer:find('%s',caret) or #buffer
			print(caret,'-')
		end
	end
	caret = math.max(math.min(c,#buffer),0)
end
local function insertCharacter(c,position,incrementCaret)
	if not position then position = caret end
	buffer = buffer:sub(0,position).. c ..buffer:sub(position+1)
	position = position + #c
	if incrementCaret then moveCaret(position) end
end
local function removeCharacter(c,incrementCaret)
	buffer = buffer:sub(0,c-1)..buffer:sub(c+1)
	if(incrementCaret and caret >= c) then moveCaret(caret - 1) end
end
local keyAtlas = { -- uppercase = shift pressed
	equals="=",
	minus="-",
	EQUALS="+",
	MINUS="_",
	leftbracket='[',
	rightbracket=']',
	LEFTBRACKET='{',
	RIGHTBRACKET='}',
	semicolon=';',
	SEMICOLON=':',
	quote='\'',
	QUOTE='"',
	comma=',',
	period='.',
	COMMA='<',
	PERIOD='>',
	slash='/',
	backslash='\\',
	SLASH='?',
	BACKSLASH='|',
	SHIFT1="!",
	SHIFT2="@",
	SHIFT3="#",
	SHIFT4="$",
	SHIFT5="%",
	SHIFT6="^",
	SHIFT7="&",
	SHIFT8="*",
	SHIFT9="(",
	SHIFT0=")",
}
local keybindFunctions = {
	l=function() buffer = "" output = "" caret = 0 end,
	v=function() 
		local clip = executeCmd('wl-paste')
		insertCharacter(clip:sub(1,1) == '"' or clip:sub(1,1) == "'" and clip or ('%q'):format(clip),caret,true)
	end,
	delete=function() buffer = "" end
}

local lastKey = ""
local handleKey = nil
local timerFromLastPress = 0
local allowRepeat = false
win.scene:action(function(e)
	local keys_pressed = win:keys_pressed()
	local keys_down = win:keys_down()
	if(#keys_down == 0) then return end
	local isShift = win:key_down("lshift") or win:key_down("rshift")
	local isCtrl = win:key_down("lctrl") or win:key_down("rctrl")
	timerFromLastPress = timerFromLastPress + am.delta_time
	for i,v in ipairs(keys_pressed) do
		allowRepeat = false
		handleKey(v,isShift,isCtrl)
	end
	if(not allowRepeat) then 
		if(timerFromLastPress > 1) then
			allowRepeat = true
			timerFromLastPress = 0
		end
	elseif(timerFromLastPress > 0.1) then
		for i,v in ipairs(keys_down) do
			handleKey(v)
		end
		timerFromLastPress = 0
	end
	module.updateInput(buffer)
	local caret = caret
	local buffer = buffer:sub(0,caret) .. caretCharacter .. buffer:sub(caret+1)
	-- local buffer = buffer
	-- if(#buffer > 30 and caret > 30) then

	-- 	buffer = buffer:sub(caret-30,caret+30)
	-- 	-- if(caret > 10) then
	-- 	-- 	buffer = '..'..buffer
	-- 	-- end
	-- 	-- if(#buffer-caret > 10) then
	-- 	-- 	buffer = buffer..'..'
	-- 	-- end
	-- 	CARETTEXT.text = (' '):rep(30)..caretCharacter
	-- else
	-- 	CARETTEXT.text = (' '):rep(caret)..caretCharacter

	-- end

	TEXT.text = buffer .. '\n' .. module.output
end)

function handleKey(v,isShift,isCtrl)
	if(v == "space") then
		insertCharacter(" ",caret,true)
	elseif(v == "backspace") then
		removeCharacter(caret,true)
	elseif(v == "enter") then
		local buffer = buffer
		-- -- if not buffer:find('return ') then buffer = "return " ..buffer end
		-- local succ,err = pcall(function()
		-- 	local chunk,err = load(buffer)
		-- 	if not chunk then return err end
		-- 	return chunk()
		-- end)
		module.finish(buffer)
		win:close()
	elseif(v == "pause" or v == "escape") then
		win:close()
	elseif(v == "left") then
		moveCaret(caret-1,isCtrl)
	elseif(v == "right") then
		moveCaret(caret+1,isCtrl)
	elseif(v == "down") then
		local id = tonumber(buffer:match(' (%d+)$') or 1)
		id = id + 1
		buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
	elseif(v == "up") then
		local id = tonumber(buffer:match(' (%d+)$') or 2)
		id = id - 1
		if(id < 1) then id = 1 end
		buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
	elseif(v == "tab") then
		-- local id = tonumber(buffer:match(' (%d+)$') or 0)
		-- id = id + (isShift and -1 or 1)
		-- if(id < 1) then id = 1 end
		-- buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
		if(tostring(module.runable[2]):find('%.desktop$')) then
			local file = io.open(tostring(module.runable[2]),'r')
			local content = file:read('*a')
			file:close()
			local newBuffer = content:match('Exec=([^\n]+)')
			if newBuffer then
				buffer = newBuffer:gsub('%%.',''):gsub('^%s+',''):gsub('%s+$','')
			end
			caret = #buffer
		end
	else
		local v = v
		if isShift then 
			if(tonumber(v) ~= nil and tonumber(v) == tonumber(v)) then
				v = 'SHIFT'..v
			else
				v = v:upper()
			end
		end
		v = keyAtlas[v] or v
		if(isCtrl) then
			local func = keybindFunctions[v]
			if(func) then
				return func()
			end
		elseif(#v == 1) then
			insertCharacter(v,caret,true)
			-- lastKey = v .. (isShift and " + shift" or "")  .. (isCtrl and " + ctrl" or "")
			return
		end
	end
	-- lastKey = v .. (isShift and " + shift" or "")  .. (isCtrl and " + ctrl" or "")
end
module.updateInput(buffer)
TEXT.text = buffer .. '\n' .. module.output

local firstEv = am.group()
firstEv:action(function()
	win.scene:remove(firstEv)
	if(os.getenv('XDG_CURRENT_DESKTOP') == "cwc") then
		os.execute(('cwctl -c %q'):format(([[local client = cwc.client:focused()
		client.floating = true
		client:raise()
		client:focus()
		client:center()
		local g = client.geometry
		client.x = g.x
		client.y = g.y
		client.width = ${width}
		client.height = ${height}
		]]):gsub('%${(.-)}',winInfo):gsub('%s+\t+',';')))
	end
end)

win.scene:append(firstEv)
