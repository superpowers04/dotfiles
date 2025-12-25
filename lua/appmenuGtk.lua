#!/bin/luajit
-- Originally by Superpowers04, using https://github.com/Miqueas/GTK-Examples/blob/main/lua/gtk3/entry.lua as a template

-- To use, install some form of https://github.com/lgi-devs/lgi and GTK 3
--  Then bind a keybind to `luajit /path/to/script` This script SHOULD work with both lua5.4 AND LuaJIT
--  Change the location below to wherever you've installed the appmenuBase.lua that should've been alongside thisw script

-- This frontend has UP and DOWN bound to change menu options and tab to auto-fill any highlighted desktop files to their Exec field



local Module_Location = os.getenv('HOME')..'/SRC/dotfiles/lua/appmenuBase.lua'

arg = arg or args
-- Flag parsing
local flags = {
	keepopen=true
}

for i,v in pairs(arg) do
	if(v:sub(1,2) == "--") then
		flags[v:sub(3):lower()] = true
	elseif(v:sub(1,1) == "-") then
		for char in v:sub(2):gmatch('.') do
			flags[char:lower()] = true
		end
	elseif(v=="--") then
		break
	end
end

if flags.help or flags.h then
	print([[appmenuGtk.lua [arguments]
	--help  - Show this message
	--keepopen --keep-open -k  - Prevent appmenu from closing after selecting an option
	--cache  - Run appmenuBase to cache desktop files and exit
]])
	return
end

-- Load the module first
local succ,module = pcall(dofile,Module_Location)
local err
if succ then
	module.allow_markup = true
else
	err = module;module = nil;print(err)
end

if flags.cache then return end
if flags["keep-open"] or flags.k then
	flags.keep_open=true
	return
end

local appID = "Superpowers04.appmenu.lua"
local appTitle = "Appmenu" 
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GLib = lgi.require('GLib')
local app = Gtk.Application({ application_id = appID })
module.xml_escape = function(a)
	if not a then return nil end
	return GLib.markup_escape_text(a,#a)
end


local keys = {
	enter= 65293,
	down=  65362,
	up=    65364,
	tab=   '\t'
}

function app:on_startup()

	local win = Gtk.MessageDialog({
		title = appTitle,
		application = self,
	})
	win.visible=true
	win:set_decorated(false)
	local box = win:get_child()

	local entry = Gtk.Entry({ visible = true})
	local label = Gtk.Label({ visible = true, xalign = 0, label = "Loading appmenu module", use_markup = true, wrap=0, selectable=true})

	if not module then
		box:add(label)
		label.label = "Unable to init appmenu!\n" .. err..'\n\n\n\n'
		return
	end
	box:add(entry)
	box:add(label)
	module.apply_text = function(output)
		entry.text = module.text_buffer
		label.label = output
	end

	module.updateInput("")
	module.set_text()
	entry:grab_focus()


	local key_functions = { -- I would define this outside of on_startup but these functions require access to `entry` and `label`
		[keys.tab] = module.key_functions.tab,
		[keys.up] = module.key_functions.up,
		[keys.down] = module.key_functions.down,
		[keys.enter] = function()
			if module.finish(module.text_buffer) == true or flags.keep_open then return end

			module.exit(0)
			return true
		end
	}
	module.exit = function(...)
		if(flags.keep_open) then return end
		win:destroy()
		os.exit(...)
	end
	module.move_cursor = function(pos) entry:set_position(pos); end
	win.on_focus_out_event=function()
		if(flags.keep_open) then return end
		win:destroy()
	end
	win.on_key_press_event = function(self,key)

		local func = key_functions[key.string] or key_functions[math.floor(key.keyval)]
		if(func) then
			if(func()) then
				module.updateInput(module.text_buffer)
				-- module.set_text()
				return true
			end
		end
	end
	win.on_key_release_event = function(self,key)
		local func = key_functions[key.string] or key_functions[key.keyval]
		if(func) then
			return true
		end
	end
	entry.on_key_release_event = function(self,key)
		if(entry.text == module.text_buffer) then return end
		module.updateInput(entry.text)
	end
	

end

function app:on_activate()
	self.active_window:present()
end

return app:run(arg)
