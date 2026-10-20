-- The guides and chapters the addon ships (Guides/, as listed in the TOC), through the real parser as the client runs
-- it: every guide must parse without errors for the character it is for, and come out with steps. The offline lint
-- reads the same files, but only this checks them the way the game will.
local addon = dofile("tests/helpers/addon.lua")

local function shippedFiles()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		if line:find("^Guides\\") and not line:find("^Guides\\Travel\\") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

local function first(list, default)
	if type(list) == "table" and type(list[1]) == "string" and list[1] ~= "*" then
		return list[1]
	end
	return default
end

describe("the shipped guides", function()
	local ns = addon.load({ extra = shippedFiles(), login = false })
	local guides = ns.Guides:All()

	it("ships at least the two Release 1 routes written so far", function()
		local ids = {}
		for _, def in ipairs(guides) do
			ids[def.id] = true
		end
		assert.is_true(ids["horde-tauren-druid"])
		assert.is_true(ids["horde-troll-hunter"])
	end)

	for _, def in ipairs(guides) do
		describe(def.id, function()
			local player = {
				class = first(def.classes, "Hunter"),
				classFile = first(def.classes, "HUNTER"),
				race = first(def.races, "Troll"),
				raceFile = first(def.races, "Troll"),
				faction = def.faction == "*" and "Horde" or def.faction,
				level = 1,
				professions = {},
			}
			local guide = ns.Parser:ParseGuide(def, { player = player })

			it("parses without errors", function()
				local messages = {}
				for _, err in ipairs(guide.errors) do
					messages[#messages + 1] = type(err) == "table" and (err.message or err.text or tostring(err[1]))
						or tostring(err)
				end
				assert.are.same({}, messages)
			end)

			it("has chapters and steps, each step with at least one directive", function()
				assert.is_true(#guide.chapters > 0)
				assert.is_true(#guide.steps > 0)
				for _, step in ipairs(guide.steps) do
					assert.is_true(#step.directives > 0, step.id)
				end
			end)

			it("is selected for a character of its race and class", function()
				local best = ns.Guides:Best(player)
				assert.are.equal(def.id, best and best.id)
			end)

			-- A doing step (a .complete and no place directive) is left to the quest log's own marks: nothing of it
			-- is drawn, whatever the quests and the data pack, and its lines are its quests.
			it("draws no markers for its doing steps", function()
				for _, step in ipairs(guide.steps) do
					if ns.Conditions:IsDoingStep(step) then
						assert.are.same({}, ns.Conditions:Targets(step, ns.Context, {}), step.id)
					end
				end
			end)
		end)
	end
end)
