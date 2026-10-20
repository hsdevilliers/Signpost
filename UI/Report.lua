-- "Report this step": a way to flag a step that is wrong, from the game. It records the guide, the step, the
-- character's level and map position and an optional note into SignpostDB.reports (a small, bounded list). Nothing is
-- sent anywhere; the reports travel with the rest of the saved data when the player shares the file
-- (docs/SHARING-DATA.md), and `/signpost export` shows them.
-- /signpost report [note]   report the current step, with a note if given
-- /signpost report count    how many reports are saved
local ADDON_NAME, ns = ...
local L = ns.L
local Util = ns.Util

local Report = {}
ns.Report = Report

Report.MAX_REPORTS = 200 -- the oldest goes first
Report.MAX_NOTE = 300

-- A note as plain text on one line: control characters become spaces, the length is capped.
local function cleanNote(note)
	if type(note) ~= "string" or Util.IsSecret(note) then
		return nil
	end
	note = note:gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
	if note == "" then
		return nil
	end
	return note:sub(1, Report.MAX_NOTE)
end

-- Adds a report for `step` (the current step when nil). Returns the entry, or nil when there is nothing to report on.
function Report:Add(step, note)
	local reports = ns.db and ns.db.reports
	local progress = ns.Progress
	if type(reports) ~= "table" then
		return nil
	end
	step = step or (progress and progress.Current and progress:Current())
	if not step then
		Util.Print(L["There is no current step to report."])
		return nil
	end
	local guide = progress and progress.Guide and progress:Guide()
	local pos = Util.PlayerPosition()
	local entry = {
		t = time(),
		guide = guide and guide.id or nil,
		step = step.id,
		level = ns.Player and ns.Player.level or nil,
		version = ns.version,
		note = cleanNote(note),
	}
	if pos and pos.map then
		entry.map, entry.x, entry.y = pos.map, pos.x, pos.y
	end
	reports[#reports + 1] = entry
	while #reports > Report.MAX_REPORTS do
		table.remove(reports, 1)
	end
	ns.Events:Fire("REPORT_ADDED", entry)
	Util.Print(L["Reported step %s. Thank you."], tostring(step.id))
	return entry
end

function Report:Count()
	local reports = ns.db and ns.db.reports
	return type(reports) == "table" and #reports or 0
end

ns.Slash:Register("report", function(args)
	local text = (args or ""):match("^%s*(.-)%s*$")
	if text:lower() == "count" then
		Util.Print(L["%d step reports are saved."], Report:Count())
		return
	end
	Report:Add(nil, text)
end, L["report the current step as wrong: report [note] | report count"])
