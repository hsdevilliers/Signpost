-- Stand-ins for the modules Engine/Progress.lua calls — ns.Guides, ns.Parser, ns.Professions, ns.Conditions and
-- ns.Context — in the shapes of docs/ENGINE.md (the real ones are built in parallel), plus a small guide builder.
local M = {}

-- Directive definitions over a scriptable world (it is also ns.Context): "flag", "quest" and "trainprof" are
-- satisfied by world.flags[key]; "count n" needs world.count to rise by n after its step became current; "note" is
-- not completable; "todo" is completable and never satisfied.
local function definitions()
	local function flag(args, context)
		return context.flags[args.key] == true
	end
	return {
		flag = { kind = "misc", isSatisfied = flag },
		quest = { kind = "quest", isSatisfied = flag },
		trainprof = { kind = "profession", isSatisfied = flag },
		note = { kind = "misc" },
		todo = { kind = "misc", completable = true },
		count = {
			kind = "misc",
			onStart = function(_, context, state)
				state.base = context.count
				state.starts = (state.starts or 0) + 1
			end,
			isSatisfied = function(args, context, state)
				return context.count - (state.base or 0) >= args.n
			end,
		},
	}
end

local function inPlan(plan, key)
	for _, list in ipairs({ plan and plan.primary or {}, plan and plan.secondary or {} }) do
		for _, item in ipairs(list) do
			if item == key then
				return true
			end
		end
	end
	return false
end

-- def = { id, name, headers, chapters = { { id, name, levels, dungeon, steps = { spec, ... } }, ... } }. A step spec
-- lists directive lines ("quest a", "count 2", "sticky flag s"); { track = key, n = 3, ... } makes it step 3 of that
-- profession track, present only when the plan has the track (standing in for track merging). Line numbers count
-- every spec line whether or not it is present, as in a real source text.
function M.build(def, plan)
	local defs = definitions()
	local guide = {
		id = def.id,
		name = def.name,
		def = def,
		headers = def.headers or {},
		chapters = {},
		steps = {},
		byId = {},
		skipQuests = {},
		errors = {},
	}
	for c, chapterSpec in ipairs(def.chapters) do
		local chapter = {
			id = chapterSpec.id,
			name = chapterSpec.name,
			levels = chapterSpec.levels or { 1, 60 },
			dungeon = chapterSpec.dungeon == true,
		}
		guide.chapters[c] = chapter
		local routeCount, line = 0, 0
		for _, spec in ipairs(chapterSpec.steps) do
			line = line + 1
			local id, source
			if spec.track then
				source = "track:" .. spec.track
				id = source .. ":" .. spec.n
			else
				routeCount = routeCount + 1
				source = chapter.id
				id = source .. ":" .. routeCount
			end
			local step = {
				id = id,
				chapter = c,
				source = source,
				line = line,
				directives = {},
				sticky = {},
				optional = {},
				track = spec.track,
			}
			for _, text in ipairs(spec) do
				line = line + 1
				local sticky, name, arg = false, text:match("^(%S+)%s*(.-)$")
				if name == "sticky" then
					sticky = true
					name, arg = arg:match("^(%S+)%s*(.-)$")
				end
				local directive =
					{ name = name, args = { key = arg, n = tonumber(arg) }, line = line, def = defs[name] }
				table.insert(sticky and step.sticky or step.directives, directive)
			end
			if not spec.track or inPlan(plan, spec.track) then
				step.index = #guide.steps + 1
				guide.steps[step.index] = step
				guide.byId[id] = step
				chapter.first = chapter.first or step.index
				chapter.last = step.index
			end
		end
	end
	return guide
end

local function removeKey(list, key)
	for i = #list, 1, -1 do
		if list[i] == key then
			table.remove(list, i)
		end
	end
end

-- Installs the stand-ins on ns. opts.def (the selected guide definition, or nil for none), opts.plan, opts.flags,
-- opts.count. Returns the world they read and record into.
function M.install(ns, opts)
	local world = {
		flags = opts.flags or {},
		count = opts.count or 0,
		plan = opts.plan or { primary = {}, secondary = {}, declined = {} },
		parses = {},
		planCalls = {},
	}
	local selected = opts.def
	ns.Context = world
	ns.Guides = {
		Selected = function()
			return selected
		end,
	}
	ns.Parser = {
		Headers = function(_, guideDef)
			return guideDef.headers
		end,
		ParseGuide = function(_, guideDef, parseOpts)
			world.parses[#world.parses + 1] = parseOpts
			return M.build(guideDef, parseOpts.plan)
		end,
	}
	ns.Professions = {
		Plan = function(_, suggestions)
			world.planCalls[#world.planCalls + 1] = suggestions
			return world.plan
		end,
		Decline = function(_, key)
			removeKey(world.plan.primary, key)
			removeKey(world.plan.secondary, key)
			world.plan.declined[key] = true
			ns.Events:Fire("PROFESSION_PLAN_CHANGED", world.plan)
		end,
		Restore = function(_, key)
			world.plan.declined[key] = nil
			table.insert(world.plan.primary, key)
			ns.Events:Fire("PROFESSION_PLAN_CHANGED", world.plan)
		end,
	}
	-- GUIDE-FORMAT: complete when every completable directive is satisfied; without one, only the player's `>`.
	ns.Conditions = {
		IsComplete = function(_, step, context, states)
			local any = false
			for i, directive in ipairs(step.directives) do
				local def = directive.def
				local completable = def.completable
				if completable == nil then
					completable = def.isSatisfied ~= nil
				end
				if completable then
					any = true
					if not (def.isSatisfied and def.isSatisfied(directive.args, context, states[i])) then
						return false
					end
				end
			end
			return any
		end,
		Describe = function(_, step)
			local lines = {}
			for _, directive in ipairs(step.directives) do
				lines[#lines + 1] = directive.name .. " " .. directive.args.key
			end
			return lines
		end,
	}
	return world
end

return M
