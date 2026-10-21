-- The guides and chapters the addon ships (Guides/, as listed in the TOC), through the real parser as the client runs
-- it: every guide must parse without errors for the character it is for, and come out with steps. The offline lint
-- reads the same files, but only this checks them the way the game will.
local addon = dofile("tests/helpers/addon.lua")
-- The fake player state of the directive specs: the engine's calls take the context as an argument.
local mocks = dofile("tests/mocks/directives.lua")

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

			-- A joined pick-up or hand-in step (several .goto lines, each NPC's followed by its directives) has one pin
			-- for each .goto, naming the quests behind it: read here from the step's own directives, against what the
			-- engine pins for a player who has done nothing and has no data pack.
			it("pins each NPC of a joined step with the quests behind its .goto", function()
				local joined = 0
				local CLAIMS = { accept = true, turnin = true, complete = true }
				for _, step in ipairs(guide.steps) do
					local behind, gotos = {}, {}
					for _, directive in ipairs(step.directives) do
						if directive.name == "goto" then
							gotos[#gotos + 1] = directive.args
						elseif CLAIMS[directive.name] then
							-- a directive stands behind the .goto before it; one before the first .goto is behind the first
							local owner = math.max(#gotos, 1)
							behind[owner] = behind[owner] or {}
							local list, questID = behind[owner], directive.args.questID
							local known = false
							for _, other in ipairs(list) do
								known = known or other == questID
							end
							if not known then
								list[#list + 1] = questID
							end
						end
					end
					if #gotos >= 2 and not ns.Conditions:IsDoingStep(step) then
						joined = joined + 1
						local pins = {}
						for _, pin in ipairs(ns.Conditions:Targets(step, mocks.context(), {})) do
							if pin.radius then
								pins[#pins + 1] = pin -- the .goto lines' pins; a .fish or a .path has its own
							end
						end
						assert.are.equal(#gotos, #pins, step.id)
						for i, args in ipairs(gotos) do
							assert.are.same({ args.x, args.y }, { pins[i].x, pins[i].y }, step.id)
							assert.are.same(behind[i] or {}, pins[i].quests or {}, step.id .. " .goto " .. i)
						end
					end
				end
				assert.is_true(joined > 0 or def.id ~= "horde-troll-hunter", "the Troll Hunter route has joined steps")
			end)

			-- A step made only of `.optional` quests (a group quest of a normal route) never holds the player up; once
			-- the player has taken the quest it is the step it would be without the `.optional` line.
			it("never stops at an optional-only step unless the player took its quest", function()
				local seen = 0
				for _, step in ipairs(guide.steps) do
					local only = ns.Conditions:OptionalOnly(step, mocks.context())
					if only then
						seen = seen + 1
						assert.is_true((ns.Conditions:IsComplete(step, mocks.context(), {})), step.id)
						local plain = {}
						for key, value in pairs(step) do
							plain[key] = value
						end
						plain.optional = {} -- the same step with every quest of it counting
						local took = mocks.context()
						for _, questID in ipairs(only.quests) do
							took.log[questID] = true
							took.objectives[questID] = { { text = "something: 0/1", finished = false } }
						end
						assert.are.equal(
							(ns.Conditions:IsComplete(plain, took, {})),
							(ns.Conditions:IsComplete(step, took, {})),
							step.id
						)
					end
				end
				assert.is_true(seen > 0 or def.id ~= "horde-troll-hunter", "the Troll Hunter route has group quests")
			end)

			-- Two real steps of the Troll Hunter route, read by their quests (the planner may renumber them).
			if def.id == "horde-troll-hunter" then
				local function stepWith(...)
					local want = { ... }
					for _, step in ipairs(guide.steps) do
						local have = {}
						for _, directive in ipairs(step.directives) do
							if directive.args and directive.args.questID then
								have[directive.name .. directive.args.questID] = true
							end
						end
						local all = true
						for _, key in ipairs(want) do
							all = all and have[key] == true
						end
						if all then
							return step
						end
					end
					error("the Troll Hunter route has no step with " .. table.concat(want, ", "))
				end

				local function summary(pins)
					local out = {}
					for i, pin in ipairs(pins) do
						out[i] = { pin.kind, pin.x, unpack(pin.quests or {}) }
					end
					return out
				end

				it("pins the NPCs of the opening step one by one, and drops each as its quests are done", function()
					-- the Valley of Trials' first step: one NPC hands over a quest, the next takes it and gives two more
					local step = stepWith("accept4641", "turnin4641", "accept788")
					local context = mocks.context()
					local pins = ns.Conditions:Targets(step, context, {})
					assert.are.same({ { "accept", 43.29, 4641 }, { "turnin", 42.06, 4641, 788, 97279 } }, summary(pins))
					assert.are.equal('Accept "Quest #4641"', pins[1].label)
					assert.are.equal('Turn in "Quest #4641"\nAccept "Quest #788"\nAccept "Quest #97279"', pins[2].label)
					-- the first quest in the log: the first NPC is done, the second's quests are all still to do
					context.log[4641] = true
					assert.are.same(
						{ { "turnin", 42.06, 4641, 788, 97279 } },
						summary(ns.Conditions:Targets(step, context, {}))
					)
					-- handed in, and one of the two new ones taken: the second pin names the one left
					context.log[4641], context.completed[4641], context.log[788] = nil, true, true
					assert.are.same({ { "accept", 42.06, 97279 } }, summary(ns.Conditions:Targets(step, context, {})))
					-- the last one taken: nothing is left to visit, and the step is complete
					context.log[97279] = true
					assert.are.same({}, ns.Conditions:Targets(step, context, {}))
					assert.is_true((ns.Conditions:IsComplete(step, context, {})))
				end)

				it("hands in at two NPCs and offers a group quest at the third, which never holds the step", function()
					-- Silverpine Forest: two hand-ins and a pick-up, then Assault on Fenris Isle (442), a group quest
					local step = stepWith("turnin446", "accept442")
					local context = mocks.context()
					assert.is_nil(ns.Conditions:OptionalOnly(step, context)) -- other quests decide it: not optional-only
					local pins = ns.Conditions:Targets(step, context, {})
					assert.are.equal(3, #pins)
					assert.are.same({ { "turnin", 446, 448 }, { "turnin", 92401 }, { "turnin", 448, 442 } }, {
						{ pins[1].kind, unpack(pins[1].quests) },
						{ pins[2].kind, unpack(pins[2].quests) },
						{ pins[3].kind, unpack(pins[3].quests) },
					})
					-- the three hand-ins done: the group quest, offered at the third NPC, was never needed to move on
					context.completed[446], context.completed[92401], context.completed[448] = true, true, true
					assert.is_true((ns.Conditions:IsComplete(step, context, {})))
					-- and its own steps: the quest is not taken, so they are passed; once taken, they are not
					local doing, handIn = stepWith("complete442"), stepWith("turnin442")
					for _, optional in ipairs({ doing, handIn }) do
						assert.are.same({ 442 }, ns.Conditions:OptionalOnly(optional, context).quests)
						assert.is_true((ns.Conditions:IsComplete(optional, context, {})))
					end
					context.log[442] = true
					context.objectives[442] = { { text = "Fenris Keep: 0/1", finished = false } }
					assert.is_false((ns.Conditions:IsComplete(doing, context, {})))
					context.ready[442] = true
					assert.is_true((ns.Conditions:IsComplete(doing, context, {})))
					assert.is_false((ns.Conditions:IsComplete(handIn, context, {}))) -- ready, not handed in
				end)
			end
		end)
	end
end)
