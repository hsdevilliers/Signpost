-- Core: namespace, version, localization fallback, error isolation and the event bus.
-- Loaded before the libraries so that Core/Errors.lua also records errors raised while they load.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local function metadata(field)
	local ok, value = pcall(GetAddOnMetadata, ADDON_NAME, field)
	if ok and type(value) == "string" and value ~= "" then
		return value
	end
end

-- "@project-version@" is replaced by tools/package.py in release zips; a git checkout reports "dev".
local version = metadata("Version")
if not version or version:find("@", 1, true) then
	version = "dev"
end
ns.version = version
ns.isDev = version == "dev"

-- Which TOC file the client loaded: each TOC carries its own X-Flavor-TOC value (Forever prefers _Camelot; verified on
-- beta 1.60.1.70450).
ns.tocFlavor = metadata("X-Flavor-TOC")

-- Localization: strings are keyed by their enUS text, and a key without a translation is its own text.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

-- Error isolation ---------------------------------------------------------------------------------------------------

local function errorHandler(err)
	return geterrorhandler()(err)
end

-- WoW's xpcall passes extra arguments on to the function; stock Lua 5.1 (used by the tests) does not.
local XPCALL_PASSES_ARGS = select(
	2,
	xpcall(function(...)
		return select("#", ...)
	end, errorHandler, true)
) == 1

-- Runs fn(...) so that an error goes to the current error handler (and Core/Errors.lua) instead of unwinding into
-- the caller. Returns true plus fn's results, or false.
function ns.SafeCall(fn, ...)
	if XPCALL_PASSES_ARGS then
		return xpcall(fn, errorHandler, ...)
	end
	local n, args = select("#", ...), { ... }
	return xpcall(function()
		return fn(unpack(args, 1, n))
	end, errorHandler)
end

-- Event bus ---------------------------------------------------------------------------------------------------------
-- Game events arrive on one frame; internal messages (e.g. "DB_READY", fired once SavedVariables are ready) are fired
-- directly. Both are dispatched by Events:Fire, each handler under SafeCall so one failing module cannot stop the rest.

local Events = { handlers = {}, registered = {} }
ns.Events = Events

local eventFrame = CreateFrame("Frame")

-- Handler lists are replaced, never mutated, so a Fire in progress keeps iterating the list it started with.
local function withHandler(list, fn)
	local copy = {}
	for i = 1, #list do
		copy[i] = list[i]
	end
	copy[#copy + 1] = fn
	return copy
end

function Events:Fire(name, ...)
	local list = self.handlers[name]
	if not list then
		return
	end
	for i = 1, #list do
		ns.SafeCall(list[i], name, ...)
	end
end

-- Registers fn(event, ...) for a game event. Returns false (and registers nothing) if the client rejects the event.
function Events:Register(event, fn)
	if not self.registered[event] then
		if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
			return false
		end
		self.registered[event] = true
	end
	self.handlers[event] = withHandler(self.handlers[event] or {}, fn)
	return true
end

-- Registers fn(message, ...) for an internal message.
function Events:RegisterMessage(message, fn)
	self.handlers[message] = withHandler(self.handlers[message] or {}, fn)
end

function Events:Unregister(name, fn)
	local list = self.handlers[name]
	if not list then
		return
	end
	local kept = {}
	for i = 1, #list do
		if list[i] ~= fn then
			kept[#kept + 1] = list[i]
		end
	end
	if #kept > 0 then
		self.handlers[name] = kept
		return
	end
	self.handlers[name] = nil
	if self.registered[name] then
		eventFrame:UnregisterEvent(name)
		self.registered[name] = nil
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	Events:Fire(event, ...)
end)
