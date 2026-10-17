-- Specs for Engine/Parser.lua against docs/GUIDE-FORMAT.md and docs/ENGINE.md. The registries the parser calls
-- (ns.Directives, ns.Chapters, ns.Professions) are written by other tracks; here they are stand-ins with the documented
-- shapes, and the directive registry knows a few fake directives.
local addon = dofile("tests/helpers/addon.lua")

local HUNTER = { classFile = "HUNTER", raceFile = "Troll", faction = "Horde" }
local WARRIOR = { classFile = "WARRIOR", raceFile = "Orc", faction = "Horde" }
local MAGE = { classFile = "MAGE", raceFile = "Human", faction = "Alliance" }
local PLAN = {
	primary = { "skinning", "leatherworking" },
	secondary = { "firstaid", "cooking", "fishing" },
	declined = {},
}

local function lines(...)
	return table.concat({ ... }, "\n")
end

local function number(text)
	return text:match("^%d+$") and tonumber(text)
end

-- Fake directive defs: each records the argument string and ctx it was given.
local function fakeDirectives(env)
	local function define(name, parse)
		env.defs[name] = {
			kind = "misc",
			parse = function(argString, ctx)
				env.parsed[#env.parsed + 1] = { name = name, args = argString, ctx = ctx }
				return parse(argString, ctx)
			end,
		}
	end
	define("goto", function(text)
		local map, x, y, radius = text:match("^(%d+),([%d%.]+),([%d%.]+),?(%d*)$")
		if not map then
			return nil, "expected <map>,<x>,<y>[,<radius>]"
		end
		return { map = tonumber(map), x = tonumber(x), y = tonumber(y), radius = tonumber(radius) }
	end)
	for _, name in ipairs({ "accept", "turnin", "level" }) do
		define(name, function(text)
			local id = number(text)
			if not id then
				return nil, "expected a number"
			end
			return { id = id }
		end)
	end
	for _, name in ipairs({ "note", "text" }) do
		define(name, function(text)
			if text == "" then
				return nil, "expected text"
			end
			return { text = text }
		end)
	end
	define("skill", function(text)
		local key, value = text:match("^(%S+) (%d+)$")
		if not key then
			return nil, "expected <key> <N>"
		end
		return { key = key, value = tonumber(value) }
	end)
	define("trainprof", function(text)
		return text:match("^%S+$") and { key = text } or nil, "expected <key>"
	end)
	define("home", function(text)
		if text ~= "" then
			return nil, "takes no arguments"
		end
		return {}
	end)
	define("fail", function()
		return nil, "always fails"
	end)
	define("silent", function()
		return nil
	end)
	define("boom", function()
		error("kaboom")
	end)
	env.defs.bare = { kind = "misc" } -- no parse function
end

-- Loads the addon with the parser and installs the stand-in registries.
local function setup()
	local ns, mock = addon.load({ extra = { "Engine/Parser.lua" } })
	local env = { ns = ns, mock = mock, defs = {}, chapters = {}, parsed = {}, lookups = {}, chapterLookups = {} }
	fakeDirectives(env)
	ns.Directives = {
		Get = function(_, name)
			env.lookups[#env.lookups + 1] = name
			return env.defs[name]
		end,
	}
	ns.Chapters = {
		Get = function(_, id)
			env.chapterLookups[#env.chapterLookups + 1] = id
			return env.chapters[id]
		end,
	}
	ns.Professions = { Merge = function() end }
	return ns.Parser, env
end

local function guideDef(text)
	return {
		id = "test-guide",
		name = "Test Guide",
		faction = "*",
		races = { "*" },
		classes = { "*" },
		levels = { 1, 60 },
		text = text,
	}
end

local function parse(Parser, text, opts)
	return Parser:ParseGuide(guideDef(text), opts or { player = HUNTER })
end

local function stepIds(steps)
	local ids = {}
	for i, step in ipairs(steps) do
		ids[i] = step.id
	end
	return ids
end

local function names(directives)
	local out = {}
	for i, directive in ipairs(directives) do
		out[i] = directive.name
	end
	return out
end

local function summarize(directives)
	local out = {}
	for i, d in ipairs(directives) do
		out[i] = { name = d.name, args = d.args, text = d.text, line = d.line, sticky = d.sticky }
	end
	return out
end

local function chapterSummary(guide)
	local out = {}
	for i, c in ipairs(guide.chapters) do
		out[i] = {
			id = c.id,
			name = c.name,
			levels = c.levels,
			dungeon = c.dungeon,
			first = c.first,
			last = c.last,
			implicit = c.implicit,
		}
	end
	return out
end

local function errorList(errors)
	local out = {}
	for i, e in ipairs(errors) do
		out[i] = tostring(e.source) .. ":" .. tostring(e.line) .. ": " .. tostring(e.message)
	end
	return out
end

local function findError(errors, source, line, fragment)
	for _, e in ipairs(errors) do
		if e.source == source and e.line == line and e.message:find(fragment, 1, true) then
			return e
		end
	end
end

local function assertError(errors, source, line, fragment)
	assert.is_truthy(
		findError(errors, source, line, fragment),
		string.format(
			"expected an error at %s:%s containing '%s'; got:\n%s",
			source,
			line,
			fragment,
			table.concat(errorList(errors), "\n")
		)
	)
end

local function assertNoErrors(errors)
	assert.are.same({}, errorList(errors))
end

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

-- The derived fields of a guide agree with each other.
local function checkGuide(guide)
	assert.are.equal(#guide.steps, count(guide.byId))
	for i, step in ipairs(guide.steps) do
		assert.are.equal(i, step.index)
		assert.are.equal(step, guide.byId[step.id])
		assert.is_table(guide.chapters[step.chapter])
		assert.is_true(#step.directives + #step.sticky > 0)
	end
	for _, chapter in ipairs(guide.chapters) do
		assert.is_true(chapter.first <= chapter.last)
		assert.are.equal(guide.steps[chapter.first].chapter, guide.steps[chapter.last].chapter)
	end
	for _, err in ipairs(guide.errors) do
		assert.is_string(err.source)
		assert.is_number(err.line)
		assert.is_string(err.message)
	end
end

describe("Parser lines", function()
	it("ignores blank lines, indentation and comments", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"-- a comment line",
				"",
				"step -- the first step",
				"\t  .goto 1411,42.1,68.7   -- a trailing comment",
				"    -- an indented comment",
				"  .note Waypoints like a--b stay   ",
				"step",
				"  .note see https://example.com/a--b"
			)
		)
		assertNoErrors(guide.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(guide.steps))
		local first = guide.steps[1]
		assert.are.equal(3, first.line)
		assert.are.same({ map = 1411, x = 42.1, y = 68.7 }, first.directives[1].args)
		assert.are.equal(4, first.directives[1].line)
		assert.are.equal("Waypoints like a--b stay", first.directives[2].args.text)
		assert.are.equal("see https://example.com/a--b", guide.steps[2].directives[1].args.text)
	end)

	it("accepts CRLF line endings", function()
		local Parser = setup()
		local guide = parse(Parser, "step\r\n  .goto 1411,1,2\r\n\r\nstep\r\n  .accept 787 >> Accept it\r\n")
		assertNoErrors(guide.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(guide.steps))
		assert.are.equal(4, guide.steps[2].line)
		assert.are.equal("Accept it", guide.steps[2].directives[1].text)
	end)

	it("reports anything that is not a statement, with its line, and goes on", function()
		local Parser = setup()
		local guide =
			parse(Parser, lines("step", "  .goto 1411,1,2", "goto 1411,1,2", "steps", "Step", "step", "  .accept 1"))
		assertError(guide.errors, "test-guide", 3, "not a step, directive or header: goto 1411,1,2")
		assertError(guide.errors, "test-guide", 4, "not a step, directive or header: steps")
		assertError(guide.errors, "test-guide", 5, "not a step, directive or header: Step")
		assert.are.equal(3, #guide.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(guide.steps))
		assert.are.same({ "goto" }, names(guide.steps[1].directives))
	end)

	it("reports a directive line before any step", function()
		local Parser = setup()
		local guide = parse(Parser, lines(".goto 1411,1,2", "step", "  .accept 1"))
		assertError(guide.errors, "test-guide", 1, "directive outside a step")
		assert.are.equal(1, #guide.errors)
		assert.are.same({ "test-guide:1" }, stepIds(guide.steps))
	end)

	it("reports malformed directive lines", function()
		local Parser = setup()
		local guide = parse(Parser, lines("step", "  .", "  .123", "  .goto,1411,1,2", "  .accept 1"))
		assertError(guide.errors, "test-guide", 2, "malformed directive line")
		assertError(guide.errors, "test-guide", 3, "malformed directive line")
		assertError(guide.errors, "test-guide", 4, "expected a space after .goto")
		assert.are.equal(3, #guide.errors)
		assert.are.same({ "accept" }, names(guide.steps[1].directives))
	end)
end)

describe("Parser headers", function()
	local headerText = lines(
		"#guide Troll Hunter 1-60 (draft)",
		"#author someone",
		"#version 2026.10",
		"#class HUNTER",
		"#race Troll,Orc",
		"#faction Horde",
		"#professions skinning,leatherworking,firstaid,cooking,fishing",
		"#include missing-chapter",
		"step",
		"  .accept 1"
	)

	it("reads the guide's own headers without a full parse", function()
		local Parser, env = setup()
		assert.are.same({
			guide = "Troll Hunter 1-60 (draft)",
			author = "someone",
			version = "2026.10",
			class = { "HUNTER" },
			race = { "Troll", "Orc" },
			faction = "Horde",
			professions = { "skinning", "leatherworking", "firstaid", "cooking", "fishing" },
		}, Parser:Headers(guideDef(headerText)))
		assert.are.same({}, env.chapterLookups)
		assert.are.same({}, env.lookups)
	end)

	it("gives ParseGuide the same headers; the Register name wins over #guide", function()
		local Parser = setup()
		local def = guideDef(headerText)
		local guide = Parser:ParseGuide(def, { player = HUNTER })
		assert.are.same(Parser:Headers(def), guide.headers)
		assert.are.equal("Test Guide", guide.name)
		assert.are.equal(def, guide.def)
		assert.are.equal("test-guide", guide.id)

		def.name = nil
		assert.are.equal("Troll Hunter 1-60 (draft)", Parser:ParseGuide(def, { player = HUNTER }).name)
		def.text = "step\n  .accept 1"
		assert.are.equal("test-guide", Parser:ParseGuide(def, { player = HUNTER }).name)
	end)

	it("defaults to an empty profession list", function()
		local Parser = setup()
		assert.are.same({ professions = {} }, Parser:Headers(guideDef("step\n  .accept 1")))
		assert.are.same({ professions = {} }, Parser:Headers({}))
		assert.are.same({ professions = {} }, Parser:Headers(nil))
		assert.are.same({ professions = {} }, parse(Parser, "step\n  .accept 1").headers)
	end)

	it("reports malformed, unknown and duplicate headers; the first valid one wins", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"#professions skinning,,cooking",
				"#professions first aid",
				"#professions skinning, cooking",
				"#author",
				"#author one",
				"#author two",
				"#flavor sweet",
				"# spaced",
				"step",
				"  .accept 1"
			)
		)
		assertError(guide.errors, "test-guide", 1, "#professions: malformed list")
		assertError(guide.errors, "test-guide", 2, "#professions: malformed list")
		assertError(guide.errors, "test-guide", 4, "#author needs a value")
		assertError(guide.errors, "test-guide", 6, "duplicate #author (first on line 5)")
		assertError(guide.errors, "test-guide", 7, "unknown header #flavor")
		assertError(guide.errors, "test-guide", 8, "unknown header #")
		assert.are.equal(6, #guide.errors)
		assert.are.same({ "skinning", "cooking" }, guide.headers.professions)
		assert.are.equal("one", guide.headers.author)
		assert.are.same(guide.headers, Parser:Headers(guide.def))
	end)

	it("keeps guide-only headers out of chapters and tracks", function()
		local Parser, env = setup()
		env.chapters.shared =
			lines("#author someone", "#professions cooking", "#chapter 1-2 Shared", "step", "  .accept 1")
		local guide = parse(Parser, "#include shared")
		assertError(guide.errors, "shared", 1, "#author is only allowed in a guide's own text")
		assertError(guide.errors, "shared", 2, "#professions is only allowed in a guide's own text")
		assert.are.equal(2, #guide.errors)
		assert.are.same({ professions = {} }, guide.headers)

		local steps, errors = Parser:ParseTrack(
			"cooking",
			lines(
				"#track cooking",
				"#author someone",
				"#include shared",
				"#chapter 1 Nope",
				"#skipquest 1 >> no",
				"step @level 5",
				"  .accept 1"
			),
			{ player = HUNTER }
		)
		assertError(errors, "track:cooking", 2, "#author is not allowed in a profession track")
		assertError(errors, "track:cooking", 3, "#include is not allowed in a profession track")
		assertError(errors, "track:cooking", 4, "#chapter is not allowed in a profession track")
		assertError(errors, "track:cooking", 5, "#skipquest is not allowed in a profession track")
		assert.are.equal(4, #errors)
		assert.are.same({ "track:cooking:1" }, stepIds(steps))
	end)
end)

describe("Parser #include", function()
	it("splices a chapter's steps where it is included, with the chapter's ids, sources and lines", function()
		local Parser, env = setup()
		env.chapters["durotar-1-6"] =
			lines("#chapter 1-6 Valley of Trials", "step", "  .accept 4641", "step", "  .turnin 4641")
		local guide = parse(Parser, lines("step", "  .goto 1411,1,1", "#include durotar-1-6", "step", "  .accept 787"))
		assertNoErrors(guide.errors)
		assert.are.same({ "test-guide:1", "durotar-1-6:1", "durotar-1-6:2", "test-guide:2" }, stepIds(guide.steps))
		local where = {}
		for i, step in ipairs(guide.steps) do
			where[i] = { step.source, step.line, step.chapter }
		end
		-- the guide's own step after the include continues the included chapter: the text is spliced in
		assert.are.same(
			{ { "test-guide", 1, 1 }, { "durotar-1-6", 2, 2 }, { "durotar-1-6", 4, 2 }, { "test-guide", 4, 2 } },
			where
		)
		assert.are.equal(3, guide.steps[2].directives[1].line)
		checkGuide(guide)
	end)

	it("resolves nested includes", function()
		local Parser, env = setup()
		env.chapters.outer = lines("#chapter 1-5 Outer", "step", "  .accept 1", "#include inner", "step", "  .accept 3")
		env.chapters.inner = lines("step", "  .accept 2")
		local guide = parse(Parser, "#include outer")
		assertNoErrors(guide.errors)
		assert.are.same({ "outer:1", "inner:1", "outer:2" }, stepIds(guide.steps))
		assert.are.same({ "outer", "inner" }, env.chapterLookups)
		assert.are.same({ 1, 1, 1 }, { guide.steps[1].chapter, guide.steps[2].chapter, guide.steps[3].chapter })
	end)

	it("reports an unknown chapter where it is included and goes on", function()
		local Parser, env = setup()
		env.chapters.outer = lines("step", "  .accept 1", "#include nowhere-else")
		local guide = parse(Parser, lines("#include nowhere", "#include outer", "step", "  .accept 2"))
		assertError(guide.errors, "test-guide", 1, "unknown chapter nowhere")
		assertError(guide.errors, "outer", 3, "unknown chapter nowhere-else")
		assert.are.equal(2, #guide.errors)
		assert.are.same({ "outer:1", "test-guide:1" }, stepIds(guide.steps))
	end)

	it("reports include cycles instead of looping", function()
		local Parser, env = setup()
		env.chapters.a = lines("#chapter 1-2 A", "step", "  .accept 1", "#include b")
		env.chapters.b = lines("step", "  .accept 2", "#include a")
		env.chapters.selfish = lines("#include selfish", "step", "  .accept 3")
		env.chapters.back = lines("#include test-guide", "step", "  .accept 4")
		local guide = parse(Parser, lines("#include a", "#include selfish", "#include back"))
		assertError(guide.errors, "b", 3, "include cycle: a -> b -> a")
		assertError(guide.errors, "selfish", 1, "include cycle: selfish -> selfish")
		assertError(guide.errors, "back", 1, "include cycle: test-guide -> back -> test-guide")
		assert.are.equal(3, #guide.errors)
		assert.are.same({ "a:1", "b:1", "selfish:1", "back:1" }, stepIds(guide.steps))
	end)

	it("reports a chapter included twice, whose step ids would collide", function()
		local Parser, env = setup()
		env.chapters.twice = lines("step", "  .accept 1")
		env.chapters.other = lines("#include twice")
		local guide = parse(Parser, lines("#include twice", "#include other", "#include twice"))
		assertError(guide.errors, "other", 1, "chapter twice is already included (test-guide line 1)")
		assertError(guide.errors, "test-guide", 3, "chapter twice is already included (test-guide line 1)")
		assert.are.equal(2, #guide.errors)
		assert.are.same({ "twice:1" }, stepIds(guide.steps))
	end)

	it("needs a chapter id of lowercase letters, digits and -", function()
		local Parser, env = setup()
		local guide = parse(Parser, lines("#include Durotar", "#include", "#include a b", "#include a_b"))
		for line = 1, 4 do
			assertError(guide.errors, "test-guide", line, "#include needs one chapter id")
		end
		assert.are.equal(4, #guide.errors)
		assert.are.same({}, env.chapterLookups)
	end)

	it("treats chapter text that is not a string, or a failing registry, as an unknown chapter", function()
		local Parser, env = setup()
		env.chapters.weird = 42
		local guide = parse(Parser, "#include weird")
		assertError(guide.errors, "test-guide", 1, "unknown chapter weird")
		env.ns.Chapters = {
			Get = function()
				error("registry broke")
			end,
		}
		guide = parse(Parser, "#include anything")
		assertError(guide.errors, "test-guide", 1, "unknown chapter anything")
		env.ns.Chapters = nil
		guide = parse(Parser, "#include anything")
		assertError(guide.errors, "test-guide", 1, "unknown chapter anything")
	end)
end)

describe("Parser chapters", function()
	it("builds chapters with level ranges, names and #dungeon", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"#chapter 1-6 Valley of Trials",
				"step",
				"  .accept 1",
				"#chapter 17 Wailing Caverns #dungeon",
				"step",
				"  .accept 2",
				"step",
				"  .accept 3",
				"#chapter 7-12 Sen'jin Village -- with a comment",
				"step",
				"  .accept 4"
			)
		)
		assertNoErrors(guide.errors)
		assert.are.same({
			{ id = "test-guide", name = "Valley of Trials", levels = { 1, 6 }, dungeon = false, first = 1, last = 1 },
			{ id = "test-guide#2", name = "Wailing Caverns", levels = { 17, 17 }, dungeon = true, first = 2, last = 3 },
			{ id = "test-guide#3", name = "Sen'jin Village", levels = { 7, 12 }, dungeon = false, first = 4, last = 4 },
		}, chapterSummary(guide))
		assert.are.same({ "test-guide", 4 }, { guide.chapters[2].source, guide.chapters[2].line })
		checkGuide(guide)
	end)

	it("gives each included chapter file its own chapter id", function()
		local Parser, env = setup()
		env.chapters["barrens-12-20"] = lines("#chapter 12-20 The Barrens", "step", "  .accept 1")
		env.chapters["wc-17"] = lines("#chapter 17 Wailing Caverns #dungeon", "step", "  .accept 2")
		local guide = parse(Parser, lines("#include barrens-12-20", "#include wc-17"))
		assert.are.same({ "barrens-12-20", "wc-17" }, { guide.chapters[1].id, guide.chapters[2].id })
		assert.are.same({ "barrens-12-20", "wc-17" }, { guide.chapters[1].source, guide.chapters[2].source })
	end)

	it("puts steps before the first #chapter into an implicit chapter named after the guide", function()
		local Parser = setup()
		local guide = parse(Parser, lines("step", "  .accept 1", "#chapter 2-3 Next", "step", "  .accept 2"))
		assertNoErrors(guide.errors)
		assert.are.same({
			{
				id = "test-guide",
				name = "Test Guide",
				levels = { 1, 60 },
				dungeon = false,
				first = 1,
				last = 1,
				implicit = true,
			},
			{ id = "test-guide#2", name = "Next", levels = { 2, 3 }, dungeon = false, first = 2, last = 2 },
		}, chapterSummary(guide))

		local def = guideDef(lines("#guide From The Header", "step", "  .accept 1"))
		def.name = nil
		assert.are.equal("From The Header", Parser:ParseGuide(def, { player = HUNTER }).chapters[1].name)
	end)

	it("needs no implicit chapter when the text starts with one, even from an include", function()
		local Parser, env = setup()
		env.chapters.first = lines("#chapter 1-6 First", "step", "  .accept 1")
		env.chapters.loose = lines("step", "  .accept 3")
		local guide = parse(Parser, lines("#include first", "step", "  .accept 2"))
		assert.are.same({ "First" }, { guide.chapters[1].name, guide.chapters[2] })
		assert.are.same({ 1, 2 }, { guide.chapters[1].first, guide.chapters[1].last })

		-- an included text without #chapter at the very start lands in the implicit chapter
		guide = parse(Parser, lines("#include loose", "#chapter 4-5 Later", "step", "  .accept 4"))
		assert.are.same({ "test-guide", "test-guide#2" }, { guide.chapters[1].id, guide.chapters[2].id })
		assert.is_true(guide.chapters[1].implicit)
		assert.are.equal("loose", guide.steps[1].source)
	end)

	it("rejects malformed #chapter lines and keeps their steps in the chapter before", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"#chapter 1-6 Good",
				"#chapter 6-1 Backwards",
				"#chapter 0-3 Zero",
				"#chapter a-b Letters",
				"#chapter 5",
				"#chapter 5 #dungeon",
				"#chapter",
				"step",
				"  .accept 1"
			)
		)
		for line = 2, 4 do
			assertError(guide.errors, "test-guide", line, "chapter levels must be N or N-M with 1 <= N <= M")
		end
		for line = 5, 7 do
			assertError(guide.errors, "test-guide", line, "expected #chapter <N or N-M> <name> [#dungeon]")
		end
		assert.are.equal(6, #guide.errors)
		assert.are.same({ "Good" }, { guide.chapters[1].name, guide.chapters[2] })
		assert.are.equal(1, guide.steps[1].chapter)
	end)

	it("drops chapters whose steps are all gated away", function()
		local Parser = setup()
		local text = lines(
			"#chapter 1-6 Everyone",
			"step",
			"  .accept 1",
			"#chapter 13 Hunters only #dungeon",
			"step",
			"  .class HUNTER",
			"  .accept 2",
			"#chapter 14-15 After",
			"step",
			"  .accept 3"
		)
		local hunter = parse(Parser, text, { player = HUNTER })
		local warrior = parse(Parser, text, { player = WARRIOR })
		assert.are.same({ "Everyone", "Hunters only", "After" }, {
			hunter.chapters[1].name,
			hunter.chapters[2].name,
			hunter.chapters[3].name,
		})
		assert.are.equal(2, #warrior.chapters)
		assert.are.same({ "test-guide", "test-guide#3" }, { warrior.chapters[1].id, warrior.chapters[2].id })
		assert.are.same({ 1, 2 }, { warrior.steps[1].chapter, warrior.steps[2].chapter })
		assert.are.same({ 2, 2 }, { warrior.chapters[2].first, warrior.chapters[2].last })
		checkGuide(hunter)
		checkGuide(warrior)
	end)

	it("ends the step being read at #chapter and #include, but not at other headers", function()
		local Parser, env = setup()
		env.chapters.side = lines("step", "  .accept 9")
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .accept 1",
				"#chapter 2-3 Two",
				"  .accept 2",
				"step",
				"  .accept 3",
				"#include side",
				"  .accept 4",
				"step",
				"  .accept 5",
				"#skipquest 99 >> not on this route",
				"  .accept 6"
			)
		)
		assertError(guide.errors, "test-guide", 4, "directive outside a step")
		assertError(guide.errors, "test-guide", 8, "directive outside a step")
		assert.are.equal(2, #guide.errors)
		local shape = {}
		for i, step in ipairs(guide.steps) do
			shape[i] = names(step.directives)
		end
		assert.are.same({ { "accept" }, { "accept" }, { "accept" }, { "accept", "accept" } }, shape)
	end)
end)

describe("Parser steps", function()
	it("keeps directives in line order with their arguments, >> text, line and def", function()
		local Parser, env = setup()
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .goto 1411,42.1,68.7,5",
				"  .accept 787 >> Accept the first quest",
				"  .home",
				"  .bare anything goes here"
			)
		)
		assertNoErrors(guide.errors)
		local step = guide.steps[1]
		assert.are.same({
			{ name = "goto", args = { map = 1411, x = 42.1, y = 68.7, radius = 5 }, line = 2 },
			{ name = "accept", args = { id = 787 }, text = "Accept the first quest", line = 3 },
			{ name = "home", args = {}, line = 4 },
			{ name = "bare", args = "anything goes here", line = 5 },
		}, summarize(step.directives))
		assert.are.equal(env.defs.accept, step.directives[2].def)
		assert.are.same({ {}, {} }, { step.sticky, step.optional })
		assert.is_nil(step.hub)
		assert.is_nil(step.track)
		assert.is_nil(step.anchor)
		assert.are.same(
			{ "test-guide:1", 1, 1, "test-guide", 1 },
			{ step.id, step.index, step.chapter, step.source, step.line }
		)
	end)

	it("hands each directive parser its argument string and ctx", function()
		local Parser, env = setup()
		env.chapters.ch = lines("step", "  .accept 5")
		parse(Parser, lines("step", "  .goto   1411,1,2   >> text", "  .note a  b", "#include ch"))
		assert.are.same({
			{ name = "goto", args = "1411,1,2", ctx = { source = "test-guide", line = 2, guideId = "test-guide" } },
			{ name = "note", args = "a  b", ctx = { source = "test-guide", line = 3, guideId = "test-guide" } },
			{ name = "accept", args = "5", ctx = { source = "ch", line = 2, guideId = "test-guide" } },
		}, env.parsed)
	end)

	it("hands every directive form of GUIDE-FORMAT its argument string and >> text intact", function()
		local Parser, env = setup()
		local seen = {}
		env.ns.Directives = {
			Get = function(_, name)
				return {
					parse = function(argString)
						seen[#seen + 1] = name .. "|" .. argString
						return { raw = argString }
					end,
				}
			end,
		}
		-- { line, what its parser receives, its >> text }
		local cases = {
			{ ".goto 1411,42.1,68.7", "goto|1411,42.1,68.7" },
			{ ".goto 1411,42.1,68.7,15", "goto|1411,42.1,68.7,15" },
			{ ".accept 787 >> Accept the first quest", "accept|787", "Accept the first quest" },
			{ ".turnin 787", "turnin|787" },
			{ ".complete 787,1", "complete|787,1" },
			{ ".complete 787", "complete|787" },
			{ ".reward 4402,2", "reward|4402,2" },
			{ ".train 1494", "train|1494" },
			{ ".train class", "train|class" },
			{ ".trainprof skinning", "trainprof|skinning" },
			{ ".skill cooking 75", "skill|cooking 75" },
			{ ".craft 2152,5", "craft|2152,5" },
			{ ".fish 1411,55.0,70.0", "fish|1411,55.0,70.0" },
			{ ".buy 2516,200", "buy|2516,200" },
			{ ".collect 2589,10", "collect|2589,10" },
			{ ".use 5070", "use|5070" },
			{ ".level 10", "level|10" },
			{ '.todo "Exact position not in the data yet"', 'todo|"Exact position not in the data yet"' },
			{
				".note Only if you want the pet chain now; otherwise skip.",
				"note|Only if you want the pet chain now; otherwise skip.",
			},
			{ ".text Kaltunk stands at the Den entrance.", "text|Kaltunk stands at the Den entrance." },
			{ ".link https://example.com/quest=6069", "link|https://example.com/quest=6069" },
			{ ".sticky .skill skinning 50", "skill|skinning 50" },
			{
				".path 1411,52.0,43.5 ; 1411,47.8,41.0 ; 1413,61.9,54.9",
				"path|1411,52.0,43.5 ; 1411,47.8,41.0 ; 1413,61.9,54.9",
			},
			{
				".zone 1413 >> Follow the road west into the Barrens",
				"zone|1413",
				"Follow the road west into the Barrens",
			},
			{ ".fp 1413,Ratchet", "fp|1413,Ratchet" },
			{ ".fly Orgrimmar", "fly|Orgrimmar" },
			{
				".boat 1413,63.9,38.6 > 1434,27.2,77.1 >> Take the boat to Booty Bay",
				"boat|1413,63.9,38.6 > 1434,27.2,77.1",
				"Take the boat to Booty Bay",
			},
			{
				".zeppelin 1454,51.2,12.6 > 1434,32.1,29.3 >> Zeppelin to Grom'gol",
				"zeppelin|1454,51.2,12.6 > 1434,32.1,29.3",
				"Zeppelin to Grom'gol",
			},
			{ ".hs Razor Hill", "hs|Razor Hill" },
			{ ".home", "home|" },
			{ ".tame 3100 .class HUNTER", "tame|3100" },
		}
		local text, expected, texts = { "step" }, {}, {}
		for i, case in ipairs(cases) do
			text[#text + 1] = "  " .. case[1]
			expected[i] = case[2]
			texts[i] = case[3] or false
		end
		local guide = parse(Parser, table.concat(text, "\n"))
		assertNoErrors(guide.errors)
		assert.are.same(expected, seen)
		local step, got, d, s = guide.steps[1], {}, 0, 0
		for i, case in ipairs(cases) do
			local directive
			if case[1]:find("^%.sticky") then
				s = s + 1
				directive = step.sticky[s]
			else
				d = d + 1
				directive = step.directives[d]
			end
			got[i] = directive.text or false
		end
		assert.are.same(texts, got)
	end)

	it("reads .sticky, .optional and .hub without asking the directive registry about them", function()
		local Parser, env = setup()
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .goto 1411,42.1,68.7",
				"  .hub razorhill",
				"  .accept 4402 >> Cutting Teeth (if offered)",
				"  .optional 4402",
				"  .sticky .skill skinning 50 >> Skin everything",
				"  .sticky .note keep going"
			)
		)
		assertNoErrors(guide.errors)
		local step = guide.steps[1]
		assert.are.same({ "goto", "accept" }, names(step.directives))
		assert.are.same({
			{
				name = "skill",
				args = { key = "skinning", value = 50 },
				text = "Skin everything",
				line = 6,
				sticky = true,
			},
			{ name = "note", args = { text = "keep going" }, line = 7, sticky = true },
		}, summarize(step.sticky))
		assert.are.same({ [4402] = true }, step.optional)
		assert.are.equal("razorhill", step.hub)
		assert.are.same({ "goto", "accept", "skill", "note" }, env.lookups)
	end)

	it("reports malformed .optional, .hub and .sticky lines and skips them", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .accept 1",
				"  .optional",
				"  .optional abc",
				"  .optional 1,2",
				"  .optional 1 >> text",
				"  .hub",
				"  .hub razor hill",
				"  .hub x >> X",
				"  .sticky",
				"  .sticky accept 1",
				"  .sticky .sticky .accept 1",
				"  .sticky .optional 1",
				"  .sticky .class HUNTER",
				"  .sticky .goto,1,2,3",
				"  .hub a",
				"  .hub b"
			)
		)
		local expected = {
			[3] = ".optional takes one quest ID",
			[4] = ".optional takes one quest ID",
			[5] = ".optional takes one quest ID",
			[6] = ">> text is not allowed on .optional",
			[7] = ".hub takes one name",
			[8] = ".hub takes one name",
			[9] = ">> text is not allowed on .hub",
			[10] = ".sticky needs a directive",
			[11] = ".sticky needs a directive",
			[12] = ".sticky cannot be sticky",
			[13] = ".optional cannot be sticky",
			[14] = ".class cannot be sticky",
			[15] = "expected a space after .goto",
			[17] = "a step has one .hub (a already)",
		}
		for line, fragment in pairs(expected) do
			assertError(guide.errors, "test-guide", line, fragment)
		end
		assert.are.equal(count(expected), #guide.errors)
		local step = guide.steps[1]
		assert.are.same({ "accept" }, names(step.directives))
		assert.are.same({ {}, {} }, { step.sticky, step.optional })
		assert.are.equal("a", step.hub)
	end)

	it("rejects a .sticky whose directive can never be satisfied (completable = false), as the lint does", function()
		local Parser, env = setup()
		env.defs.note.completable = false
		env.defs.skill.completable = true
		local guide =
			parse(Parser, lines("step", "  .accept 1", "  .sticky .note keep going", "  .sticky .skill skinning 50"))
		assertError(guide.errors, "test-guide", 3, ".sticky needs a directive that can be satisfied, not .note")
		assert.are.equal(1, #guide.errors)
		assert.are.same({ "skill" }, names(guide.steps[1].sticky))
	end)

	it("reports a step without directives and drops it", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines("step", "step", "  .class HUNTER", "step", "  .hub razorhill", "  .optional 5", "step", "  .accept 1")
		)
		assertError(guide.errors, "test-guide", 1, "step has no directives")
		assertError(guide.errors, "test-guide", 2, "step has no directives")
		assertError(guide.errors, "test-guide", 4, "step has no directives")
		assert.are.equal(3, #guide.errors)
		assert.are.same({ "test-guide:4" }, stepIds(guide.steps))
	end)

	it("keeps a step with no completable directive, and one with only stickies", function()
		local Parser = setup()
		local guide = parse(Parser, lines("step", "  .note Only a note", "step", "  .sticky .skill skinning 50"))
		assertNoErrors(guide.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(guide.steps))
		assert.are.same({}, guide.steps[2].directives)
		assert.are.same({ "skill" }, names(guide.steps[2].sticky))
	end)

	it("turns unknown directives and parse failures into errors and skips the line", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .goto 1411,1,2",
				"  .acept 787",
				"  .goto nowhere",
				"  .silent x",
				"  .boom 1",
				"  .accept 1 >>",
				"step",
				"  .acept 1"
			)
		)
		assertError(guide.errors, "test-guide", 3, "unknown directive .acept")
		assertError(guide.errors, "test-guide", 4, ".goto: expected <map>,<x>,<y>[,<radius>]")
		assertError(guide.errors, "test-guide", 5, ".silent: invalid arguments")
		assertError(guide.errors, "test-guide", 6, "kaboom")
		assertError(guide.errors, "test-guide", 7, "nothing after >>")
		assertError(guide.errors, "test-guide", 9, "unknown directive .acept")
		assert.are.equal(6, #guide.errors)
		assert.are.same({ "test-guide:1" }, stepIds(guide.steps))
		assert.are.same({ "goto" }, names(guide.steps[1].directives))
	end)

	it("treats every directive as unknown when the registry fails or is missing", function()
		local Parser, env = setup()
		env.ns.Directives = {
			Get = function()
				error("registry broke")
			end,
		}
		local guide = parse(Parser, lines("step", "  .accept 1"))
		assertError(guide.errors, "test-guide", 2, "unknown directive .accept")
		env.ns.Directives = nil
		guide = parse(Parser, lines("step", "  .accept 1"))
		assertError(guide.errors, "test-guide", 2, "unknown directive .accept")
		assert.are.same({}, guide.steps)
	end)

	it("records #skipquest lines from the guide and its chapters", function()
		local Parser, env = setup()
		env.chapters.shared = lines("#skipquest 2000 >> Other faction's variant", "step", "  .accept 1")
		local guide = parse(
			Parser,
			lines(
				"#skipquest 1234 >> Alliance-side variant of the weapon chain",
				"#skipquest 1234 >> a second reason is ignored",
				"#skipquest 99",
				"#skipquest abc >> x",
				"#skipquest 5 >>",
				"#include shared"
			)
		)
		assert.are.same(
			{ [1234] = "Alliance-side variant of the weapon chain", [2000] = "Other faction's variant" },
			guide.skipQuests
		)
		for line = 3, 5 do
			assertError(guide.errors, "test-guide", line, "expected #skipquest <questID> >> <reason>")
		end
		assert.are.equal(3, #guide.errors)
	end)

	it("reports an anchor or other text on a route step and keeps the step", function()
		local Parser = setup()
		local guide = parse(Parser, lines("step @hub orgrimmar", "  .accept 1", "step extra words", "  .accept 2"))
		assertError(guide.errors, "test-guide", 1, "anchors (@hub, @level, @zone) belong to profession tracks")
		assertError(guide.errors, "test-guide", 3, "unexpected text after step: extra words")
		assert.are.equal(2, #guide.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(guide.steps))
		assert.is_nil(guide.steps[1].anchor)
	end)
end)

describe("Parser gates", function()
	local function ids(Parser, text, player, plan)
		local guide = parse(Parser, text, { player = player, plan = plan })
		assertNoErrors(guide.errors)
		return stepIds(guide.steps)
	end

	it("gates a whole step by class, race and faction", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .class HUNTER",
			"  .accept 1",
			"step",
			"  .race Troll",
			"  .accept 2",
			"step",
			"  .faction Horde",
			"  .accept 3",
			"step",
			"  .faction Alliance",
			"  .accept 4",
			"step",
			"  .class WARRIOR,PALADIN",
			"  .accept 5"
		)
		assert.are.same({ "test-guide:1", "test-guide:2", "test-guide:3" }, ids(Parser, text, HUNTER))
		assert.are.same({ "test-guide:3", "test-guide:5" }, ids(Parser, text, WARRIOR))
		assert.are.same({ "test-guide:4" }, ids(Parser, text, MAGE))
	end)

	it("gates the whole step from a gate line anywhere in it", function()
		local Parser = setup()
		local text = lines("step", "  .goto 1411,1,2", "  .accept 1", "  .class HUNTER", "step", "  .accept 2")
		assert.are.same({ "test-guide:1", "test-guide:2" }, ids(Parser, text, HUNTER))
		assert.are.same({ "test-guide:2" }, ids(Parser, text, WARRIOR))
	end)

	it("applies negated items, lists of only negated items and mixed lists", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .class !HUNTER",
			"  .accept 1",
			"step",
			"  .class !HUNTER,!WARRIOR",
			"  .accept 2",
			"step",
			"  .class HUNTER,WARRIOR,!WARRIOR",
			"  .accept 3",
			"step",
			"  .race Troll,Orc,!Orc",
			"  .accept 4"
		)
		assert.are.same({ "test-guide:3", "test-guide:4" }, ids(Parser, text, HUNTER))
		assert.are.same({ "test-guide:1" }, ids(Parser, text, WARRIOR))
		assert.are.same({ "test-guide:1", "test-guide:2" }, ids(Parser, text, MAGE))
	end)

	it("needs every gate of a step to pass", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .class HUNTER",
			"  .race Orc",
			"  .accept 1",
			"step",
			"  .class HUNTER .race Troll",
			"  .accept 2"
		)
		assert.are.same({ "test-guide:2" }, ids(Parser, text, HUNTER))
	end)

	it("compares gate items case-insensitively", function()
		local Parser = setup()
		local text = lines("step", "  .class hunter", "  .race TROLL", "  .faction horde", "  .accept 1")
		assert.are.same({ "test-guide:1" }, ids(Parser, text, HUNTER))
		assert.are.same({}, ids(Parser, text, WARRIOR))
	end)

	it("filters only its own line with a trailing gate; a step left without directives is dropped", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .goto 1411,1,2 .race Orc",
			"  .accept 1",
			"  .accept 2 .class HUNTER",
			"  .accept 3 .class HUNTER .race Troll",
			"  .accept 4 .class HUNTER >> For hunters",
			"  .accept 5 >> For hunters .class HUNTER",
			"  .sticky .skill skinning 50 .class HUNTER",
			"  .hub razorhill .class HUNTER",
			"  .optional 2 .class HUNTER",
			"step",
			"  .accept 6 .class WARRIOR"
		)
		local hunter = parse(Parser, text, { player = HUNTER })
		assertNoErrors(hunter.errors)
		assert.are.same({ "test-guide:1" }, stepIds(hunter.steps))
		local step = hunter.steps[1]
		assert.are.same({
			{ name = "accept", args = { id = 1 }, line = 3 },
			{ name = "accept", args = { id = 2 }, line = 4 },
			{ name = "accept", args = { id = 3 }, line = 5 },
			{ name = "accept", args = { id = 4 }, text = "For hunters", line = 6 },
			{ name = "accept", args = { id = 5 }, text = "For hunters", line = 7 },
		}, summarize(step.directives))
		assert.are.same({ "skill" }, names(step.sticky))
		assert.are.same({ "razorhill", { [2] = true } }, { step.hub, step.optional })

		local warrior = parse(Parser, text, { player = WARRIOR })
		assertNoErrors(warrior.errors)
		assert.are.same({ "test-guide:1", "test-guide:2" }, stepIds(warrior.steps))
		step = warrior.steps[1]
		assert.are.same({ "goto", "accept" }, names(step.directives))
		assert.are.same({ {}, {} }, { step.sticky, step.optional })
		assert.is_nil(step.hub)
	end)

	it("matches .prof against the profession plan, never the learned skills", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .prof skinning",
			"  .accept 1",
			"step",
			"  .prof fishing",
			"  .accept 2",
			"step",
			"  .prof !mining",
			"  .accept 3",
			"step",
			"  .prof mining,herbalism",
			"  .accept 4",
			"step",
			"  .accept 5 .prof leatherworking",
			"  .accept 6"
		)
		assert.are.same(
			{ "test-guide:1", "test-guide:2", "test-guide:3", "test-guide:5" },
			ids(Parser, text, HUNTER, PLAN)
		)
		assert.are.same({ "test-guide:4", "test-guide:5" }, ids(Parser, text, HUNTER, { primary = { "Mining" } }))
		local learned = { classFile = "HUNTER", professions = { [393] = { key = "skinning", rank = 1, max = 75 } } }
		assert.are.same({ "test-guide:3", "test-guide:5" }, ids(Parser, text, learned))
		local guide = parse(Parser, text, { player = HUNTER })
		assert.are.same({ "accept" }, names(guide.byId["test-guide:5"].directives))
	end)

	it("never passes .hc yet", function()
		local Parser = setup()
		local guide = parse(Parser, lines("step", "  .hc", "  .accept 1", "step", "  .accept 2 .hc", "  .accept 3"))
		assertNoErrors(guide.errors)
		assert.are.same({ "test-guide:2" }, stepIds(guide.steps))
		assert.are.same({ { id = 3 } }, { guide.steps[1].directives[1].args })
		assert.are.equal(1, #guide.steps[1].directives)
	end)

	it("drops a step whose gate line is malformed, for every player", function()
		local Parser = setup()
		local text = lines(
			"step",
			"  .class HUNTER, ROGUE",
			"  .accept 1",
			"step",
			"  .class",
			"  .accept 2",
			"step",
			"  .race Troll,,Orc",
			"  .accept 3",
			"step",
			"  .class !",
			"  .accept 4",
			"step",
			"  .class !!HUNTER",
			"  .accept 5",
			"step",
			"  .hc yes",
			"  .accept 6",
			"step",
			"  .class HUNTER >> hunters",
			"  .accept 7",
			"step",
			"  .class,HUNTER",
			"  .accept 8",
			"step",
			"  .accept 9"
		)
		local expected = {
			[2] = ".class: a list is comma-separated without spaces",
			[5] = ".class needs a list",
			[8] = ".race: malformed list 'Troll,,Orc'",
			[11] = ".class: malformed list '!'",
			[14] = ".class: malformed list '!!HUNTER'",
			[17] = ".hc takes no list",
			[20] = ">> text is not allowed on .class",
			[23] = "expected a space after .class",
		}
		for _, player in ipairs({ HUNTER, WARRIOR }) do
			local guide = parse(Parser, text, { player = player })
			for line, fragment in pairs(expected) do
				assertError(guide.errors, "test-guide", line, fragment)
			end
			assert.are.equal(count(expected), #guide.errors)
			assert.are.same({ "test-guide:9" }, stepIds(guide.steps))
		end
	end)

	it("drops only its line for a malformed or misplaced trailing gate", function()
		local Parser = setup()
		local guide = parse(
			Parser,
			lines(
				"step",
				"  .accept 1 .class HUNTER,,ROGUE",
				"  .accept 2 .class HUNTER extra",
				"  .note Hunters .class",
				"  .accept 3"
			)
		)
		assertError(guide.errors, "test-guide", 2, ".class: malformed list")
		assertError(guide.errors, "test-guide", 3, "misplaced or malformed gate .class")
		assertError(guide.errors, "test-guide", 4, "misplaced or malformed gate .class")
		assert.are.equal(3, #guide.errors)
		assert.are.same({ { id = 3 } }, { guide.steps[1].directives[1].args })
		assert.are.equal(1, #guide.steps[1].directives)
	end)

	it("never sends gated-away lines to the directive registry", function()
		local Parser, env = setup()
		-- .tame is a class directive the stand-in registry does not know
		local text =
			lines("step", "  .tame 3100", "  .class HUNTER", "step", "  .accept 1", "  .tame 3101 .class HUNTER")
		local warrior = parse(Parser, text, { player = WARRIOR })
		assertNoErrors(warrior.errors)
		assert.are.same({ "test-guide:2" }, stepIds(warrior.steps))
		assert.are.same({ "accept" }, env.lookups)

		local hunter = parse(Parser, text, { player = HUNTER })
		assertError(hunter.errors, "test-guide", 2, "unknown directive .tame")
		assertError(hunter.errors, "test-guide", 6, "unknown directive .tame")
		assert.are.equal(2, #hunter.errors)
	end)
end)

describe("Parser stable step ids", function()
	it("numbers steps by their position in the source text, so gating never shifts an id", function()
		local Parser, env = setup()
		env.chapters["shared-1"] = lines(
			"#chapter 1-5 Shared",
			"step",
			"  .class HUNTER",
			"  .accept 1",
			"step",
			"  .accept 2",
			"step",
			"  .accept 3 .class WARRIOR",
			"step",
			"  .accept 4"
		)
		local text = lines("step", "  .race Orc", "  .accept 10", "#include shared-1", "step", "  .accept 11")
		local hunter = parse(Parser, text, { player = HUNTER })
		local warrior = parse(Parser, text, { player = WARRIOR })
		assert.are.same({ "shared-1:1", "shared-1:2", "shared-1:4", "test-guide:2" }, stepIds(hunter.steps))
		assert.are.same(
			{ "test-guide:1", "shared-1:2", "shared-1:3", "shared-1:4", "test-guide:2" },
			stepIds(warrior.steps)
		)
		-- the same step keeps its id while its index moves
		assert.are.same({ 3, 4 }, { hunter.byId["shared-1:4"].index, warrior.byId["shared-1:4"].index })
		checkGuide(hunter)
		checkGuide(warrior)
	end)

	it("keeps ids across profession plans", function()
		local Parser = setup()
		local text =
			lines("step", "  .accept 1 .prof cooking", "step", "  .prof fishing", "  .accept 2", "step", "  .accept 3")
		local function ids(plan)
			return stepIds(parse(Parser, text, { player = HUNTER, plan = plan }).steps)
		end
		assert.are.same({ "test-guide:1", "test-guide:2", "test-guide:3" }, ids(PLAN))
		assert.are.same({ "test-guide:1", "test-guide:3" }, ids({ primary = {}, secondary = { "cooking" } }))
		assert.are.same({ "test-guide:3" }, ids(nil))
	end)
end)

describe("Parser:ParseTrack", function()
	it("reads track steps with their anchors", function()
		local Parser = setup()
		local steps, errors = Parser:ParseTrack(
			"skinning",
			lines(
				"#track skinning",
				"step @hub orgrimmar",
				"  .trainprof skinning",
				"step @level 6",
				"  .sticky .skill skinning 50",
				"step @zone 1411",
				"  .accept 1"
			),
			{ player = HUNTER, plan = PLAN }
		)
		assertNoErrors(errors)
		local shape = {}
		for i, step in ipairs(steps) do
			shape[i] = {
				id = step.id,
				index = step.index,
				source = step.source,
				line = step.line,
				track = step.track,
				anchor = step.anchor,
				chapter = step.chapter,
			}
		end
		assert.are.same({
			{
				id = "track:skinning:1",
				index = 1,
				source = "track:skinning",
				line = 2,
				track = "skinning",
				anchor = { kind = "hub", value = "orgrimmar" },
			},
			{
				id = "track:skinning:2",
				index = 2,
				source = "track:skinning",
				line = 4,
				track = "skinning",
				anchor = { kind = "level", value = 6 },
			},
			{
				id = "track:skinning:3",
				index = 3,
				source = "track:skinning",
				line = 6,
				track = "skinning",
				anchor = { kind = "zone", value = 1411 },
			},
		}, shape)
		assert.are.same({ "trainprof" }, names(steps[1].directives))
		assert.are.same({ "skill" }, names(steps[2].sticky))
	end)

	it("drops a track step without exactly one valid anchor; later ids do not move", function()
		local Parser = setup()
		local steps, errors = Parser:ParseTrack(
			"cooking",
			lines(
				"#track cooking",
				"step",
				"  .accept 1",
				"step @hub",
				"  .accept 2",
				"step @hub a @level 5",
				"  .accept 3",
				"step @town orgrimmar",
				"  .accept 4",
				"step @level six",
				"  .accept 5",
				"step @zone 0",
				"  .accept 6",
				"step @level 10",
				"  .accept 7"
			),
			{ player = HUNTER }
		)
		assertError(errors, "track:cooking", 2, "a track step needs one anchor")
		assertError(errors, "track:cooking", 4, "a track step needs one anchor")
		assertError(errors, "track:cooking", 6, "a track step has exactly one anchor")
		assertError(errors, "track:cooking", 8, "unknown anchor @town")
		assertError(errors, "track:cooking", 10, "@level needs a positive whole number")
		assertError(errors, "track:cooking", 12, "@zone needs a positive whole number")
		assert.are.equal(6, #errors)
		assert.are.same({ "track:cooking:7" }, stepIds(steps))
		assert.are.same({ { id = 7 } }, { steps[1].directives[1].args })
		assert.are.equal(1, #steps[1].directives)
	end)

	it("checks the #track header", function()
		local Parser = setup()
		local _, errors = Parser:ParseTrack("fishing", lines("step @level 5", "  .accept 1"))
		assertError(errors, "track:fishing", 1, "a track starts with #track fishing")
		_, errors = Parser:ParseTrack("fishing", lines("#track cooking", "step @level 5", "  .accept 1"))
		assertError(errors, "track:fishing", 1, "#track cooking does not match the track key fishing")
		_, errors = Parser:ParseTrack("fishing", lines("#track fishing", "#track fishing"))
		assertError(errors, "track:fishing", 2, "#track must be the first statement of a track")
		_, errors = Parser:ParseTrack("fishing", "-- nothing here")
		assertError(errors, "track:fishing", 0, "a track starts with #track fishing")
		local steps
		steps, errors = Parser:ParseTrack("fishing", nil)
		assert.are.same({}, steps)
		assertError(errors, "track:fishing", 0, "track fishing has no text")
		local guide = parse(Parser, lines("#track skinning", "step", "  .accept 1"))
		assertError(guide.errors, "test-guide", 1, "#track is only allowed in a profession track")
	end)

	it("gates track steps with opts.player and opts.plan", function()
		local Parser = setup()
		local text = lines(
			"#track fishing",
			"step @level 10",
			"  .prof cooking",
			"  .accept 1",
			"step @level 12",
			"  .accept 2 .class HUNTER",
			"  .accept 3"
		)
		local steps, errors = Parser:ParseTrack("fishing", text, { player = HUNTER, plan = PLAN })
		assertNoErrors(errors)
		assert.are.same({ "track:fishing:1", "track:fishing:2" }, stepIds(steps))
		assert.are.equal(2, #steps[2].directives)
		steps = Parser:ParseTrack("fishing", text, { player = WARRIOR, plan = { secondary = { "fishing" } } })
		assert.are.same({ "track:fishing:2" }, stepIds(steps))
		assert.are.same({ "accept" }, names(steps[1].directives))
		assert.are.equal(1, steps[1].index)
	end)

	it("passes the track source and opts.guideId to the directive parsers", function()
		local Parser, env = setup()
		Parser:ParseTrack(
			"cooking",
			lines("#track cooking", "step @level 1", "  .accept 1"),
			{ player = HUNTER, guideId = "some-guide" }
		)
		assert.are.same({ source = "track:cooking", line = 3, guideId = "some-guide" }, env.parsed[1].ctx)
	end)
end)

describe("Parser profession merge", function()
	it("merges only when a plan is given, with the plan, the player and the guide id", function()
		local Parser, env = setup()
		local calls = {}
		env.ns.Professions = {
			Merge = function(self, guide, plan, opts)
				calls[#calls + 1] =
					{ self = self, guide = guide, plan = plan, opts = opts, step = guide.byId["test-guide:1"] }
			end,
		}
		local text = lines("step", "  .accept 1")
		parse(Parser, text, { player = HUNTER })
		assert.are.equal(0, #calls)
		local guide = parse(Parser, text, { player = HUNTER, plan = PLAN })
		assert.are.equal(1, #calls)
		local call = calls[1]
		assert.are.equal(env.ns.Professions, call.self)
		assert.are.equal(guide, call.guide)
		assert.are.equal(PLAN, call.plan)
		assert.are.same({ HUNTER, PLAN, "test-guide" }, { call.opts.player, call.opts.plan, call.opts.guideId })
		-- Merge sees a finished route: indexed, with byId and chapter ranges
		assert.are.equal(guide.steps[1], call.step)
	end)

	it("brings index, byId and chapters up to date after the merge", function()
		local Parser, env = setup()
		local track = lines("#track skinning", "step @hub razorhill", "  .accept 100", "step @level 7", "  .accept 101")
		-- a simplified merge that, like a real one may, leaves the derived fields to the parser
		env.ns.Professions = {
			Merge = function(_, guide, _, opts)
				local steps = Parser:ParseTrack("skinning", track, opts)
				for _, step in ipairs(steps) do
					local at
					for i, routeStep in ipairs(guide.steps) do
						local chapter = routeStep.chapter and guide.chapters[routeStep.chapter]
						if step.anchor.kind == "hub" and routeStep.hub == step.anchor.value then
							at = i + 1
						elseif step.anchor.kind == "level" and chapter and chapter.levels[1] >= step.anchor.value then
							at = i
						end
						if at then
							break
						end
					end
					table.insert(guide.steps, at, step)
				end
			end,
		}
		local guide = parse(
			Parser,
			lines(
				"#chapter 1-6 First",
				"step",
				"  .accept 1",
				"step",
				"  .accept 2",
				"  .hub razorhill",
				"#chapter 7-12 Second",
				"step",
				"  .accept 3"
			),
			{ player = HUNTER, plan = PLAN }
		)
		assertNoErrors(guide.errors)
		assert.are.same(
			{ "test-guide:1", "test-guide:2", "track:skinning:1", "track:skinning:2", "test-guide:3" },
			stepIds(guide.steps)
		)
		-- both track steps sit between the chapters: the @hub step joins the hub's chapter, the @level step the
		-- chapter it was placed before
		local chapters = {}
		for i, step in ipairs(guide.steps) do
			chapters[i] = step.chapter
		end
		assert.are.same({ 1, 1, 1, 2, 2 }, chapters)
		assert.are.same({ 1, 3, 4, 5 }, {
			guide.chapters[1].first,
			guide.chapters[1].last,
			guide.chapters[2].first,
			guide.chapters[2].last,
		})
		checkGuide(guide)
	end)

	it("turns a failing merge into an error and keeps the route", function()
		local Parser, env = setup()
		env.ns.Professions = {
			Merge = function()
				error("merge broke")
			end,
		}
		local logged = #env.ns.db.errors
		local guide = parse(Parser, lines("step", "  .accept 1"), { player = HUNTER, plan = PLAN })
		assertError(guide.errors, "test-guide", 0, "profession tracks not merged: ")
		assertError(guide.errors, "test-guide", 0, "merge broke")
		assert.are.equal(1, #guide.errors)
		assert.are.same({ "test-guide:1" }, stepIds(guide.steps))
		-- a bug, not guide text: it also reaches the error log
		assert.are.equal(logged + 1, #env.ns.db.errors)
		assert.truthy(env.ns.db.errors[#env.ns.db.errors].msg:find("merge broke", 1, true))
	end)

	it("reports a plan it cannot merge without ns.Professions", function()
		local Parser, env = setup()
		env.ns.Professions = nil
		local guide = parse(Parser, lines("step", "  .accept 1"), { player = HUNTER, plan = PLAN })
		assertError(guide.errors, "test-guide", 0, "profession tracks not merged: ns.Professions is not loaded")
		assert.are.same({ "test-guide:1" }, stepIds(guide.steps))
	end)

	it("reports a duplicate step id once, however often the guide is re-indexed", function()
		local Parser, env = setup()
		env.ns.Professions = {
			Merge = function(_, guide)
				local copy = { id = "test-guide:1", source = "test-guide", line = 1, directives = {}, sticky = {} }
				table.insert(guide.steps, copy)
				Parser:Reindex(guide)
			end,
		}
		local guide = parse(Parser, lines("step", "  .accept 1"), { player = HUNTER, plan = PLAN })
		assert.are.same({ "test-guide:1: duplicate step id test-guide:1" }, errorList(guide.errors))
		assert.are.equal(guide.steps[1], guide.byId["test-guide:1"])
		assert.are.same({ 1, 2 }, { guide.steps[1].index, guide.steps[2].index })
	end)
end)

describe("Parser robustness", function()
	it("never throws, whatever the text", function()
		local Parser, env = setup()
		local fragments = {
			"step",
			"step @hub x",
			"step @level",
			"step @level 3",
			".goto 1411,1,2",
			".accept",
			".accept 12 >>",
			".accept 7 >> text .class HUNTER",
			">>",
			" -- c",
			"--",
			"#include a",
			"#include b",
			"#include fuzz",
			"#include zz",
			"#chapter",
			"#chapter 3-1 X",
			"#chapter 1 Y #dungeon",
			"#skipquest 1 >> r",
			"#track t",
			"#professions",
			"#guide",
			".class",
			".class A,!B",
			".prof !x",
			".hc",
			".sticky",
			".sticky .goto 1,2,3",
			".optional x",
			".optional 3",
			".hub",
			".hub h",
			".boom 1",
			".fail",
			".bare",
			"!",
			",",
			"@",
			"#",
			".",
			"\r",
			"\t",
			"\0",
			"%",
			"%s",
			"]]",
			"steps",
		}
		env.chapters.a = lines("#include b", "step", ".goto 1,2,3")
		env.chapters.b = lines("#include a", ".accept 1", "#chapter 2 B")
		-- a local generator (Park-Miller), so the run is repeatable and the global math.random state is left alone
		local seed = 1790
		local function random(low, high)
			seed = seed * 16807 % 2147483647
			if not low then
				return seed / 2147483647
			end
			if not high then
				low, high = 1, low
			end
			return low + seed % (high - low + 1)
		end
		for _ = 1, 300 do
			local parts = {}
			for i = 1, random(0, 30) do
				local piece = fragments[random(#fragments)]
				if random() < 0.3 then
					piece = piece .. " " .. fragments[random(#fragments)]
				end
				if random() < 0.1 then
					piece = piece .. string.char(random(0, 255))
				end
				parts[i] = piece
			end
			local text = table.concat(parts, random() < 0.5 and "\n" or "\r\n")
			local def = { id = "fuzz", levels = { 1, 10 }, text = text }
			local ok, guide = pcall(Parser.ParseGuide, Parser, def, { player = HUNTER, plan = PLAN })
			assert.is_true(ok, tostring(guide))
			checkGuide(guide)
			local steps, errors
			ok, steps, errors = pcall(Parser.ParseTrack, Parser, "t", text, { player = WARRIOR })
			assert.is_true(ok, tostring(steps))
			assert.is_table(errors)
			for i, step in ipairs(steps) do
				assert.are.equal(i, step.index)
				assert.is_table(step.anchor)
			end
			assert.is_table(Parser:Headers(def))
		end
	end)

	it("survives missing definitions, text and options", function()
		local Parser = setup()
		local guide = Parser:ParseGuide(nil)
		assertError(guide.errors, "?", 0, "guide has no id")
		assertError(guide.errors, "?", 0, "guide has no text")
		assert.are.same({}, guide.steps)

		guide = Parser:ParseGuide({ id = "x" }, "not a table")
		assert.are.same({ "x:0: guide has no text" }, errorList(guide.errors))

		guide = Parser:ParseGuide({ id = "x", text = lines("step", "  .accept 1") }, { player = HUNTER })
		assert.are.same({ "x:0: guide levels must be { min, max }" }, errorList(guide.errors))
		assert.is_nil(guide.chapters[1].levels)
		assert.are.equal(1, #guide.steps)
	end)

	it("gates for ns.Player when opts has no player", function()
		local Parser = setup()
		-- the mock client logs in a hunter
		local guide = Parser:ParseGuide(guideDef(lines("step", "  .class HUNTER", "  .accept 1")))
		assert.are.same({ "test-guide:1" }, stepIds(guide.steps))
	end)

	it("turns an internal failure into an error entry instead of throwing", function()
		local Parser, env = setup()
		local player = setmetatable({}, {
			__index = function()
				error("player exploded")
			end,
		})
		local logged = #env.ns.db.errors
		local guide = Parser:ParseGuide(guideDef(lines("step", "  .accept 1")), { player = player })
		assertError(guide.errors, "test-guide", 0, "parser failure: ")
		assertError(guide.errors, "test-guide", 0, "player exploded")
		assert.are.same({}, guide.steps)
		local _, errors = Parser:ParseTrack("k", "#track k", { player = player })
		assertError(errors, "track:k", 0, "player exploded")
		-- the same bug twice: the error log counts the repeat
		assert.are.equal(logged + 1, #env.ns.db.errors)
		local entry = env.ns.db.errors[#env.ns.db.errors]
		assert.truthy(entry.msg:find("player exploded", 1, true))
		assert.are.equal(2, entry.count)
	end)
end)

describe("Parser performance", function()
	it("parses a 2,000-step guide in well under a second", function()
		local Parser, env = setup()
		local includes = {}
		for c = 1, 20 do
			local id = "chapter-" .. c
			local out = { string.format("#chapter %d-%d Chapter %d", c, c + 1, c) }
			for s = 1, 100 do
				local quest = c * 1000 + s
				out[#out + 1] = "step"
				out[#out + 1] = string.format("  .goto 1411,%d.5,%d.25 -- waypoint", s % 100, (s * 7) % 100)
				out[#out + 1] = string.format("  .accept %d >> Accept quest %d", quest, s)
				if s % 5 == 0 then
					out[#out + 1] = "  .class HUNTER,!WARRIOR"
				end
				if s % 10 == 0 then
					out[#out + 1] = "  .sticky .skill skinning 50 .prof skinning"
				end
				if s % 4 == 0 then
					out[#out + 1] = string.format("  .turnin %d .race Troll", quest - 1)
				end
			end
			env.chapters[id] = table.concat(out, "\n")
			includes[#includes + 1] = "#include " .. id
		end
		local def = guideDef("#professions skinning,cooking\n" .. table.concat(includes, "\n"))
		local start = os.clock()
		local guide = Parser:ParseGuide(def, { player = HUNTER, plan = PLAN })
		local elapsed = os.clock() - start
		assertNoErrors(guide.errors)
		assert.are.equal(2000, #guide.steps)
		assert.are.equal(20, #guide.chapters)
		assert.is_true(elapsed < 0.5, string.format("parsing took %.3f s", elapsed))
	end)
end)
