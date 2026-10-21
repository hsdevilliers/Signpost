-- Scriptable trainer and trade skill windows for the profession recorder specs (Core/LearnProfessions.lua). install(G,
-- opts) sets the client functions the recorder reads and returns the `win` table the spec edits; uninstall(G) removes
-- them again so no other spec sees them. Run it after tests/mocks/learn.lua's install (that mock holds the unit being
-- talked to and the position); it adds to and, for the trainer functions, replaces the ones that mock sets.
--
-- opts.trainer: which trainer functions exist: "global" (the Classic shape: GetTrainerServiceInfo answers name, rank
--   text, type), "namespaced" (C_TrainerUI.<name>, GetTrainerServiceInfo answers one table), "both", or "none".
--   Default "global". opts.tooltip == false leaves C_TooltipInfo out.
-- opts.trade: which trade skill functions exist: "modern" (C_TradeSkillUI.GetAllRecipeIDs and friends), "classic" (the
--   global GetNumTradeSkills and friends), "both" or "none". Default "modern". opts.listing == false leaves out the
--   client's profession list (C_TradeSkillUI.GetProfessionSkillLineID and friends).
local M = {}

local GLOBALS = {
	"C_TooltipInfo",
	"C_TradeSkillUI",
	"C_TrainerUI",
	"Enum",
	"GetNumTradeSkills",
	"GetNumTrainerServices",
	"GetTradeSkillInfo",
	"GetTradeSkillItemLink",
	"GetTradeSkillLine",
	"GetTradeSkillNumReagents",
	"GetTradeSkillReagentInfo",
	"GetTradeSkillReagentItemLink",
	"GetTradeSkillRecipeLink",
	"GetTrainerServiceCost",
	"GetTrainerServiceInfo",
	"GetTrainerServiceItemLink",
	"GetTrainerServiceLevelReq",
	"GetTrainerServiceSkillLine",
	"GetTrainerServiceSkillReq",
	"IsTradeSkillGuild",
	"IsTradeSkillLinked",
}

-- Enum.TradeskillRelativeDifficulty on the Mainline API
local DIFFICULTY_NUMBER = { optimal = 0, medium = 1, easy = 2, trivial = 3 }

function M.spellLink(id, name)
	return string.format("|cff71d5ff|Hspell:%d|h[%s]|h|r", id, name or "Spell")
end

function M.enchantLink(id, name)
	return string.format("|cffffd000|Henchant:%d|h[%s]|h|r", id, name or "Recipe")
end

function M.itemLink(id, name)
	return string.format("|cffffffff|Hitem:%d::::::::1:::::::|h[%s]|h|r", id, name or "Item")
end

function M.install(G, opts)
	opts = opts or {}
	local trainerShape, tradeShape = opts.trainer or "global", opts.trade or "modern"
	-- trainer.services: { name, rank, kind ("available" | "unavailable" | "used" | "header"), cost, level, line (the
	-- profession's name), need = { profession name, skill }, spell, link }
	-- trade: the open trade skill window. recipes: { id, name, difficulty ("optimal" | "medium" | "easy" | "trivial"),
	-- learned, item, reagents = { { item, count } }, header }; base and child: the modern profession info tables.
	local win = {
		trainer = { services = {} },
		trade = {
			line = 100,
			skill = 40,
			max = 75,
			recipes = {},
			linked = false,
			guild = false,
			base = nil,
			child = nil,
		},
		-- the client's profession list: skill line -> name (Enum.Profession order: Alpha = 1, Beta = 2)
		professions = { [100] = "Alpha", [200] = "Beta" },
		children = { [2937] = 100 }, -- child skill line -> the profession it belongs to
	}
	win.trade.base = { professionID = 100, skillLevel = 40, maxSkillLevel = 75 }

	G.Enum = G.Enum or {}
	G.Enum.Profession = { Alpha = 1, Beta = 2 }
	G.Enum.TooltipDataType = G.Enum.TooltipDataType or { Spell = 1 }
	G.Enum.TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }
	G.Enum.CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2 }

	-- the client's profession list
	G.C_TradeSkillUI = {}
	if opts.listing ~= false then
		G.C_TradeSkillUI.GetProfessionSkillLineID = function(enum)
			return enum * 100
		end
		G.C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(line)
			return {
				professionID = line,
				professionName = win.professions[line] or ("Child " .. line),
				parentProfessionID = win.children[line] or 0,
			}
		end
		G.C_TradeSkillUI.GetAllProfessionTradeSkillLines = function()
			return { 100, 200, 2937 }
		end
	end

	-- trainer ---------------------------------------------------------------------------------------------------
	local function service(index)
		return win.trainer.services[index]
	end
	local trainer = {
		GetNumTrainerServices = function()
			return #win.trainer.services
		end,
		GetTrainerServiceCost = function(index)
			local s = service(index)
			return s and s.cost
		end,
		GetTrainerServiceLevelReq = function(index)
			local s = service(index)
			return s and s.level
		end,
		GetTrainerServiceSkillLine = function(index)
			local s = service(index)
			return s and s.line
		end,
		GetTrainerServiceSkillReq = function(index)
			local s = service(index)
			if s and s.need then
				return s.need[1], s.need[2], true
			end
		end,
		GetTrainerServiceItemLink = function(index)
			local s = service(index)
			return s and s.link
		end,
	}
	local function globalInfo(index)
		local s = service(index)
		if s then
			return s.name, s.rank, s.kind or "available", false
		end
	end
	local function tableInfo(index)
		local s = service(index)
		if s then
			return { name = s.name, subText = s.rank, serviceType = s.kind or "available" }
		end
	end
	-- tests/mocks/learn.lua installs two of the trainer globals: only the shapes asked for may stay
	for name in pairs(trainer) do
		G[name] = nil
	end
	G.GetTrainerServiceInfo = nil
	if trainerShape == "global" or trainerShape == "both" then
		for name, fn in pairs(trainer) do
			G[name] = fn
		end
		G.GetTrainerServiceInfo = globalInfo
	end
	if trainerShape == "namespaced" or trainerShape == "both" then
		G.C_TrainerUI = { GetTrainerServiceInfo = tableInfo }
		for name, fn in pairs(trainer) do
			G.C_TrainerUI[name] = fn
		end
	end
	if opts.tooltip ~= false then
		G.C_TooltipInfo = {
			GetTrainerService = function(index)
				local s = service(index)
				if s and s.spell then
					return { type = 1, id = s.spell }
				end
			end,
		}
	else
		G.C_TooltipInfo = nil
	end

	-- trade skill ---------------------------------------------------------------------------------------------------
	local function recipe(id)
		for _, r in ipairs(win.trade.recipes) do
			if r.id == id then
				return r
			end
		end
	end
	if tradeShape == "modern" or tradeShape == "both" then
		local ui = G.C_TradeSkillUI
		ui.GetAllRecipeIDs = function()
			local ids = {}
			for _, r in ipairs(win.trade.recipes) do
				if not r.header then
					ids[#ids + 1] = r.id
				end
			end
			return ids
		end
		ui.GetRecipeInfo = function(id)
			local r = recipe(id)
			if r then
				return {
					recipeID = id,
					name = r.name,
					learned = r.learned ~= false,
					relativeDifficulty = r.difficulty and DIFFICULTY_NUMBER[r.difficulty] or nil,
				}
			end
		end
		ui.GetRecipeSchematic = function(id)
			local r = recipe(id)
			if r then
				local slots = {}
				for _, reagent in ipairs(r.reagents or {}) do
					slots[#slots + 1] =
						{ reagentType = 1, reagents = { { itemID = reagent.item } }, quantityRequired = reagent.count }
				end
				return { recipeID = id, name = r.name, outputItemID = r.item, reagentSlotSchematics = slots }
			end
		end
		ui.GetBaseProfessionInfo = function()
			return win.trade.base
		end
		ui.GetChildProfessionInfo = function()
			return win.trade.child
		end
		ui.IsTradeSkillLinked = function()
			return win.trade.linked
		end
		ui.IsTradeSkillGuild = function()
			return win.trade.guild
		end
	end
	if tradeShape == "classic" or tradeShape == "both" then
		G.GetTradeSkillLine = function()
			return win.professions[win.trade.line], win.trade.skill, win.trade.max
		end
		G.GetNumTradeSkills = function()
			return #win.trade.recipes
		end
		G.GetTradeSkillInfo = function(index)
			local r = win.trade.recipes[index]
			if r then
				return r.name, r.header and "header" or r.difficulty, 1, false
			end
		end
		G.GetTradeSkillRecipeLink = function(index)
			local r = win.trade.recipes[index]
			return r and M.enchantLink(r.id, r.name)
		end
		G.GetTradeSkillItemLink = function(index)
			local r = win.trade.recipes[index]
			return r and r.item and M.itemLink(r.item)
		end
		G.GetTradeSkillNumReagents = function(index)
			local r = win.trade.recipes[index]
			return r and #(r.reagents or {}) or 0
		end
		G.GetTradeSkillReagentInfo = function(index, reagent)
			local g = win.trade.recipes[index].reagents[reagent]
			return "Reagent " .. g.item, 134000, g.count, 0
		end
		G.GetTradeSkillReagentItemLink = function(index, reagent)
			return M.itemLink(win.trade.recipes[index].reagents[reagent].item)
		end
		G.IsTradeSkillLinked = function()
			return win.trade.linked
		end
		G.IsTradeSkillGuild = function()
			return win.trade.guild
		end
	end
	return win
end

function M.uninstall(G)
	for _, name in ipairs(GLOBALS) do
		G[name] = nil
	end
end

return M
