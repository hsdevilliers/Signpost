-- Automation/*.lua on the generic client mock: a scripted "world" provides the NPC dialogs, trainer, vendor and flight
-- map APIs; the current guide step is a stand-in whose directives are parsed by the real ns.Directives, so the argument
-- shapes are the engine's. Everything is off by default; Shift, combat and death stop it; it acts on the current step.
local addon = dofile("tests/helpers/addon.lua")
local G = addon.G

-- Client globals this spec defines (wow_mock does not reset them).
local OWN = {
	"IsShiftKeyDown",
	"InCombatLockdown",
	"UnitIsDeadOrGhost",
	"GetQuestID",
	"QuestGetAutoAccept",
	"AcceptQuest",
	"CompleteQuest",
	"IsQuestCompletable",
	"GetQuestReward",
	"GetNumQuestChoices",
	"GetQuestItemLink",
	"GetQuestItemInfo",
	"GetNumAvailableQuests",
	"GetAvailableQuestInfo",
	"GetNumActiveQuests",
	"GetActiveQuestID",
	"SelectAvailableQuest",
	"SelectActiveQuest",
	"GetMoney",
	"GetNumTrainerServices",
	"GetTrainerServiceInfo",
	"GetTrainerServiceItemLink",
	"GetTrainerServiceCost",
	"BuyTrainerService",
	"GetMerchantNumItems",
	"GetMerchantItemID",
	"GetMerchantItemMaxStack",
	"BuyMerchantItem",
	"TakeTaxiNode",
	"GetBindLocation",
	"GetFileIDFromPath",
	"StaticPopup_FindVisible",
	"ConfirmBinder",
	"SettingsPanel",
	"GetTaxiMapID",
	"UnitLevel",
	"C_MerchantFrame",
	"C_TooltipInfo",
	"C_PlayerInteractionManager",
}

local function newWorld()
	local world = {
		shift = false,
		combat = false,
		dead = false,
		money = 100000,
		questID = nil,
		autoAccept = false,
		completable = true,
		choices = {}, -- { { itemID, quantity } }
		items = {}, -- [itemID] = { sell = copper } (nil: not cached)
		available = {}, -- gossip: { { questID, isTrivial } }
		active = {}, -- gossip: { { questID, isComplete } }
		options = {}, -- gossip options
		bags = {},
		level = 1,
		accepted = 0,
		completed = 0,
		rewards = {},
		selected = {},
		requested = {},
		bought = {},
		purchases = {},
		taken = {},
		services = {}, -- trainer: { { name, type, spellID, cost } }
		slots = {}, -- vendor: { { itemID, price, stack, available } }
		confirms = {},
	}
	return world
end

-- Installs the scripted client. Quest, trainer and vendor APIs are the Classic-shaped globals Forever has; the gossip
-- quest lists and C_Item are the Mainline namespaces.
local function install(world)
	G.IsShiftKeyDown = function()
		return world.shift
	end
	G.InCombatLockdown = function()
		return world.combat
	end
	G.UnitIsDeadOrGhost = function()
		return world.dead
	end
	G.UnitLevel = function()
		return world.level
	end
	G.GetQuestID = function()
		return world.questID
	end
	G.QuestGetAutoAccept = function()
		return world.autoAccept
	end
	G.AcceptQuest = function()
		world.accepted = world.accepted + 1
	end
	G.CompleteQuest = function()
		world.completed = world.completed + 1
	end
	G.IsQuestCompletable = function()
		return world.completable
	end
	G.GetQuestReward = function(index)
		world.rewards[#world.rewards + 1] = index
	end
	G.GetNumQuestChoices = function()
		return #world.choices
	end
	G.GetQuestItemLink = function(_, index)
		local choice = world.choices[index]
		return choice and string.format("|cff1eff00|Hitem:%d::::::::1:::::::|h[Item %d]|h|r", choice[1], choice[1])
	end
	G.GetQuestItemInfo = function(_, index)
		local choice = world.choices[index]
		return "Item", 1, choice and choice[2] or 1
	end
	G.GetNumAvailableQuests = function()
		return #world.available
	end
	G.GetAvailableQuestInfo = function(index)
		local quest = world.available[index]
		return quest.isTrivial == true, 0, false, false, quest.questID
	end
	G.GetNumActiveQuests = function()
		return #world.active
	end
	G.GetActiveQuestID = function(index)
		return world.active[index].questID
	end
	G.SelectAvailableQuest = function(index)
		world.selected[#world.selected + 1] = "available:" .. index
	end
	G.SelectActiveQuest = function(index)
		world.selected[#world.selected + 1] = "active:" .. index
	end
	G.C_QuestLog = {
		IsComplete = function(questID)
			for _, quest in ipairs(world.active) do
				if quest.questID == questID then
					return quest.isComplete ~= false
				end
			end
			return false
		end,
	}
	G.C_GossipInfo = {
		GetAvailableQuests = function()
			return world.available
		end,
		GetActiveQuests = function()
			return world.active
		end,
		GetOptions = function()
			return world.options
		end,
		SelectAvailableQuest = function(questID)
			world.selected[#world.selected + 1] = "gossip-available:" .. questID
		end,
		SelectActiveQuest = function(questID)
			world.selected[#world.selected + 1] = "gossip-active:" .. questID
		end,
		SelectOption = function(optionID)
			world.selected[#world.selected + 1] = "option:" .. optionID
		end,
	}
	G.C_Item = {
		GetItemInfo = function(link)
			local itemID = tonumber(tostring(link):match("item:(%d+)"))
			local item = world.items[itemID]
			if not item then
				return nil
			end
			return "Item", link, 1, 1, 1, "", "", 1, "", 0, item.sell
		end,
		RequestLoadItemDataByID = function(itemID)
			world.requested[#world.requested + 1] = itemID
		end,
		GetItemCount = function(itemID)
			return world.bags[itemID] or 0
		end,
	}
	G.GetMoney = function()
		return world.money
	end
	G.GetNumTrainerServices = function()
		return #world.services
	end
	G.GetTrainerServiceInfo = function(index)
		local service = world.services[index]
		return service.name or "Service", "", service.type or "available"
	end
	G.GetTrainerServiceItemLink = function(index)
		local service = world.services[index]
		return service.spellID and string.format("|cff71d5ff|Hspell:%d|h[Spell]|h|r", service.spellID) or nil
	end
	G.GetTrainerServiceCost = function(index)
		return world.services[index].cost or 0
	end
	G.BuyTrainerService = function(index)
		local service = world.services[index]
		world.bought[#world.bought + 1] = service.spellID or service.tooltipID
	end
	G.GetMerchantNumItems = function()
		return #world.slots
	end
	G.GetMerchantItemID = function(index)
		return world.slots[index].itemID
	end
	G.GetMerchantItemMaxStack = function()
		return 20
	end
	G.C_MerchantFrame = {
		GetItemInfo = function(index)
			local slot = world.slots[index]
			return {
				name = "Thing",
				price = slot.price,
				stackCount = slot.stack or 1,
				numAvailable = slot.available or -1,
				isPurchasable = true,
				hasExtendedCost = slot.extended == true,
			}
		end,
	}
	G.BuyMerchantItem = function(index, quantity)
		world.purchases[#world.purchases + 1] = { world.slots[index].itemID, quantity }
	end
	G.TakeTaxiNode = function(argument)
		world.taken[#world.taken + 1] = argument
	end
end

-- Loads the addon on the scripted client; `step` is the current guide step as ".directive args" lines.
local function start(lines, opts)
	opts = opts or {}
	local world = opts.world or newWorld()
	local ns, mock = addon.load({
		before = function()
			install(world)
			if opts.setup then
				opts.setup(world)
			end
		end,
	})
	local guide = { steps = {}, skipQuests = opts.skip or {} }
	local function parse(text)
		local directive, message = ns.Directives:ParseLine(text, { source = "spec", line = 1, guideId = "spec" })
		assert.is_truthy(directive, message)
		return directive
	end
	local function setStep(texts)
		local step = { id = "spec:1", directives = {} }
		for _, text in ipairs(texts) do
			step.directives[#step.directives + 1] = parse(text)
		end
		guide.steps = { step }
		world.step = step
	end
	setStep(lines or {})
	ns.Progress.Current = function()
		return world.step, 1
	end
	ns.Progress.Guide = function()
		return guide
	end
	ns.Progress.State = function()
		return {}
	end
	if opts.enable then
		for _, feature in ipairs(opts.enable) do
			ns.char.automation[feature] = true
		end
	end
	return ns, mock, world, setStep
end

local function noErrors(ns, mock)
	assert.are.same({}, mock.errors)
	assert.are.same({}, ns.db.errors)
end

after_each(function()
	for _, name in ipairs(OWN) do
		G[name] = nil
	end
	G.C_QuestLog, G.C_GossipInfo, G.C_Item, G.C_TaxiMap = nil, nil, nil, nil
	G.NumTaxiNodes, G.TaxiNodeName, G.TaxiNodeGetType = nil, nil, nil
end)

describe("Automation settings and gate", function()
	it("is off by default, for every feature and every mode", function()
		local ns = start()
		for _, feature in ipairs(ns.Automation.FEATURES) do
			assert.is_false(ns.Automation:Enabled(feature), feature)
		end
		local settings = ns.char.automation
		assert.is_false(settings.acceptAll)
		assert.is_false(settings.turnInAll)
		assert.is_false(settings.rewardAsk)
		assert.are.equal(0, ns.Automation:Reserve())
	end)

	it("blocks on Shift, combat, death and the open Settings panel", function()
		local ns, _, world = start({}, { enable = { "quests" } })
		assert.is_true(ns.Automation:Allowed("quests"))
		world.shift = true
		assert.is_false(ns.Automation:Allowed("quests"))
		world.shift = false
		world.combat = true
		assert.is_false(ns.Automation:Allowed("quests"))
		world.combat = false
		world.dead = true
		assert.is_false(ns.Automation:Allowed("quests"))
		world.dead = false
		G.SettingsPanel = {
			IsShown = function()
				return true
			end,
		}
		assert.is_false(ns.Automation:Allowed("quests"))
		G.SettingsPanel = nil
		assert.is_true(ns.Automation:Allowed("quests"))
	end)

	it("has a slash master switch and a reserve", function()
		local ns, mock = start()
		G.SlashCmdList.SIGNPOST("automation on")
		for _, feature in ipairs(ns.Automation.FEATURES) do
			assert.is_true(ns.Automation:Enabled(feature), feature)
		end
		assert.is_false(ns.char.automation.acceptAll) -- the modes stay as chosen
		G.SlashCmdList.SIGNPOST("automation off")
		for _, feature in ipairs(ns.Automation.FEATURES) do
			assert.is_false(ns.Automation:Enabled(feature), feature)
		end
		G.SlashCmdList.SIGNPOST("automation reserve 2.5")
		assert.are.equal(25000, ns.Automation:Reserve())
		G.SlashCmdList.SIGNPOST("automation status")
		G.SlashCmdList.SIGNPOST("automation nonsense")
		noErrors(ns, mock)
	end)
end)

describe("quest accept", function()
	it("does nothing while off, even on a step that accepts the quest", function()
		local ns, mock, world = start({ ".accept 100" })
		world.questID = 100
		mock.fire("QUEST_DETAIL")
		assert.are.equal(0, world.accepted)
		noErrors(ns, mock)
	end)

	it("accepts the guide's quest and no other in guide mode", function()
		local ns, mock, world = start({ ".accept 100" }, { enable = { "quests" } })
		world.questID = 100
		mock.fire("QUEST_DETAIL")
		assert.are.equal(1, world.accepted)
		world.questID = 200
		mock.fire("QUEST_DETAIL")
		assert.are.equal(1, world.accepted)
		noErrors(ns, mock)
	end)

	it("accepts any non-trivial quest in the wide mode, but never one the guide skips", function()
		local ns, mock, world = start(
			{ ".note nothing" },
			{ enable = { "quests", "acceptAll" }, skip = { [300] = "bad" } }
		)
		G.C_QuestLog.IsQuestTrivial = function(questID)
			return questID == 400
		end
		world.questID = 200
		mock.fire("QUEST_DETAIL")
		assert.are.equal(1, world.accepted)
		world.questID = 300 -- #skipquest
		mock.fire("QUEST_DETAIL")
		assert.are.equal(1, world.accepted)
		world.questID = 400 -- trivial
		mock.fire("QUEST_DETAIL")
		assert.are.equal(1, world.accepted)
		noErrors(ns, mock)
	end)

	it("never accepts a skipped quest even when the step asks for it", function()
		local _, mock, world = start({ ".accept 100" }, { enable = { "quests" }, skip = { [100] = "skipped" } })
		world.questID = 100
		mock.fire("QUEST_DETAIL")
		assert.are.equal(0, world.accepted)
	end)

	it("honours Shift and combat", function()
		local _, mock, world = start({ ".accept 100" }, { enable = { "quests" } })
		world.questID = 100
		world.shift = true
		mock.fire("QUEST_DETAIL")
		world.shift = false
		world.combat = true
		mock.fire("QUEST_DETAIL")
		assert.are.equal(0, world.accepted)
	end)

	it("picks the guide's quest from a greeting and from gossip", function()
		local ns, mock, world = start({ ".accept 100" }, { enable = { "quests" } })
		world.available = { { questID = 55 }, { questID = 100 } }
		mock.fire("QUEST_GREETING")
		assert.are.same({ "available:2" }, world.selected)
		world.selected = {}
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ "gossip-available:100" }, world.selected)
		noErrors(ns, mock)
	end)

	it("leaves a greeting alone when the step wants none of its quests", function()
		local _, mock, world = start({ ".accept 999" }, { enable = { "quests" } })
		world.available = { { questID = 55 } }
		mock.fire("QUEST_GREETING")
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, world.selected)
	end)
end)

describe("quest turn-in", function()
	it("completes the guide's quest at QUEST_PROGRESS when it is completable, and no other", function()
		local ns, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
		world.questID = 100
		mock.fire("QUEST_PROGRESS")
		assert.are.equal(1, world.completed)
		world.completable = false
		mock.fire("QUEST_PROGRESS")
		assert.are.equal(1, world.completed)
		world.completable, world.questID = true, 101
		mock.fire("QUEST_PROGRESS")
		assert.are.equal(1, world.completed)
		noErrors(ns, mock)
	end)

	it("does nothing while off", function()
		local _, mock, world = start({ ".turnin 100" })
		world.questID = 100
		mock.fire("QUEST_PROGRESS")
		mock.fire("QUEST_COMPLETE")
		assert.are.equal(0, world.completed)
		assert.are.same({}, world.rewards)
	end)

	it("turns in everything completable in the wide mode", function()
		local _, mock, world = start({ ".note x" }, { enable = { "turnIn", "turnInAll" } })
		world.questID = 777
		mock.fire("QUEST_PROGRESS")
		assert.are.equal(1, world.completed)
	end)

	it("selects the guide's active quest at gossip and at a greeting", function()
		local _, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
		world.active = { { questID = 9, isComplete = true }, { questID = 100, isComplete = true } }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ "gossip-active:100" }, world.selected)
		world.selected = {}
		mock.fire("QUEST_GREETING")
		assert.are.same({ "active:2" }, world.selected)
		-- not complete yet: nothing
		world.selected = {}
		world.active = { { questID = 100, isComplete = false } }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, world.selected)
	end)

	describe("the reward", function()
		local function complete(world, mock)
			world.questID = 100
			mock.fire("QUEST_COMPLETE")
		end

		it("passes 0 for no choice and 1 for the only one", function()
			local _, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
			complete(world, mock)
			assert.are.same({ 0 }, world.rewards)
			world.rewards, world.choices = {}, { { 5001, 1 } }
			complete(world, mock)
			assert.are.same({ 1 }, world.rewards)
		end)

		it("takes the guide's choice index", function()
			local _, mock, world = start({ ".turnin 100", ".reward 100,2" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 }, { 5003, 1 } }
			world.items = { [5001] = { sell = 900 }, [5002] = { sell = 1 }, [5003] = { sell = 50 } }
			complete(world, mock)
			assert.are.same({ 2 }, world.rewards) -- not the 5001 the value rule would pick
		end)

		it("takes the guide's item ID", function()
			local _, mock, world = start({ ".turnin 100", ".reward 100,5003" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 }, { 5003, 1 } }
			world.items = { [5001] = { sell = 900 }, [5002] = { sell = 1 }, [5003] = { sell = 50 } }
			complete(world, mock)
			assert.are.same({ 3 }, world.rewards)
		end)

		it("falls back to the value rule when the guide's item is not offered", function()
			local _, mock, world = start({ ".turnin 100", ".reward 100,5999" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 } }
			world.items = { [5001] = { sell = 5 }, [5002] = { sell = 50 } }
			complete(world, mock)
			assert.are.same({ 2 }, world.rewards)
		end)

		it("takes the highest vendor value, counting the quantity", function()
			local _, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 10 }, { 5003, 1 } }
			world.items = { [5001] = { sell = 900 }, [5002] = { sell = 100 }, [5003] = { sell = 899 } }
			complete(world, mock)
			assert.are.same({ 2 }, world.rewards) -- 10 x 100 beats 900
		end)

		it("asks the client for uncached items and decides when they arrive", function()
			local ns, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 } }
			world.items = { [5001] = { sell = 10 } } -- 5002 not cached
			complete(world, mock)
			assert.are.same({}, world.rewards)
			assert.are.same({ 5002 }, world.requested)
			world.items[5002] = { sell = 99 }
			mock.fire("ITEM_DATA_LOAD_RESULT", 5002, true)
			assert.are.same({ 2 }, world.rewards)
			mock.runTimers() -- the 2 s timer finds nothing left to do
			assert.are.same({ 2 }, world.rewards)
			noErrors(ns, mock)
		end)

		it("stops and leaves the window open when the data does not arrive in 2 seconds", function()
			local ns, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 } }
			world.items = { [5001] = { sell = 10 } }
			complete(world, mock)
			mock.runTimers() -- the 2 s are up
			assert.are.same({}, world.rewards)
			assert.is_truthy(table.concat(mock.printed, "\n"):find("choose the reward yourself", 1, true))
			-- a late arrival no longer turns anything in
			world.items[5002] = { sell = 99 }
			mock.fire("ITEM_DATA_LOAD_RESULT", 5002, true)
			assert.are.same({}, world.rewards)
			noErrors(ns, mock)
		end)

		it("does not decide for the player in 'always let me choose' mode, but still honours .reward", function()
			local _, mock, world = start({ ".turnin 100" }, { enable = { "turnIn", "rewardAsk" } })
			world.choices = { { 5001, 1 }, { 5002, 1 } }
			world.items = { [5001] = { sell = 10 }, [5002] = { sell = 20 } }
			complete(world, mock)
			assert.are.same({}, world.rewards)
			local _, mock2, world2 = start({ ".turnin 100", ".reward 100,1" }, { enable = { "turnIn", "rewardAsk" } })
			world2.choices = { { 5001, 1 }, { 5002, 1 } }
			world2.questID = 100
			mock2.fire("QUEST_COMPLETE")
			assert.are.same({ 1 }, world2.rewards)
		end)

		it("stops when no choice has a vendor value", function()
			local _, mock, world = start({ ".turnin 100" }, { enable = { "turnIn" } })
			world.choices = { { 5001, 1 }, { 5002, 1 } }
			world.items = { [5001] = { sell = 0 }, [5002] = { sell = 0 } }
			complete(world, mock)
			assert.are.same({}, world.rewards)
		end)

		it("only turns in the step's quest and honours Shift", function()
			local _, mock, world = start({ ".turnin 101" }, { enable = { "turnIn" } })
			complete(world, mock)
			assert.are.same({}, world.rewards)
			local _, mock2, world2 = start({ ".turnin 100" }, { enable = { "turnIn" } })
			world2.shift = true
			complete(world2, mock2)
			assert.are.same({}, world2.rewards)
		end)
	end)
end)

describe("gossip", function()
	local function option(id, name, icon)
		return { gossipOptionID = id, name = name or "Option", icon = icon }
	end

	it("does nothing while off", function()
		local _, mock, world = start({ ".train class" })
		world.options = { option(1) }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, world.selected)
	end)

	it("selects a single option on an NPC visit step", function()
		local ns, mock, world = start({ ".train class" }, { enable = { "gossip" } })
		world.options = { option(7) }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ "option:7" }, world.selected)
		noErrors(ns, mock)
	end)

	it("leaves several options, quests and unrelated steps alone", function()
		local _, mock, world, setStep = start({ ".train class" }, { enable = { "gossip" } })
		world.options = { option(7), option(8) }
		mock.fire("GOSSIP_SHOW")
		world.options = { option(7) }
		world.available = { { questID = 5 } }
		mock.fire("GOSSIP_SHOW")
		world.available = {}
		setStep({ ".note walk" })
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, world.selected)
	end)

	it("sets the hearth during a .hs step and confirms the popup with its accept button", function()
		local ns, mock, world = start({ ".hs Razor Hill" }, { enable = { "gossip" } })
		world.options = { option(1, "I want to browse your goods."), option(2, "Make this inn your home.") }
		mock.fire("GOSSIP_SHOW")
		assert.are.same({ "option:2" }, world.selected)
		local clicks = 0
		G.StaticPopup_FindVisible = function(which)
			assert.are.equal("CONFIRM_BINDER", which)
			return {
				button1 = {
					Click = function()
						clicks = clicks + 1
					end,
				},
			}
		end
		mock.fire("CONFIRM_BINDER", "Razor Hill")
		mock.runTimers()
		assert.are.equal(1, clicks) -- confirmed once, not once per retry
		noErrors(ns, mock)
	end)

	it("recognises the binder by its icon", function()
		local ns = start()
		G.GetFileIDFromPath = function()
			return 132052
		end
		assert.is_true(ns.Automation.Gossip.IsBinderOption({ icon = 132052, name = "x" }))
		assert.is_false(ns.Automation.Gossip.IsBinderOption({ icon = 1, name = "Let me browse your goods" }))
	end)

	it("confirms through the interaction manager or ConfirmBinder when there is no popup to click", function()
		local ns, mock, world = start({ ".hs Razor Hill" }, { enable = { "gossip" } })
		local confirmed
		G.Enum = { PlayerInteractionType = { Binder = 21 } }
		G.C_PlayerInteractionManager = {
			ConfirmationInteraction = function(kind)
				confirmed = kind
			end,
		}
		mock.fire("CONFIRM_BINDER")
		mock.runTimers()
		assert.are.equal(21, confirmed)
		assert.is_table(world)
		noErrors(ns, mock)
	end)

	it("does not set the hearth when the step is not a .hs step or the inn is already home", function()
		local ns, mock, world, setStep = start({ ".note x" }, { enable = { "gossip" } })
		world.options = { option(1, "Browse"), option(2, "Make this inn your home.") }
		mock.fire("GOSSIP_SHOW")
		mock.fire("CONFIRM_BINDER")
		mock.runTimers()
		assert.are.same({}, world.selected)
		G.GetBindLocation = function()
			return "Razor Hill"
		end
		ns.Context:Invalidate("bind")
		setStep({ ".hs Razor Hill" })
		mock.fire("GOSSIP_SHOW")
		assert.are.same({}, world.selected)
	end)
end)

describe("flights", function()
	local function classic(world)
		G.NumTaxiNodes = function()
			return 3
		end
		local names = { "Orgrimmar, Durotar", "Crossroads, The Barrens", "Ratchet, The Barrens" }
		local types = { "CURRENT", "REACHABLE", world.ratchetType or "REACHABLE" }
		G.TaxiNodeName = function(index)
			return names[index]
		end
		G.TaxiNodeGetType = function(index)
			return types[index]
		end
	end

	it("takes the named node by index, whatever the case", function()
		local ns, mock, world = start({ ".fly ratchet, the barrens" }, { enable = { "taxi" } })
		classic(world)
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({ 3 }, world.taken)
		noErrors(ns, mock)
	end)

	it("matches the part before the comma", function()
		local _, mock, world = start({ ".fly Crossroads" }, { enable = { "taxi" } })
		classic(world)
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({ 2 }, world.taken)
	end)

	it("takes the node ID with the C_TaxiMap shape", function()
		local ns, mock, world = start({ ".fly Ratchet" }, { enable = { "taxi" } })
		G.GetTaxiMapID = function()
			return 1414
		end
		G.C_TaxiMap = {
			GetAllTaxiNodes = function()
				return {
					{ nodeID = 11, name = "Orgrimmar, Durotar", state = 0, slotIndex = 1 },
					{ nodeID = 3201, name = "Ratchet, The Barrens", state = 1, slotIndex = 4 },
				}
			end,
		}
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({ 3201 }, world.taken)
		noErrors(ns, mock)
	end)

	it("does not take the node it stands at, an unknown node, or anything when no .fly asks", function()
		local _, mock, world, setStep = start({ ".fly Orgrimmar" }, { enable = { "taxi" } })
		classic(world)
		mock.fire("TAXIMAP_OPENED") -- the current node
		setStep({ ".fly Ratchet" })
		world.ratchetType = "NONE"
		classic(world)
		mock.fire("TAXIMAP_OPENED")
		setStep({ ".note x" })
		world.ratchetType = "REACHABLE"
		classic(world)
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({}, world.taken)
	end)

	it("is off by default and bypassed by Shift", function()
		local _, mock, world = start({ ".fly Ratchet" })
		classic(world)
		mock.fire("TAXIMAP_OPENED")
		assert.are.same({}, world.taken)
		local _, mock2, world2 = start({ ".fly Ratchet" }, { enable = { "taxi" } })
		classic(world2)
		world2.shift = true
		mock2.fire("TAXIMAP_OPENED")
		assert.are.same({}, world2.taken)
	end)
end)

describe("trainer", function()
	local function service(spellID, extra)
		local s = { spellID = spellID, type = "available", cost = 100 }
		for key, value in pairs(extra or {}) do
			s[key] = value
		end
		return s
	end

	it("buys only the listed spell", function()
		local ns, mock, world = start({ ".train 100" }, { enable = { "trainer" } })
		world.services = { service(99), service(100), service(101) }
		mock.fire("TRAINER_SHOW")
		assert.are.same({ 100 }, world.bought)
		noErrors(ns, mock)
	end)

	it("skips what is not available, and a service whose spell ID it cannot read", function()
		local _, mock, world = start({ ".train 100" }, { enable = { "trainer" } })
		world.services = {
			service(100, { type = "unavailable" }),
			service(nil, { tooltipID = 100 }),
			service(100, { type = "used" }),
		}
		mock.fire("TRAINER_SHOW")
		assert.are.same({}, world.bought)
	end)

	it("reads the spell ID from the tooltip data when the link has none", function()
		local _, mock, world = start({ ".train 100" }, { enable = { "trainer" } })
		world.services = { service(nil, { tooltipID = 100 }) }
		G.C_TooltipInfo = {
			GetTrainerService = function()
				return { id = 100 }
			end,
		}
		mock.fire("TRAINER_SHOW")
		assert.are.same({ 100 }, world.bought)
	end)

	it("respects the gold reserve", function()
		local _, mock, world = start({ ".train 100", ".train 101" }, { enable = { "trainer" } })
		world.money = 1000
		world.services = { service(100, { cost = 600 }), service(101, { cost = 600 }) }
		mock.fire("TRAINER_SHOW")
		assert.are.same({ 100 }, world.bought) -- the second does not fit
	end)

	it("never spends below a configured reserve", function()
		local ns, mock, world = start({ ".train 100" }, { enable = { "trainer" } })
		ns.char.automation.goldReserve = 500
		world.money = 1000
		world.services = { service(100, { cost = 600 }) }
		mock.fire("TRAINER_SHOW")
		assert.are.same({}, world.bought)
		world.money = 1100
		mock.fire("TRAINER_SHOW")
		assert.are.same({ 100 }, world.bought)
	end)

	it("buys the class module's spells at or below the player's level for .train class", function()
		local ns, mock, world = start({ ".train class" }, {
			enable = { "trainer" },
			setup = function(w)
				w.level = 4
			end,
		})
		assert.is_true(
			ns.Classes:Register("HUNTER", { trainerSpells = { [1] = { 10 }, [4] = { 11, 12 }, [6] = { 13 } } })
		)
		world.services = { service(10), service(11), service(13), service(77) }
		mock.fire("TRAINER_SHOW")
		table.sort(world.bought)
		assert.are.same({ 10, 11 }, world.bought) -- 12 is not offered, 13 is above level 4, 77 is not listed
	end)

	it("buys nothing for .train class when the class module lists nothing", function()
		local ns, mock, world = start({ ".train class" }, { enable = { "trainer" } })
		assert.is_true(ns.Classes:Register("HUNTER", { trainerSpells = {} }))
		world.services = { service(10), service(11) }
		mock.fire("TRAINER_SHOW")
		assert.are.same({}, world.bought)
	end)

	it("buys a profession's rank spells for .trainprof, and nothing when its module lists none", function()
		local ns, mock, world = start({ ".trainprof skinning" }, { enable = { "trainer" } })
		world.services = { service(900), service(901) }
		assert.is_true(
			ns.Professions:Register("skinning", { skillLine = 393, primary = true, gathering = true, ranks = { 75 } })
		)
		mock.fire("TRAINER_SHOW")
		assert.are.same({}, world.bought)
		assert.is_true(ns.Professions:Register("skinning", {
			skillLine = 393,
			primary = true,
			gathering = true,
			ranks = { 75 },
			rankSpells = { 900 },
		}))
		mock.fire("TRAINER_SHOW")
		assert.are.same({ 900 }, world.bought)
	end)

	it("does nothing without a training step, while off, or with Shift held", function()
		local _, mock, world, setStep = start({ ".note x" }, { enable = { "trainer" } })
		world.services = { service(100) }
		mock.fire("TRAINER_SHOW")
		setStep({ ".train 100" })
		world.shift = true
		mock.fire("TRAINER_SHOW")
		assert.are.same({}, world.bought)
		local _, mock2, world2 = start({ ".train 100" })
		world2.services = { service(100) }
		mock2.fire("TRAINER_SHOW")
		assert.are.same({}, world2.bought)
	end)
end)

describe("vendor", function()
	it("buys what is missing to reach the count, in chunks of the vendor's maximum", function()
		local ns, mock, world = start({ ".buy 2512,200" }, { enable = { "vendor" } })
		world.bags[2512] = 150
		world.slots = { { itemID = 9999, price = 1 }, { itemID = 2512, price = 2 } }
		mock.fire("MERCHANT_SHOW")
		assert.are.same({ { 2512, 20 }, { 2512, 20 }, { 2512, 10 } }, world.purchases)
		noErrors(ns, mock)
	end)

	it("buys nothing when the bags already hold enough, and nothing the step did not list", function()
		local _, mock, world = start({ ".buy 2512,100" }, { enable = { "vendor" } })
		world.bags[2512] = 100
		world.slots = { { itemID = 2512, price = 2 }, { itemID = 4540, price = 1 } }
		mock.fire("MERCHANT_SHOW")
		assert.are.same({}, world.purchases)
	end)

	it("counts bundles for a vendor that sells in stacks", function()
		local _, mock, world = start({ ".buy 2512,50" }, { enable = { "vendor" } })
		world.slots = { { itemID = 2512, price = 10, stack = 5 } }
		mock.fire("MERCHANT_SHOW")
		assert.are.same({ { 2512, 10 } }, world.purchases)
	end)

	it("buys no more than the gold pays for, the reserve and the stock allow", function()
		local ns, mock, world = start({ ".buy 2512,200" }, { enable = { "vendor" } })
		world.money = 50
		world.slots = { { itemID = 2512, price = 2 } }
		mock.fire("MERCHANT_SHOW")
		assert.are.same({ { 2512, 20 }, { 2512, 5 } }, world.purchases)
		world.purchases = {}
		ns.char.automation.goldReserve = 30
		mock.fire("MERCHANT_SHOW")
		assert.are.same({ { 2512, 10 } }, world.purchases)
		world.purchases = {}
		ns.char.automation.goldReserve = 0
		world.money = 100000
		world.slots[1].available = 3
		mock.fire("MERCHANT_SHOW")
		assert.are.same({ { 2512, 3 } }, world.purchases)
	end)

	it("skips items that cost something other than gold", function()
		local _, mock, world = start({ ".buy 2512,10" }, { enable = { "vendor" } })
		world.slots = { { itemID = 2512, price = 2, extended = true } }
		mock.fire("MERCHANT_SHOW")
		assert.are.same({}, world.purchases)
	end)

	it("does nothing while off, without a .buy step, or with Shift held", function()
		local _, mock, world = start({ ".buy 2512,10" })
		world.slots = { { itemID = 2512, price = 2 } }
		mock.fire("MERCHANT_SHOW")
		local _, mock2, world2 = start({ ".note x" }, { enable = { "vendor" } })
		world2.slots = { { itemID = 2512, price = 2 } }
		mock2.fire("MERCHANT_SHOW")
		local _, mock3, world3 = start({ ".buy 2512,10" }, { enable = { "vendor" } })
		world3.shift = true
		world3.slots = { { itemID = 2512, price = 2 } }
		mock3.fire("MERCHANT_SHOW")
		assert.are.same({}, world.purchases)
		assert.are.same({}, world2.purchases)
		assert.are.same({}, world3.purchases)
	end)
end)
