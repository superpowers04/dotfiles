local mod = {
	queuedFuncs = {

	}
}
AsyncSpawn = mod
function AsyncSpawn:handleCallback(id,...)
	notifyPrint(id)
	local func = AsyncSpawn.queuedFuncs[id]
	notifyPrint(func)
	AsyncSpawn.queuedFuncs[id] = nil
	func(...)
end

function AsyncSpawn:spawn(c,func)
	local ID = os.time() .. "-" .. math.random()
	AsyncSpawn.queuedFuncs[ID] = func
	local cmd = ('echo "local str = [==[`%s`]==];AsyncSpawn:handleCallback(%q,str)" | cwctl'):format(
		c,ID
	)
	-- local a =io.open('/tmp/e','w')
	-- a:write(cmd)
	-- a:close()
	-- notifySend(cmd)
	cwc.spawn_with_shell(cmd)
end

return mod