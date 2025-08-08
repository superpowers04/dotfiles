#!/bin/luajit
-- To use, install some form of https://github.com/lgi-devs/lgi and GTK 3
--  Then bind a keybind to `luajit /path/to/script` This script SHOULD work with both lua5.4 AND LuaJIT
--  Change the location below to wherever you've installed the appmenuBase.lua that should've been alongside thisw script

-- This frontend has UP and DOWN bound to change menu options and tab to auto-fill any highlighted desktop files to their Exec field

local Module_Location = os.getenv('HOME')..'/SRC/dotfiles/lua/appmenuBase.lua'

local appID = "Superpowers04.appmenu.lua"
local appTitle = "Appmenu" 
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local app = Gtk.Application({ application_id = appID })

local succ,module = pcall(dofile,Module_Location)
local err
if succ then 
	module.allow_markup = true
else
	err = module;module = nil;print(err)
end



local keys = {
	enter= 65293,
	down=  65362,
	up=    65364,
	tab=   '\t'
}

function app:on_startup()
	print('dies')
	local win = Gtk.MessageDialog({
		title = appTitle,
		application = self,
	})
	win.visible=true
	win:set_decorated(false)
	local box = win:get_child()
	local entry = Gtk.Entry({ visible = true})
	local label = Gtk.Label({ visible = true, halign = Gtk.Align.START, label = "", use_markup = true, wrap=0})
	
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
		[keys.tab] = function()
			if(tostring(module.runable[2]):find('%.desktop$')) then
				local file = io.open(tostring(module.runable[2]),'r')
				local content = file:read('*a')
				file:close()
				local newBuffer = content:match('Exec=([^\n]+)')
				if newBuffer then
					module.text_buffer = newBuffer:gsub('%%.',''):gsub('^%s+',''):gsub('%s+$','')
				end
				return true
			end
		end,
		[keys.up] =function()
			local buffer = module.text_buffer
			local id = tonumber(buffer:match(' (%d+)$') or 1)
			id = id + 1
			module.text_buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
			return true
		end,
		[keys.down] = function()
			local buffer = module.text_buffer
			local id = tonumber(buffer:match(' (%d+)$') or 2)
			id = id - 1
			if(id < 1) then id = 1 end
			module.text_buffer = (buffer:match('(.+) %d+$') or buffer) .. " " .. id
			return true
		end,
		[keys.enter] = function()
			module.finish(module.text_buffer)
			win:destroy()
			return true
		end
	}
	win.on_focus_out_event=function()
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
		module.updateInput(entry.text)
	end

end

function app:on_activate()
	self.active_window:present()
end

return app:run(arg)