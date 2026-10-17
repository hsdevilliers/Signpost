-- Scriptable learned professions for specs: GetProfessions (any number of values) and GetProfessionInfo in the retail
-- return order, and optionally C_TradeSkillUI's primary flag per skill line. tests/wow_mock.lua does not reset
-- GetProfessions/GetProfessionInfo, so specs call uninstall after each test.
local M = {}

-- A profession index is not the slot number on the real client; keep them apart so the code cannot mix them up.
local INDEX_BASE = 40

-- learned: { [slot] = { skillLine = id, name = text, rank = n, max = n } }, changeable during a test.
-- opts.slots: how many values GetProfessions returns (Forever: 7). opts.primaries: { [skillLine] = true } served by
-- C_TradeSkillUI.GetProfessionInfoBySkillLineID (installed only when given; C_TradeSkillUI is reset by wow_mock).
function M.install(G, learned, opts)
	opts = opts or {}
	local client = { learned = learned or {}, slots = opts.slots or 7, infoCalls = 0 }
	function G.GetProfessions()
		local values = {}
		for slot = 1, client.slots do
			if client.learned[slot] then
				values[slot] = INDEX_BASE + slot
			end
		end
		return unpack(values, 1, client.slots)
	end
	function G.GetProfessionInfo(index)
		client.infoCalls = client.infoCalls + 1
		local entry = client.learned[index - INDEX_BASE]
		if entry then
			local name, icon = entry.name or ("Profession " .. entry.skillLine), 136000 + entry.skillLine
			-- name, icon, rank, max, spells, spell offset, skill line, modifier, spec index, spec offset, line name
			return name, icon, entry.rank or 1, entry.max or 75, 2, 0, entry.skillLine, 0, 0, 0, name
		end
	end
	if opts.primaries then
		G.C_TradeSkillUI = {
			GetProfessionInfoBySkillLineID = function(skillLine)
				return { professionID = skillLine, isPrimaryProfession = opts.primaries[skillLine] == true }
			end,
		}
	end
	return client
end

function M.uninstall(G)
	G.GetProfessions = nil
	G.GetProfessionInfo = nil
end

return M
