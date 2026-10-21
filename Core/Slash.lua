-- /signpost (alias /sign): a registry of subcommands. Modules add their own with ns.Slash:Register.
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Slash = { commands = {} }
ns.Slash = Slash

-- Dev-loop marker (PLAN Phase 0 acceptance): change it, /reload, run /signpost ping, /reload again, and
-- tools/read_savedvars.py ping shows the new text.
local PING_TEXT = "pong 2: edited after the first beta run"

-- A command is one word ("place"), or two ("reset progress"): a two-word command wins over its first word, which keeps
-- its own meaning for everything else typed after it (`/signpost reset` is still the step frame's).
function Slash:Register(name, fn, help)
	self.commands[name] = { fn = fn, help = help }
end

function Slash:Run(input)
	local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = command:lower()
	if command == "" then
		-- /signpost alone opens the Journal once it exists; /signpost help lists the commands
		local journal = ns.Journal
		if journal and journal.Toggle then
			ns.SafeCall(journal.Toggle, journal)
			return
		end
		command = "help"
	end
	local entry = self.commands[command]
	local word, after = rest:match("^(%S+)%s*(.-)$")
	local two = word and self.commands[command .. " " .. word:lower()]
	if two then
		entry, rest = two, after
	end
	if not entry then
		Util.Print(L["Unknown command '%s'."], command)
		entry = self.commands.help
	end
	ns.SafeCall(entry.fn, rest)
end

Slash:Register("help", function()
	Util.Print(L["%s %s. Commands:"], ADDON_NAME, ns.version)
	local names = {}
	for name in pairs(Slash.commands) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		Util.Print("  /signpost %s - %s", name, Slash.commands[name].help or "")
	end
end, L["list commands"])

Slash:Register("status", function()
	local _, build, _, interface = GetBuildInfo()
	Util.Print(
		L["version %s, client build %s, interface %s, TOC %s"],
		ns.version,
		tostring(build),
		tostring(interface),
		tostring(ns.tocFlavor)
	)
	Util.Print(L["data pack: %s"], ns.Data:Describe())
	Util.Print(L["Lua errors recorded: %d"], #ns.db.errors)
end, L["version, client build, data pack and error count"])

Slash:Register("ping", function()
	ns.db.ping = { text = PING_TEXT, time = time(), version = ns.version }
	Util.Print(L["%s (saved; /reload writes it to disk)"], PING_TEXT)
end, L["store a marker for tools/read_savedvars.py (dev check)"])

Slash:Register("errors", function(args)
	local list = ns.db.errors
	if args == "clear" then
		wipe(list)
		Util.Print(L["Error list cleared."])
		return
	end
	Util.Print(L["Lua errors recorded: %d"], #list)
	for i = math.max(1, #list - 2), #list do
		local entry = list[i]
		Util.Print("  [%dx] %s", entry.count or 1, (entry.msg or ""):match("^[^\n]*"))
	end
end, L["show the last recorded Lua errors ('errors clear' empties the list)"])

Slash:Register("export", function()
	local payload = {
		addon = ADDON_NAME,
		version = ns.version,
		exported = time(),
		learned = ns.db.learned,
		reports = ns.db.reports,
		pace = ns.char and ns.char.pace,
	}
	ns.UI:ShowTextDialog(L["Signpost export (Ctrl+C to copy)"], Util.ToJSON(payload, "  "))
end, L["show learned data as JSON to copy"])

SLASH_SIGNPOST1 = "/signpost"
-- No other command claims /sign (probe on beta 1.60.1.70450); /signpost probe keeps checking for collisions.
SLASH_SIGNPOST2 = "/sign"
SlashCmdList.SIGNPOST = function(input)
	Slash:Run(input)
end

-- Named in both TOCs as ## AddonCompartmentFunc.
function Signpost_OnAddonCompartmentClick()
	Slash:Run("")
end

ns.Events:Register("PLAYER_LOGIN", function()
	if ns.isDev then
		Util.Print(L["%s (dev) loaded. Data pack: %s. Type /signpost for commands."], ADDON_NAME, ns.Data:Describe())
	end
end)
