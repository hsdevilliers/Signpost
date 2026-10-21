-- Core/LearnProfessions.lua: what trainers teach and charge, and the recipes of the trade skill window, recorded into
-- SignpostDB.learned. The client is scripted by tests/mocks/profession_windows.lua (every API variant present or
-- absent); nothing here has been seen in the real client.
local addon = dofile("tests/helpers/addon.lua")
local learnMock = dofile("tests/mocks/learn.lua")
local windows = dofile("tests/mocks/profession_windows.lua")
local professionsMock = dofile("tests/mocks/professions.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G

local TRAINER = "Creature-0-1465-1-47-3154-00004F2B3E"
local PLAYER = "Player-1465-0A1B2C3D"
local PET = "Pet-0-1465-1-47-3100-01004F2B42"
local NOW = 1790000000

-- opts: the window variants (see tests/mocks/profession_windows.lua), opts.release for a release build,
-- opts.before(mock, world, win) to change the world before the addon loads.
local function load(opts)
	opts = opts or {}
	local world, win
	local ns, mock = addon.load({
		before = function(m)
			if opts.release then
				m.metadata.Version = "1.0.0"
			end
			world = learnMock.install(G)
			win = windows.install(G, opts)
			if opts.before then
				opts.before(m, world, win)
			end
		end,
	})
	return ns, mock, world, win
end

local function talkTo(world, guid, name)
	world.units.npc = { guid = guid, name = name }
end

-- Opens the trade skill window: its update events, then the moment the recorder waits before it reads.
local function openTradeSkill(mock, event)
	mock.fire(event or "TRADE_SKILL_LIST_UPDATE")
	mock.runTimers()
end

-- Whether text occurs anywhere (keys or values) in a nested table.
local function contains(value, text)
	if type(value) == "string" then
		return value:find(text, 1, true) ~= nil
	elseif type(value) == "table" then
		for key, item in pairs(value) do
			if contains(key, text) or contains(item, text) then
				return true
			end
		end
	end
	return false
end

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

-- Three services of the profession the mock calls Beta (skill line 200): one with its spell in the link, one with the
-- spell only in the tooltip data, one the character knows, and a header the recorder skips.
local function betaServices()
	return {
		{
			name = "Journeyman Beta",
			rank = "Journeyman",
			kind = "unavailable",
			cost = 1500,
			level = 10,
			line = "Beta",
			need = { "Beta", 50 },
			spell = 3100,
			link = windows.spellLink(3100),
		},
		{
			name = "Apprentice Beta",
			rank = "Apprentice",
			cost = 100,
			level = 5,
			line = "Beta",
			link = windows.spellLink(2018),
		},
		{ name = "Heavy Armor Kit", kind = "used", cost = 0, line = "Beta", spell = 2153 },
		{ name = "Learn Skills", kind = "header" },
	}
end

local BETA_SERVICES = {
	{ id = 2018, n = "Apprentice Beta", r = "Apprentice", cost = 100, lvl = 5, line = 200 },
	{ id = 2153, n = "Heavy Armor Kit", cost = 0, line = 200, known = true },
	{ id = 3100, n = "Journeyman Beta", r = "Journeyman", cost = 1500, lvl = 10, need = 50, line = 200 },
}

-- Three recipes of the profession the mock calls Alpha (skill line 100): two the character knows, one it does not.
local function alphaRecipes()
	return {
		{
			id = 2149,
			name = "Handstitched Boots",
			difficulty = "optimal",
			item = 2302,
			reagents = { { item = 2318, count = 2 }, { item = 2320, count = 1 } },
		},
		{
			id = 2152,
			name = "Light Armor Kit",
			difficulty = "easy",
			item = 2304,
			reagents = { { item = 2318, count = 1 } },
		},
		{ id = 9999, name = "Unlearned Recipe", learned = false, difficulty = "medium", item = 5000 },
	}
end

describe("Core/LearnProfessions", function()
	after_each(function()
		windows.uninstall(G)
		professionsMock.uninstall(G)
		learnMock.uninstall(G)
	end)

	describe("trainer services", function()
		it("records what a trainer's window lists: IDs, names, rank text, prices, levels and skills", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			mock.fire("TRAINER_SHOW")
			assert.are.same(BETA_SERVICES, ns.db.learned.trainers[3154].services)
			-- Core/Learn.lua still records the NPC, and what it always recorded of the trainer
			assert.are.equal("Trainer", ns.db.learned.npcs[3154].n)
			assert.are.same({ 2153, 3100 }, ns.db.learned.trainers[3154].spells)
			assert.are.equal(NOW, ns.db.learned.trainers[3154].t)
			assert.are.same({}, mock.errors)
		end)

		it("reads the spell ID from the link, and from the tooltip data when the link has none", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = {
				{ name = "From the link", link = windows.spellLink(11), spell = 99 },
				{ name = "From the tooltip", spell = 22 },
				{ name = "An item link", link = windows.itemLink(33), cost = 5 },
			}
			mock.fire("TRAINER_SHOW")
			local services = ns.db.learned.trainers[3154].services
			assert.are.same({ 11, 22 }, { services[2].id, services[3].id })
			assert.are.same({ n = "An item link", cost = 5, item = 33 }, services[1])
		end)

		it("reads a client whose trainer functions live in C_TrainerUI and answer one table per service", function()
			local ns, mock, world, win = load({ trainer = "namespaced" })
			assert.is_nil(G.GetTrainerServiceInfo)
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			mock.fire("TRAINER_SHOW")
			assert.are.same(BETA_SERVICES, ns.db.learned.trainers[3154].services)
			assert.are.equal("C_TrainerUI", ns.db.recorder.trainer.api)
		end)

		it("prefers C_TrainerUI where both exist, and falls back to the global function it lacks", function()
			local ns, mock, world, win = load({
				trainer = "both",
				before = function()
					G.GetTrainerServiceInfo = function()
						return "The global shape", "Rank 9", "available"
					end
					G.C_TrainerUI.GetTrainerServiceCost = nil
				end,
			})
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = { { name = "The namespaced shape", rank = "Rank 1", cost = 40 } }
			mock.fire("TRAINER_SHOW")
			assert.are.same(
				{ { n = "The namespaced shape", r = "Rank 1", cost = 40 } },
				ns.db.learned.trainers[3154].services
			)
		end)

		it("skips headers and rows the client tells nothing about besides their ID", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = { { kind = "header", name = "Header", cost = 1 }, { spell = 5 }, { name = "Real" } }
			mock.fire("TRAINER_SHOW")
			assert.are.same({ { n = "Real" } }, ns.db.learned.trainers[3154].services)
			-- Core/Learn.lua keeps the IDs on its own
			assert.are.same({ 5 }, ns.db.learned.trainers[3154].spells)
			assert.are.equal(1, ns.db.recorder.trainer.services)
		end)

		it("takes the latest reading of each service and never loses one a filtered window does not list", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = {
				{ name = "One", cost = 100, level = 5, spell = 1 },
				{ name = "Two", cost = 200, spell = 2 },
			}
			mock.fire("TRAINER_SHOW")
			-- the window now lists one service again (a filter) with another price, and a service it did not list before
			win.trainer.services =
				{ { name = "Two", cost = 250, spell = 2 }, { name = "Three", cost = 300, spell = 3 } }
			mock.now = mock.now + 5
			mock.fire("TRAINER_UPDATE")
			assert.are.same({
				{ id = 1, n = "One", cost = 100, lvl = 5 },
				{ id = 2, n = "Two", cost = 250 },
				{ id = 3, n = "Three", cost = 300 },
			}, ns.db.learned.trainers[3154].services)
		end)

		it("names a service by its name and rank when no spell ID can be read, one entry each", function()
			local ns, mock, world, win = load({ tooltip = false })
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = {
				{ name = "Same", rank = "Rank 1", cost = 10 },
				{ name = "Same", rank = "Rank 2", cost = 20 },
				{ name = "Same", rank = "Rank 1", cost = 11 },
			}
			mock.fire("TRAINER_SHOW")
			assert.are.same({
				{ n = "Same", r = "Rank 1", cost = 10 },
				{ n = "Same", r = "Rank 2", cost = 20 },
			}, ns.db.learned.trainers[3154].services)
		end)

		it(
			"drops stored services that are not a table with a numeric spell ID and text names, and raises nothing",
			function()
				local ns, mock, world, win = load({
					before = function()
						G.SignpostDB = {
							dbVersion = 1,
							learned = {
								trainers = {
									[3154] = {
										t = 1,
										services = {
											"junk",
											{ id = "x", n = "Text ID" },
											{ id = 5, n = {} },
											{ id = 6, r = 7 },
											{ id = 8, n = "Kept" },
										},
									},
								},
							},
						}
					end,
				})
				talkTo(world, TRAINER, "Trainer")
				win.trainer.services = { { name = "Fresh", spell = 9, cost = 1 } }
				mock.fire("TRAINER_SHOW")
				assert.are.same(
					{ { id = 8, n = "Kept" }, { id = 9, n = "Fresh", cost = 1 } },
					ns.db.learned.trainers[3154].services
				)
				assert.are.same({}, mock.errors)
			end
		)

		it("keeps at most LIMITS.servicesPerTrainer services", function()
			local ns, mock, world, win = load()
			ns.Learn.LIMITS.servicesPerTrainer = 2
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = {
				{ name = "A", spell = 30, cost = 1 },
				{ name = "B", spell = 20, cost = 1 },
				{ name = "C", spell = 10, cost = 1 },
			}
			mock.fire("TRAINER_SHOW")
			assert.are.same({ 20, 30 }, {
				ns.db.learned.trainers[3154].services[1].id,
				ns.db.learned.trainers[3154].services[2].id,
			})
			assert.are.equal(2, #ns.db.learned.trainers[3154].services)
		end)

		it("records a class trainer's services too, without a skill line", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Class Trainer")
			win.trainer.services = { { name = "A class spell", rank = "Rank 1", cost = 10, level = 4, spell = 75 } }
			mock.fire("TRAINER_SHOW")
			assert.are.same(
				{ { id = 75, n = "A class spell", r = "Rank 1", cost = 10, lvl = 4 } },
				ns.db.learned.trainers[3154].services
			)
		end)

		it("reads a window again only a second after a read that found services", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			-- a first read that found nothing does not start the wait
			mock.fire("TRAINER_SHOW")
			assert.is_nil(ns.db.learned.trainers[3154])
			win.trainer.services = { { name = "One", spell = 1, cost = 1 } }
			mock.fire("TRAINER_UPDATE")
			assert.are.equal(1, #ns.db.learned.trainers[3154].services)
			-- updates within the second are not read; the window opening again always is
			win.trainer.services = { { name = "Two", spell = 2, cost = 2 } }
			mock.now = mock.now + 0.5
			mock.fire("TRAINER_UPDATE")
			assert.are.equal(1, #ns.db.learned.trainers[3154].services)
			mock.fire("TRAINER_SHOW")
			assert.are.equal(2, #ns.db.learned.trainers[3154].services)
		end)

		it("says which functions answered and how much of each service they filled in", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			mock.fire("TRAINER_SHOW")
			assert.are.same({
				api = "global",
				services = 3,
				ids = 3,
				names = 3,
				costs = 3,
				levels = 2,
				skills = 1,
				lines = 3,
				known = 1,
				t = NOW,
			}, ns.db.recorder.trainer)
		end)

		it("records nothing, and raises nothing, where the client has no trainer functions", function()
			local ns, mock, world = load({ trainer = "none" })
			talkTo(world, TRAINER, "Trainer")
			mock.fire("TRAINER_SHOW")
			mock.fire("TRAINER_UPDATE")
			assert.are.same({}, ns.db.learned.trainers)
			assert.is_nil(ns.db.recorder.trainer.api)
			assert.are.same({}, mock.errors)
		end)

		it("never records a player's or a pet's window", function()
			local ns, mock, world, win = load()
			win.trainer.services = betaServices()
			for _, who in ipairs({ { PLAYER, "Someplayer" }, { PET, "Fluffy" } }) do
				talkTo(world, who[1], who[2])
				mock.fire("TRAINER_SHOW")
				mock.fire("TRAINER_UPDATE")
			end
			assert.are.same({}, ns.db.learned.trainers)
			assert.is_false(contains(ns.db.learned, "Someplayer"))
			assert.is_false(contains(ns.db.learned, "Fluffy"))
			assert.is_nil(ns.db.recorder)
		end)

		it("leaves out what the client hides behind a secret value", function()
			local ns, mock, world, win = load({
				before = function()
					G.issecretvalue = function(value)
						return value == "Hidden name" or value == 777
					end
				end,
			})
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = { { name = "Hidden name", cost = 777, level = 8, spell = 4 } }
			mock.fire("TRAINER_SHOW")
			assert.are.same({ { id = 4, lvl = 8 } }, ns.db.learned.trainers[3154].services)
			assert.are.same({}, mock.errors)
		end)
	end)

	describe("recipes", function()
		it("records each recipe the window lists with its item, reagents and difficulty at the skill", function()
			local ns, mock, _, win = load()
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			assert.are.same({
				[2149] = {
					n = "Handstitched Boots",
					line = 100,
					item = 2302,
					reagents = { [2318] = 2, [2320] = 1 },
					obs = { { skill = 40, cat = "optimal" } },
					t = NOW,
				},
				[2152] = {
					n = "Light Armor Kit",
					line = 100,
					item = 2304,
					reagents = { [2318] = 1 },
					obs = { { skill = 40, cat = "easy" } },
					t = NOW,
				},
				-- a recipe the character does not know has no difficulty to record
				[9999] = { n = "Unlearned Recipe", line = 100, item = 5000, t = NOW },
			}, ns.db.learned.recipes)
			assert.are.same({}, mock.errors)
		end)

		it("reads the same from a client with the Classic trade skill functions only", function()
			local ns, mock, _, win = load({ trade = "classic" })
			assert.is_nil(G.C_TradeSkillUI.GetAllRecipeIDs)
			local recipes = alphaRecipes()
			table.insert(recipes, 1, { name = "Armor", header = true })
			recipes[4].learned = nil
			win.trade.recipes = recipes
			openTradeSkill(mock, "TRADE_SKILL_UPDATE")
			local stored = ns.db.learned.recipes
			assert.are.same({
				n = "Handstitched Boots",
				line = 100,
				item = 2302,
				reagents = { [2318] = 2, [2320] = 1 },
				obs = { { skill = 40, cat = "optimal" } },
				t = NOW,
			}, stored[2149])
			assert.are.equal(3, count(stored))
			assert.are.equal("global", ns.db.recorder.tradeSkill.api)
			assert.are.equal("classic", ns.db.recorder.tradeSkill.skillFrom)
		end)

		it("raises nothing and records nothing where the client has neither shape", function()
			local ns, mock, _, win = load({ trade = "none" })
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.are.same({}, mock.errors)
			windows.uninstall(G)
			openTradeSkill(mock, "TRADE_SKILL_SHOW")
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.are.same({}, mock.errors)
		end)

		it("files a recipe under the profession of the child skill line the window shows, at its skill", function()
			local ns, mock, _, win = load()
			win.trade.child = { professionID = 2937, parentProfessionID = 100, skillLevel = 33, maxSkillLevel = 75 }
			win.trade.base = { professionID = 100, skillLevel = 0, maxSkillLevel = 75 }
			win.trade.recipes = { alphaRecipes()[1] }
			openTradeSkill(mock)
			assert.are.same({ skill = 33, cat = "optimal" }, ns.db.learned.recipes[2149].obs[1])
			assert.are.equal(100, ns.db.learned.recipes[2149].line)
			assert.are.equal("child", ns.db.recorder.tradeSkill.skillFrom)
		end)

		it("takes the skill from the learned professions when the window gives none", function()
			local ns, mock, _, win = load({
				before = function()
					professionsMock.install(G, { [1] = { skillLine = 100, name = "Alpha", rank = 55, max = 75 } })
				end,
			})
			win.trade.base = { professionID = 100 }
			win.trade.recipes = { alphaRecipes()[1] }
			openTradeSkill(mock)
			assert.are.same({ { skill = 55, cat = "optimal" } }, ns.db.learned.recipes[2149].obs)
			assert.are.equal("player", ns.db.recorder.tradeSkill.skillFrom)
		end)

		it(
			"records the recipe without a difficulty when no skill value can be read, and none above the maximum",
			function()
				local ns, mock, _, win = load()
				win.trade.base = { professionID = 100, maxSkillLevel = 75 }
				win.trade.recipes = { alphaRecipes()[1] }
				openTradeSkill(mock)
				assert.is_nil(ns.db.learned.recipes[2149].obs)
				assert.are.equal("Handstitched Boots", ns.db.learned.recipes[2149].n)
				win.trade.base = { professionID = 100, skillLevel = 80, maxSkillLevel = 75 }
				openTradeSkill(mock)
				assert.is_nil(ns.db.learned.recipes[2149].obs)
			end
		)

		it("records nothing when the profession of the window cannot be named, and says so", function()
			local ns, mock, _, win = load()
			win.trade.base = nil
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.are.equal("no skill line", ns.db.recorder.tradeSkill.skipped)
			assert.are.equal(3, ns.db.recorder.tradeSkill.recipes)
		end)

		it("names the profession of a Classic window through the client's own profession list", function()
			local ns, mock, _, win = load({ trade = "classic" })
			win.trade.line = 200
			win.trade.recipes = { alphaRecipes()[1] }
			openTradeSkill(mock)
			assert.are.equal(200, ns.db.learned.recipes[2149].line)
			win.professions[300] = "Gamma" -- a profession the client's list does not have
			win.trade.line = 300
			win.trade.recipes = { alphaRecipes()[2] }
			openTradeSkill(mock)
			assert.is_nil(ns.db.learned.recipes[2152])
		end)

		it("keeps the lowest and highest skill seen in each difficulty across visits", function()
			local ns, mock, _, win = load()
			win.trade.recipes = { { id = 7, name = "Practice", difficulty = "optimal", item = 70 } }
			local function visit(skill, difficulty)
				win.trade.base = { professionID = 100, skillLevel = skill, maxSkillLevel = 300 }
				win.trade.recipes[1].difficulty = difficulty
				openTradeSkill(mock)
			end
			visit(40, "optimal")
			visit(45, "optimal")
			visit(50, "optimal")
			visit(55, "medium")
			visit(58, "medium")
			visit(70, "easy")
			assert.are.same({
				{ skill = 40, cat = "optimal" },
				{ skill = 50, cat = "optimal" },
				{ skill = 55, cat = "medium" },
				{ skill = 58, cat = "medium" },
				{ skill = 70, cat = "easy" },
			}, ns.db.learned.recipes[7].obs)
		end)

		it(
			"keeps the item and reagents it had when a later reading lacks them, and replaces them when it has them",
			function()
				local ns, mock, _, win = load()
				win.trade.recipes = { alphaRecipes()[1] }
				openTradeSkill(mock)
				win.trade.recipes = { { id = 2149, name = "Handstitched Boots", difficulty = "optimal" } }
				openTradeSkill(mock)
				assert.are.same({ [2318] = 2, [2320] = 1 }, ns.db.learned.recipes[2149].reagents)
				assert.are.equal(2302, ns.db.learned.recipes[2149].item)
				win.trade.recipes =
					{ { id = 2149, name = "Handstitched Boots", reagents = { { item = 2321, count = 3 } } } }
				openTradeSkill(mock)
				assert.are.same({ [2321] = 3 }, ns.db.learned.recipes[2149].reagents)
			end
		)

		it("keeps at most LIMITS.reagentsPerRecipe reagents and adds up an item that fills two slots", function()
			local ns, mock, _, win = load()
			ns.Learn.LIMITS.reagentsPerRecipe = 2
			win.trade.recipes = {
				{
					id = 5,
					name = "Many",
					reagents = {
						{ item = 1, count = 1 },
						{ item = 2, count = 1 },
						{ item = 3, count = 1 },
						{ item = 1, count = 2 },
					},
				},
			}
			openTradeSkill(mock)
			assert.are.same({ [1] = 3, [2] = 1 }, ns.db.learned.recipes[5].reagents)
		end)

		it("drops the recipe seen longest ago when LIMITS.recipes is reached", function()
			local ns, mock, _, win = load()
			ns.Learn.LIMITS.recipes = 2
			for i, id in ipairs({ 11, 12, 13 }) do
				mock.clock = NOW + i
				win.trade.recipes = { { id = id, name = "Recipe " .. id } }
				openTradeSkill(mock)
			end
			assert.is_nil(ns.db.learned.recipes[11])
			assert.is_table(ns.db.learned.recipes[12])
			assert.is_table(ns.db.learned.recipes[13])
			assert.are.equal(2, ns.Learn:Count("recipes"))
		end)

		it("never reads another player's trade skill window, nor the guild's", function()
			for shape, names in pairs({
				modern = { "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillGuild" },
				classic = { "IsTradeSkillLinked", "IsTradeSkillGuild" },
			}) do
				for index, field in ipairs({ "linked", "guild" }) do
					local ns, mock, _, win = load({ trade = shape })
					win.trade[field] = true
					win.trade.recipes = alphaRecipes()
					openTradeSkill(mock)
					assert.are.same({}, ns.Learn:Table("recipes"), shape .. " " .. field)
					assert.are.equal(names[index], ns.db.recorder.tradeSkill.skipped)
					windows.uninstall(G)
					learnMock.uninstall(G)
				end
			end
		end)

		it("reads once, a moment after the last update of a burst", function()
			local ns, mock, _, win = load()
			local reads = 0
			local original = G.C_TradeSkillUI.GetAllRecipeIDs
			G.C_TradeSkillUI.GetAllRecipeIDs = function()
				reads = reads + 1
				return original()
			end
			win.trade.recipes = alphaRecipes()
			mock.fire("TRADE_SKILL_SHOW")
			mock.fire("TRADE_SKILL_LIST_UPDATE")
			mock.fire("TRADE_SKILL_DATA_SOURCE_CHANGED")
			assert.are.equal(0, reads)
			mock.runTimers()
			assert.are.equal(1, reads)
			assert.are.equal("TRADE_SKILL_DATA_SOURCE_CHANGED", ns.db.recorder.tradeSkill.event)
			assert.are.equal(3, count(ns.db.learned.recipes))
		end)

		it("says which functions answered, where the skill came from and how much it filled in", function()
			local ns, mock, _, win = load()
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			assert.are.same({
				api = "C_TradeSkillUI",
				event = "TRADE_SKILL_LIST_UPDATE",
				line = 100,
				skill = 40,
				skillFrom = "base",
				skills = { base = 40 },
				recipes = 3,
				written = 3,
				items = 3,
				reagents = 2,
				difficulties = 2,
				t = NOW,
			}, ns.db.recorder.tradeSkill)
		end)

		it("leaves out what the client hides behind a secret value", function()
			local ns, mock, _, win = load({
				before = function()
					G.issecretvalue = function(value)
						return value == "Secret recipe" or value == 2302
					end
				end,
			})
			win.trade.recipes = { { id = 2149, name = "Secret recipe", difficulty = "optimal", item = 2302 } }
			openTradeSkill(mock)
			-- nothing readable is left of the recipe: it is not recorded at all
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.are.same({}, mock.errors)
		end)
	end)

	describe("difficulty observations", function()
		local Professions
		before_each(function()
			Professions = load().Learn.Professions
		end)

		it("starts a recipe's list and keeps the lowest and highest skill of each difficulty", function()
			local list = Professions.MergeObservation(nil, 40, "optimal")
			assert.are.same({ { skill = 40, cat = "optimal" } }, list)
			list = Professions.MergeObservation(list, 50, "optimal")
			list = Professions.MergeObservation(list, 45, "optimal")
			assert.are.same({ { skill = 40, cat = "optimal" }, { skill = 50, cat = "optimal" } }, list)
		end)

		it("replaces the observation at the same skill with the newer one", function()
			local list = Professions.MergeObservation({ { skill = 50, cat = "optimal" } }, 50, "medium")
			assert.are.same({ { skill = 50, cat = "medium" } }, list)
		end)

		it("ignores stored entries that are not a skill value with one of the four difficulties", function()
			local list = Professions.MergeObservation({
				{ skill = 0, cat = "optimal" },
				{ skill = 20, cat = "orange" },
				{ skill = "x", cat = "easy" },
				"junk",
				{ skill = 30, cat = "trivial" },
			}, 10, "optimal")
			assert.are.same({ { skill = 10, cat = "optimal" }, { skill = 30, cat = "trivial" } }, list)
		end)

		it("never holds more than two entries per difficulty, however long the character plays", function()
			local list
			for skill = 1, 300 do
				local cat = skill < 100 and "optimal" or skill < 150 and "medium" or skill < 200 and "easy" or "trivial"
				list = Professions.MergeObservation(list, skill, cat)
			end
			local skills = {}
			for i, entry in ipairs(list) do
				skills[i] = entry.skill
			end
			assert.are.same({ 1, 99, 100, 149, 150, 199, 200, 300 }, skills)
		end)

		it("names the difficulties the client reports as words or as numbers", function()
			local category = Professions.Category
			assert.are.same({ "optimal", "medium", "easy", "trivial", "optimal", "trivial" }, {
				category("optimal"),
				category("Medium"),
				category("easy"),
				category("trivial"),
				category(0),
				category(3),
			})
			assert.is_nil(category("header"))
			assert.is_nil(category(7))
			assert.is_nil(category(nil))
			-- a client whose enum names the values differently is followed, not guessed at
			G.Enum.TradeskillRelativeDifficulty = { Optimal = 5, Medium = 6 }
			assert.are.same({ "optimal", "medium" }, { category(5), category(6) })
			assert.is_nil(category(0))
		end)
	end)

	describe("what is recorded, and when", function()
		it("records nothing on a release build before the player agrees, and everything after", function()
			local ns, mock, world, win = load({ release = true })
			assert.is_false(ns.Contribute:Enabled())
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			win.trade.recipes = alphaRecipes()
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			assert.are.same({}, ns.db.learned.trainers)
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.is_nil(ns.db.recorder)
			ns.Contribute:SetEnabled(true)
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			assert.are.equal(3, #ns.db.learned.trainers[3154].services)
			assert.are.equal(3, count(ns.db.learned.recipes))
		end)

		it("does not read a trade skill window the player took the choice back from before the read", function()
			local ns, mock, _, win = load({ release = true })
			ns.Contribute:SetEnabled(true)
			win.trade.recipes = alphaRecipes()
			mock.fire("TRADE_SKILL_LIST_UPDATE")
			ns.Contribute:SetEnabled(false)
			mock.runTimers()
			assert.are.same({}, ns.Learn:Table("recipes"))
			assert.is_nil(ns.db.recorder)
		end)

		it("always records on a development build", function()
			local ns, mock, _, win = load()
			assert.is_true(ns.isDev)
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			assert.are.equal(3, count(ns.db.learned.recipes))
		end)

		it("reads no gold and no player: the only name it asks the client for is the NPC's it talks to", function()
			local readUnits, forbidden = {}, {}
			local ns, mock, world, win = load({
				before = function()
					local unitName = G.UnitName
					G.UnitName = function(unit)
						readUnits[#readUnits + 1] = unit
						return unitName and unitName(unit)
					end
					for _, name in ipairs({
						"GetMoney",
						"GetGuildInfo",
						"UnitFullName",
						"GetUnitName",
						"GetPlayerInfoByGUID",
					}) do
						G[name] = function()
							forbidden[#forbidden + 1] = name
							return "Someplayer"
						end
					end
				end,
			})
			world.units.player = { guid = PLAYER, name = "Someplayer" }
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			win.trade.recipes = alphaRecipes()
			readUnits = {}
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			assert.is_true(#readUnits > 0)
			for _, unit in ipairs(readUnits) do
				assert.are.equal("npc", unit)
			end
			assert.are.same({}, forbidden)
			assert.is_false(contains(ns.db.learned, "Someplayer"))
			assert.is_false(contains(ns.db.recorder, "Someplayer"))
			for _, name in ipairs({ "GetMoney", "GetGuildInfo", "UnitFullName", "GetUnitName", "GetPlayerInfoByGUID" }) do
				G[name] = nil
			end
		end)

		it("handles every event without errors on a client that has none of the functions", function()
			local ns, mock, world = load({ trainer = "none", trade = "none", listing = false })
			windows.uninstall(G)
			learnMock.uninstall(G)
			for _, event in ipairs({
				"TRAINER_SHOW",
				"TRAINER_UPDATE",
				"TRADE_SKILL_SHOW",
				"TRADE_SKILL_LIST_UPDATE",
				"TRADE_SKILL_DATA_SOURCE_CHANGED",
				"TRADE_SKILL_UPDATE",
			}) do
				mock.fire(event)
			end
			mock.runTimers()
			assert.are.same({}, mock.errors)
			assert.are.same({}, ns.db.errors)
			assert.are.same({ services = 0, recipes = 0 }, ns.Learn.Professions:Counts())
			assert.is_table(world)
		end)

		it("shows the new counts in the consent window", function()
			local ns, mock, world, win = load({ release = true })
			ns.Contribute:SetEnabled(true)
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			win.trade.recipes = alphaRecipes()
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			ns.UI.Contribute:Show()
			local frame = ns.UI.Contribute.frame
			local shown
			frame.State.SetText = function(_, text)
				shown = text
			end
			ns.UI.Contribute:Refresh()
			assert.are.equal(
				"Recorded so far: 1 NPCs, 0 objects, 0 quests, 0 flight nodes, 0 zone crossings, 3 trainer services, 3 recipes.",
				shown
			)
			assert.are.same({}, mock.errors)
		end)

		it("counts what it recorded for /signpost learned", function()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			win.trade.recipes = alphaRecipes()
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			assert.are.same({ services = 3, recipes = 3 }, ns.Learn.Professions:Counts())
			G.SlashCmdList.SIGNPOST("learned")
			local last = mock.printed[#mock.printed]
			assert.truthy(last:find("1 trainers, 0 vendors, 3 trainer services, 3 recipes", 1, true))
		end)
	end)

	describe("the file it writes", function()
		-- The SavedVariables file the importer's tests read (tools/tests/test_learned_professions.py): what this scenario
		-- records, written as the client writes it. When the recorder's format changes on purpose, this spec fails with
		-- the difference; write the new file with  SIGNPOST_WRITE_FIXTURES=1 busted tests/learn_professions_spec.lua
		-- and adjust the importer's tests to it.
		local FIXTURE = "tests/fixtures/profession-recorder/Signpost.lua"

		-- A trainer's window, then the profession window at skill 40, then again at skill 55 with the boots one colour on.
		local function scenario()
			local ns, mock, world, win = load()
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			mock.fire("TRAINER_SHOW")
			win.trade.recipes = alphaRecipes()
			openTradeSkill(mock)
			win.trade.base = { professionID = 100, skillLevel = 55, maxSkillLevel = 75 }
			win.trade.recipes[1].difficulty = "medium"
			openTradeSkill(mock)
			return { trainers = ns.db.learned.trainers, recipes = ns.db.learned.recipes }
		end

		local function sortedKeys(tbl)
			local keys = {}
			for key in pairs(tbl) do
				keys[#keys + 1] = key
			end
			table.sort(keys, function(a, b)
				if type(a) == type(b) then
					return a < b
				end
				return type(a) == "number"
			end)
			return keys
		end

		-- Lua source for a table of plain data, keys sorted so that the file is the same every time
		local function serialize(value, depth)
			if type(value) == "string" then
				return '"' .. value:gsub('[\\"]', "\\%0") .. '"'
			elseif type(value) ~= "table" then
				return tostring(value)
			end
			local pad = string.rep("\t", depth + 1)
			local lines = {}
			for _, key in ipairs(sortedKeys(value)) do
				local name = type(key) == "number" and string.format("[%d]", key) or string.format('["%s"]', key)
				lines[#lines + 1] = string.format("%s%s = %s,", pad, name, serialize(value[key], depth + 1))
			end
			return "{\n" .. table.concat(lines, "\n") .. "\n" .. string.rep("\t", depth) .. "}"
		end

		it("is the file tools/tests/test_learned_professions.py imports", function()
			local recorded = scenario()
			if os.getenv("SIGNPOST_WRITE_FIXTURES") then
				local file = assert(io.open(FIXTURE, "wb")) -- binary: the file keeps the line endings it is written with
				file:write("SignpostDB = " .. serialize({ learned = recorded }, 0) .. "\n")
				file:close()
			end
			local chunk = assert(loadfile(FIXTURE))
			local env = {}
			setfenv(chunk, env)
			chunk()
			local written = env.SignpostDB.learned
			assert.are.same(written.trainers, recorded.trainers)
			assert.are.same(written.recipes, recorded.recipes)
			-- and it is a scenario with something in it
			assert.are.equal(3, #recorded.trainers[3154].services)
			assert.are.same(
				{ { skill = 40, cat = "optimal" }, { skill = 55, cat = "medium" } },
				recorded.recipes[2149].obs
			)
		end)
	end)

	describe("/signpost probe", function()
		local function has(list, name)
			for _, entry in ipairs(list) do
				if entry == name then
					return true
				end
			end
			return false
		end

		it("lists which of the profession windows' functions exist, and what the last windows answered", function()
			local ns, mock, world, win = load({ trainer = "both", trade = "modern" })
			talkTo(world, TRAINER, "Trainer")
			win.trainer.services = betaServices()
			win.trade.recipes = alphaRecipes()
			mock.fire("TRAINER_SHOW")
			openTradeSkill(mock)
			G.SlashCmdList.SIGNPOST("probe")
			local recorder = ns.db.probe.recorder
			assert.is_nil(recorder.error)
			-- present in the shapes the mock has, absent in the one it lacks
			assert.are.equal("function", recorder.types["C_TrainerUI.GetTrainerServiceInfo"])
			assert.are.equal("function", recorder.types["GetTrainerServiceInfo"])
			assert.are.equal("function", recorder.types["C_TradeSkillUI.GetAllRecipeIDs"])
			assert.are.equal("nil", recorder.types["GetNumTradeSkills"])
			-- the client's own namespaces are listed, so functions nobody thought of show up
			assert.is_true(has(recorder.namespaces.C_TradeSkillUI, "GetAllRecipeIDs"))
			assert.is_true(has(recorder.namespaces.C_TrainerUI, "GetTrainerServiceCost"))
			assert.are.equal(1, recorder.enums.TradeskillRelativeDifficulty.Medium)
			-- and what the last windows answered
			assert.are.equal("C_TradeSkillUI", recorder.last.tradeSkill.api)
			assert.are.equal("C_TrainerUI", recorder.last.trainer.api)
			assert.are.equal(3, recorder.last.trainer.services)
		end)

		it("completes on a client that has none of them", function()
			local ns = load({ trainer = "none", trade = "none", listing = false })
			windows.uninstall(G)
			G.SlashCmdList.SIGNPOST("probe")
			local recorder = ns.db.probe.recorder
			assert.is_nil(recorder.error)
			assert.are.equal("nil", recorder.types["C_TradeSkillUI.GetAllRecipeIDs"])
			assert.are.same({}, recorder.namespaces)
			assert.are.same({}, recorder.enums)
		end)
	end)
end)
