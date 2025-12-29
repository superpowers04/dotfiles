#!/bin/lua
-- Originally by Superpowers04
-- This script is not designed to be run alone. Infact all it'll do is generate it's cache
-- If you want to pass a custom menu:
--  Replace MODULE.finish(input) to do whatever
--  Set _G.appmenuList to a table consisting of `{"NAME",EXTRA_VALUES}`

-- Please note, this script was not originally designed to be public so it's a bit of a mess


-- TODO ADD MARKUP AFTER INSTEAD OF DURING
-- TODO HISTORY
-- TODO FAVS

local module = {
	output = "",
	text_buffer = "",
	queued_cursor_pos = nil,
	args = {}
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

-- Allow history
module.enable_history = true
-- Command to use for terminal
module.terminal = "xfce4-terminal -e %q"
-- Command to use by default
module.def_command = "rifle %q"

module.locked_char_width = 300

-- Function that gets called for any executables
function module.spawn(cmd)
	os.execute(cmd .. " &")
end
-- Function that gets called when something is run in a terminal
function module.run_in_terminal(cmd)
	module.spawn((module.terminal):format(cmd))
end
-- Gets called after set_text, can be used if you need to manually set a label or something
function module.apply_text(input)
	-- STUB
end
-- Gets called whenever the text cursor should be moved
function module.move_cursor(pos)
	-- STUB
end
-- Function that runs whenever it tries to exit
function module.exit(...)
	os.exit(...)
end

module.on_error = error

module.MenuFolder = os.getenv('HOME')..'/.config/SupersAppMenu/'
module.HistoryFile = module.MenuFolder..'history.lua' 
module.cacheFile = '/tmp/APPMENU_CACHE-'..os.getenv('USER')..'.lua'


local function exec(cmd)
	local f = io.popen(cmd,'r')
	local c = f:read('*a')
	f:close()
	return c
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
executeCmd = function(a)
	local e = io.popen(a,'r')
	local r = e:read('*a')
	e:close()
	if(r:sub(-1) == "\n") then r=r:sub(0,-2) end
	return r
end
module.top_text = ""
module.bottom_text = ""
local pack,unpack = pack or table.pack, unpack or table.unpack

local help = [[Usage:
 (NAME)[ (ID)]
Shortcuts:]]

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
local list, cached_list, exelist, paths, runable, custom_list = {}, {}, {}, {""}, false, {}
local home_dir = os.getenv('HOME')
if(appmenuList) then
	cached_list = appmenuList
	if not module.dmenu_mode then module.dmenu_mode = true end
else
	local cache = io.open(module.cacheFile,'r')
	if(cache) then
		local succ,err = pcall(function()
			local chunk,err = load(cache:read('*a'))
			if not chunk then error(err) end
			local tbl = chunk()
			cached_list, exelist, paths = tbl.cached_list,tbl.exelist,tbl.paths
			cache:close()
		end)
		if not succ or not list or not paths then print('Error while trying to load cached list',err or "list not found", " - Regenerating config") end
	else
		local desktop_file_dirs = {
			home_dir.."/.local/share/applications",
			'/usr/share/applications'
		}
		do
			local path_cache = {}
			for path in os.getenv('PATH'):gmatch('[^:]+') do
				path = exec(('file %q'):format(path)):match('link to (.+)') or path
				if not path_cache[path] then
					paths[#paths+1]=path
					path_cache[path] = true
				end
			end
			do
				local f = home_dir.."/.local/bin"
				if not path_cache[f] then
					paths[#paths+1]=f
				end
			end
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
		local custom_list_file = io.open(module.MenuFolder..'/custom_list.lua')
		if(custom_list_file) then
			local succ,err = pcall(function()
				local chunk,err = load(custom_list_file:read('*a'))
				if not chunk then error(err) end
				for i,v in pairs(chunk()) do
					table.insert(cached_list,1,v)
				end
				custom_list_file:close()
			end)
			if not succ then print('Error while trying to load custom list',err or "custom list") end
		end
		-- table.sort(list,function(a,b) return #a[1] > #b[1] end)
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
		cache = io.open(module.cacheFile,'w')
		cache:write(('return %s'):format(_tostring({
			-- list = list,
			cached_list = cached_list,
			exelist = exelist,
			paths = paths
		})))
		cache:close()
	end
end



-- Totally not stolen from awesome
local xml_entity_names = { ["'"] = "&apos;", ["\""] = "&quot;", ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" };
function module.xml_escape(text) 
    return text and text:gsub("['&<>\"]", xml_entity_names) or nil
end
function module.getBackend()
	return os.getenv('WAYLAND_DISPLAY') and "WAYLAND" or os.getenv('DISPLAY') and "X11" or "TTY"
end
function module.get_history(runable)
	
end
function module.updateHistory(runable)
	local succ,err = pcall(function()
		local file = io.open(module.HistoryFile,'r')
		local history = {}
		if file then
			history = load(file:read('*a'))
			file:close()
		end
		local found_match = false
		for i,hist_run in ipairs(history) do
			if(hist_run[1] == runable[1] or hist_run.tab == runable.tab) then
				hist_run.uses = hist_run.uses+1
				found_match = true
			end
		end
		if not found_match then
			runable.uses=1
			history[#history+1] = runable
		end


		local file = io.open(module.HistoryFile,'w')
		
		file:write('return '.._tostring(history))
		-- _tostring(tbl)
	end)
	if not succ then print(err) end
end
function module.getClipboard()
	local backend = module.getBackend()
	if(backend == "WAYLAND") then
		return executeCmd('wl-paste -t TEXT')
	elseif(backend == "X11") then 
		return executeCmd('xclip -o')
	else
		return ""

	end
end
help = ('Detected as %s - %s'):format(module.getBackend(),help)
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
	module.top_text = ""
	module.bottom_text = ""
	local buffer = input
	local executables=not module.dmenu_mode
	local list_to_search = cached_list
	if(executables) then
		if not input or #input == 0 or input == " " then return module.set_text() end
		for i,cmd in pairs(module.commands) do
			if((cmd.starts_with and input:sub(1,#cmd.starts_with) ==cmd.starts_with) or cmd.match and input:find(cmd.match)) then
				executables=false
				if(cmd.top_text) then
					module.top_text = module.top_text..cmd.top_text
				end
				if(cmd.bottom_text) then
					module.bottom_text = module.bottom_text..cmd.bottom_text
				end
				module.set_text(('%s - %s'):format(cmd[1],cmd[2]))
				if(cmd.get_list) then
					if(cmd.top_text) then
						module.top_text = cmd.top_text
					end
					input,list_to_search = cmd:get_list(input)
					break;
				elseif cmd.update_text then
					if cmd.runable then module.runable = cmd.runable end
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
		index,input = (tonumber(index) or 1), input:lower():gsub('%s+$','') or OLD
	end
	if #input == 0 or input == " " then return module.set_text() end
	input = input:gsub(' $',''):gsub('^ ','')
	local search,search_simple 
	do
		local stop_filter = false
		local skipNext = false
		search = input:gsub('.', function(a) 
			if --[[ not skipNext and--]]  (a=="'" or a=='"') --[[ and (not stop_filter or stop_filter == a)--]]  then
				stop_filter = stop_filter ~= a and a
				return ''
			end
			-- skipNext = a=="\\"
			-- if(skipNext) then return "" end
			return stop_filter and a or a:upper() == a:lower() and ('('..a..")(.-)") 
				or ('([%s%s])(.-)'):format(a:upper(),a:lower()) 
		end)
		stop_filter=false
		skipNext = false
		search_simple = input:lower():gsub('.',function(a)
			if not skipNext and (a=="'" or a=='"') --[[ and (not stop_filter or stop_filter == a)--]]  then
				stop_filter = stop_filter ~= a and a
				return ''
			end
			return stop_filter and a or a..'.-'
		end)
	end
	local runables = {}
	local exec = input:match('^([^ ]+)') or input:match('^"([^"]+)') or input:match('^\'([^\']+)')
	local locked_order_list = {}
	if(executables) then
		local list = locked_order_list

		for _,path in ipairs(paths) do
			path = path..'/'..exec
			local file = io.open(path,'r')
			if(file) then
				file:close()
				local TEXT = "* <b></b><b>"..path:gsub('<>','\\%1')..'</b> (Executable)'
				list[#list+1] = TEXT
				runables[TEXT] = path .. input:sub(#exec+1)
				local extra = input:sub(#exec)
				local path = extra:match(' ([~/])$') or extra:match(' ([~/]/?[^ ]+)$') or extra:match(' "([^ ][^"]+)$')
				if(path) then
					if(path:sub(1,1) == "~") then path = home_dir .. path:sub(2) end
					sort = false
					local pathFolder = path:match('.+/') or path..'/'
					local out = executeCmd(('find %q -maxdepth 1 -mindepth 1 -type d'):format(pathFolder)):gsub('\n','/\n') 
					out = (out == "" and "" or out.."\n")..executeCmd(('find %q -maxdepth 1 -mindepth 1 -type f'):format(pathFolder))
					for result in out:gmatch('[^\n]+') do
						if(result:sub(0,#path) == path) then
							local end_path = input..result:sub(#path+1)
							local TEXT = " * <b></b><b>"..end_path..'</b>'
							list[#list+1] = TEXT
							runables[TEXT] = end_path
						end
					end
				end
			end
		end
	end
	local xml = module.allow_markup and module.xml_escape or function(...) return ... end
	for i,v in ipairs(list_to_search) do
		-- i = v[1]
		local endingString = {'*'}
		local matched_name,matched_generic_name, matched_description,matched_at_all
		if v.match and buffer:find(v.match) then
			matched_at_all = true
		end
		matched_name = v[1]:lower():find(search_simple)
		endingString[#endingString+1] = matched_name and xml(v[1]):gsub(search,module.highlight_match) or xml(v[1])
		if(v.gn and include_gen_name) then

			matched_generic_name = v.gn:lower():find(search_simple)
			endingString[#endingString+1] = '<span size="small" color="#dddddd">/'..(matched_generic_name and xml(v.gn):gsub(search,module.highlight_match) or xml(v.gn)).."</span>"
		end
		if(v.desc) then
			matched_description = include_desc and v.desc:lower():find(search_simple)
			endingString[#endingString+1] = ' <span size="x-small" color="#aaaaaa"> ('..(matched_description and xml(v.desc):gsub(search,module.highlight_match) or xml(v.desc)) ..')</span>'
		end

		if(matched_name or matched_description or matched_at_all) then
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
	if #list+#locked_order_list > 0 then
		local fullWord,wordparts = {},{}
		local sraw = input:lower()
		local list = list
		if(sort) then
			for i,v in pairs(list) do
				if(v:lower():find(sraw)) then
					fullWord[#fullWord+1] = v
				else
					wordparts[#wordparts+1] = v
				end
			end
			list = locked_order_list
			-- TODO FIX SORTING, SORTING SHOULD BE BY LENGTH OF MATCHED CHARACTERS, NOT THE FIRST </b> TAG
			pcall(function()
				local compFunc = function(a,b) 
					return a:match('<b>.-</b>') < b:match('<b>.-</b>')
				end
				table.sort(fullWord,function(a,b) return a:find('</b>') > b:find('</b>') end) 
				table.sort(wordparts,compFunc) 
			end)
			for i,v in ipairs(fullWord) do list[#list+1] = v end
			for i,v in ipairs(wordparts) do list[#list+1] = v end
		else
			local lol_index = #locked_order_list
			while lol_index > 0 do 
				table.insert(list,1,locked_order_list[lol_index])
				lol_index = lol_index - 1
			end
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
	if(module.dmenu_mode) then
		module.set_text('Nothing found out of '..#cached_list..'\nReturn ' .. module.runable)
		return
	end
	module.runable = module.def_command:format(input)
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
	{"$, $$","Run shell command, Run shell command and return output here",
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
				module.set_text(exec(input):gsub('%[.-[a-zA-Z]',''))
				return true
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
			local shell = os.getenv('SHELL') or "/bin/bash"
			if(not input or input == "") then input=shell end 
			if(use_read) then
				cmd = cmd..';read'
			end
			if(use_shell) then
				cmd = ('%s -c %q'):format(shell,cmd)
			end
			module.spawn((module.terminal):format(input))
			
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
		top_text="Lua output: ",
		update_text=function(self,input)
			runLua(input:sub(2))
			return
		end
	},
	{"[0-9+%-^%/*&><]","Calculator/Lua code", match="^[0-9+%-^%/*&><]+$",
		top_text="Calculator output: ",
		update_text=function(self,input)
			runLua(input)
			return
		end
	},
--[[ 	{"pm","pacman",starts_with="pm ",
		get_list=function(self,input)
			local list=module.pacman_list 
			if not list then
				list = {}
				-- Apparently io.popen doesn't work correctly with pacsift?
				-- exec('pacsift > /tmp/pacsift list')
				local a,b,c = exec('sh -c "/usr/bin/pacsift | grep \'\'"')
				input = "  "..#tostring(a)
				-- io.open('/tmp/pacsiftlist','r')
				-- local content = file:read('*a')
				-- file:close()
				-- exec('rm /tmp/pacsiftlist')
				-- local content = os.execute('pacsift')

				-- for i in (content:gmatch('([^\n]+)')) do
				-- 	list[#list+1] = {i}
				-- end
				-- module.pacman_list=list
			end
			return input:sub(3),list
		end
	},--]] 
	{"m","Menu",starts_with="m ",
		get_list=function(self,input)
			if not self.menu_contents then
				local menu_contents_file = io.open(module.MenuFolder..'/menu_contents.lua')
				self.menu_contents = {}
				if menu_contents_file then 
					local succ,err = pcall(function()
						self.menu_contents = load(menu_contents_file:read('*a'))()
					end)
					menu_contents_file:close()
				end
			end
			local list= {}
			local recurse
			recurse = function(l,str)
				for i,v in pairs(l) do
					if(type(v) == "table") then
						if(type(v[2]) == "table") then
							recurse(v[2],str..v[1]:lower()..'>')
						else
							list[#list+1] = {str..v[1]:lower(),v[2]}
						end
					end
				end
			end

			recurse(self.menu_contents,"")
			return input:sub(2),list
		end
	},
	{"cl","CLear menu cache",match="^cl$",
		update_text=function(self,input)
			return module.set_text('Remove '..module.cacheFile..' to clear appmenu cache')
		end,
		runable=function(self,input)
			os.execute('rm '..module.cacheFile)
		end
	},

	{"umnt(c),mnt(c)","(un)mount drives (Requires dkjson) Include c to use normal mount",match="^u?mntc?",
		get_list=function(self,input)
			local succ,json = pcall(require,'dkjson')
			if not succ then 
				print('NO CJSON')
				module.set_text('Missing DKJSON!\n' .. json)
				return "",{{'Missing DKJSON!\n'..json,''}}
			end
			local unmount = false
 			input = input:gsub(self.match,function(a) unmount = not not a:find('u') return "" end)

			if not module.mountlist then
				local mountlist = {}
				local mounts = json.decode(executeCmd('lsblk -AJ -o PATH,MOUNTPOINTS,TYPE,SIZE,PARTLABEL'))
				for _,mount in ipairs(mounts.blockdevices) do
					if(mount.type == "part" and mount.path) then
						local m = {}
						mountlist[#mountlist + 1] = m
						m.desc = (#mount.mountpoints == 1 and ("mounted at "..mount.mountpoints[1]) or (#mount.mountpoints.." mount points"))
							.. "  -  " .. mount.size
						if not mount.partlabel then mount.partlabel = mount.model end
						if not mount.partlabel then mount.partlabel = mount.path:gsub('.+/','') end
						m[1] = mount.partlabel
						m.gn = '('..mount.path..")"
						local USER = os.getenv('USER')

						m[2] = function() module.run_in_terminal(('sudo %s %q %q'):format(unmount and "umount" or "mount -m",mount.path,("/run/media/%s/%s"):format(USER,mount.partlabel))) end
					end
				end
				module.mountlist = mountlist
			end
			local list = {}
			for i,v in pairs(module.mountlist) do list[i]=v end
			-- recurse(old_menu,"")
			return input,list
		end
	},
	-- {"dw","download clipboard and open with",starts_with="dw ",
	-- 	runable=function(s,input)

	-- 		-- module.spawn(('xdg-open %q'):format('https://duckduckgo.com/'..input:sub(3):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end)))
	-- 	end,
	-- 	update_text=function(self,input)
	-- 		module.set_text('Download ' .. input:sub(2),true)
	-- 		return
	-- 	end
	-- },
	{"d","duckduckgo search",starts_with="d ",
		runable=function(s,input)

			module.spawn(('%s %q'):format(module.def_command,'https://duckduckgo.com/'..input:sub(3):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end)))
		end,
		update_text=function(self,input)
			module.set_text('Search duckduckgo for ' .. input:sub(2),true)
			return
		end
	},
	{"mr","modrinth search",starts_with="mr ",
		runable={exec=function(s,input)
			local link = s.last_input == input and s.link
			or 'https://modrinth.com/mods?q='..input:sub(4):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end) 
			module.spawn(('%s %q'):format(module.def_command,link))

		end,tab=function(self,input)
			local json_lib_exists,json_lib = pcall(require,'json')
			if not json_lib_exists then
				json_lib_exists,json_lib = pcall(require,'dkjson')
			end
			if not json_lib_exists then
				self.last_text = 'No JSON library is available!'
				return 
			end

			self.last_input = input
			local index = 1
			if(input:find(' %d+$')) then
				input,index = input:match('^(.+) (%d+)$')
			end
			local json
			if(self.last_json and input == self.last_input:match('^(.+) (%d+)$')) then
				json = self.last_json
			else
				input = input:sub(4):gsub('[^a-zA-Z%.0-9,]',function(a) return ('%%%x'):format(a:byte()) end)


				os.execute(('curl %q -o /tmp/modrinth_api_output'):format('https://api.modrinth.com/v2/search?query='..input))
				local f = io.open('/tmp/modrinth_api_output','r')
				json = f:read('*a')
				self.last_json = json
				f:close()
			end
			if(#json < 10) then
				self.last_text = 'No results!'
				return 
			end
			local meta = json_lib.decode(json)

			if not meta then self.last_text = 'Invalid JSON recieved from modrinth!' return end 
			local count = #meta.hits
			local meta = meta.hits[tonumber(index or 1)]
			if not meta then self.last_text = 'Invalid mod index' return end 

			meta.result_count = count
			meta.game_versions = table.concat(meta.versions,', ')
			meta.categories = table.concat(meta.categories,', ')
			self.link = 'https://modrinth.com/project/'..meta.slug
			self.last_text = ([[$title$/$slug$
			$description$
			Client/Server: $client_side$/$server_side$
			Versions: $game_versions$
			Categories: $categories$

			Press Enter to open
			]]):gsub('\t',''):gsub("%$(.-)%$",function(a) return tostring(meta[a]) end)
			return true
		end
		},
		update_text=function(self,input)
			if(self.runable.last_text and self.runable.last_input == input ) then

				return module.set_text(self.runable.last_text)
			end
			if(self.runable.last_json ) then
				local json_lib_exists,json_lib = pcall(require,'json')
				if not json_lib_exists then
					json_lib_exists,json_lib = pcall(require,'dkjson')
				end
				local txt = ""
				for i,v in pairs(json_lib.decode(self.runable.last_json).hits) do
					txt = txt .. ('%i - %s\n'):format(i,v.slug)
				end
				return module.set_text(txt)
			end
			module.set_text('Search Modrinth for ' .. input:sub(4) .. '\n Press tab to get info about mod',true)
			return
		end
	},

}

module.key_functions = {
	tab = function()
		if not module.runable then return end
		if(module.runable.tab) then
			local tab = module.runable.tab
			if(type(tab) == "function") then
				tab(module.runable,module.text_buffer)
				return true
			end
			module.text_buffer = module.runable.tab
			module.queued_text_pos = (#module.text_buffer)
			return true
		elseif(type(module.runable) == "string") then
			module.text_buffer = module.runable
			module.queued_text_pos = (#module.text_buffer)
			return true
		elseif(tostring(module.runable[2]):find('%.desktop$')) then
			local file = io.open(tostring(module.runable[2]),'r')
			local content = file:read('*a')
			file:close()
			local newBuffer = content:match('Exec=([^\n]+)')
			if newBuffer then
				module.text_buffer = newBuffer:gsub('%%.',''):gsub('^%s+',''):gsub('%s+$','')
			end
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
			buffer, id = module.text_buffer,tonumber(id or 2)
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
	if(txt == nil) then 
		txt = module.dmenu_mode and ('Running in dmenu mode; ' .. tostring(module.dmenu_mode)) or generate_help()
		plain = false
	end
	txt = module.top_text..tostring(txt)..module.bottom_text
	local lp = ('-'):rep(math.floor(module.locked_char_width))
	-- '|'..(' '):rep(math.floor(module.locked_char_width-1))..'|'
	if module.allow_markup then
		-- print(module.output)
		module.output = (lp.. "\n"..txt):gsub('&.-;',function(a) return a:gsub('<.->','') end)
		module.apply_text(module.output)
		module._update_cursor_pos()
		return
	end
	module.output = (lp.. "\n"..txt):gsub('<.->','')
	module.apply_text(module.output)
	module._update_cursor_pos()
end

module.finish = function(input)
	if not input or #input == 0 then return end
	local runable=module.runable
	-- print(runable)
	if(module.dmenu_mode) then
		if(module.dmenu_mode:find('~%d+$')) then
			local a = tonumber(module.dmenu_mode)
			io.stdout:write(runable[a] or runable[1])
		elseif(type(module.dmenu_mode) == "string") then
			local dmenu_mode = module.dmenu_mode:lower():gsub('_','')
			if(dmenu_mode == 'option') then
				io.stdout:write(runable[2] or runable[1])
			elseif(dmenu_mode == 'all') then
				io.stdout:write(input..'\n'..table.concat(runable,'\n'))
			elseif(dmenu_mode == 'aspassed') then
				io.stdout:write(table.concat(runable,';'))

			end
		else
			io.stdout:write(input)
		end
		module.exit()
		return input
	end
	-- naughty.notify({
	-- 	preset = naughty.config.presets.normal,
	-- 	title = 'Input was ' .. input
	-- })
	for i,cmd in pairs(module.commands) do
		if((cmd.starts_with and input:sub(1,#cmd.starts_with) ==cmd.starts_with) or cmd.match and input:find(cmd.match)) then
			executables=false
			if(cmd.runable) then
				if(type(cmd.runable) == "function") then
					return cmd:runable(input)
				end
				runable = cmd.runable
				break
			end
		end
	end
	if(runable) then
		local runable_tbl
		if(type(runable) == "table") then -- TODO ADD RECENTS
			if(type(runable.exec) == "function") then
				return runable:exec(input)
			end
			runable_tbl=runable
			runable = runable.runable or runable[2]
			-- if(type(runable) == "string") then
			-- 	for i,v in pairs(recents) do

			-- 	end

			-- end
		end
		if(type(runable) == "string") then
			if(runable:sub(-8)==".desktop") then runable = ('exo-open %q'):format(runable) end
			print('Running '..runable)
			return module.spawn(runable)
		elseif(type(runable) == "function") then
			return runable(input,runable_tbl)
		else
			print('Attempt to run '..type(runable) .. "(expected string,function)")
		end
		return
	end
end




local extension = io.open(module.MenuFolder..'/extensions.lua')
if extension then 
	local succ,err = pcall(function()
		load(menu_contents:read('*a'))()
	end)
	menu_contents:close()
end


local current_desktop = (os.getenv('XDG_CURRENT_DESKTOP') or os.getenv('XDG_DESKTOP') or ""):lower()

if(module.enable_history) then
	module.commands[#module.commands+1]={"h","Run past queries",
		starts_with="h ",
		match = nil,
		check = nil,
		-- update_text=function(self,input)
		-- 	return module.set_text("Run command" .. (input:sub(2,2) == '$' and " and return output here" or input:sub(2,2) == '>' and " and send a notification" or ""))
		-- end,
		get_list=function(self,input)
			local list = module.get_history()


			return input,list
		end
	}
end

if(current_desktop == "cwc") then
	module.commands[#module.commands+1]={"^c","Run lua code on cwc",
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
	}

	module.commands[#module.commands+1]={"cw","(CWC ONLY) CWC stuff",
		-- match="^cw",
		starts_with="cw",
		funcs = {
			{'cw res WIDTH HEIGHT REFRESH',
			function(_,self) 
				local a,b,c = module.text_buffer:match('(%d+).(%d+).(%d+)')
				if not a then module.set_text('Missing width') return true end
				if not b then module.set_text('Missing height') return true end
				if c then c = ','..c end
				local cmd = ('cwctl -c "cwc.screen.focused():set_custom_mode(%i,%i%s)"'):format(a,b,c)
				os.execute(cmd)
				os.execute(('notify-send'):format(cmd))
				return false
			end,
			match="^cw res",
			desc="Set resolution of current display",
			tab='cw res '
			},
			-- wm=function(_,self) self.client:jump_to() end,
			-- wc=function(_,self) os.execute(('cwctl -c "local c = cwc.client.get()[%i];c:focus();c:move_to_screen()"'):format(self.client_id)) end,
		},
		get_list=function(self,input)

			local list = self.funcs



			-- local f = input:sub(1,2):gsub(' $',''):lower()
			-- local func = self.funcs[f] or self.funcs.w
			-- if(os.getenv('XDG_CURRENT_DESKTOP') == "cwc") then
			-- 	local e = io.popen(('cwctl -c %q'):format([[local str = {};for i,v in pairs(cwc.client.get()) do str[#str+1] = v.name and ('%s - %s'):format(v.name,v.appid) or v.appid end;return table.concat(str,'\n')]]),'r')
			-- 	local content = e:read('*a')
			-- 	e:close()
			-- 	local i = 0
			-- 	for clientName in content:gmatch('[^\n]+') do
			-- 		i = i + 1
			-- 		list[i] = {f.. ' ' .. clientName,func,client_id = i}
			-- 	end
			-- end
			-- local list= {}
			-- for _,cur_client in ipairs(client.get()) do
			-- 	list[#list+1] = {f..' '..(cur_client.name or cur_client.class),func,client=cur_client}
			-- end
			return input,list
		end
	}
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

-- for i,v in pairs(module) do
-- 	if(type(v) == "function") then
-- 		modules[i] = function(...)
-- 			local a = pack(pcall(v,...))
-- 			if(not a[1]) then
-- 				module.on_error(a[2])
-- 				return nil
-- 			end
-- 			table.remove(a,1)
-- 			return unpack(a)
-- 		end
-- 	end
-- end

return module