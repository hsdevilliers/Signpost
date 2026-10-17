local addon = dofile("tests/helpers/addon.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

-- Loads the addon with the registry and empties the registries, so guide, chapter and class files that join the
-- TOC later do not change what these tests see.
local function load(opts)
	opts = opts or {}
	opts.extra = { "Engine/Registry.lua" }
	local ns, mock = addon.load(opts)
	for _, registry in ipairs({ ns.Guides.defs, ns.Chapters.texts, ns.Classes.modules }) do
		wipe(registry)
	end
	wipe(ns.Guides.problems)
	wipe(ns.Chapters.problems)
	wipe(ns.Classes.problems)
	return ns, mock
end

local function guide(id, fields)
	local def = { id = id, name = id, text = "step\n  .note hello\n" }
	for key, value in pairs(fields or {}) do
		def[key] = value
	end
	return def
end

local function player(faction, raceFile, classFile)
	return { faction = faction, raceFile = raceFile, classFile = classFile }
end

local function ids(list)
	local result = {}
	for i, def in ipairs(list) do
		result[i] = def.id
	end
	return result
end

local TROLL_HUNTER = player("Horde", "Troll", "HUNTER")

describe("ns.Guides registration", function()
	it("registers guides and lists them by name, then id", function()
		local ns = load()
		assert.is_true(ns.Guides:Register(guide("b", { name = "Same" })))
		assert.is_true(ns.Guides:Register(guide("a", { name = "Same" })))
		assert.is_true(ns.Guides:Register(guide("c", { name = "Alpha" })))
		assert.is_true(ns.Guides:Register(guide("d", { name = nil })))
		assert.are.same({ "c", "a", "b", "d" }, ids(ns.Guides:All()))
		assert.are.equal("Alpha", ns.Guides:Get("c").name)
		assert.is_nil(ns.Guides:Get("missing"))
		assert.is_nil(ns.Guides:Get(nil))
	end)

	it("keeps the registered table itself", function()
		local ns = load()
		local def = guide("x", { levels = { 1, 60 } })
		ns.Guides:Register(def)
		assert.are.equal(def, ns.Guides:Get("x"))
	end)

	it("refuses a guide without an id or text, or with a malformed restriction, and reports it", function()
		local ns = load()
		local ok, problem = ns.Guides:Register({ text = "" })
		assert.is_false(ok)
		assert.truthy(problem:find("without an id", 1, true))
		assert.is_false(ns.Guides:Register("not a table"))
		assert.is_false(ns.Guides:Register({ id = "notext" }))
		assert.is_false(ns.Guides:Register(guide("badfaction", { faction = 3 })))
		assert.is_false(ns.Guides:Register(guide("badraces", { races = { "Troll", 8 } })))
		assert.is_false(ns.Guides:Register(guide("badclasses", { classes = true })))
		assert.are.same({}, ns.Guides:All())
		assert.are.equal(6, #ns.Guides.problems)
		assert.truthy(ns.db.errors[#ns.db.errors].msg:find("badclasses", 1, true))
	end)

	it("uses the later of two guides with one id and reports the duplicate", function()
		local ns = load()
		local first, second = guide("dup", { name = "First" }), guide("dup", { name = "Second" })
		ns.Guides:Register(first)
		ns.Guides:Register(first)
		assert.are.same({}, ns.Guides.problems)
		ns.Guides:Register(second)
		assert.are.equal(second, ns.Guides:Get("dup"))
		assert.are.equal(1, #ns.Guides.problems)
		assert.truthy(ns.Guides.problems[1]:find("registered twice", 1, true))
	end)
end)

describe("ns.Guides:Compatible", function()
	it("matches faction, race and class, with '*' matching everyone", function()
		local ns = load()
		local exact = guide("exact", { faction = "Horde", races = { "Troll" }, classes = { "HUNTER" } })
		assert.is_true(ns.Guides:Compatible(exact, TROLL_HUNTER))
		local everyone = guide("everyone", { faction = "*", races = { "*" }, classes = "*" })
		assert.is_true(ns.Guides:Compatible(everyone, player("Alliance", "Gnome", "MAGE")))
		local open = guide("open")
		assert.is_true(ns.Guides:Compatible(open, player("Alliance", "Gnome", "MAGE")))
		local listed = guide("listed", { races = { "Orc", "Troll" }, classes = { "SHAMAN", "*" } })
		assert.is_true(ns.Guides:Compatible(listed, TROLL_HUNTER))
		local empty = guide("empty", { races = {}, classes = {} })
		assert.is_true(ns.Guides:Compatible(empty, TROLL_HUNTER))
	end)

	it("gives the first unmet requirement (faction, race, class) as the reason", function()
		local ns = load()
		local def = guide("g", { faction = "Alliance", races = { "Gnome", "Human" }, classes = { "MAGE" } })
		local ok, reason, kind = ns.Guides:Compatible(def, TROLL_HUNTER)
		assert.is_false(ok)
		assert.are.equal("faction", kind)
		assert.are.equal("Requires faction: Alliance", reason)

		ok, reason, kind = ns.Guides:Compatible(def, player("Alliance", "Troll", "MAGE"))
		assert.is_false(ok)
		assert.are.equal("race", kind)
		assert.are.equal("Requires race: Gnome, Human", reason)

		ok, reason, kind = ns.Guides:Compatible(def, player("Alliance", "Gnome", "HUNTER"))
		assert.is_false(ok)
		assert.are.equal("class", kind)
		assert.are.equal("Requires class: MAGE", reason)

		assert.is_true(ns.Guides:Compatible(def, player("Alliance", "Gnome", "MAGE")))
	end)

	it("accepts a single token instead of a list", function()
		local ns = load()
		local def = guide("g", { races = "Troll", classes = "HUNTER" })
		assert.is_true(ns.Guides:Compatible(def, TROLL_HUNTER))
		assert.is_false(ns.Guides:Compatible(def, player("Horde", "Orc", "HUNTER")))
	end)

	it("checks ns.Player by default and refuses a player it knows nothing about", function()
		local ns = load()
		local def = guide("g", { faction = "Horde", races = { "Troll" }, classes = { "HUNTER" } })
		assert.is_true(ns.Guides:Compatible(def))
		local ok, _, kind = ns.Guides:Compatible(def, {})
		assert.is_false(ok)
		assert.are.equal("faction", kind)
		assert.is_true(ns.Guides:Compatible(guide("open"), {}))
		local notGuide, _, invalid = ns.Guides:Compatible(nil)
		assert.is_false(notGuide)
		assert.are.equal("invalid", invalid)
	end)
end)

describe("ns.Guides:Best", function()
	local function registerAll(ns)
		ns.Guides:Register(guide("everyone"))
		ns.Guides:Register(guide("faction-only", { faction = "Horde" }))
		ns.Guides:Register(guide("race-only", { races = { "Troll" } }))
		ns.Guides:Register(guide("class-only", { faction = "*", races = { "*" }, classes = { "HUNTER" } }))
		ns.Guides:Register(guide("race-class", { faction = "Horde", races = { "Troll" }, classes = { "HUNTER" } }))
		ns.Guides:Register(guide("other-race-class", { races = { "Orc" }, classes = { "HUNTER" } }))
		ns.Guides:Register(guide("other-faction", { faction = "Alliance", classes = { "HUNTER" } }))
	end

	it("prefers race and class, then class only, then race only, then faction only, then everyone", function()
		local ns = load()
		registerAll(ns)
		local order = {}
		for _ = 1, 5 do
			local best = ns.Guides:Best(TROLL_HUNTER)
			order[#order + 1] = best.id
			ns.Guides.defs[best.id] = nil
		end
		assert.are.same({ "race-class", "class-only", "race-only", "faction-only", "everyone" }, order)
		assert.is_nil(ns.Guides:Best(TROLL_HUNTER))
	end)

	it("selects for the player it is given, by default ns.Player", function()
		local ns = load()
		registerAll(ns)
		assert.are.equal("race-class", ns.Guides:Best().id)
		assert.are.equal("other-race-class", ns.Guides:Best(player("Horde", "Orc", "HUNTER")).id)
		-- two class-only guides: the one naming the player's faction beats the one for every faction
		assert.are.equal("other-faction", ns.Guides:Best(player("Alliance", "Gnome", "HUNTER")).id)
		assert.are.equal("faction-only", ns.Guides:Best(player("Horde", "Orc", "WARLOCK")).id)
		assert.are.equal("everyone", ns.Guides:Best(player("Alliance", "Gnome", "MAGE")).id)
	end)

	it("breaks ties by a named faction, then by id", function()
		local ns = load()
		ns.Guides:Register(guide("b-any-faction", { races = { "Troll" }, classes = { "HUNTER" } }))
		ns.Guides:Register(guide("c-named", { faction = "Horde", races = { "Troll" }, classes = { "HUNTER" } }))
		ns.Guides:Register(guide("d-named", { faction = { "Horde" }, races = { "Troll" }, classes = { "HUNTER" } }))
		assert.are.equal("c-named", ns.Guides:Best(TROLL_HUNTER).id)
		ns.Guides.defs["c-named"] = nil
		assert.are.equal("d-named", ns.Guides:Best(TROLL_HUNTER).id)
		ns.Guides.defs["d-named"] = nil
		assert.are.equal("b-any-faction", ns.Guides:Best(TROLL_HUNTER).id)
	end)

	it("never picks an incompatible guide, however specific", function()
		local ns = load()
		ns.Guides:Register(guide("other", { faction = "Alliance", races = { "Gnome" }, classes = { "MAGE" } }))
		assert.is_nil(ns.Guides:Best(TROLL_HUNTER))
		ns.Guides:Register(guide("everyone"))
		assert.are.equal("everyone", ns.Guides:Best(TROLL_HUNTER).id)
	end)
end)

describe("ns.Guides selection", function()
	it("follows Best until the character selects a guide, then keeps the choice", function()
		local ns = load()
		ns.Guides:Register(guide("everyone"))
		ns.Guides:Register(guide("exact", { faction = "Horde", races = { "Troll" }, classes = { "HUNTER" } }))
		assert.are.equal("exact", ns.Guides:Selected().id)
		assert.is_true(ns.Guides:Select("everyone"))
		assert.are.equal("everyone", SignpostCharDB.guide)
		assert.are.equal("everyone", ns.Guides:Selected().id)
	end)

	it("returns to automatic selection with nil", function()
		local ns = load()
		ns.Guides:Register(guide("everyone"))
		ns.Guides:Register(guide("exact", { races = { "Troll" }, classes = { "HUNTER" } }))
		ns.Guides:Select("everyone")
		assert.is_true(ns.Guides:Select(nil))
		assert.is_nil(ns.char.guide)
		assert.are.equal("exact", ns.Guides:Selected().id)
	end)

	it("keeps the choice across a reload and drops it when it no longer fits", function()
		local ns = load({
			before = function()
				G.SignpostCharDB = { dbVersion = 2, guide = "chosen" }
			end,
		})
		ns.Guides:Register(guide("chosen", { classes = { "HUNTER" } }))
		ns.Guides:Register(guide("exact", { races = { "Troll" }, classes = { "HUNTER" } }))
		assert.are.equal("chosen", ns.Guides:Selected().id)
		-- the guide changed its classes in an update: Best takes over, the stored id stays for a later fix
		ns.Guides:Register(guide("chosen", { classes = { "WARLOCK" } }))
		assert.are.equal("exact", ns.Guides:Selected().id)
		-- the guide was removed
		ns.char.guide = "removed"
		assert.are.equal("exact", ns.Guides:Selected().id)
	end)

	it("refuses unknown and incompatible guides and keeps the stored choice", function()
		local ns = load()
		ns.Guides:Register(guide("everyone"))
		ns.Guides:Register(guide("other", { faction = "Alliance" }))
		ns.Guides:Select("everyone")
		local ok, reason = ns.Guides:Select("missing")
		assert.is_false(ok)
		assert.are.equal("Unknown guide: missing", reason)
		ok, reason = ns.Guides:Select("other")
		assert.is_false(ok)
		assert.are.equal("Requires faction: Alliance", reason)
		assert.are.equal("everyone", ns.char.guide)
	end)

	it("fires GUIDE_SELECTED when the selected guide changes", function()
		local ns = load()
		local everyone = guide("everyone")
		local exact = guide("exact", { races = { "Troll" }, classes = { "HUNTER" } })
		ns.Guides:Register(everyone)
		ns.Guides:Register(exact)
		local fired = {}
		ns.Events:RegisterMessage("GUIDE_SELECTED", function(_, def)
			fired[#fired + 1] = def
		end)
		ns.Guides:Select("exact") -- already the automatic choice
		ns.Guides:Select("everyone")
		ns.Guides:Select("everyone")
		ns.Guides:Select(nil)
		assert.are.same({ everyone, exact }, fired)
	end)

	it("needs SavedVariables to store a choice, and selects without them", function()
		local ns = load({ login = false })
		ns.Guides:Register(guide("everyone"))
		local ok, reason = ns.Guides:Select("everyone")
		assert.is_false(ok)
		assert.truthy(reason:find("not loaded", 1, true))
		assert.are.equal("everyone", ns.Guides:Selected(TROLL_HUNTER).id)
	end)
end)

describe("ns.Chapters", function()
	it("registers chapter texts by id", function()
		local ns = load()
		assert.is_true(ns.Chapters:Register("durotar-1-6", "step\n"))
		assert.are.equal("step\n", ns.Chapters:Get("durotar-1-6"))
		assert.is_nil(ns.Chapters:Get("barrens-12-20"))
		assert.is_nil(ns.Chapters:Get(nil))
	end)

	it("refuses ids that are not lowercase letters, digits and '-', and chapters without text", function()
		local ns = load()
		assert.is_false(ns.Chapters:Register("Durotar-1-6", "step\n"))
		assert.is_false(ns.Chapters:Register("durotar 1-6", "step\n"))
		assert.is_false(ns.Chapters:Register("", "step\n"))
		assert.is_false(ns.Chapters:Register(12, "step\n"))
		assert.is_false(ns.Chapters:Register("notext", nil))
		assert.are.equal(5, #ns.Chapters.problems)
		assert.is_nil(ns.Chapters:Get("Durotar-1-6"))
	end)

	it("uses the later of two texts with one id and reports it", function()
		local ns = load()
		ns.Chapters:Register("dup", "first")
		ns.Chapters:Register("dup", "first")
		assert.are.same({}, ns.Chapters.problems)
		ns.Chapters:Register("dup", "second")
		assert.are.equal("second", ns.Chapters:Get("dup"))
		assert.are.equal(1, #ns.Chapters.problems)
	end)
end)

describe("ns.Classes", function()
	local function directiveStub()
		local registered = {}
		return {
			registered = registered,
			Register = function(_, name, def)
				registered[#registered + 1] = { name = name, def = def }
			end,
		}
	end

	it("registers class modules by class token", function()
		local ns = load()
		local module = { trainerSpells = { [10] = { 1515 } } }
		assert.is_true(ns.Classes:Register("HUNTER", module))
		assert.are.equal(module, ns.Classes:Get("HUNTER"))
		assert.is_nil(ns.Classes:Get("WARRIOR"))
		assert.is_nil(ns.Classes:Get(nil))
		assert.is_false(ns.Classes:Register(nil, {}))
		assert.is_false(ns.Classes:Register("MAGE", "module"))
		assert.are.equal(2, #ns.Classes.problems)
	end)

	it("registers a module's directives into ns.Directives, for every class", function()
		local ns = load()
		ns.Directives = directiveStub()
		local tame, ammo, warcry = { kind = "misc" }, { kind = "misc" }, { kind = "misc" }
		ns.Classes:Register("HUNTER", { directives = { tame = tame, ammo = ammo } })
		ns.Classes:Register("WARRIOR", { directives = { warcry = warcry } })
		assert.are.same({
			{ name = "ammo", def = ammo },
			{ name = "tame", def = tame },
			{ name = "warcry", def = warcry },
		}, ns.Directives.registered)
	end)

	it("reports directives it cannot register and keeps the module", function()
		local ns = load()
		ns.Directives = nil
		assert.is_true(ns.Classes:Register("HUNTER", { directives = { tame = {} } }))
		assert.is_table(ns.Classes:Get("HUNTER"))
		assert.truthy(ns.Classes.problems[1]:find("directives could not be registered", 1, true))
	end)

	it("keeps going when the directive registry refuses one", function()
		local ns, mock = load()
		ns.Directives = directiveStub()
		local register = ns.Directives.Register
		ns.Directives.Register = function(self, name, def)
			if name == "bad" then
				error("duplicate directive")
			end
			register(self, name, def)
		end
		local errorsBefore = #mock.errors
		ns.Classes:Register("HUNTER", { directives = { bad = {}, good = {} } })
		assert.are.equal("good", ns.Directives.registered[1].name)
		assert.are.equal(errorsBefore + 1, #mock.errors)
	end)

	it("tells the player's class module about a new level, after ns.Player has it", function()
		local ns, mock = load()
		local heard = {}
		ns.Classes:Register("HUNTER", {
			onLevelUp = function(level)
				heard[#heard + 1] = { level = level, stored = ns.Player.level }
			end,
		})
		ns.Classes:Register("WARRIOR", {
			onLevelUp = function(level)
				heard[#heard + 1] = { level = level, wrongClass = true }
			end,
		})
		mock.fire("PLAYER_LEVEL_UP", 2)
		assert.are.same({ { level = 2, stored = 2 } }, heard)
	end)
end)
