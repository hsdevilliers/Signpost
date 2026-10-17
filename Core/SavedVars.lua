-- SignpostDB (account) and SignpostCharDB (character): defaults, versioned migrations, and the DB_READY message.
local ADDON_NAME, ns = ...

local SavedVars = {}
ns.SavedVars = SavedVars

SavedVars.DB_VERSION = 1
SavedVars.CHAR_VERSION = 2

-- probe and mapDump are written on demand by /signpost probe and /signpost dumpmaps.
SavedVars.defaults = {
	settings = {},
	framePos = {},
	learned = { npcs = {}, objects = {}, taxi = {}, crossings = {} },
	reports = {},
	errors = {},
	debug = { enabled = false, chat = false, counts = {} },
	eventLog = {},
	posLog = {},
}

-- `guide` (the selected guide id) is set by the guide registry; progress is kept per guide id. The profession plan is
-- detected, not stored (PLAN §3.8); only the professions a character declined will be kept here.
SavedVars.charDefaults = {
	progress = {},
	automation = {},
}

-- migrations[n] upgrades a table from version n - 1 to n.
SavedVars.migrations = {}
SavedVars.charMigrations = {
	-- 2: the detected profession plan (with per-profession decline) replaces the all-or-nothing hideProfessions flag.
	[2] = function(db)
		db.hideProfessions = nil
	end,
}

function SavedVars.ApplyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = type(value) == "table" and ns.Util.CopyTable(value) or value
		elseif type(value) == "table" and type(target[key]) == "table" then
			SavedVars.ApplyDefaults(target[key], value)
		end
	end
	return target
end

function SavedVars.Upgrade(db, migrations, latest)
	if next(db) ~= nil then
		for version = (db.dbVersion or 0) + 1, latest do
			if migrations[version] then
				migrations[version](db)
			end
		end
	end
	db.dbVersion = latest
end

function SavedVars:Init()
	if type(SignpostDB) ~= "table" then
		SignpostDB = {}
	end
	if type(SignpostCharDB) ~= "table" then
		SignpostCharDB = {}
	end
	self.Upgrade(SignpostDB, self.migrations, self.DB_VERSION)
	self.Upgrade(SignpostCharDB, self.charMigrations, self.CHAR_VERSION)
	self.ApplyDefaults(SignpostDB, self.defaults)
	self.ApplyDefaults(SignpostCharDB, self.charDefaults)
	ns.db, ns.char = SignpostDB, SignpostCharDB

	local clientVersion, build, _, interface = GetBuildInfo()
	SignpostDB.lastLoad = {
		time = time(),
		version = ns.version,
		toc = ns.tocFlavor,
		client = clientVersion,
		build = build,
		interface = interface,
	}
end

local function onAddonLoaded(event, name)
	if name ~= ADDON_NAME then
		return
	end
	ns.Events:Unregister(event, onAddonLoaded)
	SavedVars:Init()
	ns.Events:Fire("DB_READY")
end

ns.Events:Register("ADDON_LOADED", onAddonLoaded)
