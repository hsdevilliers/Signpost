-- Test doubles for tests/directives_spec.lua and tests/conditions_spec.lua: a scriptable stand-in for ns.Context (its
-- docs/ENGINE.md API), stubs for the registries other tracks build (ns.Professions, ns.Classes, ns.Progress), and steps
-- built from directive lines the way Engine/Parser.lua builds them.
local addon = dofile("tests/helpers/addon.lua")

local M = {}

M.FILES = { "Engine/Directives.lua", "Engine/Conditions.lua" }

local function spot(map, x, y)
	return string.format("%s:%s:%s", tostring(map), tostring(x), tostring(y))
end

-- A fake ns.Context. Fields (all optional): log, completed, ready = { [questID] = true }; objectives = { [questID] =
-- { { text, finished, have, need } } }; spells = { [spellID] = true }; skills = { [skillLine] = { rank, max } };
-- items = { [itemID] = count }; level; position = { map = id, x, y }; distances = { ["map:x:y"] = yards } (or :Near).
function M.context(fields)
	local context = {
		log = {},
		completed = {},
		ready = {},
		objectives = {},
		spells = {},
		skills = {},
		items = {},
		level = 1,
		distances = {},
	}
	for key, value in pairs(fields or {}) do
		context[key] = value
	end
	function context:QuestInLog(questID)
		return self.log[questID] == true
	end
	function context:QuestCompleted(questID)
		return self.completed[questID] == true
	end
	function context:QuestReady(questID)
		return self.ready[questID] == true
	end
	function context:Objectives(questID)
		return self.objectives[questID] or {}
	end
	function context:SpellKnown(spellID)
		return self.spells[spellID] == true
	end
	function context:Skill(skillLine)
		local skill = self.skills[skillLine]
		if skill then
			return skill[1], skill[2]
		end
	end
	function context:ItemCount(itemID)
		return self.items[itemID] or 0
	end
	function context:Level()
		return self.level
	end
	function context:Position()
		return self.position
	end
	function context:Distance(map, x, y)
		return self.distances[spot(map, x, y)]
	end
	-- test helper: the player is `yards` away from map,x,y
	function context:Near(map, x, y, yards)
		self.distances[spot(map, x, y)] = yards
	end
	return context
end

-- Loads the addon with the two engine files. opts.pack becomes the data pack (Signpost_Data, schema 1);
-- opts.professions = { [key] = module }, opts.classes = { [classFile] = module } and opts.guide (for
-- ns.Progress:Guide()) stub the registries; opts.before runs like addon.load's.
function M.load(opts)
	opts = opts or {}
	local ns, mock = addon.load({
		extra = M.FILES,
		before = function(m)
			if opts.pack then
				local pack = { _meta = { schema = 1, source = "test" } }
				for key, value in pairs(opts.pack) do
					pack[key] = value
				end
				addon.G.Signpost_Data = pack
			end
			if opts.before then
				opts.before(m)
			end
		end,
	})
	local professions, classes = opts.professions or {}, opts.classes or {}
	ns.Professions = {
		Get = function(_, key)
			return professions[key]
		end,
	}
	ns.Classes = {
		Get = function(_, classFile)
			return classes[classFile]
		end,
	}
	if opts.guide then
		ns.Progress = {
			Guide = function()
				return opts.guide
			end,
		}
	end
	return ns, mock
end

-- A step as docs/ENGINE.md describes it, from directive lines: .sticky lines go to step.sticky unwrapped (the inner
-- directive, carrying the line's ">>" text), .optional lines stay in place and also fill step.optional.
function M.step(ns, lines, id)
	local step = { id = id or "test:1", directives = {}, sticky = {}, optional = {} }
	for i, line in ipairs(lines) do
		local directive = assert(ns.Directives:ParseLine(line, { source = "test", line = i }))
		if directive.name == "sticky" then
			local inner = directive.args.directive
			inner.text = inner.text or directive.text
			step.sticky[#step.sticky + 1] = inner
		else
			step.directives[#step.directives + 1] = directive
			if directive.name == "optional" then
				step.optional[directive.args.questID] = true
			end
		end
	end
	return step
end

return M
