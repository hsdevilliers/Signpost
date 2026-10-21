-- The profession route tracks the addon ships (Guides/Professions/, as listed in the TOC): the five of the Troll
-- Hunter's default plan, read by the real parser, merged by the real engine into the shipped Troll Hunter guide and
-- walked by it. The route's chapters are written by the planner and regenerated from time to time, so nothing here
-- names one of their ids or step numbers: a track step is checked against its anchor (the map of the route step it
-- lands before), never against a place in a file. tests/professions_spec.lua has the merge rules on a made-up route.
local addon = dofile("tests/helpers/addon.lua")
local contextMock = dofile("tests/mocks/context.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local KEYS = { "skinning", "leatherworking", "firstaid", "cooking", "fishing" }
local DEFAULT_PLAN = { primary = { "skinning", "leatherworking" }, secondary = { "firstaid", "cooking", "fishing" } }

local function character(raceFile, classFile)
	return {
		class = classFile,
		classFile = classFile,
		race = raceFile,
		raceFile = raceFile,
		faction = "Horde",
		level = 1,
		professions = {},
	}
end

local TROLL_HUNTER = character("Troll", "HUNTER")
-- A race no gate names: what is left of a track for it are the steps that are for everyone.
local NOBODY = character("Nobody", "HUNTER")

-- The guides, chapters, tracks and profession modules the TOC lists (the specs of the engine register their own).
local function shippedFiles()
	local files = {}
	for line in io.lines("Signpost.toc") do
		line = line:gsub("\r$", "")
		if (line:find("^Guides\\") and not line:find("^Guides\\Travel\\")) or line:find("^Professions\\") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

-- The map tree the client reports for the towns of the route (docs/FOREVER-API-NOTES.md: a capital is a sibling of its
-- zone), so an @zone anchor tests "in this map or below it" as in the game.
local MAPS = {
	[947] = { mapID = 947, parentMapID = 0 },
	[1414] = { mapID = 1414, parentMapID = 947 },
	[1415] = { mapID = 1415, parentMapID = 947 },
}
for _, id in ipairs({ 1411, 1412, 1413, 1440, 1441, 1442, 1454, 1456 }) do
	MAPS[id] = { mapID = id, parentMapID = 1414 }
end
for _, id in ipairs({ 1420, 1421, 1424, 1458 }) do
	MAPS[id] = { mapID = id, parentMapID = 1415 }
end

-- The uiMapID of a route step's first .goto or .path (what an @zone anchor reads).
local function firstMap(step)
	for _, directive in ipairs(step.directives) do
		if directive.name == "goto" then
			return directive.args.map
		elseif directive.name == "path" then
			return directive.args.points[1].map
		end
	end
end

local function directivesNamed(step, name)
	local found = {}
	for _, directive in ipairs(step.directives) do
		if directive.name == name then
			found[#found + 1] = directive
		end
	end
	return found
end

local function stickyNamed(step, name)
	local found = {}
	for _, directive in ipairs(step.sticky) do
		if directive.name == name then
			found[#found + 1] = directive
		end
	end
	return found
end

local function routeIds(guide)
	local ids = {}
	for _, step in ipairs(guide.steps) do
		if not step.track then
			ids[#ids + 1] = step.id
		end
	end
	return ids
end

local function messages(guide)
	local list = {}
	for i, entry in ipairs(guide.errors) do
		list[i] = entry.message
	end
	return list
end

describe("the shipped profession tracks", function()
	local ns = addon.load({ extra = shippedFiles(), login = false })
	G.C_Map = {
		GetMapInfo = function(id)
			return MAPS[id]
		end,
	}
	local def = ns.Guides:Get("horde-troll-hunter")
	local suggestions = ns.Parser:Headers(def).professions
	local plan = ns.Professions:Plan(suggestions)

	local function parseTrack(key, player)
		return ns.Parser:ParseTrack(key, ns.Professions:Track(key), { player = player, plan = plan, guideId = def.id })
	end

	local route = ns.Parser:ParseGuide(def, { player = TROLL_HUNTER })
	local merged = ns.Parser:ParseGuide(def, { player = TROLL_HUNTER, plan = plan })

	describe("the files", function()
		it("are suggested by the Troll Hunter guide as exactly its default plan", function()
			assert.are.same(KEYS, suggestions)
			assert.are.same(DEFAULT_PLAN.primary, plan.primary)
			assert.are.same(DEFAULT_PLAN.secondary, plan.secondary)
			assert.are.same({}, plan.unknown)
		end)

		it("register one track per profession of the plan, each starting with its own key", function()
			for _, key in ipairs(KEYS) do
				local text = ns.Professions:Track(key)
				assert.is_string(text, key)
				assert.is_truthy(text:find("^#track " .. key .. "\n"), key)
			end
			assert.are.same({}, ns.Professions.problems)
		end)

		for _, key in ipairs(KEYS) do
			describe(key, function()
				local steps, errors = parseTrack(key, TROLL_HUNTER)

				it("parses without errors into steps that each have an @zone or @level anchor, never a hub", function()
					assert.are.same({}, errors)
					assert.is_true(#steps >= 3)
					for _, step in ipairs(steps) do
						assert.is_truthy(step.anchor.kind == "zone" or step.anchor.kind == "level", step.id)
					end
				end)

				it("names its own profession in every .trainprof and .skill", function()
					for _, step in ipairs(steps) do
						for _, directive in ipairs(directivesNamed(step, "trainprof")) do
							assert.are.equal(key, directive.args.key, step.id)
						end
						for _, directive in ipairs(stickyNamed(step, "skill")) do
							assert.are.equal(key, directive.args.key, step.id)
						end
					end
				end)

				it("teaches the profession in its first .trainprof step, the track's first step", function()
					local first
					for _, step in ipairs(steps) do
						if #directivesNamed(step, "trainprof") > 0 then
							first = first or step
						end
					end
					assert.are.equal(steps[1], first)
					-- Skipping that step declines the profession (Engine/Progress.lua): it carries the skill goal that
					-- rides beside the route afterwards
					assert.are.equal(1, #stickyNamed(first, "skill"))
				end)

				it("sends a step with a position to the town of its anchor", function()
					for _, step in ipairs(steps) do
						for _, directive in ipairs(directivesNamed(step, "goto")) do
							assert.are.equal("zone", step.anchor.kind, step.id)
							assert.are.equal(step.anchor.value, directive.args.map, step.id)
						end
					end
				end)

				it("gates every step with a position to a race, so other guides get none of them", function()
					for _, step in ipairs(parseTrack(key, NOBODY)) do
						assert.are.same({}, directivesNamed(step, "goto"), step.id)
					end
				end)
			end)
		end
	end)

	describe("merged into the shipped Troll Hunter guide with the default plan", function()
		it("keeps the route as it is, steps and order", function()
			assert.are.same(routeIds(route), routeIds(merged))
			assert.are.same(plan, merged.plan)
		end)

		it("lands every step of every track, in track order, but the ones above the guide's levels", function()
			local expectedErrors = {}
			for _, key in ipairs(KEYS) do
				local landed, last = {}, 0
				for _, step in ipairs(parseTrack(key, TROLL_HUNTER)) do
					if step.anchor.kind == "level" and step.anchor.value > def.levels[2] then
						-- Version 1 stops at level 30: the engine drops the step (and says so), the lint only notes it
						assert.is_nil(merged.byId[step.id], step.id)
						expectedErrors[#expectedErrors + 1] = "No route step matches @level " .. step.anchor.value
					else
						local placed = merged.byId[step.id]
						assert.is_table(placed, step.id)
						assert.is_true(placed.index > last, step.id)
						last = placed.index
						landed[#landed + 1] = step.id
					end
				end
				assert.is_true(#landed >= 3, key)
			end
			assert.are.same(expectedErrors, messages(merged))
		end)

		it("puts each @zone step before the first route step of its map after the track's previous step", function()
			for _, key in ipairs(KEYS) do
				local previous = 0
				for i, step in ipairs(merged.steps) do
					if step.track == key then
						if step.anchor.kind == "zone" then
							local after
							for j = i + 1, #merged.steps do
								if not merged.steps[j].track then
									after = merged.steps[j]
									break
								end
							end
							assert.are.equal(step.anchor.value, firstMap(after), step.id)
							assert.are.equal(after.chapter, step.chapter, step.id) -- the chapter of the visit it opens
							for j = previous + 1, i - 1 do
								if not merged.steps[j].track then
									assert.are_not.equal(step.anchor.value, firstMap(merged.steps[j]), step.id)
								end
							end
						end
						previous = i
					end
				end
			end
		end)

		-- The level each step of a track needs, in track order (Classic's: the notes say them). A rank step does not check
		-- the level itself, so a regenerated route that reaches a town too early is noticed here.
		local NEEDS = {
			skinning = { 5, 10, 20, 20 },
			leatherworking = { 5, 10, 20, 20 },
			firstaid = { 5, 10, 10 },
			cooking = { 5, 10, 10 },
			fishing = { 5, 10, 10 },
		}

		it("lands each step in a chapter whose levels reach what its rank needs (Classic's levels)", function()
			for _, key in ipairs(KEYS) do
				local n = 0
				for _, step in ipairs(merged.steps) do
					if step.track == key then
						n = n + 1
						assert.is_true(merged.chapters[step.chapter].levels[1] >= NEEDS[key][n], step.id)
					end
				end
				assert.are.equal(#NEEDS[key], n, key)
			end
		end)

		it("opens each visit to a town with the tracks' steps for it in plan order", function()
			-- the five learn steps come one after the other, before the first route step in Orgrimmar
			local start = merged.byId["track:skinning:1"].index
			for offset, key in ipairs(KEYS) do
				assert.are.equal("track:" .. key .. ":1", merged.steps[start + offset - 1].id)
			end
			assert.are.equal(1454, firstMap(merged.steps[start + #KEYS]))
			-- and the next rank at Undercity, one step per track, again in plan order
			local undercity = merged.byId["track:skinning:2"].index
			for offset, key in ipairs(KEYS) do
				assert.are.equal("track:" .. key .. ":2", merged.steps[undercity + offset - 1].id)
			end
			assert.are.equal(1458, firstMap(merged.steps[undercity + #KEYS]))
		end)

		it("leaves the specialization for level 40, outside the guide, as the one dropped step", function()
			assert.are.same({ "No route step matches @level 40" }, messages(merged))
			assert.are.same({ "track:leatherworking" }, { merged.errors[1].source })
		end)
	end)

	describe("with a plan that lacks them", function()
		local function steps(guide)
			local list = {}
			for _, step in ipairs(guide.steps) do
				if step.track then
					list[#list + 1] = step.id
				end
			end
			return list
		end

		it("adds nothing for a character with no profession in the plan", function()
			local guide = ns.Parser:ParseGuide(def, { player = TROLL_HUNTER, plan = { primary = {}, secondary = {} } })
			assert.are.same(routeIds(route), routeIds(guide))
			assert.are.same({}, steps(guide))
			assert.are.same({}, guide.errors)
		end)

		it("merges the tracks of the professions in the plan and no others", function()
			local guide = ns.Parser:ParseGuide(def, {
				player = TROLL_HUNTER,
				plan = { primary = { "skinning" }, secondary = { "fishing" } },
			})
			assert.are.same(routeIds(route), routeIds(guide))
			assert.is_not_nil(guide.byId["track:skinning:1"])
			assert.is_not_nil(guide.byId["track:fishing:1"])
			for _, id in ipairs(steps(guide)) do
				assert.is_truthy(id:find("^track:skinning:") or id:find("^track:fishing:"), id)
			end
			assert.are.same({}, guide.errors) -- the leatherworking step above level 30 is not merged without it
		end)

		it("keeps the route whole for professions that have no track", function()
			-- keys no track will ever have; tests/professions_spec.lua runs the PLAN section 3.8 seam test (a character
			-- with other professions) on a made-up route
			local guide = ns.Parser:ParseGuide(def, {
				player = TROLL_HUNTER,
				plan = { primary = { "juggling", "knitting" }, secondary = {} },
			})
			assert.are.same(routeIds(route), routeIds(guide))
			assert.are.same({}, steps(guide))
			assert.are.same({
				"No track is registered for profession juggling",
				"No track is registered for profession knitting",
			}, messages(guide))
		end)

		it("is the plain route when the guide is parsed without any plan", function()
			assert.are.same({}, steps(route))
			assert.are.same({}, route.errors)
			assert.is_nil(route.plan)
		end)
	end)
end)

-- The real engine on the real guide: the profession steps as the player meets them ---------------------------------

local sessions = {}

after_each(function()
	for _, session in ipairs(sessions) do
		assert.are.same({}, session.ns.db.errors)
		assert.are.same({}, session.mock.errors)
	end
	sessions = {}
	contextMock.uninstall()
	G.GetProfessions, G.GetProfessionInfo = nil, nil
end)

-- Logs a Troll Hunter in on the scripted client with every shipped file loaded. setup(world) runs before they load.
local function start(setup)
	local world
	local ns, mock = addon.load({
		extra = shippedFiles(),
		login = false,
		before = function(m)
			world = contextMock.install(m)
			if setup then
				setup(world)
			end
		end,
	})
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	world.advance(1)
	sessions[#sessions + 1] = { ns = ns, mock = mock }
	return ns, world, mock
end

local function current(ns)
	local step = ns.Progress:Current()
	return step and step.id
end

-- A client that knows Skinning at `rank` of `max` (skill line 393, the beta client's answer), or none.
local function knowSkinning(rank, max)
	G.GetProfessions = function()
		return 41
	end
	G.GetProfessionInfo = function(index)
		if index == 41 then
			return "Skinning", 134366, rank, max or 75, 1, 0, 393
		end
	end
end

-- Lets the client send an event and enough time pass for Context's refresh and Progress's once-a-second evaluation.
local function event(world, mock, name, ...)
	if name then
		mock.fire(name, ...)
	end
	world.advance(1.1)
end

-- Makes the step just before a track step current and presses `>`, so the engine arrives at the track step as it
-- does on the way (a jump would hold the step by hand).
local function arriveAt(ns, world, stepId)
	local guide = ns.Progress:Guide()
	local index = guide.byId[stepId].index
	assert.is_true(ns.Progress:JumpTo(index - 1))
	world.advance(1.1)
	assert.are.equal(guide.steps[index - 1].id, current(ns))
	ns.Progress:Next()
	world.advance(1.1)
end

-- What the engine hands the step card and the pins for a step: its own lines, its ongoing (sticky) lines and its
-- markers.
local function show(ns, step)
	local states = ns.Progress:State(step.id)
	local lines, info = ns.Conditions:Describe(step, ns.Context, states)
	local own, ongoing = {}, {}
	for i, text in ipairs(lines) do
		table.insert(info[i].sticky and ongoing or own, text)
	end
	return own, ongoing, ns.Conditions:Targets(step, ns.Context, states)
end

local function where(target)
	return { target.kind, target.map, target.x, target.y }
end

describe("the profession steps in the engine", function()
	it("shows the learn step with a trainer pin and, once learned, keeps the skill goal beside the route", function()
		local ns, world, mock = start()
		local guide = ns.Progress:Guide()
		assert.are.same(DEFAULT_PLAN.primary, guide.plan.primary)
		assert.are.same(DEFAULT_PLAN.secondary, guide.plan.secondary)

		arriveAt(ns, world, "track:skinning:1")
		assert.are.equal("track:skinning:1", current(ns))
		local own, ongoing, targets = show(ns, ns.Progress:Current())
		assert.are.equal("Learn Skinning from Thuwd", own[1])
		assert.are.same({ "Raise skinning to 150" }, ongoing)
		assert.are.equal(1, #targets)
		assert.are.same({ "trainer", 1454, 63.36, 45.42 }, where(targets[1]))

		knowSkinning(1)
		event(world, mock, "SKILL_LINES_CHANGED")
		assert.are.equal("track:leatherworking:1", current(ns))
		local sticky = ns.Progress:Sticky()
		assert.are.equal(1, #sticky)
		assert.are.equal("track:skinning:1", sticky[1].id)
		assert.is_true(ns.Progress:IsDone("track:skinning:1"))
		assert.are.same({ "Raise Skinning to 150 (now 1)" }, select(2, show(ns, sticky[1])))

		knowSkinning(150, 150)
		event(world, mock, "CHAT_MSG_SKILL", "skill up")
		assert.are.same({}, ns.Progress:Sticky())
	end)

	it("passes the learn step by itself when the profession is known and far from its cap", function()
		local ns, world = start(function()
			knowSkinning(30)
		end)
		arriveAt(ns, world, "track:skinning:1")
		assert.is_true(ns.Progress:IsDone("track:skinning:1"))
		assert.are.equal("track:leatherworking:1", current(ns))
		local sticky = ns.Progress:Sticky()
		assert.are.equal("track:skinning:1", sticky[1].id)
		assert.are.same({ "Raise Skinning to 150 (now 30)" }, select(2, show(ns, sticky[1])))
	end)

	it("asks for the next rank only once the skill is within 25 of the cap, and passes by itself before", function()
		-- too low for Journeyman: nothing to train, the step passes
		local ns, world = start(function()
			knowSkinning(40, 75)
		end)
		arriveAt(ns, world, "track:skinning:2")
		assert.is_true(ns.Progress:IsDone("track:skinning:2"))
		assert.are_not.equal("track:skinning:2", current(ns))

		-- close enough: the step waits at the trainer, and training (the cap rising) completes it
		local ns2, world2, mock2 = start(function()
			knowSkinning(60, 75)
		end)
		arriveAt(ns2, world2, "track:skinning:2")
		assert.are.equal("track:skinning:2", current(ns2))
		local _, _, targets = show(ns2, ns2.Progress:Current())
		assert.are.same({ "trainer", 1458, 70.16, 59.18 }, where(targets[1]))
		knowSkinning(60, 150)
		event(world2, mock2, "SKILL_LINES_CHANGED")
		assert.is_true(ns2.Progress:IsDone("track:skinning:2"))
		assert.are_not.equal("track:skinning:2", current(ns2))
	end)

	it("declines a profession whose learn step is skipped, takes its track out, and `<` brings it back", function()
		local ns, world = start()
		arriveAt(ns, world, "track:skinning:1")
		assert.are.equal("track:skinning:1", current(ns))

		ns.Progress:Skip()
		local guide = ns.Progress:Guide()
		assert.is_true(ns.char.declinedProfessions.skinning)
		assert.are.same({ "leatherworking" }, guide.plan.primary)
		assert.are.same({ skinning = true }, guide.plan.declined)
		for _, step in ipairs(guide.steps) do
			assert.are_not.equal("skinning", step.track, step.id)
		end
		assert.is_nil(guide.byId["track:skinning:1"])
		assert.is_not_nil(guide.byId["track:leatherworking:1"])
		assert.is_not_nil(guide.byId["track:fishing:3"])
		assert.are.equal("track:leatherworking:1", current(ns))

		ns.Progress:Back()
		assert.is_nil(ns.char.declinedProfessions.skinning)
		assert.are.equal("track:skinning:1", current(ns))
		assert.is_not_nil(ns.Progress:Guide().byId["track:skinning:4"])
	end)

	it("does not decline anything when a later rank step is skipped", function()
		local ns, world = start()
		arriveAt(ns, world, "track:fishing:2")
		assert.are.equal("track:fishing:2", current(ns))
		ns.Progress:Skip()
		assert.is_nil(ns.char.declinedProfessions.fishing)
		assert.is_not_nil(ns.Progress:Guide().byId["track:fishing:3"])
	end)
end)
