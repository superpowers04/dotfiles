#!/usr/bin/amulet
local buffer = ""
local caret = 1
local caretCharacter = "_"
local output = ""


-- Generate list
local MenuFolder = os.getenv('HOME')..'/.config/SupersAppMenu/'


local cache = io.open('/tmp/APPMENU_CACHE.lua','r')
local module = {}
local awful = {}
awful.spawn = function(a)
	os.execute(a .. " &")
end
executeCmd = function(a)
	local e = io.popen(a,'r')
	local r = e:read('*a')
	e:close()
	if(r:sub(-1) == "\n") then r=r:sub(0,-2) end
	return r
end

local help = [[Usage:
 (NAME)[ (ID)]
Shortcuts:]]




local menu_contents = io.open(MenuFolder..'/menu_contents.lua')
local old_menu = {}
if menu_contents then 
	local succ,err = pcall(function()
		old_menu = load(menu_contents:read('*a'))()
	end)
	menu_contents:close()
end
module.commands = {}
local function generate_help(cmds)
	cmds = cmds or module.commands
	local out = {help}
	for i,v in pairs(cmds) do
		out[#out+1] = (' %s | %s'):format(v[1],v[2])
	end
	return table.concat(out,'\n')
end

local recents = {}
local list, cached_list, exelist, paths, runable = {}, {}, {}, {},false
if not cache then
	local desktop_file_dirs = {
		os.getenv('HOME').."/.local/share/applications",
		'/usr/share/applications'
	}
	do
		for path in os.getenv('PATH'):gmatch('[^:]+') do
			paths[#paths+1]=path
		end
		paths[#paths+1]=os.getenv('HOME').."/.local/bin"
	end

	do
		local proc = io.popen('find '..table.concat(desktop_file_dirs,' '),'r')
		local desktop_files = proc:read('*a')
		proc:close()
		for path in desktop_files:gmatch('[^\n]+') do
			local file = io.open(path,'r')
			if file then
				local content = file:read('*a')
				file:close()
				cached_list[#cached_list+1] = {
					content and (content:match('Name=([^\n]+)') or content:match('Name%[EN%]=([^\n]+)')) or path:match('.+/([^%./]+)'),
					path
				}
			end
		end
	end
	table.sort(list,function(a,b) return #a[1] > #b[1] end)
	table.sort(cached_list,function(a,b) return #a[1] > #b[1] end)
	do
		local proc = io.popen('flatpak list --app | cat','r')
		local flatpak_list = proc:read('*a')
		proc:close()
		local name_template,cmd_template = "%s (Flatpak)","flatpak run %s"
		for info in flatpak_list:gmatch('[^\n]+') do
			local name,cmd = info:match('([^\t]+)\t([^\t]+)')
			name,cmd = name_template:format(name),cmd_template:format(cmd)
			cached_list[#cached_list+1] = {name,cmd}
		end
	end
	cache = io.open('/tmp/APPMENU_CACHE.lua','w')
	cache:write(('return %s,%s,%s,%s'):format(table.tostring(list), table.tostring(cached_list), table.tostring(exelist), table.tostring(paths)))
	cache:close()
else
	list, cached_list, exelist, paths = load(cache:read('*a'))()
	cache:close()
end





function updateInput(input)
	module.runable = false
	local executables=true
	if not input or #input == 0 or input == " " then return set_text() end
	local list_to_search = cached_list
	for i,cmd in pairs(module.commands) do
		if((cmd.starts_with and input:sub(1,#cmd.starts_with) ==cmd.starts_with) or cmd.match and input:find(cmd.match)) then
			executables=false
			if(cmd.get_list) then
				input,list_to_search = cmd:get_list(input)
				break;
			elseif cmd.update_text then
				return cmd:update_text(input)
			else
				break;
			end
		elseif(cmd.check) then
			local ret = cmd:check(input)
			if ret then return ret end
		end
	end
	while #list > 0 do list[#list]=nil end
	local index = 1
	local OLD = input
	if(input:find(' (%d+)$')) then
		input,index = input:match('^(.+) (%d+)$')
		index = tonumber(index) or 1
		input = input:lower():gsub('%s+$','')
		if not input then input = OLD end
	end
	input = input:gsub(' $','')
	if #input == 0 or input == " " then return set_text() end
	local search_raw,search,search_simple = input, input:gsub('.',function(a) 
		return a:upper() == a:lower() and (a..".-") 
			or ('[%s%s].-'):format(a:upper(),a:lower()) 
	end),input:lower():gsub('.','%1.-')
	local runables = {}
	local exec = input:match('[^ ]+')
	if(executables) then
		for _,v in ipairs(paths) do
			v = v..'/'..exec
			local file = io.open(v,'r')
			if(file) then
				local id = #list+1
				local TEXT = "* <b></b><b>"..v:gsub('<>','\\%1')..'</b> (Executable)'
				list[id] = TEXT
				runables[TEXT] = v .. input:sub(#exec+1)
				-- break
				file:close()
			end
		end
	end
	exec = exec:lower()
	local xml = --[[ gears.string.xml_escape or--]]  function(...) return ... end
	for _,v in ipairs(list_to_search) do
		-- list[#list+1] = ('%s = %s'):format(tostring(i),tostring(v))
		i = v[1]
		local s = i:lower():find(search_simple)
		-- local foundExec = false
		-- if not s and type(v[2]) == "string" then
		-- 	local s = v[2]:lower():find(search)

		-- 	foundExec = true
		-- end
		if(s) then
			local result = xml(i):gsub(search,"<i><b>%1</b></i>")
			-- local rs,re=i:lower():find(search_raw) 
			-- if rs then s,e = rs,re end
			local id = #list+1
			-- local xml_i = i
			local TEXT = ('* %s'):format(result)
			list[id] = TEXT
			runables[TEXT] = v
			-- if(id > 14) then 
			-- 	break
			-- end
		end
	end
	if #list > 0 then
		local fullWord,wordparts = {},{}
		local sraw = search_raw:lower()
		for i,v in pairs(list) do
			if(v:lower():find(sraw)) then
				fullWord[#fullWord+1] = v
			else
				wordparts[#wordparts+1] = v

			end
		end
		local list = {}
		table.sort(fullWord,function(a,b)
			return a:find("</b>") < b:find("</b>")
		end) 
		table.sort(wordparts,function(a,b)
			return a:find("</b>") < b:find("</b>")
		end) 
		for i,v in ipairs(fullWord) do list[#list+1] = v end
		for i,v in ipairs(wordparts) do list[#list+1] = v end
		-- table.sort(list,function(a,b)
		-- 	local a_start,a_end = a:find('<b>(.-)</b>')
		-- 	if not a_start then a_start = 10000 end
		-- 	if not a_end then a_end = 100000 end
		-- 	-- local a_diff = a_end-a_start

		-- 	local b_start,b_end = b:find('<b>(.-)</b>')
		-- 	if not b_start then b_start = 10000 end
		-- 	if not b_end then b_end = 100000 end
		-- 	-- local b_diff = b_end-b_start
		-- 	return b_end > a_end
		-- end)
		if(list[index]) then
			local runable = runables[list[index] or ""]
			module.runable = runable
			list[index] = ('<span underline="single">%s - (%s)</span>'):format(list[index]:gsub('(.-)%* ','%1> '),tostring(type(runable) == "string" and runable or runable[2]))
		end

		local list,oldList = {},list
		local halfCount = 9 
		for i,v in ipairs(oldList) do
			if(math.abs(math.max(index,halfCount)-i) < halfCount) then 
				list[#list+1] = ('<span font_size="small">%3i</span> %s'):format(i,v)
			end
		end
		-- if(#list > 9) then
		-- 	list[#list+1]="..."
		-- end
		if not module.runable then
			table.insert(list,1,'<span color="#F00"><b><i>NO ITEM SELECTED!</i></b></span>')
		end
		set_text(table.concat(list, "\n"))
		return
	end
	module.runable = 'xdg-open ' .. input
	set_text('Nothing found out of '..#cached_list..'\nRun ' .. module.runable)


end


local runLua = function(input)
	local out = "nil"
	local succ,err = pcall(function()
		if(not input:find('return')) then input = 'return ' .. input end
		local chunk,err = load(input)
		if err then return err end
		return chunk()
	end)
	set_text(tostring(err))
end
module.commands = {
	{"' '","Normal search", starts_with=" ",
	},
	{"$, $$, $>","Run shell command, Run shell command and return output here, Run shell command and send notification containing content",
		starts_with="$",
		match = nil,
		check = nil,
		update_text=function(self,input)
			return set_text("Run command" .. (input:sub(2,2) == '$' and " and return output here" or input:sub(2,2) == '>' and " and send a notification" or ""))
		end,
		runable=function(self,input)
			input = input:sub(2)
			if(input:sub(1,1) == '$') then
				input = input:sub(2)
				module.app_menu.visible = true
				awful.spawn.easy_async_with_shell(input,function(output)
					set_text(output)
					show_prompt()
				end)
			elseif(input:sub(1,1) == '/' or input:sub(1,1) == '~') then
				module.app_menu.visible = true
				awful.spawn.with_shell(('clifm --open=%q'):format(input))
			elseif(input:sub(1,1) == '$>') then
				input = input:sub(2)
				module.app_menu.visible = true
				awful.spawn(input ..' | notify-send')
			else
				awful.spawn(input)
			end
		end
	},
	{"t ","Run shell command in terminal",
		starts_with="t ",
		match = nil,
		check = nil,
		update_text=function(self,input)
			return set_text(("Run command %q in terminal"):format(input:sub(3)))
		end,
		runable=function(self,input)
			input = input:sub(3)
			awful.spawn(('foot bash -c %q'):format(input..';read'))
			
		end
	},
	{"/, ~","Directory search", match="^[~/]",
		update_text=function(self,input)
			local f = io.open(input:match('^"(.-)"') or input:match('[^ ]+'),'r')
			if(f) then
				f:close()
				set_text('Run '..input)
			else
				set_text(('(Invalid file or directory!) Run %s'):format(input))
			end
			module.runable = input
			return
		end
	},
	{"^","Run lua code", starts_with="^",
		update_text=function(self,input)
			runLua(input:sub(2))
			return
		end
	},
	{"[0-9+%-^%/*&><]","Calculator/Lua code", match="^[0-9+%-^%/*&><]+$",
		update_text=function(self,input)
			runLua(input)
			return
		end
	},
	{"m","Menu",starts_with="m ",
		get_list=function(self,input)

			local list= {}
			local recurse
			recurse = function(l,str)
				for i,v in pairs(l) do
					if(type(v) == "table") then
						if(type(v[2]) == "table") then
							recurse(v[2],str..v[1]:lower()..'>')
						else
							list[#list+1] = {'m '..str..v[1]:lower(),v[2]}
						end
					end
				end
			end

			recurse(old_menu,"")
			return input,list
		end
	},
	{"cl","CLear menu cache",starts_with="cl ",
		update_text=function(self,input)
			return set_text('Remove /tmp/APPMENU_CACHE.lua to clear appmenu cache')
		end,
		runable=function(self,input)
			
			os.execute('rm /tmp/APPMENU_CACHE.lua')
		end
	},
	-- {"wm","Window selection + move to screen",starts_with="ws ",
	-- 	get_list=function(self,input)
	-- 		local list= {}
	-- 		for _,curClient in ipairs(client.get()) do
	-- 			list[#list+1] = {'wm '..(curClient.name or curClient.class),function() curClient:jump_to();curClient:moveToScreen(mouse.screen) end}
	-- 		end
	-- 		return input,list
	-- 	end
	-- },
	-- {"wc","Window selection + close",starts_with="wc ",
	-- 	get_list=function(self,input)
	-- 		local list= {}
	-- 		for _,curClient in ipairs(client.get()) do
	-- 			list[#list+1] = {'wm '..(curClient.name or curClient.class),function() curClient:close() end}
	-- 		end
	-- 		return input,list
	-- 	end
	-- },

	{"w","(CWC ONLY) (W)indow selection + (C)lose, (M)ove to screen",
		match="^w%w? ",
		funcs = {
			w=function(_,self) os.execute(('cwctl -c "cwc.client.get()[%i]:jump_to()"'):format(self.client_id)) end,
			wm=function(_,self) self.client:jump_to() end,
			wc=function(_,self) os.execute(('cwctl -c "local c = cwc.client.get()[%i];c:focus();c:move_to_screen()"'):format(self.client_id)) end,
		},
		get_list=function(self,input)
			local list = {}

			local f = input:sub(1,2):gsub(' $',''):lower()
			local func = self.funcs[f] or self.funcs.w
			if(os.getenv('XDG_CURRENT_DESKTOP') == "cwc") then
				local e = io.popen(('cwctl -c %q'):format([[local str = {};for i,v in pairs(cwc.client.get()) do str[#str+1] = v.name and ('%s - %s'):format(v.name,v.appid) or v.appid end;return table.concat(str,'\n')]]),'r')
				local content = e:read('*a')
				e:close()
				local i = 0
				for clientName in content:gmatch('[^\n]+') do
					i = i + 1
					list[i] = {f.. ' ' .. clientName,func,client_id = i}
				end
			end
			-- local list= {}
			-- for _,cur_client in ipairs(client.get()) do
			-- 	list[#list+1] = {f..' '..(cur_client.name or cur_client.class),func,client=cur_client}
			-- end
			return input,list
		end
	},
	{"d","duckduckgo search",starts_with="d ",
		runable=function(s,input)

			awful.spawn(('xdg-open %q'):format('https://duckduckgo.com/'..input:sub(3):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end)))
		end,
		update_text=function(self,input)
			set_text('Search duckduckgo for ' .. input:sub(2),true)
			return
		end
	},

}





-- Actual display and stuff
local winInfo = {title="FUNNI LUA APPLICATION MENU",borderless=false,width=1000,height=300}
win = am.window(winInfo)
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
	updateInput(buffer)
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

	TEXT.text = buffer .. '\n' .. output
end)

set_text = function(txt,plain)
	if(txt == nil) then txt = generate_help();plain = false end
	txt = tostring(txt)
	local lp = tostring(lastPressed)
	local sep = ('-'):rep(math.floor(16-((#lp)*.5)))
	lp =  sep..lp..sep
	output = (lp.. "\n"..txt):gsub('<.->','')
	-- if plain then
	-- 	textbox.text = lp.. "\n"..txt
	-- else
	-- 	local out = lp.."\n"..txt
	-- 	-- textbox.markup = out
	-- 	local succ,err = textbox:set_markup_silently(out)
	-- 	if not succ then
	-- 		textbox.text = lp.. "\n"..txt.."\nERR:"..tostring(err)
	-- 	end
	-- end
end
function finish(input)
	if not input or #input == 0 then return end
	-- naughty.notify({
	-- 	preset = naughty.config.presets.normal,
	-- 	title = 'Input was ' .. input
	-- })
	local runable=module.runable
	for i,cmd in pairs(module.commands) do
		if((cmd.starts_with and input:sub(1,#cmd.starts_with) ==cmd.starts_with) or cmd.match and input:find(cmd.match)) then
			executables=false
			if(cmd.runable) then
				return cmd:runable(input)
			end
		end
	end
	print(type(runable))
	if(runable) then
		local _runable
		if(type(runable) == "table") then -- TODO ADD RECENTS
			if(type(runable.exec) == "function") then
				return runable:exec(input)
			end
			_runable=runable
			runable = runable[2]
			-- if(type(runable) == "string") then
			-- 	for i,v in pairs(recents) do

			-- 	end

			-- end
		end
		if(type(runable) == "string") then
			if(runable:sub(-8)==".desktop") then runable = ('exo-open %q'):format(runable) end
			print('Running '..runable)
			awful.spawn(runable)
		elseif(type(runable) == "function") then
			runable(input,_runable)
		else
			print('Attempt to run '..type(runable) .. "(expected string,function)")
		end
		return
	end
end

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
		finish(buffer)
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
updateInput(buffer)
TEXT.text = buffer .. '\n' .. output

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
