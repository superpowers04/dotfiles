local req = require
-- require = function(...)
-- 	local succ,err = pcall(req,...)
-- 	if not succ then

-- 	end
-- 	return err
-- end



local cful = require("cuteful")
local gears = require("gears")
local cwc = cwc

local MODKEY = require("cuteful").enum.modifier.LOGO
local kbd = cwc.kbd
kbd.bind({ MODKEY }, "r", cwc.reload, { description = "reload configuration", group = "cwc" })


local succ,err = pcall(require,'cwc_rc')
if not succ then 
	os.execute(('notify-send "ERROR" %q'):format(err))
end