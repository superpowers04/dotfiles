-- cwc default config
-- gears.protected_call(function()
-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

local gears = require("gears")
local enum = require("cuteful.enum")
local tag = require("cuteful.tag")
-- make it local so the `undefined global` lsp error stop yapping on every cwc access
local cwc = cwc

-- execute oneshot.lua once, cwc.is_startup() mark that the configuration is loaded for the first time

function str_tbl(tbl,index)
	local str = ""
	for i,v in pairs(tbl) do
		str = str .. '\n' .. i .. ' - ' .. (index and v[index] or v)
	end
	return str
end

function spawn_shell(cmd,a,...)
	if(type(a) == "tbl") then
		local args = {}
		for i,v in pairs(a) do
			if(type(i) == "string") then
				if(v == true) then
					args[#args+1] = ('-%s'):format(#i ==1 and i or '-'..i)
				else
					args[#args+1] = ('-%s=%q'):format(#i ==1 and i or '-'..i,tostring(v))
				end

			end
		end
		for i,v in ipairs(a) do
			args[#args+1] = ('%q'):format(v)
		end
		cwc.spawn_with_shell(('%s %s'):format(cmd,table.concat(args,' ')))

		return
	end
	local args = {...}
	table.insert(args,1,a)
	cwc.spawn_with_shell((cmd..(' %q'):rep(#args)):format(unpack(args)))

end

notifySend = function(...)
	spawn_shell('notify-send',...)
end
notifyPrint = function(...)
	local e = {}
	local input = {...}
	for i=1,#input do
		e[i] = tostring(input[i]):gsub('[`${}]','\\%1')
	end
	notifySend('',table.concat(e,'\n'))
	print(...)
end
gears.debug.print_error = function(a)
	local succ,err = pcall(function()
		local f = io.open('/tmp/cwcerr','w')
		f:write(a)
		f:close()
	end)
	notifySend(a)
end
if(not cwc.is_nested()) then 
	if cwc.is_startup() then
		gears.protected_call(require, "oneshot")
	else
		cwc.spawn_with_shell('killall waybar;waybar')
	end
end



notifySend('hi')
local kbd = cwc.kbd


local cful = require("cuteful")
local enum = cful.enum
local mod = enum.modifier
local MODKEY = mod.LOGO
kbd.bind({ MODKEY }, "r", cwc.reload, { description = "reload configuration", group = "cwc" })

-- kbd.bind({ "SUPER_L", mod.CTRL }, "r", cwc.commit, { description = "commit configuration", group = "cwc" })

-- execute keybind script
gears.protected_call(require, "keybind")

---------------------------------- CONFIGURATION --------------------------------------
-- A library for declarative configuration and per device configuration will be added later.
-- If you change configuration at runtime some of configuration need to get committed by calling
-- `cwc.commit()``

-- pointer config
cwc.pointer.set_cursor_size(22)
cwc.pointer.set_inactive_timeout(0)
cwc.pointer.set_edge_threshold(32)
cwc.pointer.set_edge_snapping_overlay_color(0.1, 0.2, 0.3, 0.05)

-- keyboard config
cwc.kbd.set_repeat_rate(30)
cwc.kbd.set_repeat_delay(300)
-- cwc.kbd.xkb_variant = "colemak"

-- cwc.kbd.xkb_layout  = "us,de,fr"
cwc.kbd.xkb_options = ""
-- #b4b8e6:0.0,#e1a5d7:0.25,##ffffff:0.5,#e1a5d7:0.75,#b4b8e6:1.0
-- client config
cwc.client.set_border_color_focus(gears.color(
	"linear:0,0:0,0:0,#b4b8e6:0.1,#c9a5d7:0.2,#e1a5d7:0.3,#f1d5e7:0.4,#ffffff:0.5,#f1d5e7:0.6,#e1a5d7:0.7,#e1a5d7:0.8,#c9a5d7:0.9,#b4b8e6:1.0,#b4b8e6"))
cwc.client.set_border_color_normal(gears.color("#221b24"))
cwc.client.set_border_width(2)


-- screen/tag config
cwc.screen.set_useless_gaps(1)

-- plugin config
if cwc.cwcle then
	cwc.cwcle.set_border_color_raised(gears.color("#d2d6f9"))
end

-- input device config
cwc.connect_signal("input::new", function(dev)
	dev.sensitivity   = 0
	dev.accel_profile = enum.libinput.ACCEL_PROFILE_FLAT

	if dev.name:lower():match("touchpad") then
		dev.sensitivity    = 0.7
		dev.natural_scroll = true
		dev.tap            = true
		dev.tap_drag       = true
		dev.dwt            = true
	elseif dev.name:lower() == "wacom one pen display 13 pen" then
		-- dev.tap            = true
		-- dev.output_name = "HDMI-A-2"
		-- dev.click_method = 2
	end
end)
--for _,dev in pairs(cwc.input.get()) do
--	dev.sensitivity   = 0
--end

-- uncategorized
cwc.tasklist_show_all = false
local scrs = {}

------------------------------- SCREEN SETUP ------------------------------------
cwc.connect_signal("screen::new", function(screen)
	screen:set_transform(enum.output_transform.TRANSFORM_NORMAL)

	screen.allow_tearing = false
	screen:set_mode(1920, 1080, 75)
	-- notifySend(screen.description or screen.make)
	if((screen.description or screen.name):find("KA242Y")) then
		scrs.top = screen
	elseif((screen.description or screen.name):find("Wacom One 13")) then
		scrs.bot = screen
	end
	if(scrs.bot and scrs.top) then
		local bot,top = scrs.bot,scrs.top
		top:set_position(0,0)
		top:set_custom_mode(1920,1080,73300)
		bot:set_position(0,1080)
	end
	-- end


	-- don't apply if restored since it will reset whats manually changed
	if screen.restored then return end

	-- set all "general" tags to master/stack mode by default
	for i = 1, 9 do
		tag.layout_mode(i, enum.layout_mode.MASTER, screen)
	end

end)

-- cwc.connect_signal("screen::destroy", function(screen)
--     --- here screen.clients is equivalent as screen:get_clients()
--     local cmd = string.format(
--         'notify-send "Screen removed" "Screen %s [%s] with %s clients attached"', screen.name,
--         screen.description or "-", #screen.clients)
--     cwc.spawn_with_shell(cmd)
-- end)


local client_rules = {
	['aseprite'] = {
		func = function(c)
			client.floating = true
			client.fullscreen = false
			client.maximised = false
			client:center()

			-- client.geometry.width = 400
			-- client.geometry.height = 400
		end
	},
	['copyq'] = {
		func = function(c)
			client:center()
			client.floating = true
			client.geometry.width = 400
			client.geometry.height = 400
		end
	},
}


------------------------ CLIENT BEHAVIOR -----------------------------
cwc.connect_signal("client::map", function(client)
	-- unmanaged client is a popup/tooltip client in xwayland so lets skip it.
	if client.unmanaged then return end
	-- if client.focus then return end

	local client_rule = client_rules[client.appid:lower()] or client_rules[(client.name or ""):lower()]
	if(client_rule) then
		if(client_rule.func) then
			if client_rule.func(client) then return end
		else
			for i,v in pairs(client_rule) do
				pcall(function()
					client[i] = v
				end)
			end
		end
	end

	if client.appid:find('pol.-agent') then
		client.floating = true
	end
	-- don't pass focus when the focused client is fullscreen but allow if the parent is the focused
	-- one. Useful when gaming where an app may restart itself and steal focus.
	-- local focused = cwc.client.focused()
	-- if focused and focused.fullscreen and client.parent ~= focused then
	-- 	client:lower()
	-- 	return
	-- end
	local focused = cwc.client.focused()
	if focused and focused.fullscreen then
		client.floating = true
	end


	client:raise()
	client:focus()

	-- the declarative rules isn't implemented yet so here is an example to do ruling.
	-- It'll move any firefox app to the workspace 2 and maximize it also we moving to tag 2.
	if client.appid == "firefox" then
		client:move_to_tag(2)
		client.screen.active_workspace = 2
	end

	-- center the client from the screen workarea if its floating or in floating layout.
	if client.floating then client:center() end

end)

cwc.connect_signal("client::unmap", function(client)
	-- exit when the unmapped client is not the focused client.
	if client ~= cwc.client.focused() then return end
	-- and for unmanaged client
	if client.unmanaged then return end

	-- if the client container has more than one client then we focus just below the unmapped
	-- client
	local cont_stack = client.container.client_stack
	if #cont_stack > 1 then
		cont_stack[2]:focus()
	else
		-- get the focus stack (first item is the newest) and we shift focus to the second newest
		-- since first one is about to be unmapped from the screen.
		local latest_focus_after = client.screen:get_focus_stack(true)[2]
		if latest_focus_after then latest_focus_after:focus() end
	end
end)

cwc.connect_signal("client::focus", function(client)
	-- by default when a client got focus it's not raised so we raise it.
	-- should've been hardcoded to the compositor since that's the intuitive behavior
	-- but it's nice to have option I guess.
	client:raise()
	client:set_border_color_rotation(math.round(os.clock() * 10000))
end)

-- sloppic focus only in tiled client
cwc.connect_signal("client::mouse_enter", function(c)
-- 	local focused = cwc.client.focused()
-- 	if focused and focused.floating then return end
	client:set_border_color_rotation(math.round(os.clock() * 10000))

-- 	c:focus()
end)

cwc.connect_signal("container::insert", function(cont, client)
	-- reset mark after first insertion in case forgot to toggle off mark
	cwc.container.reset_mark()

	-- focus to the newly inserted client
	client:focus()
end)

cwc.connect_signal("screen::mouse_enter", function(s)
	s:focus()
end)
-- end)

local succ,err = pcall(require,"ExtensionLoader")
if not succ then
	notifyPrint(err)
end
