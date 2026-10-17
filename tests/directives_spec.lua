-- ns.Directives (Engine/Directives.lua): the registry and every core directive's parse, isSatisfied, targets and
-- describe, against a fake ns.Context and a small fake data pack.
local addon = dofile("tests/helpers/addon.lua")
local mocks = dofile("tests/mocks/directives.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local CORE = {
	"accept",
	"buy",
	"collect",
	"complete",
	"craft",
	"fish",
	"goto",
	"hub",
	"level",
	"link",
	"note",
	"optional",
	"reward",
	"skill",
	"sticky",
	"text",
	"todo",
	"train",
	"trainprof",
	"turnin",
	"use",
}

-- Engine/Travel.lua (in the TOC since Wave 1 integration) registers the travel directives into the same registry.
local TRAVEL = { "boat", "fly", "fp", "home", "hs", "path", "zeppelin", "zone" }

-- A small data pack in Data/Schema.lua's shape (test values, not real data).
local function fakePack()
	return {
		quests = {
			[787] = {
				n = "The Basics",
				s = { npc = { 101 } },
				e = { npc = { 101 } },
				o = { { k = "kill", id = 201, c = 10 } },
			},
			[788] = { n = "Two Givers", s = { npc = { 101, 102 } }, e = { obj = { 301 } } },
			[789] = {
				n = "Mixed Objectives",
				o = { { k = "item", id = 401, c = 5 }, { k = "object", id = 301, c = 1 }, { k = "explore", id = 9 } },
			},
		},
		npcs = {
			[101] = { n = "Quest Giver", p = { { 1411, 42.1, 68.7 } } },
			[102] = { n = "Other Giver", p = { { 1411, 43, 69 } } },
			[201] = { n = "Boar", p = { { 1411, 50, 50 }, { 1411, 52, 48 }, { 1413, 10, 10 } } },
			[202] = { n = "Thief", p = { { 1411, 60, 60 } } },
			[203] = {
				n = "Everywhere",
				p = { { 1, 1, 1 }, { 1, 2, 2 }, { 1, 3, 3 }, { 1, 4, 4 }, { 1, 5, 5 }, { 1, 6, 6 }, { 1, 7, 7 } },
			},
			[501] = { n = "City Trainer", side = "Horde", p = { { 1454, 40, 40 } } },
			[502] = { n = "Rival Trainer", side = "Alliance", p = { { 1454, 41, 41 } } },
			[503] = { n = "Field Trainer", side = "both", p = { { 1411, 40, 40 } } },
		},
		objects = { [301] = { n = "Crate", p = { { 1411, 55, 55 } } } },
		items = { [401] = { n = "Pack Item", vendors = { 501 }, drops = { 202 } } },
		maps = { [1411] = { n = "Durotar" } },
		professions = { [393] = { n = "Skinning", trainers = { 501, 502, 503 } } },
		classes = { HUNTER = { trainers = { 501, 503 } } },
	}
end

local SKINNING = { skillLine = 393, primary = true, gathering = true, ranks = { 75, 150, 225, 300 } }

local function parsed(ns, name, text)
	return assert(ns.Directives:Parse(name, text, { source = "test", line = 1 }))
end

local function satisfied(ns, name, text, context, state)
	return ns.Directives:Get(name).isSatisfied(parsed(ns, name, text), context, state)
end

local function targets(ns, name, text, context, state)
	return ns.Directives:Get(name).targets(parsed(ns, name, text), context, state)
end

local function describe_(ns, name, text, context, state)
	return ns.Directives:Get(name).describe(parsed(ns, name, text), context or mocks.context(), state)
end

describe("the directive registry", function()
	it("loads without errors and registers every core directive of GUIDE-FORMAT", function()
		local ns, mock = mocks.load()
		assert.are.same({}, mock.errors)
		assert.are.same({}, ns.db.errors)
		local expected = {}
		for _, list in ipairs({ CORE, TRAVEL }) do
			for _, name in ipairs(list) do
				expected[#expected + 1] = name
			end
		end
		table.sort(expected)
		assert.are.same(expected, ns.Directives:Names())
		assert.is_table(ns.Conditions)
	end)

	it("knows which core directives can complete a step", function()
		local ns = mocks.load()
		local completable = {}
		for _, name in ipairs(CORE) do
			if ns.Directives:Get(name).completable then
				completable[#completable + 1] = name
			end
		end
		assert.are.same({
			"accept",
			"buy",
			"collect",
			"complete",
			"craft",
			"goto",
			"level",
			"skill",
			"sticky",
			"todo",
			"train",
			"trainprof",
			"turnin",
		}, completable)
	end)

	it("gives every core directive one of the four kinds and its own name", function()
		local ns = mocks.load()
		local kinds = { quest = true, travel = true, profession = true, misc = true }
		for _, name in ipairs(CORE) do
			local def = ns.Directives:Get(name)
			assert.is_true(kinds[def.kind] == true, name)
			assert.are.equal(name, def.name)
			assert.is_string(def.usage, name)
		end
	end)

	it("fills in kind and completable for a module's directive", function()
		local ns = mocks.load()
		local parse = function()
			return {}
		end
		local tame = ns.Directives:Register("tame", {
			parse = parse,
			isSatisfied = function()
				return true
			end,
		})
		assert.are.equal("misc", tame.kind)
		assert.is_true(tame.completable)
		assert.are.equal(tame, ns.Directives:Get("tame"))
		assert.is_false(ns.Directives:Register("hint", { parse = parse }).completable)
		local declared = ns.Directives:Register("watch", {
			kind = "travel",
			completable = false,
			parse = parse,
			isSatisfied = function()
				return true
			end,
		})
		assert.is_false(declared.completable)
		assert.are.equal("travel", declared.kind)
		-- a later registration replaces an earlier one
		local again = ns.Directives:Register("tame", { parse = parse })
		assert.are.equal(again, ns.Directives:Get("tame"))
	end)

	it("rejects malformed registrations loudly", function()
		local ns = mocks.load()
		local parse = function()
			return {}
		end
		assert.has_error(function()
			ns.Directives:Register("Tame", { parse = parse })
		end)
		assert.has_error(function()
			ns.Directives:Register("tame beast", { parse = parse })
		end)
		assert.has_error(function()
			ns.Directives:Register("tame", {})
		end)
		assert.has_error(function()
			ns.Directives:Register(nil, { parse = parse })
		end)
	end)

	it("returns nil for an unknown directive", function()
		local ns = mocks.load()
		assert.is_nil(ns.Directives:Get("nope"))
	end)

	it("parses without ever raising", function()
		local ns = mocks.load()
		ns.Directives:Register("broken", {
			parse = function()
				error("bug in a module")
			end,
		})
		ns.Directives:Register("silent", {
			parse = function()
				return nil
			end,
		})
		local args, message = ns.Directives:Parse("broken", "1")
		assert.is_nil(args)
		assert.truthy(message:find("bug in a module", 1, true))
		args, message = ns.Directives:Parse("nope", "1")
		assert.is_nil(args)
		assert.truthy(message:find("unknown directive .nope", 1, true))
		args, message = ns.Directives:Parse("silent", "")
		assert.is_nil(args)
		assert.truthy(message:find("invalid arguments for .silent", 1, true))
	end)
end)

describe("ns.Directives:ParseLine", function()
	it("builds a directive with its >> text, line and def", function()
		local ns = mocks.load()
		local directive =
			ns.Directives:ParseLine(".accept 787 >> Accept the first quest", { source = "test", line = 14 })
		assert.are.equal("accept", directive.name)
		assert.are.same({ questID = 787 }, directive.args)
		assert.are.equal("Accept the first quest", directive.text)
		assert.are.equal(14, directive.line)
		assert.are.equal(ns.Directives:Get("accept"), directive.def)
	end)

	it("leaves the text unset without an override or with an empty one", function()
		local ns = mocks.load()
		assert.is_nil(ns.Directives:ParseLine("  .level 10").text)
		assert.is_nil(ns.Directives:ParseLine(".level 10 >>   ").text)
	end)

	it("reports lines that are not directives, unknown directives and bad arguments", function()
		local ns = mocks.load()
		for _, line in ipairs({ "accept 787", "", ">> text only", ".nope 1", ".accept x", ".goto1411,42,68" }) do
			local directive, message = ns.Directives:ParseLine(line)
			assert.is_nil(directive, line)
			assert.is_string(message, line)
		end
	end)
end)

-- { directive, argument string, parsed args }
local GOOD = {
	{ "goto", "1411,42.1,68.7", { map = 1411, x = 42.1, y = 68.7 } },
	{ "goto", " 1411, 42.1 , 68.7, 25 ", { map = 1411, x = 42.1, y = 68.7, radius = 25 } },
	{ "goto", "1411,0,100,2.5", { map = 1411, x = 0, y = 100, radius = 2.5 } },
	{ "accept", "787", { questID = 787 } },
	{ "turnin", "4641", { questID = 4641 } },
	{ "complete", "787", { questID = 787 } },
	{ "complete", "787,1", { questID = 787, objective = 1 } },
	{ "optional", "4402", { questID = 4402 } },
	{ "reward", "4402,2", { questID = 4402, choice = 2 } },
	{ "reward", "4402,10", { questID = 4402, choice = 10 } },
	{ "reward", "4402,2516", { questID = 4402, itemID = 2516 } },
	{ "train", "1494", { spellID = 1494 } },
	{ "train", "class", { class = true } },
	{ "trainprof", "skinning", { key = "skinning" } },
	{ "trainprof", "firstaid", { key = "firstaid" } },
	{ "skill", "cooking 75", { key = "cooking", value = 75 } },
	{ "skill", "skinning   50", { key = "skinning", value = 50 } },
	{ "craft", "2152,5", { spellID = 2152, count = 5 } },
	{ "fish", "1411,55.0,70.0", { map = 1411, x = 55, y = 70 } },
	{ "buy", "2516,200", { itemID = 2516, count = 200 } },
	{ "collect", "2589,10", { itemID = 2589, count = 10 } },
	{ "use", "5070", { itemID = 5070 } },
	{ "level", "10", { level = 10 } },
	{ "todo", '"Position not in the data pack yet"', { reason = "Position not in the data pack yet" } },
	{ "todo", "Unquoted reason", { reason = "Unquoted reason" } },
	{ "note", "Only if you want the pet chain now.", { text = "Only if you want the pet chain now." } },
	{ "text", "  Kaltunk stands at the Den entrance. ", { text = "Kaltunk stands at the Den entrance." } },
	{ "link", "https://example.org/quest=6069", { url = "https://example.org/quest=6069" } },
	{ "hub", "razorhill", { name = "razorhill" } },
}

-- { directive, argument string }
local BAD = {
	{ "goto", "" },
	{ "goto", "1411,42.1" },
	{ "goto", "x,42.1,68.7" },
	{ "goto", "0,42.1,68.7" },
	{ "goto", "1411,142,68.7" },
	{ "goto", "1411,-1,68.7" },
	{ "goto", "1411,42.1,68.7,0" },
	{ "goto", "1411,42.1,68.7,far" },
	{ "goto", "1411,42.1,68.7,10,5" },
	{ "goto", "1411,,68.7" },
	{ "accept", "" },
	{ "accept", "abc" },
	{ "accept", "787,788" },
	{ "accept", "0" },
	{ "accept", "7.5" },
	{ "accept", "0x10" },
	{ "turnin", "" },
	{ "complete", "" },
	{ "complete", "787,0" },
	{ "complete", "787,first" },
	{ "complete", "787,1,2" },
	{ "optional", "x" },
	{ "reward", "4402" },
	{ "reward", "4402,x" },
	{ "reward", "4402,2,3" },
	{ "train", "" },
	{ "train", "classes" },
	{ "train", "-5" },
	{ "trainprof", "" },
	{ "trainprof", "Skinning" },
	{ "trainprof", "first aid" },
	{ "skill", "cooking" },
	{ "skill", "cooking,75" },
	{ "skill", "75 cooking" },
	{ "skill", "cooking 0" },
	{ "skill", "Cooking 75" },
	{ "craft", "2152" },
	{ "craft", "2152,0" },
	{ "fish", "1411,55" },
	{ "fish", "1411,55,70,5" },
	{ "buy", "2516" },
	{ "buy", "2516,-1" },
	{ "collect", "2589,x" },
	{ "use", "" },
	{ "use", "5070,1" },
	{ "level", "ten" },
	{ "level", "0" },
	{ "todo", "" },
	{ "todo", '""' },
	{ "note", "" },
	{ "text", "   " },
	{ "link", "" },
	{ "link", "two words" },
	{ "hub", "" },
	{ "hub", "razor hill" },
	{ "sticky", "" },
	{ "sticky", "level 5" },
	{ "sticky", ".note Skin everything" },
	{ "sticky", ".sticky .level 5" },
	{ "sticky", ".nope 1" },
	{ "sticky", ".skill skinning" },
}

describe("parsing", function()
	local ns
	before_each(function()
		ns = mocks.load()
	end)

	for _, case in ipairs(GOOD) do
		it(string.format("accepts .%s %s", case[1], case[2]), function()
			local args, message = ns.Directives:Get(case[1]).parse(case[2], { source = "test", line = 1 })
			assert.are.same(case[3], args, message)
		end)
	end

	for _, case in ipairs(BAD) do
		it(string.format("rejects .%s %q with a message", case[1], case[2]), function()
			local args, message = ns.Directives:Get(case[1]).parse(case[2], { source = "test", line = 1 })
			assert.is_nil(args)
			assert.is_string(message)
			assert.is_true(#message > 0)
		end)
	end

	it("parses a .sticky line into its inner directive", function()
		local args = ns.Directives:Get("sticky").parse(".skill skinning 50 >> Skin everything", { line = 3 })
		local inner = args.directive
		assert.are.equal("skill", inner.name)
		assert.are.same({ key = "skinning", value = 50 }, inner.args)
		assert.are.equal("Skin everything", inner.text)
		assert.are.equal(3, inner.line)
		assert.are.equal(ns.Directives:Get("skill"), inner.def)
	end)

	it("explains a coordinate out of range", function()
		local _, message = ns.Directives:Get("goto").parse("1411,142,68.7")
		assert.truthy(message:find("0 to 100", 1, true))
	end)
end)

describe("isSatisfied", function()
	local ns, context
	before_each(function()
		ns = mocks.load({ professions = { skinning = SKINNING } })
		context = mocks.context()
	end)

	it(".goto: within its radius, 10 yards by default", function()
		assert.is_false(satisfied(ns, "goto", "1411,42.1,68.7", context))
		context:Near(1411, 42.1, 68.7, 9.5)
		assert.is_true(satisfied(ns, "goto", "1411,42.1,68.7", context))
		context:Near(1411, 42.1, 68.7, 10)
		assert.is_true(satisfied(ns, "goto", "1411,42.1,68.7", context))
		context:Near(1411, 42.1, 68.7, 10.5)
		assert.is_false(satisfied(ns, "goto", "1411,42.1,68.7", context))
		assert.is_true(satisfied(ns, "goto", "1411,42.1,68.7,25", context))
	end)

	it(".accept: in the log or flagged completed", function()
		assert.is_false(satisfied(ns, "accept", "787", context))
		context.log[787] = true
		assert.is_true(satisfied(ns, "accept", "787", context))
		context.log[787] = nil
		context.completed[787] = true
		assert.is_true(satisfied(ns, "accept", "787", context))
	end)

	it(".turnin: flagged completed only", function()
		context.log[787], context.ready[787] = true, true
		assert.is_false(satisfied(ns, "turnin", "787", context))
		context.log[787], context.ready[787], context.completed[787] = nil, nil, true
		assert.is_true(satisfied(ns, "turnin", "787", context))
	end)

	it(".complete: every objective finished, or the quest ready or turned in", function()
		assert.is_false(satisfied(ns, "complete", "787", context))
		context.log[787] = true
		assert.is_false(satisfied(ns, "complete", "787", context)) -- no objectives known yet
		context.objectives[787] = { { text = "a", finished = true }, { text = "b", finished = false } }
		assert.is_false(satisfied(ns, "complete", "787", context))
		context.objectives[787][2].finished = true
		assert.is_true(satisfied(ns, "complete", "787", context))
		context.objectives[787], context.ready[787] = {}, true
		assert.is_true(satisfied(ns, "complete", "787", context))
		context.log[787], context.ready[787], context.completed[787] = nil, nil, true
		assert.is_true(satisfied(ns, "complete", "787", context))
	end)

	it(".complete <questID>,<n>: that objective", function()
		context.log[787] = true
		context.objectives[787] = { { text = "a", finished = false }, { text = "b", finished = true } }
		assert.is_true(satisfied(ns, "complete", "787,2", context))
		assert.is_false(satisfied(ns, "complete", "787,1", context))
		assert.is_false(satisfied(ns, "complete", "787,3", context))
		context.ready[787] = true
		assert.is_true(satisfied(ns, "complete", "787,1", context))
	end)

	it(".train <spellID>: the spell is known", function()
		assert.is_false(satisfied(ns, "train", "1494", context))
		context.spells[1494] = true
		assert.is_true(satisfied(ns, "train", "1494", context))
	end)

	it(".train class: every spell the class module lists up to the player's level", function()
		assert.is_false(satisfied(ns, "train", "class", context)) -- no class module
		ns = mocks.load({ classes = { HUNTER = { trainerSpells = { [1] = { 11 }, [4] = { 12, 13 }, [6] = { 14 } } } } })
		context.level = 4
		assert.is_false(satisfied(ns, "train", "class", context))
		context.spells = { [11] = true, [12] = true, [13] = true }
		assert.is_true(satisfied(ns, "train", "class", context))
		context.level = 6
		assert.is_false(satisfied(ns, "train", "class", context))
		context.spells[14] = true
		assert.is_true(satisfied(ns, "train", "class", context))
	end)

	it(".train class: nothing listed yet means nothing to train", function()
		ns = mocks.load({ classes = { HUNTER = { trainerSpells = { [4] = { 12 } } } } })
		context.level = 2
		assert.is_true(satisfied(ns, "train", "class", context))
		ns = mocks.load({ classes = { HUNTER = { trainerSpells = {} } } })
		assert.is_true(satisfied(ns, "train", "class", context))
		ns = mocks.load({ classes = { HUNTER = {} } })
		assert.is_false(satisfied(ns, "train", "class", context))
	end)

	it(".trainprof: learned since the step became current", function()
		local def, args, state = ns.Directives:Get("trainprof"), parsed(ns, "trainprof", "skinning"), {}
		def.onStart(args, context, state)
		assert.is_false(def.isSatisfied(args, context, state))
		context.skills[393] = { 1, 75 }
		assert.is_true(def.isSatisfied(args, context, state))
	end)

	it(".trainprof: its maximum rose since the step became current", function()
		local def, args, state = ns.Directives:Get("trainprof"), parsed(ns, "trainprof", "skinning"), {}
		context.skills[393] = { 60, 75 }
		def.onStart(args, context, state)
		assert.is_false(def.isSatisfied(args, context, state))
		context.skills[393] = { 61, 75 }
		assert.is_false(def.isSatisfied(args, context, state))
		context.skills[393] = { 61, 150 }
		assert.is_true(def.isSatisfied(args, context, state))
	end)

	it(".trainprof: a second onStart keeps the first snapshot", function()
		local def, args, state = ns.Directives:Get("trainprof"), parsed(ns, "trainprof", "skinning"), {}
		context.skills[393] = { 60, 75 }
		def.onStart(args, context, state)
		context.skills[393] = { 60, 150 }
		def.onStart(args, context, state)
		assert.is_true(def.isSatisfied(args, context, state))
	end)

	it(".trainprof: nothing to train at the top rank or far below the next one", function()
		local def, args = ns.Directives:Get("trainprof"), parsed(ns, "trainprof", "skinning")
		context.skills[393] = { 300, 300 }
		local state = {}
		def.onStart(args, context, state)
		assert.is_true(def.isSatisfied(args, context, state))
		context.skills[393] = { 80, 150 } -- trained before the step: nothing to do here yet
		state = {}
		def.onStart(args, context, state)
		assert.is_true(def.isSatisfied(args, context, state))
		context.skills[393] = { 125, 150 } -- close enough to train the next rank
		assert.is_false(def.isSatisfied(args, context, {}))
	end)

	it(".trainprof: a module may narrow the rank-up window", function()
		ns = mocks.load({ professions = { skinning = { skillLine = 393, ranks = { 75, 150 }, rankUpWindow = 5 } } })
		context.skills[393] = { 60, 75 }
		assert.is_true(satisfied(ns, "trainprof", "skinning", context, {}))
		context.skills[393] = { 71, 75 }
		assert.is_false(satisfied(ns, "trainprof", "skinning", context, {}))
	end)

	it(".trainprof: false for an unknown profession or one not learned", function()
		assert.is_false(satisfied(ns, "trainprof", "nosuchkey", context, {}))
		assert.is_false(satisfied(ns, "trainprof", "skinning", context, {}))
		assert.is_false(satisfied(ns, "trainprof", "skinning", context, nil))
	end)

	it(".skill: rank at least N", function()
		assert.is_false(satisfied(ns, "skill", "skinning 50", context)) -- not learned
		assert.is_false(satisfied(ns, "skill", "nosuchkey 50", context))
		context.skills[393] = { 49, 75 }
		assert.is_false(satisfied(ns, "skill", "skinning 50", context))
		context.skills[393] = { 50, 75 }
		assert.is_true(satisfied(ns, "skill", "skinning 50", context))
		context.skills[393] = { 51, 75 }
		assert.is_true(satisfied(ns, "skill", "skinning 50", context))
	end)

	it(".craft: the count in its state reached", function()
		assert.is_false(satisfied(ns, "craft", "2152,5", context, nil))
		assert.is_false(satisfied(ns, "craft", "2152,5", context, {}))
		assert.is_false(satisfied(ns, "craft", "2152,5", context, { started = true, count = 4 }))
		assert.is_true(satisfied(ns, "craft", "2152,5", context, { started = true, count = 5 }))
	end)

	it(".buy and .collect: at least the count in bags", function()
		for _, name in ipairs({ "buy", "collect" }) do
			context.items = { [2516] = 199 }
			assert.is_false(satisfied(ns, name, "2516,200", context), name)
			context.items[2516] = 200
			assert.is_true(satisfied(ns, name, "2516,200", context), name)
		end
	end)

	it(".level: player level at least N", function()
		context.level = 9
		assert.is_false(satisfied(ns, "level", "10", context))
		context.level = 10
		assert.is_true(satisfied(ns, "level", "10", context))
	end)

	it(".todo: never", function()
		context.level = 60
		assert.is_false(satisfied(ns, "todo", '"reason"', context))
	end)

	it(".sticky: whatever the inner directive says", function()
		context.level = 4
		assert.is_false(satisfied(ns, "sticky", ".level 5", context))
		context.level = 5
		assert.is_true(satisfied(ns, "sticky", ".level 5", context))
	end)

	it("the display and modifier directives have no isSatisfied", function()
		for _, name in ipairs({ "fish", "hub", "link", "note", "optional", "reward", "text", "use" }) do
			assert.is_nil(ns.Directives:Get(name).isSatisfied, name)
		end
	end)
end)

describe("targets", function()
	it(".goto and .fish pin their own coordinates", function()
		local ns = mocks.load()
		local context = mocks.context()
		assert.are.same(
			{ { map = 1411, x = 42.1, y = 68.7, kind = "goto", radius = 10 } },
			targets(ns, "goto", "1411,42.1,68.7", context)
		)
		assert.are.equal(25, targets(ns, "goto", "1411,42.1,68.7,25", context)[1].radius)
		assert.are.same({ { map = 1411, x = 55, y = 70, kind = "fish" } }, targets(ns, "fish", "1411,55,70", context))
	end)

	it("quest givers and enders come from the data pack", function()
		local ns = mocks.load({ pack = fakePack() })
		local context = mocks.context()
		assert.are.same(
			{ { map = 1411, x = 42.1, y = 68.7, kind = "accept", npc = 101 } },
			targets(ns, "accept", "787", context)
		)
		assert.are.same(
			{ { map = 1411, x = 42.1, y = 68.7, kind = "turnin", npc = 101 } },
			targets(ns, "turnin", "787", context)
		)
		assert.are.equal(2, #targets(ns, "accept", "788", context))
		assert.are.same(
			{ { map = 1411, x = 55, y = 55, kind = "turnin", object = 301 } },
			targets(ns, "turnin", "788", context)
		)
	end)

	it("no data pack, no pins (the step's .goto stands in, see Conditions)", function()
		local ns = mocks.load()
		local context = mocks.context({ position = { map = 1411 } })
		assert.are.same({}, targets(ns, "accept", "787", context))
		assert.are.same({}, targets(ns, "turnin", "787", context))
		assert.are.same({}, targets(ns, "complete", "787", context))
		assert.are.same({}, targets(ns, "buy", "2516,1", context))
	end)

	it("learned positions and quest givers fill in for the data pack", function()
		local ns = mocks.load()
		ns.db.learned.npcs[101] = { n = "Learned Giver", map = 1411, x = 42.2, y = 68.6, t = 1, c = 2 }
		ns.db.learned.quests = { [900] = { start = { npc = 101 }, finish = { obj = 301 } } }
		ns.db.learned.objects[301] = { n = "Learned Crate", map = 1411, x = 55, y = 55 }
		local context = mocks.context()
		assert.are.same(
			{ { map = 1411, x = 42.2, y = 68.6, kind = "accept", npc = 101 } },
			targets(ns, "accept", "900", context)
		)
		assert.are.same(
			{ { map = 1411, x = 55, y = 55, kind = "turnin", object = 301 } },
			targets(ns, "turnin", "900", context)
		)
		assert.are.equal('Accept "Quest #900" from Learned Giver', describe_(ns, "accept", "900"))
	end)

	it(".complete pins the areas of the objectives still open, the player's map first", function()
		local ns = mocks.load({ pack = fakePack() })
		local context = mocks.context({ position = { map = 1413 }, log = { [787] = true } })
		context.objectives[787] = { { text = "Boar slain: 3/10", finished = false } }
		local pins = targets(ns, "complete", "787", context)
		assert.are.same({
			{ map = 1413, x = 10, y = 10, kind = "objective", npc = 201, label = "Boar slain: 3/10", objective = 1 },
			{ map = 1411, x = 50, y = 50, kind = "objective", npc = 201, label = "Boar slain: 3/10", objective = 1 },
			{ map = 1411, x = 52, y = 48, kind = "objective", npc = 201, label = "Boar slain: 3/10", objective = 1 },
		}, pins)
		context.objectives[787][1].finished = true
		assert.are.same({}, targets(ns, "complete", "787", context))
	end)

	it(".complete: item objectives pin the NPCs that drop them, object objectives the object", function()
		local ns = mocks.load({ pack = fakePack() })
		local context = mocks.context()
		local pins = targets(ns, "complete", "789", context)
		assert.are.equal(2, #pins)
		assert.are.equal(202, pins[1].npc)
		assert.are.equal(1, pins[1].objective)
		assert.are.equal(301, pins[2].object)
		assert.are.equal(2, pins[2].objective)
		assert.are.same({ pins[2] }, targets(ns, "complete", "789,2", context))
		assert.are.same({}, targets(ns, "complete", "789,3", context)) -- explore: no position
	end)

	it("takes at most MAX_PINS pins from the pack per directive", function()
		local pack = fakePack()
		pack.quests[791] = { n = "Wide", o = { { k = "kill", id = 203, c = 1 } } }
		local ns = mocks.load({ pack = pack })
		assert.are.equal(ns.Directives.MAX_PINS, #targets(ns, "complete", "791", mocks.context()))
	end)

	it("trainers and vendors: the ones on the player's map that serve the player's faction", function()
		local ns = mocks.load({ pack = fakePack(), professions = { skinning = SKINNING } })
		local inCity = mocks.context({ position = { map = 1454, x = 50, y = 50 } })
		local inField = mocks.context({ position = { map = 1411, x = 50, y = 50 } })
		assert.are.same(
			{ { map = 1454, x = 40, y = 40, kind = "trainer", npc = 501 } },
			targets(ns, "trainprof", "skinning", inCity)
		)
		assert.are.same(
			{ { map = 1411, x = 40, y = 40, kind = "trainer", npc = 503 } },
			targets(ns, "trainprof", "skinning", inField)
		)
		assert.are.same(
			{ { map = 1454, x = 40, y = 40, kind = "trainer", npc = 501 } },
			targets(ns, "train", "class", inCity)
		)
		assert.are.same(
			{ { map = 1454, x = 40, y = 40, kind = "vendor", npc = 501 } },
			targets(ns, "buy", "401,5", inCity)
		)
		assert.are.same({}, targets(ns, "buy", "401,5", inField))
		assert.are.same({}, targets(ns, "train", "1494", mocks.context())) -- position unknown
		assert.are.same({}, targets(ns, "trainprof", "nosuchkey", inCity))
	end)

	it(".collect: nearby vendors, then the NPCs that drop it", function()
		local ns = mocks.load({ pack = fakePack() })
		local pins = targets(ns, "collect", "401,5", mocks.context({ position = { map = 1454 } }))
		assert.are.same({
			{ map = 1454, x = 40, y = 40, kind = "vendor", npc = 501 },
			{ map = 1411, x = 60, y = 60, kind = "gather", npc = 202 },
		}, pins)
	end)

	it(".sticky hands over to its inner directive", function()
		local ns = mocks.load({ pack = fakePack() })
		assert.are.same(
			{ { map = 1411, x = 42.1, y = 68.7, kind = "accept", npc = 101 } },
			targets(ns, "sticky", ".accept 787", mocks.context())
		)
	end)
end)

describe("describe", function()
	it("names quests, givers and enders from the data pack", function()
		local ns = mocks.load({ pack = fakePack() })
		assert.are.equal('Accept "The Basics" from Quest Giver', describe_(ns, "accept", "787"))
		assert.are.equal('Accept "Two Givers"', describe_(ns, "accept", "788"))
		assert.are.equal('Turn in "The Basics" to Quest Giver', describe_(ns, "turnin", "787"))
		assert.are.equal('Turn in "Two Givers" to Crate', describe_(ns, "turnin", "788"))
		assert.are.equal('Complete "The Basics"', describe_(ns, "complete", "787"))
		assert.are.equal('Complete objective 2 of "Mixed Objectives"', describe_(ns, "complete", "789,2"))
	end)

	it('falls back to the client\'s quest title, then to "Quest #id"', function()
		local ns = mocks.load()
		assert.are.equal('Accept "Quest #787"', describe_(ns, "accept", "787"))
		G.C_QuestLog = {
			GetTitleForQuestID = function(questID)
				return questID == 787 and "Client Title" or nil
			end,
		}
		assert.are.equal('Turn in "Client Title"', describe_(ns, "turnin", "787"))
		assert.are.equal('Turn in "Quest #788"', describe_(ns, "turnin", "788"))
	end)

	it("adds objective progress lines from the quest log", function()
		local ns = mocks.load()
		local context = mocks.context()
		context.objectives[787] = {
			{ text = "Boar slain: 3/10", finished = false },
			{ text = "", finished = false, have = 1, need = 4 },
		}
		local def = ns.Directives:Get("complete")
		assert.are.same({ "- Boar slain: 3/10", "- 1/4" }, def.progress(parsed(ns, "complete", "787"), context))
		assert.are.same({ "- 1/4" }, def.progress(parsed(ns, "complete", "787,2"), context))
		assert.are.same({}, def.progress(parsed(ns, "complete", "790"), context))
	end)

	it("places: map names from the client, then the pack", function()
		local ns = mocks.load({ pack = fakePack() })
		assert.are.equal("Go to Durotar 42.1, 68.7", describe_(ns, "goto", "1411,42.1,68.7"))
		assert.are.equal("Go to map 1413 10.0, 20.0", describe_(ns, "goto", "1413,10,20"))
		G.C_Map = {
			GetMapInfo = function(mapID)
				return { mapID = mapID, name = "Client Map" }
			end,
		}
		assert.are.equal("Fish at Client Map 55.0, 70.0", describe_(ns, "fish", "1411,55,70"))
	end)

	it("items: the client's name, then the pack's, then a placeholder (and asks the client to load it)", function()
		local ns = mocks.load({ pack = fakePack() })
		local requested = {}
		G.C_Item = {
			GetItemInfo = function(itemID)
				if itemID == 2516 then
					return "Light Shot", "link", 1
				end
			end,
			RequestLoadItemDataByID = function(itemID)
				requested[#requested + 1] = itemID
			end,
		}
		local context = mocks.context({ items = { [2516] = 40 } })
		assert.are.equal("Buy Light Shot (40/200)", describe_(ns, "buy", "2516,200", context))
		assert.are.equal("Collect Pack Item (0/5)", describe_(ns, "collect", "401,5", context))
		assert.are.equal("Use Item #5070", describe_(ns, "use", "5070", context))
		assert.are.same({ 401, 5070 }, requested)
		G.C_Item.GetItemNameByID = function()
			return "By ID"
		end
		assert.are.equal("Choose By ID as the reward", describe_(ns, "reward", "4402,2516"))
	end)

	it("caps item counts at the target", function()
		local ns = mocks.load()
		local context = mocks.context({ items = { [2516] = 250 } })
		assert.are.equal("Buy Item #2516 (200/200)", describe_(ns, "buy", "2516,200", context))
	end)

	it("spells: the client's name, else a placeholder", function()
		local ns = mocks.load()
		finally(function()
			G.C_Spell = nil
		end)
		assert.are.equal("Train Spell #1494", describe_(ns, "train", "1494"))
		G.C_Spell = {
			GetSpellInfo = function(spellID)
				return { spellID = spellID, name = "Track Beasts" }
			end,
		}
		assert.are.equal("Train Track Beasts", describe_(ns, "train", "1494"))
		assert.are.equal("Craft Track Beasts (3/5)", describe_(ns, "craft", "2152,5", nil, { count = 3 }))
		assert.are.equal("Craft Track Beasts (5/5)", describe_(ns, "craft", "2152,5", nil, { count = 7 }))
		assert.are.equal("Craft Track Beasts (0/5)", describe_(ns, "craft", "2152,5"))
	end)

	it("professions: the client's name, the learned list's, the pack's, else the key", function()
		local ns = mocks.load({ professions = { skinning = SKINNING } })
		assert.are.equal("Train skinning", describe_(ns, "trainprof", "skinning"))
		assert.are.equal("Raise nosuchkey to 5", describe_(ns, "skill", "nosuchkey 5"))
		ns = mocks.load({ pack = fakePack(), professions = { skinning = SKINNING } })
		assert.are.equal("Train Skinning", describe_(ns, "trainprof", "skinning"))
		ns.Player.professions = { [393] = { key = "skinning", name = "Learned Name", rank = 23, max = 75 } }
		assert.are.equal("Train Learned Name", describe_(ns, "trainprof", "skinning"))
		G.C_TradeSkillUI = {
			GetProfessionInfoBySkillLineID = function()
				return { professionID = 393, professionName = "Client Name" }
			end,
		}
		local context = mocks.context({ skills = { [393] = { 23, 75 } } })
		assert.are.equal("Raise Client Name to 50 (now 23)", describe_(ns, "skill", "skinning 50", context))
	end)

	it(".train class says how many spells are due", function()
		local ns = mocks.load({ classes = { HUNTER = { trainerSpells = { [1] = { 11 }, [4] = { 12, 13 } } } } })
		local context = mocks.context({ level = 4, spells = { [11] = true } })
		assert.are.equal("Train your class spells (2 to learn)", describe_(ns, "train", "class", context))
		context.spells[12], context.spells[13] = true, true
		assert.are.equal("Train your class spells", describe_(ns, "train", "class", context))
	end)

	it("the rest: level, todo, note, text, link, reward", function()
		local ns = mocks.load()
		assert.are.equal("Reach level 10", describe_(ns, "level", "10"))
		assert.are.equal("To do: Position unknown", describe_(ns, "todo", '"Position unknown"'))
		assert.are.equal("Skip if you like.", describe_(ns, "note", "Skip if you like."))
		assert.are.equal("Up the ramp.", describe_(ns, "text", "Up the ramp."))
		assert.are.equal("https://example.org/x", describe_(ns, "link", "https://example.org/x"))
		assert.are.equal("Choose reward 2", describe_(ns, "reward", "4402,2"))
		assert.are.equal("Raise skinning to 50", describe_(ns, "sticky", ".skill skinning 50"))
		assert.is_nil(ns.Directives:Get("optional").describe)
		assert.is_nil(ns.Directives:Get("hub").describe)
	end)
end)

describe("the class quest soft check on .train", function()
	local CHAIN = { name = "The Hunter's Path", level = 10, quests = { 6061, 6062 }, offeredBy = "trainer" }

	local function check(opts, context)
		local ns = mocks.load(opts)
		return ns.Directives:Get("train").progress(parsed(ns, "train", "class"), context)
	end

	it("names a chain the trainer offers at this level that is neither started nor done", function()
		local opts = { classes = { HUNTER = { trainerSpells = {}, classQuests = { CHAIN } } } }
		assert.are.same({ "Class quest available here: The Hunter's Path" }, check(opts, mocks.context({ level = 10 })))
		assert.is_nil(check(opts, mocks.context({ level = 9 })))
		assert.is_nil(check(opts, mocks.context({ level = 10, log = { [6061] = true } })))
		assert.is_nil(check(opts, mocks.context({ level = 12, completed = { [6062] = true } })))
	end)

	it("leaves out chains other NPCs offer and chains the guide skips", function()
		local byNpc = { name = "Elsewhere", level = 10, quests = { 7001 }, offeredBy = 3171 }
		local opts =
			{ classes = { HUNTER = { classQuests = { byNpc, CHAIN } } }, guide = { skipQuests = { [6061] = "x" } } }
		assert.is_nil(check(opts, mocks.context({ level = 10 })))
	end)

	it("works without a name or a class module", function()
		local opts = { classes = { HUNTER = { classQuests = { { level = 1, quests = { 1 } } } } } }
		assert.are.same({ "Class quest available here" }, check(opts, mocks.context({ level = 1 })))
		assert.is_nil(check({}, mocks.context({ level = 60 })))
	end)
end)
