-- The profession modules the addon ships (Professions/, as listed in the TOC): every one registers with the skill
-- line the beta client reported (FOREVER-API-NOTES "Professions"), the right primary or secondary flag, and the
-- Classic rank caps that VERIFY(launch) marks. The offline lint reads the same files; this checks them as loaded.
local addon = dofile("tests/helpers/addon.lua")

local function shippedFiles()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		if line:find("^Professions\\") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

-- key = { skill line, primary, gathering }: what C_TradeSkillUI.GetProfessionSkillLineID returned on 1.60.1.70450.
local EXPECTED = {
	alchemy = { 171, true, false },
	blacksmithing = { 164, true, false },
	enchanting = { 333, true, false },
	engineering = { 202, true, false },
	herbalism = { 182, true, true },
	leatherworking = { 165, true, false },
	mining = { 186, true, true },
	skinning = { 393, true, true },
	tailoring = { 197, true, false },
	cooking = { 185, false, false },
	firstaid = { 129, false, false },
	fishing = { 356, false, true },
}

describe("the shipped profession modules", function()
	local ns, mock = addon.load({ extra = shippedFiles(), login = false })

	it("loads every module without a report", function()
		assert.are.equal(12, #shippedFiles())
		assert.are.same({}, mock.errors)
	end)

	for key, expected in pairs(EXPECTED) do
		it(string.format("registers %s with skill line %d", key, expected[1]), function()
			local module = ns.Professions:Get(key)
			assert.is_table(module)
			assert.are.equal(expected[1], module.skillLine)
			assert.are.equal(expected[2], module.primary)
			assert.are.equal(expected[3], module.gathering)
			assert.are.same({ 75, 150, 225, 300 }, module.ranks)
			local found = ns.Professions:ForSkillLine(expected[1])
			assert.are.equal(key, found)
		end)
	end

	it("has nine primary and three secondary professions, each skill line once", function()
		local primary, secondary, lines = 0, 0, {}
		for key in pairs(EXPECTED) do
			local module = ns.Professions:Get(key)
			if module.primary then
				primary = primary + 1
			else
				secondary = secondary + 1
			end
			assert.is_nil(lines[module.skillLine], key)
			lines[module.skillLine] = true
		end
		assert.are.equal(9, primary)
		assert.are.equal(3, secondary)
	end)
end)
