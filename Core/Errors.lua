-- Keeps the last MAX_ERRORS Lua errors (from any addon; `ours` marks Signpost's) in SignpostDB.errors, the channel
-- through which errors reach tools/read_savedvars.py. Errors raised before SavedVariables load wait in `pending`.
local ADDON_NAME, ns = ...

local Errors = { pending = {} }
ns.Errors = Errors

local MAX_ERRORS = 50
local MAX_MESSAGE = 1000
local MAX_STACK = 3000

local function trim(list)
	while #list > MAX_ERRORS do
		table.remove(list, 1)
	end
end

function Errors:Record(message, stack)
	message = tostring(message or "?"):sub(1, MAX_MESSAGE)
	stack = stack and tostring(stack):sub(1, MAX_STACK) or nil
	local list = ns.db and ns.db.errors or self.pending
	local now = time()
	-- A repeat moves to the end with its count raised, so the list holds the 50 most recently seen distinct errors.
	for i = #list, 1, -1 do
		local entry = list[i]
		if entry.msg == message then
			table.remove(list, i)
			entry.count = (entry.count or 1) + 1
			entry.last = now
			list[#list + 1] = entry
			return entry
		end
	end
	local entry = {
		msg = message,
		stack = stack,
		count = 1,
		first = now,
		last = now,
		version = ns.version,
		ours = (message .. (stack or "")):find(ADDON_NAME, 1, true) ~= nil,
	}
	list[#list + 1] = entry
	trim(list)
	return entry
end

local function install()
	if BugGrabber and BugGrabber.RegisterCallback then
		-- BugGrabber owns the error handler when it is installed; listen to it rather than replacing it.
		BugGrabber.RegisterCallback(Errors, "BugGrabber_BugGrabbed", function(_, err)
			Errors:Record(err and err.message, err and err.stack)
		end)
		Errors.source = "BugGrabber"
		return
	end
	-- Works on Forever: verified on beta 1.60.1.70450 (FOREVER-API-NOTES, Verified).
	local previous = geterrorhandler()
	seterrorhandler(function(message, ...)
		pcall(Errors.Record, Errors, message, debugstack(2))
		if previous then
			return previous(message, ...)
		end
	end)
	Errors.source = "seterrorhandler"
end

install()

ns.Events:RegisterMessage("DB_READY", function()
	local list = ns.db.errors
	for _, entry in ipairs(Errors.pending) do
		list[#list + 1] = entry
	end
	Errors.pending = {}
	trim(list)
end)
