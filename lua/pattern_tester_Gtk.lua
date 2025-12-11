#!/bin/luajit
-- Originally by Superpowers04, using https://github.com/Miqueas/GTK-Examples/blob/main/lua/gtk3/entry.lua as a template

-- To use, install some form of https://github.com/lgi-devs/lgi and GTK 3
--  Then bind a keybind to `luajit /path/to/script` This script SHOULD work with both lua5.4 AND LuaJIT
--  Change the location below to wherever you've installed the appmenuBase.lua that should've been alongside thisw script

-- This frontend has UP and DOWN bound to change menu options and tab to auto-fill any highlighted desktop files to their Exec field



local appID = "Superpowers04.lua_patt_test"
local appTitle = "Lua pattern tester" 
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GLib = lgi.require('GLib')
local app = Gtk.Application({ application_id = appID })
function app:on_startup()

	local win = Gtk.MessageDialog({
		title = appTitle,
		application = self,
	})
	win.visible=true
	local box = win:get_child()
	box.spacing = 10

	local entry = Gtk.Entry({ visible = true,text = "(d.g).-( f[^ ]+)",wrap = true})
	local entry2 = Gtk.Entry({ visible = true, text = "The lesbian dog looked at the sexy fox"})
	local label = Gtk.Label({ visible = true, label = "Loading appmenu module", selectable=true})

	box:add(Gtk.Label({ visible = true, label = "Pattern:"}))
	box:add(entry)
	box:add(Gtk.Label({ visible = true, label = "Match:"}))
	box:add(entry2)
	box:add(Gtk.Label({ visible = true, label = "Results:"}))
	box:add(label)
	entry:grab_focus()
	local bot = '\n\n'..('-'):rep(100)

	local function update()

		local succ,err = pcall(function()
			label.label = table.concat({entry2.text:match(entry.text)})
		end)
		if not succ then
			label.label = "An error occurred while trying to parse that pattern: " .. err
		end
		label.label = label.label .. bot
	end
	update()
	entry.on_key_press_event = function(self,key)
		label.label = "..."..bot
	end
	entry.on_key_release_event = function(self,key)
		update()
	end
	

end

function app:on_activate()
	self.active_window:present()
end

return app:run(arg)
