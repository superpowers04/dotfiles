-- GtkLabel: A text widget

local appID = "Superpowers04.appmenu.test"
local appTitle = "Appmenu"
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local app = Gtk.Application({ application_id = appID })


local module = dofile(os.getenv('HOME')..'/SRC/dotfiles/lua/appmenuBase.lua')
module.allow_markup = true



local keys = {
	enter= '65293.0',
	down=  '65364.0',
	up=    '65362.0',
	tab=   '\t'
}

function app:on_startup()
	-- win.type_hint=0
	-- win.modal = true
	local win = Gtk.MessageDialog({
		title = appTitle,
		application = self,
		width=400,height=450,
		-- halign = Gtk.Align.START,
		-- valign = Gtk.Align.START,
		visible=true,
		
	})

	local entry = Gtk.Entry({ visible = true })
	local label = Gtk.Label({ visible = true, label = "", use_markup = true, wrap=0})

	-- win:set_modal(true)
	-- win:set_keep_above(true)
	-- win:stick(true)
	-- win:set_type_hint(8)
	win:set_decorated(false)
	module.apply_text = function(output)
		entry.text = module.text_buffer
		label.label = output
	end




	module.updateInput("")

	local box = win:get_child()
	box.visible = true
	box.orientation = Gtk.Orientation.VERTICAL
	box.width=400
	box.height=400
	box.hexpand=0
	box.vexpand=0
	box.halign = Gtk.Align.START
	box.valign = Gtk.Align.START

	
	module.set_text()
	
	box:add(entry)
	box:add(label)
	entry:grab_focus()


	local key_functions = {
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
		-- []
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
			module:finish(module.text_buffer)
			win:destroy()
			return true
		end
	}
	win.on_key_press_event = function(self,key)
		local func = key_functions[key.string] or key_functions[tostring(key.keyval)]
		-- print(key.keyval)
		if(func) then
			if(func()) then
				module.updateInput(module.text_buffer)
				module.set_text()
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
		-- print(entry.text)
		-- module.set_text()
	end

end

function app:on_activate()
	self.active_window:present()
end

return app:run(arg)