-- UI/StepFrame.lua and UI/Pins.lua against stand-ins for the engine (ns.Progress, ns.Conditions, ns.Context, ns.Travel
-- in the shapes of docs/ENGINE.md) and the UI mock in tests/mocks/ui.lua.
local addon = dofile("tests/helpers/addon.lua")
local uiMock = dofile("tests/mocks/ui.lua")
-- Client globals are set through G, the real global table (see tests/helpers/addon.lua).
local G = addon.G
local state = uiMock.state

local UI_FILES = { "UI/StepFrame.lua", "UI/Pins.lua" }
local ONGOING = "|cffffd100Ongoing:|r "
local DONE = "|cff40d040[x]|r " -- the done mark of a quest line, as the Journal's route list has it
local TODO = "[ ] "

-- A two-chapter guide in the shape of docs/ENGINE.md "Data shapes".
local function newGuide()
	local steps = {
		{ id = "valley:1", chapter = 1, directives = { { name = "accept", args = { questID = 4641 } } } },
		{ id = "valley:2", chapter = 1, directives = { { name = "complete", args = { questID = 787 } } } },
		{
			id = "valley:3",
			chapter = 1,
			directives = { { name = "use", args = { itemID = 5070 } }, { name = "complete", args = { questID = 788 } } },
		},
		{ id = "barrens:1", chapter = 2, directives = { { name = "path", args = {} }, { name = "zone", args = {} } } },
		{ id = "barrens:2", chapter = 2, directives = { { name = "use", args = { itemID = 6000 } } } },
	}
	local guide = {
		id = "test-guide",
		name = "Test Guide",
		chapters = {
			{ id = "valley", name = "Valley of Trials", levels = { 1, 6 }, first = 1, last = 3 },
			{ id = "barrens", name = "The Barrens", levels = { 12, 20 }, first = 4, last = 5 },
		},
		steps = steps,
		byId = {},
	}
	for i, step in ipairs(steps) do
		step.index, step.sticky = i, {}
		guide.byId[step.id] = step
	end
	return guide
end

local function newEngine(guide)
	return {
		guide = guide,
		index = 1,
		sticky = {},
		lines = {},
		info = {}, -- the second result of Conditions:Describe: one { name, done, ... } per line
		optional = {}, -- [stepId] = what Conditions:OptionalOnly says of an optional-only step
		targets = {},
		items = {},
		transport = {},
		states = {},
		calls = {},
	}
end

-- The engine modules other tracks build in parallel, reduced to the documented calls.
local function stubEngine(ns, engine)
	ns.Progress = {
		Guide = function()
			return engine.guide
		end,
		Current = function()
			local step = engine.guide and engine.guide.steps[engine.index]
			if step then
				return step, engine.index
			end
		end,
		Sticky = function()
			return engine.sticky
		end,
		State = function(_, stepId)
			engine.states[stepId] = engine.states[stepId] or {}
			return engine.states[stepId]
		end,
	}
	for _, method in ipairs({ "Next", "Back", "Skip" }) do
		ns.Progress[method] = function()
			engine.calls[#engine.calls + 1] = method
		end
	end
	ns.Conditions = {
		Describe = function(_, step)
			return engine.lines[step.id] or {}, engine.info[step.id]
		end,
		OptionalOnly = function(_, step)
			return engine.optional[step.id]
		end,
		Targets = function(_, step, _, states)
			engine.statesSeen = engine.statesSeen or {}
			engine.statesSeen[step.id] = states
			return engine.targets[step.id] or {}
		end,
	}
	ns.Context = {
		Distance = function(_, map, x, y)
			engine.asked = { map, x, y }
			return engine.distance
		end,
		ItemCount = function(_, itemID)
			return engine.items[itemID] or 0
		end,
		Position = function()
			return nil
		end,
	}
	ns.Travel = {
		TransportState = function(_, stepId)
			return engine.transport[stepId] or "waiting"
		end,
	}
end

-- opts.mock: options for tests/mocks/ui.lua; opts.saved: SignpostDB from an earlier session; opts.guide = false: no
-- guide; opts.setup(engine, ui): runs before login.
local function load(opts)
	opts = opts or {}
	local ui
	local ns, mock = addon.load({
		login = false,
		extra = UI_FILES,
		before = function(m)
			ui = uiMock.install(m, opts.mock)
			if opts.saved then
				G.SignpostDB = opts.saved
			end
		end,
	})
	local engine = newEngine(opts.guide ~= false and newGuide() or nil)
	if opts.setup then
		opts.setup(engine, ui)
	end
	stubEngine(ns, engine)
	-- These specs run on stand-ins for the engine, which the real Journal (UI/Journal.lua, covered by journal_spec.lua)
	-- cannot read: the step frame's and the pins' Journal hooks are tested against a Journal the spec installs itself.
	ns.Journal = nil
	mock.fire("ADDON_LOADED", "Signpost")
	mock.fire("PLAYER_LOGIN")
	return ns, mock, ui, engine
end

local function go(ns, engine, index)
	engine.index = index
	ns.Events:Fire("STEP_CHANGED", engine.guide.steps[index], index, "manual")
end

local function noErrors(ns, mock)
	assert.are.same({}, mock.errors)
	assert.are.same({}, ns.db.errors)
end

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

-- Active pins of one kind ("minimap" or "world") as { pin, entry } sorted by kind, then waypoint number.
local function pinsOf(ns, where)
	local list = {}
	for pin, entry in pairs(ns.Pins[where]) do
		list[#list + 1] = { pin = pin, entry = entry, kind = entry.target.kind, index = entry.target.index or 0 }
	end
	table.sort(list, function(a, b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return a.index < b.index
	end)
	return list
end

local function slash(text)
	SlashCmdList.SIGNPOST(text)
end

describe("step frame", function()
	after_each(uiMock.uninstall)

	it("renders the current step: chapter header, lines, icon and buttons", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["valley:2"] = { "Kill Mottled Boars", { text = "Mottled Boar slain: 6/10" } }
			end,
		})
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		assert.is_true(frame:IsShown())
		assert.are.equal("Valley of Trials · step 2/3", frame.title:GetText())
		assert.are.equal("Kill Mottled Boars\nMottled Boar slain: 6/10", frame.body:GetText())
		assert.are.equal(10, frame.body:GetMaxLines())
		assert.is_true(frame.body:GetWordWrap())
		assert.are.equal("GameFontNormal", state(frame.title).template)
		assert.are.equal("GameFontHighlight", state(frame.body).template)
		assert.are.equal("BackdropTemplate", state(frame).template)
		assert.are.equal("Interface\\DialogFrame\\UI-DialogBox-Border", frame:GetBackdrop().edgeFile)
		-- .complete: the objective icon; its Waypoint-MapPin atlas is not on the probe list, so the gossip file is used
		assert.are.equal("Interface\\GossipFrame\\ActiveQuestIcon", frame.icon:GetTexture())
		for _, button in ipairs({ frame.back, frame.next, frame.skip }) do
			assert.are.equal("UIPanelButtonTemplate", state(button).template)
		end
		assert.are.equal(">", frame.next:GetText())
		assert.is_true(frame:GetHeight() > 0)
		noErrors(ns, mock)
	end)

	it("follows STEP_CHANGED into the next chapter", function()
		local ns, mock, _, engine = load()
		local frame = ns.StepFrame.frame
		assert.are.equal("Valley of Trials · step 1/3", frame.title:GetText())
		assert.is_false(frame.back:IsEnabled())
		assert.are.equal("QuestNormal", frame.icon:GetAtlas())
		go(ns, engine, 4)
		assert.are.equal("The Barrens · step 1/2", frame.title:GetText())
		assert.is_true(frame.back:IsEnabled())
		assert.are.equal("TaxiNode_Neutral", frame.icon:GetAtlas())
		noErrors(ns, mock)
	end)

	it("counts in the guide when a chapter does not hold the step", function()
		local ns, _, _, engine = load({
			setup = function(engine)
				engine.guide.chapters[2].first = nil
			end,
		})
		go(ns, engine, 5)
		assert.are.equal("The Barrens · step 5/5", ns.StepFrame.frame.title:GetText())
	end)

	it("moves with the < > and Skip buttons", function()
		local ns, mock, _, engine = load()
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		frame.back:Click()
		frame.next:Click()
		frame.skip:Click()
		assert.are.same({ "Back", "Next", "Skip" }, engine.calls)
		noErrors(ns, mock)
	end)

	it("adds the sticky lines once, after the step's own lines", function()
		local sticky = {
			id = "track:a:2",
			sticky = {
				{ name = "skill", text = "Skin everything until 50" },
				{
					name = "collect",
					args = { count = 5 },
					def = {
						describe = function(args)
							return "Collect " .. args.count .. " leather"
						end,
					},
				},
				{ name = "note", text = "Kill Mottled Boars" },
			},
		}
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["valley:2"] = { "Kill Mottled Boars" }
				engine.guide.steps[2].sticky = { { name = "level", text = ">> Reach level 5" } }
				engine.sticky = { sticky, sticky }
			end,
		})
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		assert.are.equal(
			ONGOING .. "Reach level 5\n" .. ONGOING .. "Skin everything until 50\n" .. ONGOING .. "Collect 5 leather",
			frame.sticky:GetText()
		)
		assert.is_true(frame.sticky:IsShown())
		noErrors(ns, mock)
	end)

	it("starts every quest line (accept, complete, turn in) with its done mark and no other line", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["valley:2"] = {
					'Complete "Cutting Teeth"',
					'Complete "Sarkoth"',
					'Accept "Sting of the Scorpid"',
					'Turn in "Lazy Peons"',
					"Up the ramp.",
				}
				engine.info["valley:2"] = {
					{ name = "complete", directive = 1, done = true },
					{ name = "complete", directive = 2, done = false },
					{ name = "accept", directive = 3, done = true },
					{ name = "turnin", directive = 4, done = false },
					{ name = "note", directive = 5 },
				}
			end,
		})
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		assert.are.equal(
			DONE
				.. 'Complete "Cutting Teeth"\n'
				.. TODO
				.. 'Complete "Sarkoth"\n'
				.. DONE
				.. 'Accept "Sting of the Scorpid"\n'
				.. TODO
				.. 'Turn in "Lazy Peons"\nUp the ramp.',
			frame.body:GetText()
		)
		-- the marks follow the quest log
		engine.info["valley:2"][2].done = true
		engine.info["valley:2"][4].done = true
		ns.Events:Fire("CONTEXT_CHANGED", "quests")
		mock.runTimers()
		assert.are.equal(
			DONE
				.. 'Complete "Cutting Teeth"\n'
				.. DONE
				.. 'Complete "Sarkoth"\n'
				.. DONE
				.. 'Accept "Sting of the Scorpid"\n'
				.. DONE
				.. 'Turn in "Lazy Peons"\nUp the ramp.',
			frame.body:GetText()
		)
		noErrors(ns, mock)
	end)

	it("leaves the lines of a step that is not about quests as they are, though Describe says they are done", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["barrens:1"] = {
					"Train your class spells",
					"Train Spell #1494",
					"Buy Item #4540 (3/5)",
					"Raise skinning to 75 (now 40)",
					"Reach level 5",
					"Craft Spell #2152 (1/3)",
					"Go to Ratchet 63.9, 38.6",
					"To do: pick a profession",
				}
				engine.info["barrens:1"] = {}
				for i, name in ipairs({ "train", "train", "buy", "skill", "level", "craft", "goto", "todo" }) do
					engine.info["barrens:1"][i] = { name = name, directive = i, done = i % 2 == 0 }
				end
			end,
		})
		go(ns, engine, 4)
		assert.are.equal(
			"Train your class spells\nTrain Spell #1494\nBuy Item #4540 (3/5)\nRaise skinning to 75 (now 40)\n"
				.. "Reach level 5\nCraft Spell #2152 (1/3)\nGo to Ratchet 63.9, 38.6\nTo do: pick a profession",
			ns.StepFrame.frame.body:GetText()
		)
		noErrors(ns, mock)
	end)

	it("lists only the lines of the quests it is asked for, for a pin's tooltip: no quest, every line", function()
		local ns, _, _, engine = load({
			setup = function(engine)
				engine.lines["valley:2"] =
					{ 'Accept "A"', 'Turn in "B"', 'Accept "C"', "Reach level 5", "Up the ramp." }
				engine.info["valley:2"] = {
					{ name = "accept", directive = 1, quest = 101, done = false },
					{ name = "turnin", directive = 2, quest = 102, done = true },
					{ name = "accept", directive = 3, quest = 103, done = false },
					{ name = "level", directive = 4, done = false },
					{ name = "note", directive = 5 },
				}
			end,
		})
		local step = engine.guide.steps[2]
		assert.are.same(
			{ TODO .. 'Accept "A"', DONE .. 'Turn in "B"', TODO .. 'Accept "C"', "Reach level 5", "Up the ramp." },
			ns.StepFrame.DescribeLines(step)
		)
		assert.are.same(
			{ TODO .. 'Accept "A"', "Reach level 5", "Up the ramp." },
			ns.StepFrame.DescribeLines(step, { [101] = true })
		)
		assert.are.same(
			{ DONE .. 'Turn in "B"', TODO .. 'Accept "C"', "Reach level 5", "Up the ramp." },
			ns.StepFrame.DescribeLines(step, { [102] = true, [103] = true })
		)
		-- what Progress:Current() hands over (the step, then its index) is no filter
		assert.are.equal(5, #ns.StepFrame.DescribeLines(step, 2))
	end)

	it("lists all the quests of a step: five read like one, each with its mark and no counters", function()
		local lines, info = {}, {}
		for i = 1, 5 do
			lines[i] = string.format('Complete "Quest %d"', i)
			info[i] = { name = "complete", directive = i, done = i % 2 == 0 }
		end
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["valley:2"], engine.info["valley:2"] = lines, info
			end,
		})
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		assert.are.equal(
			TODO
				.. 'Complete "Quest 1"\n'
				.. DONE
				.. 'Complete "Quest 2"\n'
				.. TODO
				.. 'Complete "Quest 3"\n'
				.. DONE
				.. 'Complete "Quest 4"\n'
				.. TODO
				.. 'Complete "Quest 5"',
			frame.body:GetText()
		)
		assert.is_true(frame.body:GetMaxLines() >= #lines)
		noErrors(ns, mock)
	end)

	it("keeps the ten-line limit and its layout with the marks on a pick-up of ten quests", function()
		local lines, marked, plain = {}, {}, {}
		for i = 1, 10 do
			lines[i] = string.format('Accept "Quest %d"', i)
			marked[i] = { name = "accept", directive = i, done = i <= 4 }
			plain[i] = { name = "note", directive = i }
		end
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.lines["valley:1"], engine.info["valley:1"] = lines, plain
			end,
		})
		local frame = ns.StepFrame.frame
		local plainHeight = frame:GetHeight()
		assert.are.equal(10, frame.body:GetNumLines())
		engine.info["valley:1"] = marked
		go(ns, engine, 1)
		-- a mark takes room along the line, never a line of its own: ten lines, the same height, none cut off
		assert.are.equal(10, frame.body:GetNumLines())
		assert.are.equal(plainHeight, frame:GetHeight())
		assert.are.equal(10, frame.body:GetMaxLines())
		local text = frame.body:GetText()
		assert.are.equal(4, select(2, text:gsub("%[x%]", "")))
		assert.are.equal(6, select(2, text:gsub("%[ %]", "")))
		noErrors(ns, mock)
	end)

	describe("the group quests coming up", function()
		local OPTIONAL = "|cffffd100Optional:|r "

		-- the group quest (a quest's id) of the optional-only steps of the test guide, as Conditions:OptionalOnly says
		local function group(engine, stepId, ...)
			engine.optional[stepId] = { quests = { ... }, available = { ... } }
		end

		it("names the quest of an optional-only step among the next three, as a small line of its own", function()
			local ns, mock = load({
				setup = function(engine)
					engine.lines["valley:1"] = { 'Accept "Cutting Teeth"' }
					group(engine, "valley:3", 4641)
				end,
			})
			local frame = ns.StepFrame.frame
			assert.are.equal(OPTIONAL .. "Quest #4641 (group quest)", frame.optional:GetText())
			assert.is_true(frame.optional:IsShown())
			assert.are.equal("GameFontHighlightSmall", state(frame.optional).template)
			-- not one of the body's lines
			assert.are.equal('Accept "Cutting Teeth"', frame.body:GetText())
			noErrors(ns, mock)
		end)

		local function shown(quests)
			local out = {}
			for i, questID in ipairs(quests) do
				out[i] = string.format("%sQuest #%d (group quest)", OPTIONAL, questID)
			end
			return table.concat(out, "\n")
		end

		it("looks at the next three steps only: the fourth step ahead is not yet offered", function()
			local ns, _, _, engine = load({
				setup = function(engine)
					group(engine, "barrens:2", 3) -- the fifth of five steps
				end,
			})
			local frame = ns.StepFrame.frame
			assert.are.equal("", frame.optional:GetText()) -- from the first step it is four steps ahead
			go(ns, engine, 2)
			assert.are.equal(shown({ 3 }), frame.optional:GetText()) -- from the second, three ahead
			go(ns, engine, 4)
			assert.are.equal(shown({ 3 }), frame.optional:GetText()) -- and one ahead
		end)

		it("never offers the quest of the current step or of a step the route has passed", function()
			local ns, _, _, engine = load({
				setup = function(engine)
					group(engine, "valley:2", 1) -- the second of five steps
					group(engine, "barrens:1", 2) -- the fourth
				end,
			})
			local frame = ns.StepFrame.frame
			assert.are.equal(shown({ 1, 2 }), frame.optional:GetText()) -- from the first step
			go(ns, engine, 2) -- the second step's own quest is its body's business
			assert.are.equal(shown({ 2 }), frame.optional:GetText())
			go(ns, engine, 3) -- the second step is behind now
			assert.are.equal(shown({ 2 }), frame.optional:GetText())
			go(ns, engine, 4)
			assert.are.equal("", frame.optional:GetText())
			go(ns, engine, 5) -- the last step: nothing ahead
			assert.are.equal("", frame.optional:GetText())
		end)

		it("shows two lines at most, each quest once", function()
			local ns, _, _, engine = load({
				setup = function(engine)
					group(engine, "valley:2", 7)
					group(engine, "valley:3", 7, 8) -- the 7 again: its other step, same quest
					group(engine, "barrens:1", 9) -- a third quest: no room
				end,
			})
			local frame = ns.StepFrame.frame
			assert.are.equal(shown({ 7, 8 }), frame.optional:GetText())
			assert.are.equal(2, frame.optional:GetMaxLines())
			engine.optional["valley:3"], engine.optional["barrens:1"] = nil, nil
			go(ns, engine, 1)
			assert.are.equal(shown({ 7 }), frame.optional:GetText())
		end)

		it("goes when the engine no longer offers the quest: it is in the quest log, or done", function()
			local ns, mock, _, engine = load({
				setup = function(engine)
					group(engine, "valley:2", 4641)
				end,
			})
			local frame = ns.StepFrame.frame
			assert.are.equal(OPTIONAL .. "Quest #4641 (group quest)", frame.optional:GetText())
			engine.optional["valley:2"] = { quests = { 4641 }, available = {}, taken = true } -- accepted
			ns.Events:Fire("CONTEXT_CHANGED", "quests")
			mock.runTimers()
			assert.are.equal("", frame.optional:GetText())
			assert.is_false(frame.optional:IsShown())
			engine.optional["valley:2"] = nil -- not an optional-only step any more
			ns.Events:Fire("CONTEXT_CHANGED", "quests")
			mock.runTimers()
			assert.are.equal("", frame.optional:GetText())
			noErrors(ns, mock)
		end)

		it("takes room below the body and the ongoing lines, and none of the body's ten lines", function()
			local lines, info = {}, {}
			for i = 1, 10 do
				lines[i] = string.format('Accept "Quest %d"', i)
				info[i] = { name = "accept", directive = i, done = false }
			end
			local ns, _, _, engine = load({
				setup = function(engine)
					engine.lines["valley:1"], engine.info["valley:1"] = lines, info
					engine.guide.steps[1].sticky = { { name = "level", text = ">> Reach level 5" } }
				end,
			})
			local frame = ns.StepFrame.frame
			local bare = frame:GetHeight()
			assert.are.equal(10, frame.body:GetNumLines())
			group(engine, "valley:2", 5, 6)
			go(ns, engine, 1)
			assert.are.equal(10, frame.body:GetNumLines()) -- all ten, with the group quests beside them
			assert.are.equal(2, frame.optional:GetNumLines())
			-- the gap and the two lines (14 pixels each in the mock)
			assert.are.equal(bare + 4 + 2 * 14, frame:GetHeight())
			local _, _, _, _, ongoingY = frame.sticky:GetPoint(1)
			local _, _, _, _, optionalY = frame.optional:GetPoint(1)
			assert.is_true(optionalY < ongoingY) -- further down the frame
		end)

		it("shows nothing when the engine cannot say", function()
			local ns, mock, _, engine = load()
			ns.Conditions.OptionalOnly = nil
			go(ns, engine, 2)
			assert.are.equal("", ns.StepFrame.frame.optional:GetText())
			noErrors(ns, mock)
		end)
	end)

	it("says where the player is sailing to", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.targets["valley:2"] = { { kind = "dock", map = 1434, x = 27.2, y = 77.1, label = "Booty Bay" } }
			end,
		})
		go(ns, engine, 2)
		local frame = ns.StepFrame.frame
		assert.are.equal("", frame.status:GetText())
		assert.is_false(frame.status:IsShown())
		engine.transport["valley:2"] = "boarded"
		ns.Events:Fire("TRANSPORT_STATE", "valley:2", "boarded")
		mock.runTimers()
		assert.are.equal("In transit to Booty Bay...", frame.status:GetText())
		assert.is_true(frame.status:IsShown())
		engine.targets["valley:2"] = {}
		ns.Events:Fire("TRANSPORT_STATE", "valley:2", "boarded")
		mock.runTimers()
		assert.are.equal("In transit...", frame.status:GetText())
		noErrors(ns, mock)
	end)

	it("stays hidden without a guide", function()
		local ns, mock = load({ guide = false })
		assert.is_nil(ns.StepFrame.frame)
		slash("show")
		assert.truthy(mock.printed[#mock.printed]:find("once a guide is loaded", 1, true))
		noErrors(ns, mock)
	end)

	it("keeps right-click for the journal", function()
		local ns, mock, _, engine = load()
		local frame = ns.StepFrame.frame
		frame:GetScript("OnMouseUp")(frame, "RightButton")
		local toggled
		ns.Journal = {
			Toggle = function(_, step)
				toggled = step
			end,
		}
		frame:GetScript("OnMouseUp")(frame, "LeftButton")
		assert.is_nil(toggled)
		frame:GetScript("OnMouseUp")(frame, "RightButton")
		assert.are.equal(engine.guide.steps[1], toggled)
		noErrors(ns, mock)
	end)
end)

describe("step frame settings", function()
	after_each(uiMock.uninstall)

	it("registers its defaults", function()
		local ns = load()
		assert.are.same({
			shown = true,
			locked = false,
			scale = 1,
			alpha = 1,
			hideInCombat = true,
			hideWhenDead = true,
			hideWithJournal = true,
			growUp = false,
		}, ns.db.stepFrame)
		assert.are.same({ minimap = true, worldMap = true, showNext = false, nextCount = 2 }, ns.db.pins)
	end)

	it("moves on Shift-drag only and saves the position", function()
		local ns, mock, ui = load()
		local frame = ns.StepFrame.frame
		local start, stop = frame:GetScript("OnDragStart"), frame:GetScript("OnDragStop")
		start(frame)
		stop(frame)
		assert.are.equal(0, ui.moves)
		assert.is_nil(ns.db.stepFrame.pos)
		ui.shift = true
		ui.dragTo = { "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300.04, 400 }
		start(frame)
		stop(frame)
		assert.are.equal(1, ui.moves)
		assert.are.same({ point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 400 }, ns.db.stepFrame.pos)
		assert.are.same({ "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 }, { frame:GetPoint(1) })
		noErrors(ns, mock)
	end)

	it("does not move while locked", function()
		local ns, _, ui = load()
		local frame = ns.StepFrame.frame
		slash("lock")
		assert.is_true(ns.db.stepFrame.locked)
		ui.shift = true
		frame:GetScript("OnDragStart")(frame)
		assert.are.equal(0, ui.moves)
		slash("lock off")
		assert.is_false(ns.db.stepFrame.locked)
		frame:GetScript("OnDragStart")(frame)
		assert.are.equal(1, ui.moves)
	end)

	it("keeps position, scale, alpha and lock across a reload", function()
		local ns, _, ui = load()
		local frame = ns.StepFrame.frame
		ui.shift = true
		ui.dragTo = { "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 }
		frame:GetScript("OnDragStart")(frame)
		frame:GetScript("OnDragStop")(frame)
		slash("scale 1.5")
		slash("alpha 0.6")
		slash("lock")
		local saved = ns.db
		uiMock.uninstall()

		local reloaded, mock = load({ saved = saved })
		frame = reloaded.StepFrame.frame
		assert.are.equal(1.5, frame:GetScale())
		assert.are.equal(0.6, frame:GetAlpha())
		assert.are.same({ "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 }, { frame:GetPoint(1) })
		assert.is_true(reloaded.db.stepFrame.locked)
		noErrors(reloaded, mock)
	end)

	it("clamps scale and alpha", function()
		local ns, mock = load()
		slash("scale 5")
		assert.are.equal(2, ns.db.stepFrame.scale)
		assert.are.equal(2, ns.StepFrame.frame:GetScale())
		slash("alpha 0")
		assert.are.equal(0.2, ns.db.stepFrame.alpha)
		slash("scale big")
		assert.are.equal(2, ns.db.stepFrame.scale)
		assert.truthy(mock.printed[#mock.printed]:find("0.5 to 2", 1, true))
	end)

	it("resets position, scale and alpha", function()
		local ns = load()
		ns.db.stepFrame.pos = { point = "CENTER", relativePoint = "CENTER", x = 10, y = 10 }
		slash("scale 1.4")
		slash("alpha 0.5")
		slash("hide")
		slash("reset")
		local s = ns.db.stepFrame
		assert.is_nil(s.pos)
		assert.are.same({ 1, 1, true }, { s.scale, s.alpha, s.shown })
		local frame = ns.StepFrame.frame
		assert.are.same({ "TOPRIGHT", G.UIParent, "TOPRIGHT", -300, -220 }, { frame:GetPoint(1) })
		assert.is_true(frame:IsShown())
	end)

	it("hides and shows on command", function()
		local ns = load()
		local frame = ns.StepFrame.frame
		slash("hide")
		assert.is_false(frame:IsShown())
		assert.is_false(ns.db.stepFrame.shown)
		slash("show")
		assert.is_true(frame:IsShown())
	end)
end)

describe("step frame growth direction", function()
	after_each(uiMock.uninstall)

	-- The frame is `height` high when the position is applied (a position at the other edge is moved by the height).
	local function place(ns, pos, height)
		local frame = ns.StepFrame.frame
		frame:SetHeight(height or 100)
		ns.db.stepFrame.pos = pos
		ns.StepFrame:ApplyPosition()
		return frame
	end

	it("keeps the top edge by default and the bottom edge when it grows up, without moving the frame", function()
		local ns, mock = load()
		local frame = place(ns, { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 400 })
		assert.is_false(ns.db.stepFrame.growUp)
		assert.are.same({ "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 }, { frame:GetPoint(1) })
		ns.StepFrame:SetGrowUp(true)
		assert.is_true(ns.db.stepFrame.growUp)
		-- the frame is 100 high: its bottom edge is 100 below its top edge
		assert.are.same({ "BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 300, 300 }, { frame:GetPoint(1) })
		assert.are.same({ point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 300 }, ns.db.stepFrame.pos)
		-- a taller step: the bottom edge is where it was, so the frame grows upwards (the anchor does not change)
		frame:SetHeight(180)
		ns.StepFrame:ApplyPosition()
		assert.are.same({ "BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 300, 300 }, { frame:GetPoint(1) })
		frame:SetHeight(100)
		ns.StepFrame:SetGrowUp(false)
		assert.are.same({ "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 }, { frame:GetPoint(1) })
		noErrors(ns, mock)
	end)

	it("moves a centred or right-hand position to the edge it needs", function()
		local ns = load()
		local frame = place(ns, { point = "CENTER", relativePoint = "CENTER", x = 10, y = 10 })
		ns.StepFrame:SetGrowUp(true)
		assert.are.same({ "BOTTOM", G.UIParent, "CENTER", 10, -40 }, { frame:GetPoint(1) }) -- 10 - 100 / 2
		ns.StepFrame:SetGrowUp(false)
		assert.are.same({ "TOP", G.UIParent, "CENTER", 10, 60 }, { frame:GetPoint(1) })
		frame = place(ns, { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -50, y = -20 })
		ns.StepFrame:SetGrowUp(true)
		assert.are.same({ "BOTTOMRIGHT", G.UIParent, "TOPRIGHT", -50, -120 }, { frame:GetPoint(1) })
	end)

	it("has a default place for each direction, and a reset keeps the direction", function()
		local ns = load()
		local frame = ns.StepFrame.frame
		assert.are.same({ "TOPRIGHT", G.UIParent, "TOPRIGHT", -300, -220 }, { frame:GetPoint(1) })
		ns.StepFrame:SetGrowUp(true)
		assert.is_nil(ns.db.stepFrame.pos) -- nothing is saved: a frame that grows up gets a default anchored at its bottom
		assert.are.same({ "BOTTOMRIGHT", G.UIParent, "TOPRIGHT", -300, -300 }, { frame:GetPoint(1) })
		slash("reset")
		assert.is_true(ns.db.stepFrame.growUp)
		assert.are.same({ "BOTTOMRIGHT", G.UIParent, "TOPRIGHT", -300, -300 }, { frame:GetPoint(1) })
	end)

	it("anchors a dragged frame at the edge it grows from and keeps that across a reload", function()
		local ns, _, ui = load()
		local frame = ns.StepFrame.frame
		ns.StepFrame:SetGrowUp(true)
		frame:SetHeight(100)
		ui.shift = true
		ui.dragTo = { "TOPLEFT", G.UIParent, "BOTTOMLEFT", 300, 400 } -- the client hands back the corner it moved
		frame:GetScript("OnDragStart")(frame)
		frame:GetScript("OnDragStop")(frame)
		assert.are.same({ "BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 300, 300 }, { frame:GetPoint(1) })
		assert.are.same({ point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 300 }, ns.db.stepFrame.pos)
		local saved = ns.db
		uiMock.uninstall()

		local reloaded, mock = load({ saved = saved })
		assert.is_true(reloaded.db.stepFrame.growUp)
		assert.are.same({ "BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", 300, 300 }, { reloaded.StepFrame.frame:GetPoint(1) })
		noErrors(reloaded, mock)
	end)

	it("is set with /signpost grow", function()
		local ns, mock = load()
		slash("grow up")
		assert.is_true(ns.db.stepFrame.growUp)
		assert.truthy(mock.printed[#mock.printed]:find("grows upwards", 1, true))
		slash("grow down")
		assert.is_false(ns.db.stepFrame.growUp)
		slash("grow")
		assert.truthy(mock.printed[#mock.printed]:find("grows downwards", 1, true))
		slash("grow sideways")
		assert.truthy(mock.printed[#mock.printed]:find("'grow up'", 1, true)) -- the usage line
		assert.is_false(ns.db.stepFrame.growUp)
		noErrors(ns, mock)
	end)

	it("moves the item button with the frame's top edge after every layout", function()
		local ns = load()
		local calls, real = 0, ns.StepFrame.PositionItemButton
		ns.StepFrame.PositionItemButton = function(self)
			calls = calls + 1
			return real(self)
		end
		ns.StepFrame:Layout()
		assert.is_true(calls > 0)
	end)
end)

describe("step frame visibility", function()
	after_each(uiMock.uninstall)

	it("hides in combat, keeps up to date and comes back after", function()
		local ns, mock, ui, engine = load()
		local frame = ns.StepFrame.frame
		ui.combat = true
		mock.fire("PLAYER_REGEN_DISABLED")
		assert.is_false(frame:IsShown())
		go(ns, engine, 2)
		assert.is_false(frame:IsShown())
		assert.are.equal("Valley of Trials · step 2/3", frame.title:GetText())
		ui.combat = false
		mock.fire("PLAYER_REGEN_ENABLED")
		assert.is_true(frame:IsShown())
		assert.are.same({}, ui.blocked)
		noErrors(ns, mock)
	end)

	it("stays in combat when hideInCombat is off", function()
		local ns, mock, ui = load()
		ns.db.stepFrame.hideInCombat = false
		ui.combat = true
		mock.fire("PLAYER_REGEN_DISABLED")
		assert.is_true(ns.StepFrame.frame:IsShown())
	end)

	it("hides while dead unless told otherwise", function()
		local ns, mock, ui = load()
		local frame = ns.StepFrame.frame
		ui.dead = true
		mock.fire("PLAYER_DEAD")
		assert.is_false(frame:IsShown())
		ui.dead = false
		mock.fire("PLAYER_UNGHOST")
		assert.is_true(frame:IsShown())
		ns.db.stepFrame.hideWhenDead = false
		ui.dead = true
		mock.fire("PLAYER_DEAD")
		assert.is_true(frame:IsShown())
		noErrors(ns, mock)
	end)
end)

describe("quest item button", function()
	after_each(uiMock.uninstall)

	it("offers the step's .use item from the bags", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.items[5070] = 3
			end,
		})
		go(ns, engine, 3)
		local button = ns.StepFrame.itemButton
		assert.are.equal(G.SignpostItemButton, button)
		assert.are.equal("SecureActionButtonTemplate", state(button).template)
		assert.are.equal("item", button:GetAttribute("type"))
		assert.are.equal("item:5070", button:GetAttribute("item"))
		assert.is_true(button:IsShown())
		-- beside the step frame, but parented and anchored to UIParent: the step frame stays unprotected
		assert.are.equal(G.UIParent, button:GetParent())
		local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
		assert.are.same({ "TOPRIGHT", G.UIParent, "BOTTOMLEFT" }, { point, relativeTo, relativePoint })
		assert.are.equal("number", type(x))
		assert.are.equal("number", type(y))
		assert.are.equal(0, state(ns.StepFrame.frame).protectedChildren)
		assert.are.equal(0, state(ns.StepFrame.frame).protectedAnchors)
		assert.are.same({ "AnyUp", "AnyDown" }, state(button).clicks)
		assert.are.equal(105070, button.icon:GetTexture())
		assert.are.equal("3", button.count:GetText())
		noErrors(ns, mock)
	end)

	it("waits until the item is in the bags", function()
		local ns, mock, _, engine = load()
		go(ns, engine, 3)
		assert.is_nil(ns.StepFrame.itemButton)
		engine.items[5070] = 1
		ns.Events:Fire("CONTEXT_CHANGED", "bags")
		mock.runTimers()
		local button = ns.StepFrame.itemButton
		assert.are.equal("item:5070", button:GetAttribute("item"))
		assert.is_true(button:IsShown())
		assert.are.equal("", button.count:GetText())
	end)

	it("offers the Hearthstone on a .home step, only from the bags, and never uses it by itself", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				engine.items[6948] = 1
			end,
		})
		engine.guide.steps[1].directives = { { name = "home", args = {} } }
		go(ns, engine, 1)
		local button = ns.StepFrame.itemButton
		assert.are.equal("item:6948", button:GetAttribute("item"))
		assert.is_true(button:IsShown())
		assert.are.equal("item", button:GetAttribute("type")) -- a secure item button: the player's click casts it
		-- not in the bags: not offered
		engine.items[6948] = 0
		go(ns, engine, 2)
		go(ns, engine, 1)
		assert.is_false(button:IsShown())
		noErrors(ns, mock)
	end)

	it("goes away with the step", function()
		local ns, _, _, engine = load({
			setup = function(engine)
				engine.items[5070] = 1
			end,
		})
		go(ns, engine, 3)
		local button = ns.StepFrame.itemButton
		go(ns, engine, 2)
		assert.is_false(button:IsShown())
		assert.is_nil(button:GetAttribute("item"))
	end)

	it("queues its secure changes until combat ends", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.items[5070], engine.items[6000] = 1, 1
			end,
		})
		go(ns, engine, 3)
		local button = ns.StepFrame.itemButton
		ui.combat = true
		mock.fire("PLAYER_REGEN_DISABLED")
		go(ns, engine, 5)
		assert.are.equal("item:5070", button:GetAttribute("item"))
		go(ns, engine, 2)
		assert.is_true(button:IsShown())
		go(ns, engine, 5)
		assert.are.equal("item:5070", button:GetAttribute("item"))
		assert.are.same({}, ui.blocked)
		ui.combat = false
		mock.fire("PLAYER_REGEN_ENABLED")
		assert.are.equal("item:6000", button:GetAttribute("item"))
		assert.is_true(button:IsShown())
		noErrors(ns, mock)
	end)

	it("stays usable in combat while the step frame hides", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.items[5070] = 1
			end,
		})
		go(ns, engine, 3)
		ui.combat = true
		mock.fire("PLAYER_REGEN_DISABLED")
		assert.is_false(ns.StepFrame.frame:IsShown())
		assert.is_true(ns.StepFrame.itemButton:IsShown())
		-- the count follows the bags in combat (a plain font string)
		engine.items[5070] = 4
		ns.Events:Fire("CONTEXT_CHANGED", "bags")
		mock.runTimers()
		assert.are.equal("4", ns.StepFrame.itemButton.count:GetText())
		assert.are.same({}, ui.blocked)
		noErrors(ns, mock)
	end)

	it("moves along with the step frame, after combat if need be", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.items[5070] = 1
			end,
		})
		go(ns, engine, 3)
		local button, frame = ns.StepFrame.itemButton, ns.StepFrame.frame
		local _, _, _, x = button:GetPoint(1)
		ns.db.stepFrame.hideInCombat = false
		ui.combat, ui.shift = true, true
		mock.fire("PLAYER_REGEN_DISABLED")
		ui.dragTo = { "TOPRIGHT", G.UIParent, "TOPRIGHT", -500, -220 }
		frame:GetScript("OnDragStart")(frame)
		frame:GetScript("OnDragStop")(frame)
		assert.are.equal(x, select(4, button:GetPoint(1)))
		ui.combat = false
		mock.fire("PLAYER_REGEN_ENABLED")
		assert.are.equal(x - 200, select(4, button:GetPoint(1)))
		noErrors(ns, mock)
	end)

	it("shows a running cooldown", function()
		local ns, mock, ui, engine = load({
			setup = function(engine, ui)
				engine.items[5070] = 1
				ui.cooldowns[5070] = { 100, 30, true }
			end,
		})
		go(ns, engine, 3)
		local cooldown = ns.StepFrame.itemButton.cooldown
		assert.are.same({ 100, 30 }, state(cooldown).cooldown)
		ui.cooldowns[5070] = nil
		mock.fire("BAG_UPDATE_COOLDOWN")
		assert.is_nil(state(cooldown).cooldown)
	end)

	it("hides while dead", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.items[5070] = 1
			end,
		})
		go(ns, engine, 3)
		ui.dead = true
		mock.fire("PLAYER_DEAD")
		assert.is_false(ns.StepFrame.itemButton:IsShown())
		ui.dead = false
		mock.fire("PLAYER_ALIVE")
		assert.is_true(ns.StepFrame.itemButton:IsShown())
	end)
end)

describe("pins", function()
	after_each(uiMock.uninstall)

	local function questTargets(engine)
		engine.targets["valley:1"] = {
			{ kind = "accept", map = 1411, x = 42.1, y = 68.7, label = "Kaltunk", npc = 10176, questID = 4641 },
			{ kind = "vendor", map = 1411, x = 44, y = 69 },
		}
		engine.targets["valley:2"] = { { kind = "objective", map = 1411, x = 40, y = 60, questID = 787 } }
	end

	it("pins every target of the current step on the minimap and the world map", function()
		local ns, mock, ui, engine = load({ setup = questTargets })
		go(ns, engine, 1)
		local minimap, world = pinsOf(ns, "minimap"), pinsOf(ns, "world")
		assert.are.equal(2, #minimap)
		assert.are.equal(2, #world)
		assert.are.equal(2, count(ui.minimap))
		local accept = ui.minimap[minimap[1].pin]
		assert.are.same({ instance = 1, x = 1421, y = 2687, floatOnEdge = true }, {
			instance = accept.instance,
			x = math.floor(accept.x + 0.5),
			y = math.floor(accept.y + 0.5),
			floatOnEdge = accept.floatOnEdge,
		})
		local acceptWorld = ui.world[world[1].pin]
		assert.are.equal(1411, acceptWorld.map)
		assert.is_true(math.abs(acceptWorld.x - 0.421) < 1e-9 and math.abs(acceptWorld.y - 0.687) < 1e-9)
		assert.are.equal(2, acceptWorld.flag) -- HBD_PINS_WORLDMAP_SHOW_CONTINENT
		assert.are.equal("QuestNormal", minimap[1].pin.texture:GetAtlas())
		-- there is no Vendor atlas on Forever
		assert.are.equal("Interface\\GossipFrame\\VendorGossipIcon", minimap[2].pin.texture:GetTexture())
		assert.are.same({ 0, 1, 0, 1 }, state(minimap[2].pin.texture).texCoord)
		noErrors(ns, mock)
	end)

	it("replaces the pins when the targets change", function()
		local ns, mock, ui, engine = load({ setup = questTargets })
		go(ns, engine, 1)
		go(ns, engine, 2)
		assert.are.equal(1, count(ui.minimap))
		assert.are.equal(1, count(ui.world))
		assert.are.equal("objective", pinsOf(ns, "world")[1].kind)
		for pin in pairs(ui.minimap) do
			assert.are.equal("objective", ns.Pins.minimap[pin].target.kind)
		end
		go(ns, engine, 3)
		assert.are.equal(0, count(ui.minimap))
		assert.are.equal(0, count(ui.world))
		noErrors(ns, mock)
	end)

	it(
		"a step with no targets (a doing step) draws nothing and clears the pins and the arrow of the one before",
		function()
			local ns, mock, ui, engine = load({ setup = questTargets })
			ns.db.pins.showNext = true
			go(ns, engine, 1)
			local ticker = ui.tickers[#ui.tickers]
			assert.are.equal(2, count(ui.minimap))
			assert.is_false(ticker.cancelled == true)
			go(ns, engine, 3) -- no targets: what Conditions gives a doing step
			assert.are.same({}, ns.Pins:Collect())
			assert.are.equal(0, count(ui.minimap))
			assert.are.equal(0, count(ui.world))
			assert.is_nil(next(ns.Pins.minimap))
			assert.is_nil(next(ns.Pins.world))
			assert.is_true(ticker.cancelled)
			-- it stays bare through refreshes and context changes, and without the minimap or the world map pins
			ns.Events:Fire("CONTEXT_CHANGED", "position")
			ns.Events:Fire("CONTEXT_CHANGED", "quests")
			mock.runTimers()
			ns.Pins:Refresh(true)
			ns.Pins:SetEnabled("minimap", false)
			ns.Pins:SetEnabled("minimap", true)
			assert.are.equal(0, count(ui.minimap))
			assert.are.equal(0, count(ui.world))
			-- the step frame still shows the step
			assert.are.equal("Valley of Trials · step 3/3", ns.StepFrame.frame.title:GetText())
			noErrors(ns, mock)
		end
	)

	it("pins the sticky targets of the active sticky steps", function()
		local sticky = { id = "track:a:1", sticky = { { name = "skill", text = "Skin until 50" } } }
		local ns, mock, _, engine = load({
			setup = function(engine)
				questTargets(engine)
				engine.sticky = { sticky }
				engine.targets[sticky.id] = {
					{ kind = "gather", map = 1411, x = 50, y = 50, sticky = true },
					{ kind = "accept", map = 1411, x = 51, y = 51 },
				}
			end,
		})
		go(ns, engine, 1)
		local minimap = pinsOf(ns, "minimap")
		assert.are.same({ "accept", "gather", "vendor" }, { minimap[1].kind, minimap[2].kind, minimap[3].kind })
		assert.are.equal(0.8, minimap[2].pin:GetAlpha())
		assert.are.equal("poi-workorders", minimap[2].pin.texture:GetAtlas())
		-- a sticky target's tooltip shows its sticky directive
		minimap[2].pin:GetScript("OnEnter")(minimap[2].pin)
		assert.are.same({ "Gather here", "Skin until 50" }, G.GameTooltip.lines)
		noErrors(ns, mock)
	end)

	describe("a .path", function()
		local function pathTargets(engine)
			engine.targets["barrens:1"] = {
				{ kind = "waypoint", map = 1411, x = 52, y = 43.5, index = 1, reached = true },
				{ kind = "waypoint", map = 1411, x = 47.8, y = 41, index = 2, next = true },
				{ kind = "waypoint", map = 1413, x = 61.9, y = 54.9, index = 3 },
				{ kind = "waypoint", map = 1413, x = 62.3, y = 56, index = 4 },
			}
		end

		it("shows only the next waypoint on the minimap", function()
			local ns, mock, _, engine = load({ setup = pathTargets })
			go(ns, engine, 4)
			local minimap = pinsOf(ns, "minimap")
			assert.are.equal(1, #minimap)
			assert.are.equal(2, minimap[1].index)
			assert.are.equal("2", minimap[1].pin.number:GetText())
			noErrors(ns, mock)
		end)

		it("takes the lowest waypoint not reached when none is marked next", function()
			local ns, _, _, engine = load({
				setup = function(engine)
					pathTargets(engine)
					engine.targets["barrens:1"][2].next = nil
					engine.targets["barrens:1"][2].reached = true
				end,
			})
			go(ns, engine, 4)
			assert.are.equal(3, pinsOf(ns, "minimap")[1].index)
		end)

		it("numbers every waypoint on the world map and joins them on zone maps only", function()
			local ns, mock, ui, engine = load({ setup = pathTargets })
			go(ns, engine, 4)
			local world = pinsOf(ns, "world")
			assert.are.equal(4, #world)
			local flags, numbers = {}, {}
			for i, item in ipairs(world) do
				flags[i] = ui.world[item.pin].flag
				numbers[i] = item.pin.number:GetText()
			end
			-- the next waypoint also shows on the continent map; the others on zone maps
			assert.are.same({ 1, 2, 1, 1 }, flags)
			assert.are.same({ "1", "2", "3", "4" }, numbers)
			assert.is_true(world[1].pin.texture:IsDesaturated())
			local lines = ns.Pins.lines
			assert.are.equal(3, #lines)
			assert.are.equal(world[1].pin, select(2, lines[1].line:GetStartPoint()))
			assert.are.equal(world[2].pin, select(2, lines[1].line:GetEndPoint()))
			local function view(mapID)
				ui.setWorldMap(mapID)
				-- the lines follow one frame later, once every map data provider has placed its pins
				mock.runTimers()
				return { lines[1].line:IsShown(), lines[2].line:IsShown(), lines[3].line:IsShown() }
			end
			assert.are.same({ true, false, false }, view(1411))
			assert.are.same({ false, false, true }, view(1413))
			assert.are.same({ false, false, false }, view(1414)) -- the continent
			-- a waypoint HereBeDragons does not draw on this map takes its lines along
			world[4].pin:Hide()
			assert.are.same({ false, false, false }, view(1413))
			noErrors(ns, mock)
		end)
	end)

	it("refreshes within a second of CONTEXT_CHANGED", function()
		local ns, mock, ui, engine = load({ setup = questTargets })
		go(ns, engine, 2)
		engine.targets["valley:2"][2] = { kind = "objective", map = 1411, x = 41, y = 61 }
		ns.Events:Fire("CONTEXT_CHANGED", "quests")
		assert.are.equal(1, count(ui.world))
		for _, delay in ipairs(ui.delays) do
			assert.is_true(delay <= 1)
		end
		mock.runTimers()
		assert.are.equal(2, count(ui.world))
		noErrors(ns, mock)
	end)

	it("swaps a transport pin from departure to arrival on TRANSPORT_STATE", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.targets["valley:2"] = { { kind = "dock", map = 1413, x = 63.9, y = 38.6, label = "Ratchet" } }
			end,
		})
		go(ns, engine, 2)
		local function dockMap()
			return ui.world[pinsOf(ns, "world")[1].pin].map
		end
		assert.are.equal(1413, dockMap())
		assert.are.equal("TaxiNode_Horde", pinsOf(ns, "world")[1].pin.texture:GetAtlas())
		engine.targets["valley:2"] = { { kind = "dock", map = 1434, x = 27.2, y = 77.1, label = "Booty Bay" } }
		ns.Events:Fire("TRANSPORT_STATE", "valley:2", "boarded")
		assert.are.equal(1413, dockMap())
		mock.runTimers()
		assert.are.equal(1434, dockMap())
		noErrors(ns, mock)
	end)

	it("survives missing coordinates, unknown maps and no player position", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				engine.targets["valley:1"] = {
					{ kind = "goto", map = 1411, y = 50 },
					{ kind = "goto", map = 4242, x = 10, y = 10 },
					{ kind = "goto", map = 1411, x = 150, y = 10 },
					{ kind = "goto", map = "1411", x = 1, y = 1 },
					"not a target",
					{ kind = "goto", map = 1411, x = 20, y = 20 },
				}
			end,
		})
		go(ns, engine, 1)
		assert.are.equal(1, count(ui.minimap))
		assert.are.equal(1, count(ui.world))
		local pin = pinsOf(ns, "minimap")[1].pin
		pin:GetScript("OnEnter")(pin)
		assert.are.same({ "Go here" }, G.GameTooltip.lines)
		ui.onEdge[pin] = true
		ns.Pins:UpdateArrows()
		assert.is_false(pin.arrow:IsShown())
		assert.is_true(pin.texture:IsShown())
		noErrors(ns, mock)
	end)

	it("shows the step text and the distance in the tooltip", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				questTargets(engine)
				engine.lines["valley:1"] = { 'Accept "Your Place in the World"' }
				engine.distance = 123.4
			end,
		})
		go(ns, engine, 1)
		local pin = pinsOf(ns, "minimap")[1].pin
		pin:GetScript("OnEnter")(pin)
		local tooltip = G.GameTooltip
		assert.are.same({ "Kaltunk", 'Accept "Your Place in the World"', "123 yards" }, tooltip.lines)
		assert.are.same({ 1411, 42.1, 68.7 }, engine.asked)
		engine.distance = 50
		ns.Events:Fire("CONTEXT_CHANGED", "position")
		assert.are.equal("50 yards", tooltip.lines[3])
		pin:GetScript("OnLeave")(pin)
		assert.is_false(tooltip:IsShown())
		noErrors(ns, mock)
	end)

	it("lists under a pin the lines of the quests it names, not those of the step's other pins", function()
		local ns, mock, _, engine = load({
			setup = function(engine)
				-- a joined pick-up: two NPCs, each pin with its own quests (Engine/Conditions.lua Targets)
				engine.targets["valley:1"] = {
					{
						kind = "accept",
						map = 1411,
						x = 43.3,
						y = 68.5,
						label = 'Accept "A"',
						questID = 101,
						quests = { 101 },
					},
					{
						kind = "accept",
						map = 1411,
						x = 42.1,
						y = 68.3,
						label = 'Accept "B"\nAccept "C"',
						questID = 102,
						quests = { 102, 103 },
					},
					{ kind = "goto", map = 1411, x = 40.5, y = 68 }, -- a pin that names no quest
				}
				engine.lines["valley:1"] = { 'Accept "A"', 'Accept "B"', 'Accept "C"', "Reach level 5" }
				engine.info["valley:1"] = {
					{ name = "accept", directive = 1, quest = 101, done = false },
					{ name = "accept", directive = 2, quest = 102, done = false },
					{ name = "accept", directive = 3, quest = 103, done = true },
					{ name = "level", directive = 4, done = false },
				}
			end,
		})
		go(ns, engine, 1)
		local function tooltipOf(x)
			for _, item in ipairs(pinsOf(ns, "world")) do
				if item.entry.target.x == x then
					item.pin:GetScript("OnEnter")(item.pin)
					return G.GameTooltip.lines
				end
			end
		end
		assert.are.same({ 'Accept "A"', TODO .. 'Accept "A"', "Reach level 5" }, tooltipOf(43.3))
		assert.are.same(
			{ 'Accept "B"\nAccept "C"', TODO .. 'Accept "B"', DONE .. 'Accept "C"', "Reach level 5" },
			tooltipOf(42.1)
		)
		-- a pin that names no quest keeps the whole step
		assert.are.same(
			{ "Go here", TODO .. 'Accept "A"', TODO .. 'Accept "B"', DONE .. 'Accept "C"', "Reach level 5" },
			tooltipOf(40.5)
		)
		noErrors(ns, mock)
	end)

	it("turns a pin on the minimap edge into an arrow towards the target", function()
		local ns, mock, ui, engine = load({ setup = questTargets })
		go(ns, engine, 1)
		local ticker = ui.tickers[#ui.tickers]
		assert.are.equal(0.2, ticker.interval)
		local pin = pinsOf(ns, "minimap")[1].pin
		ui.player = { x = 0, y = 0, instance = 1 }
		ui.vector = { 1.0, 300 }
		ui.onEdge[pin] = true
		ns.Pins:UpdateArrows()
		assert.is_true(pin.arrow:IsShown())
		assert.is_false(pin.texture:IsShown())
		assert.are.equal(1.0, pin.arrow:GetRotation())
		ui.cvars.rotateMinimap = "1"
		ui.facing = 0.25
		ns.Pins:UpdateArrows()
		assert.are.equal(0.75, pin.arrow:GetRotation())
		ui.onEdge[pin] = false
		ns.Pins:UpdateArrows()
		assert.is_false(pin.arrow:IsShown())
		assert.is_true(pin.texture:IsShown())
		go(ns, engine, 3)
		assert.is_true(ticker.cancelled)
		noErrors(ns, mock)
	end)

	it("follows the pin settings", function()
		local ns, mock, ui, engine = load({ setup = questTargets })
		go(ns, engine, 1)
		ns.Pins:SetEnabled("minimap", false)
		assert.is_false(ns.db.pins.minimap)
		assert.are.equal(0, count(ui.minimap))
		assert.are.equal(2, count(ui.world))
		ns.Pins:SetEnabled("worldMap", false)
		assert.are.equal(0, count(ui.world))
		noErrors(ns, mock)
	end)

	it("faintly shows the next steps' targets on the world map when asked", function()
		local ns, mock, ui, engine = load({
			setup = function(engine)
				questTargets(engine)
				engine.targets["valley:3"] = { { kind = "turnin", map = 1411, x = 42.1, y = 68.7 } }
			end,
		})
		ns.db.pins.showNext = true
		go(ns, engine, 1)
		assert.are.equal(2, count(ui.minimap))
		local faint = {}
		for _, item in ipairs(pinsOf(ns, "world")) do
			if item.entry.faint then
				faint[#faint + 1] = item
			end
		end
		assert.are.equal(2, #faint)
		for _, item in ipairs(faint) do
			assert.are.equal(0.5, item.pin:GetAlpha())
			assert.are.equal(1, ui.world[item.pin].flag)
		end
		-- the next steps are asked with scratch states, never ns.Progress:State
		assert.is_nil(engine.states["valley:2"])
		assert.is_table(engine.statesSeen["valley:2"])
		noErrors(ns, mock)
	end)

	it("opens the journal at the step from a world map pin", function()
		local ns, mock, _, engine = load({ setup = questTargets })
		go(ns, engine, 1)
		local pin = pinsOf(ns, "world")[1].pin
		pin:Click()
		local shown
		ns.Journal = {
			ShowStep = function(_, step)
				shown = step
			end,
		}
		pin:Click()
		assert.are.equal(engine.guide.steps[1], shown)
		noErrors(ns, mock)
	end)

	it("does nothing without HereBeDragons", function()
		local ns, mock, _, engine = load({ mock = { noLibs = true }, setup = questTargets })
		go(ns, engine, 1)
		ns.Events:Fire("CONTEXT_CHANGED", "position")
		mock.runTimers()
		assert.is_nil(next(ns.Pins.minimap))
		assert.is_nil(next(ns.Pins.world))
		noErrors(ns, mock)
	end)
end)

describe("UI on the generic client mock", function()
	after_each(uiMock.uninstall)

	-- wow_mock's frames answer nil to everything; only CreateFontString/CreateTexture/CreateLine are added (the
	-- proposed wow_mock extension), so every other spec can load these files once they are in the TOC.
	it("loads, renders and takes events without errors", function()
		local ns, mock, _, engine = load({
			mock = { bare = true },
			setup = function(engine)
				engine.items[5070] = 1
				engine.lines["valley:3"] = { "Use the item" }
			end,
		})
		go(ns, engine, 3)
		ns.Events:Fire("CONTEXT_CHANGED", "bags")
		ns.Events:Fire("TRANSPORT_STATE", "valley:3", "boarded")
		mock.runTimers()
		mock.fire("PLAYER_REGEN_DISABLED")
		mock.fire("PLAYER_REGEN_ENABLED")
		mock.fire("PLAYER_DEAD")
		mock.fire("BAG_UPDATE_COOLDOWN")
		slash("lock")
		slash("scale 1.2")
		slash("reset")
		slash("hide")
		slash("show")
		assert.is_table(ns.StepFrame.frame)
		assert.is_table(ns.StepFrame.itemButton)
		noErrors(ns, mock)
	end)
end)
