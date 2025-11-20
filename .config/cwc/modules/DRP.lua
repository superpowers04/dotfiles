-- Note this script wasn't designed to be public so things might be a mess ^^;
-- A basic script that uses the window name of a program to set your Discord Rich Presence
-- Check the readme.md

--[[--------------
	CONFIG
------------------]]

-- Replace 1201616832885444789 with whatever your Discord Rich Presence Application ID is. THIS HAS TO BE A STRING
local APPID = "1201616832885444789"
local _path = ""
-- The program that gets killed when you disable DRP
local proccessToFind = "Haxe-FakeDRP" 
-- The address used to communicate with the http server
local DRP_ENDPOINT = 'http://localhost:7286/' 
-- The command executed to update rich presence
local command = 'bash -c \'curl -s %q\'' 
-- Temp file used to keep the DRP state across Awesome restarts
local TMPFILE = "/tmp/AWESOMEWM_DRPENABLED"

-- Table consisting of Pattern > Function, function should return a valid string for the Haxe portion
--  Valid strings are either a http styled "?KEY1=VALUE1&KEY2=VALUE2" or a "TITLE|FOOTER"
-- Below are some examples
local pattToDRP = {
	['^DRP{']= function(name) -- Matches DRP{(VALID_STRING)}
		return name:match('DRP{(.-)}') 
	end, 
	['%- YouTube']= function(name) -- Matches (FOOTER) - Youtube
		return 'Watching YouTube|'..(name:match('%) (.+) %- YouTube') or name)
	end, 
	['%| Comic Fury']= function(name) -- Matches (FOOTER) | (TITLE) | Comic Fury
		return "Reading " .. (name:match('.-%| (.-) %|') or "??")..' on Comic Fury | '..(name:match('(.-) %|') or "??") 
	end,
	['Friday Night Funkin\'']= function(name) -- Matches (FOOTER) | (TITLE) | Comic Fury
		return "Playing " .. name .. " | Check other status if there is one"
	end,
}


-- Actual script
local module = {}

local newLine,rn,hex,byte = "\n","\r\n",("%%%02X"),string.byte
local function char_to_hex(c) return hex:format(byte(c)) end

local function urlencode(url)
	if url == nil then return end
	return url:gsub(newLine, rn):gsub("([^%w ])", char_to_hex):gsub(" ", "+")
end

function module.sendToDRP(content)
	cwc.spawn_with_shell(command:format(DRP_ENDPOINT.. urlencode(content:gsub('\'','\\\'') )))
end
function module.updateDRP(c)
	if(not (c.title)) then return end
	for patt,func in pairs(pattToDRP) do
		if(c.title:find(patt)) then
			local str = func(c.title)
			if str then
				return module.sendToDRP(str)
			end
		end
	end
end

--cwc.connect_signal("client::prop::title", module.updateDRP)
--cwc.connect_signal("client::raised", module.updateDRP)