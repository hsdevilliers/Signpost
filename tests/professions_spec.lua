local addon = dofile("tests/helpers/addon.lua")
local client = dofile("tests/mocks/professions.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

-- Profession modules as Professions/<KEY>.lua registers them (skill lines from the beta probe, FOREVER-API-NOTES).
local MODULES = {
	skinning = { skillLine = 393, primary = true, gathering = true },
	leatherworking = { skillLine = 165, primary = true, gathering = false },
	mining = { skillLine = 186, primary = true, gathering = true },
	herbalism = { skillLine = 182, primary = true, gathering = true },
	firstaid = { skillLine = 129, primary = false, gathering = false },
	cooking = { skillLine = 185, primary = false, gathering = false },
	fishing = { skillLine = 356, primary = false, gathering = true },
}

-- The first guide's "#professions" header.
local SUGGESTIONS = { "skinning", "leatherworking", "firstaid", "cooking", "fishing" }

-- opts.learned: { [slot] = key or { skillLine = id, rank = n, ... } } served by GetProfessions/GetProfessionInfo.
local function clientSlots(learned)
	local slots = {}
	for slot, item in pairs(learned or {}) do
		if type(item) == "table" then
			slots[slot] = item
		else
			slots[slot] = { skillLine = MODULES[item].skillLine, name = item }
		end
	end
	return slots
end

-- Loads the addon with the profession engine on a client with opts.learned professions, empties the registries
-- (profession files that join the TOC later must not change what these tests see), registers MODULES and reads the
-- professions again. Returns ns, the wow mock and the profession mock (change its `learned` to learn or unlearn).
local function load(opts)
	opts = opts or {}
	local professions
	local ns, mock = addon.load({
		extra = { "Engine/Professions.lua" },
		login = opts.login,
		before = function()
			professions =
				client.install(G, clientSlots(opts.learned), { slots = opts.slots, primaries = opts.primaries })
			if opts.before then
				opts.before()
			end
		end,
	})
	local registry = ns.Professions
	for _, list in ipairs({ registry.modules, registry.bySkillLine, registry.tracks, registry.problems }) do
		wipe(list)
	end
	registry.suggestions, registry.current = nil, nil
	for key, module in pairs(MODULES) do
		local copy = {}
		for field, value in pairs(module) do
			copy[field] = value
		end
		registry:Register(key, copy)
	end
	if opts.login ~= false then
		ns.Player:RefreshProfessions()
	end
	return ns, mock, professions
end

local function messages(ns, name)
	local fired = {}
	ns.Events:RegisterMessage(name, function(_, value)
		fired[#fired + 1] = value
	end)
	return fired
end

after_each(function()
	client.uninstall(G)
end)

describe("ns.Player professions", function()
	it("reads every value GetProfessions returns, whatever the count", function()
		for _, count in ipairs({ 5, 7, 9 }) do
			local ns = load({ learned = { [1] = "skinning", [count] = "firstaid" }, slots = count })
			local professions = ns.Player.professions
			assert.are.equal("skinning", professions[393].key)
			assert.are.equal("firstaid", professions[129].key)
			assert.are.equal(count, professions[129].slot)
			client.uninstall(G)
		end
	end)

	it("keeps name, rank, maximum, slot and skill line, keyed by skill line", function()
		local ns = load({ learned = { [2] = { skillLine = 393, name = "Skinning", rank = 42, max = 75 } } })
		assert.are.same(
			{ key = "skinning", name = "Skinning", rank = 42, max = 75, primary = true, slot = 2, skillLine = 393 },
			ns.Player.professions[393]
		)
		assert.are.equal(ns.Player.professions[393], ns.Player:Profession("skinning"))
		assert.is_nil(ns.Player:Profession("mining"))
		assert.is_nil(ns.Player:Profession(nil))
	end)

	it("leaves the key empty for a skill line no module covers", function()
		local ns = load({ learned = { [1] = { skillLine = 171 } } })
		assert.is_nil(ns.Player.professions[171].key)
		assert.are.equal("Profession 171", ns.Player.professions[171].name)
	end)

	it("tells primary from secondary by the module, else the client, else the slot", function()
		local ns = load({
			learned = { [1] = { skillLine = 171 }, [2] = { skillLine = 9999 }, [5] = "cooking" },
			primaries = { [171] = true, [185] = true },
		})
		local professions = ns.Player.professions
		assert.is_true(professions[171].primary) -- the client says so
		assert.is_false(professions[9999].primary) -- the client says so, whatever the slot
		assert.is_false(professions[185].primary) -- the module wins over the client
		G.C_TradeSkillUI = nil
		ns.Player:RefreshProfessions()
		professions = ns.Player.professions
		assert.is_true(professions[171].primary) -- slot 1
		assert.is_true(professions[9999].primary) -- slot 2
		assert.is_false(professions[185].primary)
	end)

	it("counts a skill line once even if two values point at it", function()
		local ns, _, mockProfessions = load({ learned = { [1] = "skinning" } })
		mockProfessions.learned[4] = mockProfessions.learned[1]
		ns.Player:RefreshProfessions()
		assert.are.equal(1, ns.Player.professions[393].slot)
	end)

	it("fires PLAYER_PROFESSIONS_CHANGED when professions change, and only then", function()
		local ns, mock, mockProfessions = load({ learned = { [1] = "skinning" } })
		local fired = messages(ns, "PLAYER_PROFESSIONS_CHANGED")
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(0, #fired)

		mockProfessions.learned[1].rank = 2
		mock.fire("CHAT_MSG_SKILL", "skill up")
		assert.are.equal(1, #fired)
		assert.are.equal(ns.Player.professions, fired[1])
		assert.are.equal(2, fired[1][393].rank)

		mockProfessions.learned[2] = { skillLine = 165 }
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(2, #fired)
		assert.are.equal("leatherworking", ns.Player.professions[165].key)

		mockProfessions.learned[1] = nil
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(3, #fired)
		assert.is_nil(ns.Player.professions[393])
	end)

	it("reads the professions at login", function()
		local ns = addon.load({
			extra = { "Engine/Professions.lua" },
			before = function()
				client.install(G, clientSlots({ [1] = "skinning" }))
			end,
		})
		assert.are.equal(393, ns.Player.professions[393].skillLine)
		assert.are.equal(1, ns.Player.professions[393].slot)
	end)

	it("is empty on a client without the profession API, and skips secret values", function()
		local ns = load({ learned = { [1] = "skinning", [2] = "mining" } })
		G.issecretvalue = function(value)
			return value == 186
		end
		ns.Player:RefreshProfessions()
		assert.is_table(ns.Player.professions[393])
		assert.is_nil(ns.Player.professions[186])
		client.uninstall(G)
		ns.Player:RefreshProfessions()
		assert.are.same({}, ns.Player.professions)
	end)
end)

describe("ns.Professions registry", function()
	it("registers modules by key and skill line", function()
		local ns = load()
		local key, module = ns.Professions:ForSkillLine(393)
		assert.are.equal("skinning", key)
		assert.are.equal(ns.Professions:Get("skinning"), module)
		assert.is_true(module.primary)
		assert.is_nil(ns.Professions:ForSkillLine(171))
		assert.is_nil(ns.Professions:ForSkillLine(nil))
		assert.is_nil(ns.Professions:Get(nil))
		assert.are.same({}, ns.Professions.problems)
	end)

	it("refuses a module without a key, a table or a skill line", function()
		local ns = load()
		assert.is_false(ns.Professions:Register(nil, { skillLine = 1 }))
		assert.is_false(ns.Professions:Register("alchemy", "module"))
		assert.is_false(ns.Professions:Register("alchemy", { primary = true }))
		assert.is_nil(ns.Professions:Get("alchemy"))
		assert.are.equal(3, #ns.Professions.problems)
	end)

	it("uses the later of two modules with one key, and reports a shared skill line", function()
		local ns = load()
		local replacement = { skillLine = 9393, primary = true }
		ns.Professions:Register("skinning", replacement)
		assert.are.equal(replacement, ns.Professions:Get("skinning"))
		assert.is_nil(ns.Professions:ForSkillLine(393))
		assert.are.equal("skinning", (ns.Professions:ForSkillLine(9393)))
		ns.Professions:Register("tanning", { skillLine = 9393, primary = true })
		assert.are.equal("tanning", (ns.Professions:ForSkillLine(9393)))
		assert.are.equal(2, #ns.Professions.problems)
		assert.truthy(ns.Professions.problems[2]:find("share skill line 9393", 1, true))
	end)

	it("registers a module's directives into ns.Directives", function()
		local ns = load()
		local registered = {}
		ns.Directives = {
			Register = function(_, name, def)
				registered[#registered + 1] = { name = name, def = def }
			end,
		}
		local lure = { kind = "profession" }
		ns.Professions:Register("angling", { skillLine = 8888, primary = false, directives = { lure = lure } })
		assert.are.same({ { name = "lure", def = lure } }, registered)
		ns.Directives = nil
		ns.Professions:Register("other", { skillLine = 8889, directives = { x = {} } })
		assert.truthy(ns.Professions.problems[1]:find("directives could not be registered", 1, true))
	end)

	it("registers tracks by key", function()
		local ns = load()
		assert.is_true(ns.Professions:RegisterTrack("skinning", "#track skinning\n"))
		assert.are.equal("#track skinning\n", ns.Professions:Track("skinning"))
		assert.is_nil(ns.Professions:Track("mining"))
		assert.is_nil(ns.Professions:Track(nil))
		assert.is_false(ns.Professions:RegisterTrack("mining", nil))
		assert.is_false(ns.Professions:RegisterTrack(nil, "text"))
		ns.Professions:RegisterTrack("skinning", "#track skinning\n")
		ns.Professions:RegisterTrack("skinning", "#track skinning\nstep @hub orgrimmar\n")
		assert.are.equal(3, #ns.Professions.problems)
		assert.truthy(ns.Professions:Track("skinning"):find("orgrimmar", 1, true))
	end)
end)

describe("profession plan", function()
	it("routes a fresh character to the guide's suggestions", function()
		local ns = load()
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning", "leatherworking" }, plan.primary)
		assert.are.same({ "firstaid", "cooking", "fishing" }, plan.secondary)
		assert.are.same({}, plan.declined)
		assert.are.same({}, plan.learned)
		assert.are.same({}, plan.unknown)
		assert.are.equal(plan, ns.Professions:Current())
	end)

	it("keeps the plan when the character learns a suggested primary", function()
		local ns = load({ learned = { [1] = "skinning" } })
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning", "leatherworking" }, plan.primary)
		assert.are.same({ "firstaid", "cooking", "fishing" }, plan.secondary)
		assert.are.same({ skinning = true }, plan.learned)

		-- the second suggestion learned first: same order
		ns = load({ learned = { [1] = "leatherworking" } })
		plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning", "leatherworking" }, plan.primary)
	end)

	it("keeps a different learned primary and fills only the free slot", function()
		local ns = load({ learned = { [1] = "mining" } })
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning", "mining" }, plan.primary)
		assert.are.same({ "firstaid", "cooking", "fishing" }, plan.secondary)
		assert.are.same({ mining = true }, plan.learned)
	end)

	it("suggests no primary when both slots are filled", function()
		local ns = load({ learned = { [1] = "mining", [2] = "herbalism" } })
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "herbalism", "mining" }, plan.primary)
		assert.are.same({ "firstaid", "cooking", "fishing" }, plan.secondary)

		ns = load({ learned = { [1] = "mining", [2] = "leatherworking" } })
		plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "leatherworking", "mining" }, plan.primary)
	end)

	it("counts a learned primary without a module against the slots", function()
		local ns = load({ learned = { [1] = { skillLine = 171 } }, primaries = { [171] = true } })
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning" }, plan.primary)
		assert.are.same({}, plan.learned)
	end)

	it("declines and restores a profession, so the next suggestion takes its slot", function()
		local ns = load()
		ns.Professions:Plan({ "skinning", "leatherworking", "herbalism", "firstaid" })
		local fired = messages(ns, "PROFESSION_PLAN_CHANGED")

		assert.is_true(ns.Professions:Decline("skinning"))
		assert.is_true(SignpostCharDB.declinedProfessions.skinning)
		assert.is_true(ns.Professions:IsDeclined("skinning"))
		assert.are.equal(1, #fired)
		assert.are.same({ "leatherworking", "herbalism" }, fired[1].primary)
		assert.are.same({ skinning = true }, fired[1].declined)
		assert.are.equal(fired[1], ns.Professions:Current())

		ns.Professions:Decline("skinning")
		assert.are.equal(1, #fired)

		assert.is_true(ns.Professions:Restore("skinning"))
		assert.is_nil(SignpostCharDB.declinedProfessions.skinning)
		assert.is_false(ns.Professions:IsDeclined("skinning"))
		assert.are.equal(2, #fired)
		assert.are.same({ "skinning", "leatherworking" }, fired[2].primary)
		assert.are.same({}, fired[2].declined)

		ns.Professions:Restore("skinning")
		assert.are.equal(2, #fired)
		assert.is_false(ns.Professions:Decline(""))
		assert.is_false(ns.Professions:Restore(nil))

		-- a profession the plan does not route: only the declined list changes, and that is announced too
		ns.Professions:Decline("mining")
		assert.are.equal(3, #fired)
		assert.are.same({ "skinning", "leatherworking" }, fired[3].primary)
		assert.are.same({ mining = true }, fired[3].declined)
	end)

	it("keeps declined professions per character across a reload", function()
		local ns = load({
			before = function()
				G.SignpostCharDB = { dbVersion = 2, declinedProfessions = { cooking = true, skinning = true } }
			end,
		})
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "leatherworking" }, plan.primary)
		assert.are.same({ "firstaid", "fishing" }, plan.secondary)
		assert.are.same({ cooking = true, skinning = true }, plan.declined)
	end)

	it("keeps the guide's secondaries until learned or declined, and every learned secondary", function()
		local ns = load({ learned = { [3] = "firstaid", [4] = "fishing" } })
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "firstaid", "cooking", "fishing" }, plan.secondary)

		ns = load({ learned = { [3] = "fishing" } })
		plan = ns.Professions:Plan({ "skinning", "leatherworking" })
		assert.are.same({ "skinning", "leatherworking" }, plan.primary)
		assert.are.same({ "fishing" }, plan.secondary)
	end)

	it("keeps a learned profession in the plan even if it was declined", function()
		local ns = load({
			learned = { [3] = "cooking" },
			before = function()
				G.SignpostCharDB = { dbVersion = 2, declinedProfessions = { cooking = true, fishing = true } }
			end,
		})
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "firstaid", "cooking" }, plan.secondary)
		assert.are.same({ fishing = true }, plan.declined)
	end)

	it("lists suggestions without a module as unknown, and reads a header string", function()
		local ns = load()
		local plan = ns.Professions:Plan({ "skinning", "jewelcrafting", "skinning", " cooking " })
		assert.are.same({ "skinning" }, plan.primary)
		assert.are.same({ "cooking" }, plan.secondary)
		assert.are.same({ "jewelcrafting" }, plan.unknown)

		plan = ns.Professions:Plan("leatherworking,fishing")
		assert.are.same({ "leatherworking" }, plan.primary)
		assert.are.same({ "fishing" }, plan.secondary)

		plan = ns.Professions:Plan(nil)
		assert.are.same({}, plan.primary)
		assert.are.same({}, plan.secondary)
	end)

	it("fires PROFESSION_PLAN_CHANGED when learning or unlearning changes the plan", function()
		local ns, mock, mockProfessions = load()
		ns.Professions:Plan(SUGGESTIONS)
		local fired = messages(ns, "PROFESSION_PLAN_CHANGED")

		-- learning a suggested profession routes the same professions
		mockProfessions.learned[1] = { skillLine = 393 }
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(0, #fired)
		assert.are.same({ skinning = true }, ns.Professions:Current().learned)

		-- another primary takes the free slot
		mockProfessions.learned[2] = { skillLine = 186 }
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(1, #fired)
		assert.are.same({ "skinning", "mining" }, fired[1].primary)

		-- a skill-up is not a plan change
		mockProfessions.learned[2].rank = 5
		mock.fire("CHAT_MSG_SKILL", "skill up")
		assert.are.equal(1, #fired)

		-- unlearning frees the slot again
		mockProfessions.learned[2] = nil
		mock.fire("SKILL_LINES_CHANGED")
		assert.are.equal(2, #fired)
		assert.are.same({ "skinning", "leatherworking" }, fired[2].primary)
	end)

	it("waits for a guide to ask for a plan before announcing changes", function()
		local ns, mock, mockProfessions = load()
		local fired = messages(ns, "PROFESSION_PLAN_CHANGED")
		mockProfessions.learned[1] = { skillLine = 186 }
		mock.fire("SKILL_LINES_CHANGED")
		assert.is_true(ns.Professions:Decline("leatherworking"))
		assert.are.equal(0, #fired)
		assert.is_nil(ns.Professions:Current())
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "skinning", "mining" }, plan.primary)
		assert.are.same({ leatherworking = true }, plan.declined)
	end)

	it("detects a plan before SavedVariables load but cannot store a decline", function()
		local ns = load({ login = false })
		assert.is_false(ns.Professions:Decline("skinning"))
		assert.are.same({ "skinning", "leatherworking" }, ns.Professions:Plan(SUGGESTIONS).primary)
	end)
end)

-- Track merging ---------------------------------------------------------------------------------------------------

-- The map tree for @zone: 1411 and 1413 are zones of 1414; 1454 is a city beside 1411, not below it; 1500 lies
-- below 1413; 9000 is a dungeon map outside the tree.
local MAPS = {
	[947] = { mapID = 947, parentMapID = 0 },
	[1414] = { mapID = 1414, parentMapID = 947 },
	[1411] = { mapID = 1411, parentMapID = 1414 },
	[1413] = { mapID = 1413, parentMapID = 1414 },
	[1454] = { mapID = 1454, parentMapID = 1414 },
	[1500] = { mapID = 1500, parentMapID = 1413 },
	[9000] = { mapID = 9000, parentMapID = 0 },
}

-- A stand-in for ns.Parser:ParseTrack (Engine/Parser.lua is built in parallel). It reads "step @<kind> <value>"
-- lines, numbers steps by their place in the text (stable ids), drops a step ending in "if <key>" unless the plan
-- holds that key (as a .prof gate would), reports "oops" lines as errors, and records each call. A step marked
-- "noid" comes back without id, source and track; one marked "sameid" with the previous step's id.
local function stubParser()
	local parser = { calls = {} }
	function parser:ParseTrack(key, text, opts)
		self.calls[#self.calls + 1] = { key = key, text = text, opts = opts }
		if text:find("explode", 1, true) then
			error("parser bug")
		end
		local inPlan = {}
		for _, field in ipairs({ "primary", "secondary" }) do
			for _, planKey in ipairs(opts.plan and opts.plan[field] or {}) do
				inPlan[planKey] = true
			end
		end
		local steps, errors, n, line = {}, {}, 0, 0
		for raw in (text .. "\n"):gmatch("(.-)\n") do
			line = line + 1
			if raw:find("^%s*step") then
				n = n + 1
				local gate = raw:match("%sif%s+(%S+)%s*$")
				if not gate or inPlan[gate] then
					local source = "track:" .. key
					local step = { id = source .. ":" .. n, source = source, line = line, track = key, directives = {} }
					local kind, value = raw:match("^%s*step%s+@(%a+)%s+(%S+)")
					if kind then
						step.anchor = { kind = kind, value = kind == "hub" and value or tonumber(value) }
					end
					if raw:find("noid", 1, true) then
						step.id, step.source, step.track = nil, nil, nil
					elseif raw:find("sameid", 1, true) then
						step.id = steps[#steps] and steps[#steps].id
					end
					steps[#steps + 1] = step
				end
			elseif raw:find("^%s*oops") then
				errors[#errors + 1] = { source = "track:" .. key, line = line, message = "unknown statement" }
			end
		end
		return steps, errors
	end
	return parser
end

local function at(map)
	return { name = "goto", args = { map = map, x = 50, y = 50 } }
end

local function path(...)
	local points = {}
	for i, map in ipairs({ ... }) do
		points[i] = { map = map, x = 10 * i, y = 10 * i }
	end
	return { name = "path", args = points }
end

local function routeStep(id, chapter, directives, hub)
	return { id = id, source = id:match("^(.+):%d+$"), line = 1, chapter = chapter, directives = directives, hub = hub }
end

-- A parsed route of four chapters: valley (1-6), town (6-12), cave (10, a dungeon) and plains (12-20), with hubs
-- camp, razorhill (visited twice) and crossroads.
local function routeGuide()
	local guide = {
		id = "test-guide",
		chapters = {
			{ id = "valley", name = "Valley", levels = { 1, 6 }, dungeon = false, first = 1, last = 2 },
			{ id = "town", name = "Town", levels = { 6, 12 }, dungeon = false, first = 3, last = 4 },
			{ id = "cave", name = "Cave", levels = { 10 }, dungeon = true, first = 5, last = 6 },
			{ id = "plains", name = "Plains", levels = { 12, 20 }, dungeon = false, first = 7, last = 10 },
		},
		steps = {
			routeStep("valley:1", 1, { at(1411) }),
			routeStep("valley:2", 1, { at(1411) }, "camp"),
			routeStep("town:1", 2, { { name = "accept", args = { questID = 1 } }, at(1411) }, "razorhill"),
			routeStep("town:2", 2, { path(1411, 1413) }),
			routeStep("cave:1", 3, { at(9000) }),
			routeStep("cave:2", 3, {}),
			routeStep("plains:1", 4, { at(1500) }),
			routeStep("plains:2", 4, { at(1413) }, "crossroads"),
			routeStep("plains:3", 4, { at(1411) }, "razorhill"),
			routeStep("plains:4", 4, { at(1454) }),
		},
		byId = {},
		errors = {},
	}
	for i, step in ipairs(guide.steps) do
		step.index = i
		guide.byId[step.id] = step
	end
	return guide
end

local ROUTE = {
	"valley:1",
	"valley:2",
	"town:1",
	"town:2",
	"cave:1",
	"cave:2",
	"plains:1",
	"plains:2",
	"plains:3",
	"plains:4",
}

local function loadMerge()
	local ns, mock = load()
	ns.Parser = stubParser()
	G.C_Map = {
		GetMapInfo = function(id)
			return MAPS[id]
		end,
	}
	return ns, mock
end

local function track(ns, key, ...)
	return ns.Professions:RegisterTrack(key, "#track " .. key .. "\n" .. table.concat({ ... }, "\n") .. "\n")
end

local function ids(guide)
	local list = {}
	for i, step in ipairs(guide.steps) do
		list[i] = step.id
	end
	return list
end

-- "id@chapterId" per step.
local function layout(guide)
	local list = {}
	for i, step in ipairs(guide.steps) do
		list[i] = step.id .. "@" .. guide.chapters[step.chapter].id
	end
	return list
end

-- The route with track step ids inserted after the given route step ids ("" = before the first route step).
local function routeWith(after)
	local list = {}
	local function insert(routeId)
		for _, id in ipairs(after[routeId] or {}) do
			list[#list + 1] = id
		end
	end
	insert("")
	for _, id in ipairs(ROUTE) do
		list[#list + 1] = id
		insert(id)
	end
	return list
end

-- index, byId and the chapter ranges agree with the step list, and the chapters tile it in order.
local function assertConsistent(guide)
	local count = 0
	for i, step in ipairs(guide.steps) do
		assert.are.equal(i, step.index)
		assert.are.equal(step, guide.byId[step.id])
		count = count + 1
	end
	local nextIndex = 1
	for c, chapter in ipairs(guide.chapters) do
		assert.are.equal(nextIndex, chapter.first)
		for i = chapter.first, chapter.last do
			assert.are.equal(c, guide.steps[i].chapter)
		end
		nextIndex = chapter.last + 1
	end
	assert.are.equal(count + 1, nextIndex)
end

local function messagesOf(guide)
	local list = {}
	for i, entry in ipairs(guide.errors) do
		list[i] = string.format("%s:%d %s", entry.source, entry.line, entry.message)
	end
	return list
end

local ONLY = function(key)
	return { primary = { key }, secondary = {} }
end

describe("track merging", function()
	it("@hub: right after the first route step marked with the hub", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill")
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(routeWith({ ["town:1"] = { "track:skinning:1" } }), ids(guide))
		assert.are.same({}, guide.errors)
		assertConsistent(guide)
	end)

	it("@hub: at the visit of the track's previous step, or a later one", function()
		local ns = loadMerge()
		track(
			ns,
			"skinning",
			"step @hub razorhill",
			"step @hub razorhill",
			"step @hub crossroads",
			"step @hub razorhill"
		)
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(
			routeWith({
				["town:1"] = { "track:skinning:1", "track:skinning:2" },
				["plains:2"] = { "track:skinning:3" },
				["plains:3"] = { "track:skinning:4" },
			}),
			ids(guide)
		)
		assertConsistent(guide)
	end)

	it("@level: before the first step of the first chapter whose minimum level is at least N", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @level 1", "step @level 6", "step @level 7", "step @level 12")
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(
			routeWith({
				[""] = { "track:skinning:1" },
				["valley:2"] = { "track:skinning:2" },
				["town:2"] = { "track:skinning:3" },
				["cave:2"] = { "track:skinning:4" },
			}),
			ids(guide)
		)
		assertConsistent(guide)
	end)

	it("@zone: before the first route step whose first .goto/.path target is in the map or below it", function()
		local ns = loadMerge()
		-- 1413: not town:2 (its path starts in 1411) but plains:1 (1500 lies below 1413); 1411: plains:3 after the
		-- cursor; 1454: plains:4, the city, which 1411 does not contain
		track(ns, "skinning", "step @zone 1413", "step @zone 1411", "step @zone 1454")
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(
			routeWith({
				["cave:2"] = { "track:skinning:1" },
				["plains:2"] = { "track:skinning:2" },
				["plains:3"] = { "track:skinning:3" },
			}),
			ids(guide)
		)
		assertConsistent(guide)
	end)

	it("@zone: reads the map from the directive's targets when its arguments do not show it", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @zone 1413")
		local guide = routeGuide()
		guide.steps[6].directives = {
			{
				name = "goto",
				args = { somewhere = true },
				def = {
					targets = function(_, context, state)
						assert.are.equal(ns.Context, context)
						assert.are.same({}, state)
						return { { map = 1500, x = 1, y = 1, kind = "goto" } }
					end,
				},
			},
		}
		ns.Professions:Merge(guide, ONLY("skinning"))
		assert.are.same(routeWith({ ["cave:1"] = { "track:skinning:1" } }), ids(guide))
		assert.are.equal("cave", guide.chapters[guide.steps[6].chapter].id)
	end)

	it("merges primaries first, then secondaries, keeping plan order at a shared anchor", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill")
		track(ns, "leatherworking", "step @hub razorhill", "step @level 12")
		track(ns, "cooking", "step @hub razorhill")
		local guide = ns.Professions:Merge(
			routeGuide(),
			{ primary = { "leatherworking", "skinning" }, secondary = { "cooking" } }
		)
		assert.are.same(
			routeWith({
				["town:1"] = { "track:leatherworking:1", "track:skinning:1", "track:cooking:1" },
				["cave:2"] = { "track:leatherworking:2" },
			}),
			ids(guide)
		)

		guide = ns.Professions:Merge(
			routeGuide(),
			{ secondary = { "cooking" }, primary = { "skinning", "leatherworking" } }
		)
		assert.are.same(
			routeWith({
				["town:1"] = { "track:skinning:1", "track:leatherworking:1", "track:cooking:1" },
				["cave:2"] = { "track:leatherworking:2" },
			}),
			ids(guide)
		)
	end)

	it("drops a step whose anchor matches nothing with an error, and goes on from the previous step", function()
		local ns = loadMerge()
		track(
			ns,
			"skinning",
			"step @hub nowhere",
			"step @level 99",
			"step @zone 4242",
			"step @moon 1",
			"step",
			"step @hub razorhill"
		)
		-- anchored before the place of the track's previous step: no match either
		track(ns, "cooking", "step @hub crossroads", "step @level 6", "step @zone 1454", "step @zone 1411")
		local guide = ns.Professions:Merge(routeGuide(), { primary = { "skinning" }, secondary = { "cooking" } })
		assert.are.same({
			"track:skinning:2 No route step matches @hub nowhere",
			"track:skinning:3 No route step matches @level 99",
			"track:skinning:4 No route step matches @zone 4242",
			"track:skinning:5 Unknown anchor @moon",
			"track:skinning:6 Track step without an anchor",
			"track:cooking:3 No route step matches @level 6",
			"track:cooking:5 No route step matches @zone 1411",
		}, messagesOf(guide))
		assert.are.same(
			routeWith({
				["town:1"] = { "track:skinning:6" },
				["plains:2"] = { "track:cooking:1" },
				["plains:3"] = { "track:cooking:3" },
			}),
			ids(guide)
		)
		assertConsistent(guide)
	end)

	it("keeps step ids stable whatever the plan", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill if leatherworking", "step @hub razorhill", "step @level 12")
		track(ns, "leatherworking", "step @hub razorhill")
		local both = ns.Professions:Merge(routeGuide(), { primary = { "skinning", "leatherworking" }, secondary = {} })
		local one = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(
			routeWith({
				["town:1"] = { "track:skinning:1", "track:skinning:2", "track:leatherworking:1" },
				["cave:2"] = { "track:skinning:3" },
			}),
			ids(both)
		)
		-- the gated-away first step does not renumber the others
		assert.are.same(
			routeWith({ ["town:1"] = { "track:skinning:2" }, ["cave:2"] = { "track:skinning:3" } }),
			ids(one)
		)
		for _, id in ipairs(ROUTE) do
			assert.are.equal(id, one.byId[id].id)
		end
		assertConsistent(both)
		assertConsistent(one)
	end)

	it("passes the plan and the player to ParseTrack and appends its errors", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill", "oops")
		local plan, opts = ONLY("skinning"), { player = { classFile = "TEST" }, extra = 1 }
		local guide = ns.Professions:Merge(routeGuide(), plan, opts)
		local call = ns.Parser.calls[1]
		assert.are.equal("skinning", call.key)
		assert.are.equal(ns.Professions:Track("skinning"), call.text)
		assert.are.equal(plan, call.opts.plan)
		assert.are.equal(opts.player, call.opts.player)
		assert.are.equal(1, call.opts.extra)
		assert.are.equal("test-guide", call.opts.guideId)
		assert.is_nil(opts.plan) -- the caller's options are not changed
		assert.are.same({ { source = "track:skinning", line = 3, message = "unknown statement" } }, guide.errors)
		assert.are.equal(plan, guide.plan)

		ns.Professions:Merge(routeGuide(), plan)
		assert.are.equal(ns.Player, ns.Parser.calls[2].opts.player)
	end)

	it("reports a plan profession without a track, and a track the parser fails on", function()
		local ns, mock = loadMerge()
		track(ns, "skinning", "step @hub razorhill")
		track(ns, "cooking", "explode")
		local errorsBefore = #mock.errors
		local guide =
			ns.Professions:Merge(routeGuide(), { primary = { "skinning" }, secondary = { "fishing", "cooking" } })
		assert.are.same({
			"track:fishing:0 No track is registered for profession fishing",
			"track:cooking:0 Track cooking could not be parsed",
		}, messagesOf(guide))
		assert.are.same(routeWith({ ["town:1"] = { "track:skinning:1" } }), ids(guide))
		assert.are.equal(errorsBefore + 1, #mock.errors) -- the parser's error went to the error handler

		ns.Parser = nil
		guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same({ "track:skinning:0 No parser is loaded for profession tracks" }, messagesOf(guide))
		assert.are.same(ROUTE, ids(guide))
	end)

	it("puts boundary steps into the right chapter, never into a dungeon", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @level 1", "step @level 6", "step @level 7", "step @level 12")
		track(ns, "leatherworking", "step @hub camp")
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same({
			"track:skinning:1@valley", -- before the first route step
			"valley:1@valley",
			"valley:2@valley",
			"track:skinning:2@town", -- @level: the chapter it opens
			"town:1@town",
			"town:2@town",
			"track:skinning:3@town", -- before a dungeon: not the dungeon
			"cave:1@cave",
			"cave:2@cave",
			"track:skinning:4@plains", -- after a dungeon: not the dungeon
			"plains:1@plains",
			"plains:2@plains",
			"plains:3@plains",
			"plains:4@plains",
		}, layout(guide))
		assertConsistent(guide)

		-- @hub: the chapter of its route step; sharing a gap with a @level step, both follow the @hub step
		guide = ns.Professions:Merge(routeGuide(), { primary = { "leatherworking", "skinning" }, secondary = {} })
		assert.are.equal("track:leatherworking:1@valley", layout(guide)[4])
		assert.are.equal("track:skinning:2@valley", layout(guide)[5])
		assertConsistent(guide)
	end)

	it("updates the chapter ranges, keeping an empty chapter in place", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill", "step @level 12")
		local guide = routeGuide()
		table.insert(guide.chapters, 3, { id = "empty", name = "Empty", levels = { 9, 10 }, first = 5, last = 4 })
		for _, step in ipairs(guide.steps) do
			if step.chapter >= 3 then
				step.chapter = step.chapter + 1
			end
		end
		ns.Professions:Merge(guide, ONLY("skinning"))
		local ranges = {}
		for i, chapter in ipairs(guide.chapters) do
			ranges[i] = { chapter.first, chapter.last }
		end
		assert.are.same({ { 1, 2 }, { 3, 5 }, { 6, 5 }, { 6, 7 }, { 8, 12 } }, ranges)
	end)

	it("merges again from the route alone, so a new plan replaces the old tracks", function()
		local ns = loadMerge()
		track(ns, "skinning", "step @hub razorhill")
		track(ns, "cooking", "step @hub crossroads")
		local guide = ns.Professions:Merge(routeGuide(), { primary = { "skinning" }, secondary = { "cooking" } })
		ns.Professions:Merge(guide, ONLY("skinning"))
		assert.are.same(routeWith({ ["town:1"] = { "track:skinning:1" } }), ids(guide))
		ns.Professions:Merge(guide, nil)
		assert.are.same(ROUTE, ids(guide))
		assertConsistent(guide)
	end)

	it("names a track step without an id after its track and line, and reports a taken id", function()
		local ns = loadMerge()
		track(ns, "skinning", "", "step @hub razorhill noid", "step @hub razorhill", "step @hub razorhill sameid")
		local guide = ns.Professions:Merge(routeGuide(), ONLY("skinning"))
		assert.are.same(
			routeWith({
				["town:1"] = { "track:skinning:3", "track:skinning:2", "track:skinning:2" },
			}),
			ids(guide)
		)
		assert.are.same({ "track:skinning:5 Duplicate step id track:skinning:2" }, messagesOf(guide))
		assert.are.equal("track:skinning", guide.steps[4].source)
		assert.are.equal("skinning", guide.steps[4].track)
		assert.are.equal(guide.steps[5], guide.byId["track:skinning:2"])
	end)

	it("serves a character with other professions (PLAN §3.8 seam test, mocked GetProfessions)", function()
		local ns = loadMerge()
		ns.Professions:Register("alchemy", { skillLine = 171, primary = true })
		ns.Professions:Decline("firstaid")
		ns.Professions:Decline("cooking")
		ns.Professions:Decline("fishing")
		client.install(G, clientSlots({ [1] = "herbalism", [2] = { skillLine = 171 } }))
		ns.Player:RefreshProfessions()
		for _, key in ipairs({ "skinning", "leatherworking", "firstaid", "cooking", "fishing" }) do
			track(ns, key, "step @hub razorhill")
		end
		track(ns, "herbalism", "step @level 6", "step @hub crossroads")
		track(ns, "alchemy", "step @hub razorhill")
		local plan = ns.Professions:Plan(SUGGESTIONS)
		assert.are.same({ "alchemy", "herbalism" }, plan.primary)
		assert.are.same({}, plan.secondary)
		local guide = ns.Professions:Merge(routeGuide(), plan)
		assert.are.same(
			routeWith({
				["valley:2"] = { "track:herbalism:1" },
				["town:1"] = { "track:alchemy:1" },
				["plains:2"] = { "track:herbalism:2" },
			}),
			ids(guide)
		)
		assert.are.same({}, guide.errors)
	end)
end)
