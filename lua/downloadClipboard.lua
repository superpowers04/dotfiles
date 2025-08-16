local f = io.popen('wl-paste -t text/plain')
local file = f:read('*a')
f:close()
local out = '/tmp/'..file:match(".+/(.-)%?")
os.execute(('curl %q --output %q'):format(file,out))
if(arg[1] == 'open') then
	os.execute(('xdg-open %q'):format(out))
end
return out