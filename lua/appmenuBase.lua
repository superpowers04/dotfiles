#!/bin/lua
-- Originally by Superpowers04
-- This script is not designed to be run alone. Infact all it'll do is generate it's cache
-- If you want to pass a custom menu:
--  Replace MODULE.finish(input) to do whatever
--  Set _G.appmenuList to a table consisting of `{"NAME",EXTRA_VALUES}`

-- Please note, this script was not originally designed to be public so it's a bit of a mess



local module = {
	output = "",
	text_buffer = "",
	queued_cursor_pos = nil,
}

-- Allows module to be accessed from anywhere. Remove this if you don't want that
_G.AppMenu = module

-- If true, a small text including the .desktop's generic name will be shown
module.include_generic_name = true


-- Values to be changed by frontend, to handle support for certain features

-- This handles communication between appmenuBase and the frontend for keeping track of what the current input text is. 
--  Use this as a place to store text from user input as much as possible
module.text_buffer = ""

-- Disables certain markup and output will be filtered to remove any markup that has been generated. 
--  In the future, this should just prevent markup from being generated at all
module.allow_markup = false

-- Script will just return the input when module.finish is called and some other things will be disabled
module.dmenu_mode = false 

-- Function that gets called for any executables
function module.spawn(cmd)
	os.execute(cmd .. " &")
end
-- Gets called after set_text, can be used if you need to manually set a label or something
function module.apply_text(input)
	-- STUB
end
-- Gets called whenever the text cursor should be moved
function module.move_cursor(pos)
	-- STUB
end






local MenuFolder = os.getenv('HOME')..'/.config/SupersAppMenu/'
local cacheFile = '/tmp/'..os.getenv('USER')..'-APPMENU_CACHE.lua'


local function exec(cmd)
	local f = io.popen(cmd,'r')
	local c = f:read('*a')
	f:close()
	return c
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


local TERMINAL = "xfce4-terminal -e %q"

-- foot bash -c

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
		out[#out+1] = (' %s | %s'):format(module.xml_escape(v[1]),v[2])
	end
	return table.concat(out,'\n')
end

local recents = {}
local list, cached_list, exelist, paths, runable = {}, {}, {}, {""},false

if(appmenuList) then
	cached_list = appmenuList
	module.dmenu_mode = true
else
	local cache = io.open(cacheFile,'r')
	if(cache) then
		local succ,err = pcall(function()
			local chunk,err = load(cache:read('*a'))
			if not chunk then error(err) end
			local tbl = chunk()
			list, cached_list, exelist, paths = tbl.list,tbl.cached_list,tbl.exelist,tbl.paths
			cache:close()
		end)
		if not succ or not list or not paths then print('Error while trying to load cached list',err or "list not found", " - Regenerating config") end
	end
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
					local elm = {
						nil,
						path
					}
					if content then 
						elm[1] =(content:match('Name=([^\n]+)') or content:match('Name%[EN%]=([^\n]+)'))
						local genericName = content:match('GenericName%[EN%]=([^\n]+)') or content:match('GenericName=([^\n]+)')
						if genericName then
							if(not elm[1]) then
								elm[1] = genericName
							else
								elm.gn = genericName

							end
						end
						local description = content:match('Comment=([^\n]+)') or content:match('Description=([^\n]+)')
						if description then
							elm[elm[1] and "desc" or 1] = description
						end
					end
					if(not elm[1]) then elm[1] = path:match('.+/([^%./]+)') or path end
					cached_list[#cached_list+1] = elm
				end
			end
		end
		table.sort(list,function(a,b) return #a[1] > #b[1] end)
		table.sort(cached_list,function(a,b) print(a[1],b[1]) return #a[1] > #b[1] end)
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
		local _tostring
		function _tostring(tbl)
			local tblType = type(tbl)
			if(tblType ~= "table" ) then
				if(tblType == "string") then
					return ('%q'):format(tbl)
				elseif tblType == "number" then
					return tostring(tbl)
				elseif tblType == "boolean" then
					return tbl and "true" or "false"
				end

				return nil
			end
			local str = {}
			local tblLength = #tbl
			for i,v in pairs(tbl) do
				local ti = type(i)
				if(ti == "number" and i <= tblLength) then
					v = _tostring(v)
					if v then
						str[#str+1] = v
					end
				else
					i = _tostring(i)
					if i then
						v = _tostring(v)
						if v then
							str[#str+1] = ('[%s]=%s'):format(i,v)
						end
					end
				end
			end
			return '{'..table.concat(str,',')..'}'
		end
		cache = io.open(cacheFile,'w')
		cache:write(('return %s'):format(_tostring({
			list = list,
			cached_list = cached_list,
			exelist = exelist,
			paths = paths
		})))
		cache:close()
	end
end



local xml_entity_names = { ["'"] = "&apos;", ["\""] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" };
function module.xml_escape(text) -- Totally not stolen from awesome
    return text and text:gsub("['&<>\"]", xml_entity_names) or nil
end
function module.highlight_match(...)
	local tbl = {...}
	if(module.allow_markup) then
		local l = 0
		while l < #tbl do
			l = l + 1
			local bef,cur,next = tbl[l-1],tbl[l],tbl[l+1]
			if(cur == nil or next == nil) then break end
			if(cur == "") then
				table.remove(tbl,l)
				table.remove(tbl,l)
				l = l-1
				tbl[l] = bef..next
			end
		end
		for i,v in pairs(tbl) do
			if(i % 2 == 1) then
				tbl[i] = '<b>'..tbl[i]..'</b>'
			end
		end
	end
	return table.concat(tbl)
end

function module.updateInput(input)
	module.runable = false
	module.text_buffer = input
	local executables=true
	local list_to_search = cached_list
	if(not module.dmenu_mode) then
		if not input or #input == 0 or input == " " then return module.set_text() end
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
	end
	while #list > 0 do list[#list]=nil end
	local index = 1
	local sort = true
	local include_desc = false
	local include_gen_name = module.include_generic_name
	if(input:sub(1,1) == "?") then
		input = input:sub(2)
		include_desc = true
	end
	local OLD = input
	if(input:find(' (%d+)$')) then
		input,index = input:match('^(.+) (%d+)$')
		index = tonumber(index) or 1
		input = input:lower():gsub('%s+$','') or OLD
	end
	input = input:gsub(' $',''):gsub('^ ','')
	if #input == 0 or input == " " then return module.set_text() end

	local search_raw,search,search_simple = input, input:gsub('.',
		function(a) 
			return a:upper() == a:lower() and ('('..a..")(.-)") 
				or ('([%s%s])(.-)'):format(a:upper(),a:lower()) 
		end),input:lower():gsub('.','%1.-')
	local runables = {}
	local exec = input:match('[^ ]+') or input:match('^"([^"]+)') or input:match('^\'([^\']+)')
	if(executables) then
		for _,path in ipairs(paths) do
			path = path..'/'..exec
			local file = io.open(path,'r')
			if(file) then
				file:close()
				local TEXT = "* <b></b><b>"..path:gsub('<>','\\%1')..'</b> (Executable)'
				list[#list+1] = TEXT
				runables[TEXT] = path .. input:sub(#exec+1)
				local extra = input:sub(#exec)
				local path = extra:match(' (/[^ ]+)$') or extra:match(' "([^ ][^"]+)$')
				if(path) then
					sort = false
					for result in executeCmd(('find %q -maxdepth 1 -mindepth 1'):format(path:match('.+/'))):gmatch('[^\n]+') do
						if(result:sub(0,#path) == path) then
							local end_path = input..result:sub(#path+1)
							local TEXT = "* <b></b><b>"..end_path..'</b>'
							list[#list+1] = TEXT
							runables[TEXT] = end_path
						end
					end
				end
			end
		end
	end
	exec = exec:lower()
	local xml = module.allow_markup and module.xml_escape or function(...) return ... end
	for i,v in ipairs(list_to_search) do
		-- i = v[1]
		local endingString = {'*'}
		local matched_name,matched_generic_name, matched_description
		matched_name = v[1]:lower():find(search_simple)
		endingString[#endingString+1] = matched_name and xml(v[1]):gsub(search,module.highlight_match) or xml(v[1])
		if(v.gn and include_gen_name) then

			matched_generic_name = v.gn:lower():find(search_simple)
			endingString[#endingString+1] = '<small>/'..(matched_generic_name and xml(v.gn):gsub(search,module.highlight_match) or xml(v.gn)).."</small>"
		end
		if(v.desc) then
			matched_description = include_desc and v.desc:lower():find(search_simple)
			endingString[#endingString+1] = ' <span size="small"> ('..(matched_description and xml(v.desc):gsub(search,module.highlight_match) or xml(v.desc)) ..')</span>'
		end

		if(matched_name or matched_description) then
			local result = table.concat(endingString,'')
			list[#list+1] = result
			runables[result] = v
		end


		-- if(s) then
		-- 	local result = '*'..xml(i):gsub(search,function(...)
		-- 		local tbl = {...}
		-- 		for i,v in pairs(tbl) do
		-- 			if(i % 2 == 1) then
		-- 				tbl[i] = '<i><b>'..tbl[i]..'</b></i>'
		-- 			end
		-- 		end
		-- 		return table.concat(tbl)
		-- 	end)
		-- end
	end
	if #list > 0 then
		local fullWord,wordparts = {},{}
		local sraw = search_raw:lower()
		if(sort) then
			for i,v in pairs(list) do
				if(v:lower():find(sraw)) then
					fullWord[#fullWord+1] = v
				else
					wordparts[#wordparts+1] = v
				end
			end
			local list = {}
			-- TODO FIX SORTING, SORTING SHOULD BE BY LENGTH OF MATCHED CHARACTERS, NOT THE FIRST </b> TAG
			table.sort(fullWord,function(a,b)
				return a:find("</b>") < b:find("</b>")
			end) 
			table.sort(wordparts,function(a,b)
				return a:find("</b>") < b:find("</b>")
			end) 
			for i,v in ipairs(fullWord) do list[#list+1] = v end
			for i,v in ipairs(wordparts) do list[#list+1] = v end
		end
		if(list[index]) then
			local runable = runables[list[index] or ""]
			module.runable = runable
			list[index] = ('<span underline="single">%s</span>\n<span size="small">\t(%s)</span>'):format(list[index]:gsub('(.-)%* ','%1> '),tostring(type(runable) == "string" and runable or runable[2]))
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
		module.set_text(table.concat(list, "\n"))
		return
	end
	module.runable = 'xdg-open ' .. input
	module.set_text('Nothing found out of '..#cached_list..'\nRun ' .. module.runable)


end


local runLua = function(input)
	local out = "nil"
	local succ,err = pcall(function()
		if(not input:find('return')) then input = 'return ' .. input end
		local chunk,err = load(input)
		if err then return err end
		return chunk()
	end)
	module.set_text(tostring(err))
end
module.commands = {
	{"' '","Normal search", starts_with=" ",
	},
	{"?","Search by description AND title",
		starts_with="?",
	},
	{"$, $$, $>","Run shell command, Run shell command and return output here, Run shell command and send notification containing content",
		starts_with="$",
		match = nil,
		check = nil,
		update_text=function(self,input)
			return module.set_text("Run command" .. (input:sub(2,2) == '$' and " and return output here" or input:sub(2,2) == '>' and " and send a notification" or ""))
		end,
		runable=function(self,input)
			input = input:sub(2)
			if(input:sub(1,1) == '$') then
				input = input:sub(2)
				module.app_menu.visible = true
				module.spawn.easy_async_with_shell(input,function(output)
					module.set_text(output)
					show_prompt()
				end)
			-- elseif(input:sub(1,1) == '/' or input:sub(1,1) == '~') then
			-- 	module.app_menu.visible = true
			-- 	module.spawn.with_shell(('clifm --open=%q'):format(input))
			-- elseif(input:sub(1,1) == '$>') then
			-- 	input = input:sub(2)
			-- 	-- module.app_menu.visible = true
			-- 	module.spawn(input ..' | notify-send')
			else
				module.spawn(input)
			end
		end
	},
	{"t,tb,t_","Run shell command in terminal, Include underscore to keep terminal open after command, b to run in $SHELL",
		-- starts_with="t ",
		match = "^tb?_? ",
		check = nil,
		update_text=function(self,input)
			return module.set_text(("Run command %q in terminal"):format(input:gsub('^t.- ','')))
		end,
		runable=function(self,input)
			local use_shell,use_read = false,false
			input = input:gsub("^t.- ",function(cmd)
				if(cmd:find('_')) then use_read = true;use_shell = true end
				if(cmd:find('b')) then use_shell = true end

				return ""
			end)
			if(not input or input == "") then input='bash' end 
			if(use_read) then
				cmd = cmd..';read'
			end
			if(use_shell) then
				cmd = ('%s -c %q'):format(os.getenv('SHELL'),cmd)
			end
			module.spawn((TERMINAL):format(input))
			
		end
	},
	-- {"/, ~","Directory search", match="^[~/]",
	-- 	get_list=function(self,input)
	-- 		-- local f = io.open(input:match('^"(.-)"') or input:match('[^ ]+'),'r')
	-- 		local list = {}
	-- 		for result in executeCmd(('find %q -maxdepth 1 -mindepth 1'):format(input)):gmatch('[^\n]+') do
	-- 			if(result:sub(0,#path) == path) then
	-- 				local TEXT = "* <b></b><b>"..result..'</b>'
	-- 				list[#list+1] = {TEXT,result}
	-- 			end
	-- 		end
	-- 		-- if(f) then
	-- 		-- 	f:close()
	-- 		-- 	module.set_text('Run '..input)
	-- 		-- else
	-- 		-- 	module.set_text(('(Invalid file or directory!) Run %s'):format(input))
	-- 		-- end
	-- 		-- module.runable = input
	-- 		return input,list
	-- 	end
	-- },
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
	{"cl","CLear menu cache",match="^cl$",
		update_text=function(self,input)
			return module.set_text('Remove '..cacheFile..' to clear appmenu cache')
		end,
		runable=function(self,input)
			os.execute('rm '..cacheFile)
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

	{"d","duckduckgo search",starts_with="d ",
		runable=function(s,input)

			module.spawn(('xdg-open %q'):format('https://duckduckgo.com/'..input:sub(3):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end)))
		end,
		update_text=function(self,input)
			module.set_text('Search duckduckgo for ' .. input:sub(2),true)
			return
		end
	},

}

module.key_functions = {
	tab = function()
		if(tostring(module.runable[2]):find('%.desktop$')) then
			local file = io.open(tostring(module.runable[2]),'r')
			local content = file:read('*a')
			file:close()
			local newBuffer = content:match('Exec=([^\n]+)')
			if newBuffer then
				module.text_buffer = newBuffer:gsub('%%.',''):gsub('^%s+',''):gsub('%s+$','')
			end
			module.queued_text_pos = (#module.text_buffer)
			return true
		elseif(module.runable.tab) then
			module.text_buffer = module.runable.tab
			module.queued_text_pos = (#module.text_buffer)
			return true
		elseif(type(module.runable) == "string") then
			module.text_buffer = module.runable
			module.queued_text_pos = (#module.text_buffer)
			return true

		end
	end,
	up =function()
		local buffer,id = module.text_buffer
		buffer,id = buffer:match('(.+) (%d+)$')
		if buffer and id then
			id = tonumber(id) or 1
			id = id + 1
		else
			buffer, id = module.text_buffer,tonumber(id or 1)
		end
		module.text_buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
		module.queued_text_pos = (#buffer)
		return true
	end,
	down = function()
		local buffer,id = module.text_buffer
		buffer,id = buffer:match('(.+) (%d+)$')
		if buffer and id then
			id = tonumber(id) or 1
			id = id - 1
			if(id < 1) then id = 1 end
		else
			buffer, id = module.text_buffer,tonumber(id or 1)
		end
		module.text_buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
		module.queued_text_pos = (#buffer)
		return true
	end,
}


module.handle_input = function(buffer,key,modifiers)
	if(module.keyFunctions[key]) then
		return module.keyFunctions[key](buffer,key,modifiers)
	end
	return buffer
end
module._update_cursor_pos = function()
	if(module.queued_text_pos) then
		module.move_cursor(module.queued_text_pos)
		module.queued_text_pos=nil
	end
end
module.set_text = function(txt,plain)
	if(txt == nil) then txt = generate_help();plain = false end
	txt = tostring(txt)
	local lp = tostring(lastPressed)
	local sep = ('-'):rep(math.floor(16-((#lp)*.5)))
	lp =  sep..lp..sep

	if module.allow_markup then
		module.output = (lp.. "\n"..txt):gsub('&.-;',function(a) return a:gsub('<.->','') end)
		module.apply_text(module.output)
		module._update_cursor_pos()
		return
	end
	module.output = (lp.. "\n"..txt):gsub('<.->','')
	module.apply_text(module.output)
	module._update_cursor_pos()
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
function module.finish(input)
	if not input or #input == 0 then return end
	if(module.dmenu_mode) then
		return input
	end
	-- naughty.notify({
	-- 	preset = naughty.config.presets.normal,
	-- 	title = 'Input was ' .. input
	-- })
	local runable=module.runable
	print(runable)
	for i,cmd in pairs(module.commands) do
		if((cmd.starts_with and input:sub(1,#cmd.starts_with) ==cmd.starts_with) or cmd.match and input:find(cmd.match)) then
			executables=false
			if(cmd.runable) then
				return cmd:runable(input)
			end
		end
	end
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
			module.spawn(runable)
		elseif(type(runable) == "function") then
			runable(input,_runable)
		else
			print('Attempt to run '..type(runable) .. "(expected string,function)")
		end
		return
	end
end
local current_desktop = (os.getenv('XDG-DESKTOP') or ""):lower()

if(current_desktop == "cwc") then

	module.commands[#module.commands+1]={"w","(CWC ONLY) (W)indow selection + (C)lose, (M)ove to screen",
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
	}
end




local extension = io.open(MenuFolder..'/extensions.lua')
if extension then 
	local succ,err = pcall(function()
		load(menu_contents:read('*a'))()
	end)
	menu_contents:close()
end

return module