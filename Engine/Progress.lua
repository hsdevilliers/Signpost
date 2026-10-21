-- ns.Progress: where the character is in its guide. Starts the step engine at PLAYER_LOGIN (guide selection,
-- profession plan, parse), keeps the current step with auto-advance and auto-skip, the sticky set and the per-step
-- directive state, applies the player's manual moves (which win for the session), skips dungeon chapters, puts a
-- character that is new to a guide where its level and its quests say it is (ns.Placement), saves progress per
-- character and registers /signpost next|back|skip|step|place|reset progress. PLAN §3.3; contracts in docs/ENGINE.md.
local ADDON_NAME, ns = ...
local L = ns.L

-- stores[stepId] = { started = bool, d = { [directive key] = state } } lives for the session; views[stepId] holds the
-- same state tables as ns.Conditions receives them. byId[stepId] = step, positions[stepId] = index into guide.steps,
-- chapterOf[index] = chapter index and ranges[chapter index] = { first, last } are rebuilt for every parse.
local Progress = { stores = {}, views = {}, byId = {}, positions = {}, chapterOf = {}, ranges = {} }
ns.Progress = Progress

local EMPTY = {}
-- PLAN §3.3: completion checks are event-driven plus a re-evaluation throttled to one per second.
local THROTTLE = 1
-- After a manual move, how many of the following steps are watched for a quest event proving the player went on.
local HOLD_WINDOW = 25
-- How far above a dungeon chapter's maximum level the player must be for the one-time offer to skip it.
local DUNGEON_OFFER_LEVELS = 5
local MAX_PASSES = 5
-- A first placement waits this many seconds for the quest history (the completed-quest list the client fills a moment
-- after login) before it goes by the level alone.
local PLACE_WAIT = 5
-- /signpost reset progress is typed twice, at most this many seconds apart.
local RESET_CONFIRM = 30

-- SignpostCharDB.progress[guideId]. `current`, `skipped` and `done` are the docs/ENGINE.md contract; the rest belongs
-- to this module: sticky[stepId][key] is true while that sticky directive is active and false once it was satisfied
-- (or dismissed), states[stepId] holds the directive state of the current step and of steps with active stickies,
-- offered[first step id of a dungeon chapter] records the one-time skip offer, and placed = { step, index, reason,
-- mode, time } says that a placement ran (see "Placement"): a record with it, or with any done or skipped step, is not
-- new to the guide. A directive's key is its source line, which stays the same when the guide is parsed again.
-- fingerprint is the checksum of the guide text (guide.fingerprint, Engine/Parser.lua) the record was made for: step
-- ids are positions in that text, so a record is trusted only for the same text (see "Placement").
local RECORD_DEFAULTS = { skipped = {}, done = {}, sticky = {}, states = {}, offered = {} }

ns.SavedVars:RegisterDefaults("char", "progress", {})

-- Helpers ---------------------------------------------------------------------------------------------------------

local function completable(directive)
	local def = directive.def
	if type(def) ~= "table" then
		return false
	end
	if def.completable ~= nil then
		return def.completable and true or false
	end
	return def.isSatisfied ~= nil
end

-- GUIDE-FORMAT: a step without a completable directive completes only by the player's `>`.
local function manualOnly(step)
	for _, directive in ipairs(step.directives or EMPTY) do
		if completable(directive) then
			return false
		end
	end
	return true
end

local function hasDirective(step, name)
	for _, directive in ipairs(step.directives or EMPTY) do
		if directive.name == name then
			return true
		end
	end
	return false
end

local function hasQuestDirective(step)
	for _, directive in ipairs(step.directives or EMPTY) do
		if type(directive.def) == "table" and directive.def.kind == "quest" and completable(directive) then
			return true
		end
	end
	return false
end

local function directiveKey(directive, fallback)
	return directive.line or fallback
end

local function slot(tbl, key)
	local value = tbl[key]
	if type(value) ~= "table" then
		value = {}
		tbl[key] = value
	end
	return value
end

local function chatEnabled()
	local db = ns.db
	return type(db) == "table" and type(db.debug) == "table" and db.debug.chat == true
end

local function lineText(line)
	if type(line) == "table" then
		line = line.text or line[1]
	end
	if line ~= nil then
		return tostring(line)
	end
end

local function describeDirective(directive)
	if directive.text then
		return tostring(directive.text)
	end
	local def = directive.def
	if type(def) == "table" and def.describe then
		local ok, text = pcall(def.describe, directive.args, ns.Context)
		if ok and text then
			return tostring(text)
		end
	end
	return "." .. tostring(directive.name)
end

function Progress:Echo(text, ...)
	if chatEnabled() then
		ns.Util.Print(text, ...)
	end
end

-- Saved record and per-guide indexes ------------------------------------------------------------------------------

function Progress:Record(guideId)
	local char = ns.char
	if type(char) ~= "table" then
		-- Only before SavedVariables are ready; nothing set here is kept.
		self.unsaved = self.unsaved or {}
		char = self.unsaved
	end
	if type(char.progress) ~= "table" then
		char.progress = {}
	end
	local record = char.progress[guideId]
	if type(record) ~= "table" then
		record = {}
		char.progress[guideId] = record
	end
	return ns.SavedVars.ApplyDefaults(record, RECORD_DEFAULTS)
end

-- Positions, chapters and chapter ranges of a parsed guide. A step without a chapter (e.g. a merged profession step)
-- belongs to the chapter of the step before it.
function Progress:Index(guide)
	local byId, positions, chapterOf, ranges = {}, {}, {}, {}
	local chapter
	for i, step in ipairs(guide.steps or EMPTY) do
		byId[step.id] = step
		positions[step.id] = i
		chapter = step.chapter or chapter
		chapterOf[i] = chapter
		if chapter then
			local range = ranges[chapter]
			if range then
				range.last = i
			else
				ranges[chapter] = { first = i, last = i }
			end
		end
	end
	self.byId, self.positions, self.chapterOf, self.ranges = byId, positions, chapterOf, ranges
end

function Progress:CurrentStep()
	local guide = self.guide
	return guide and self.index and guide.steps[self.index] or nil
end

-- Directive state -------------------------------------------------------------------------------------------------

function Progress:Store(stepId)
	local store = self.stores[stepId]
	if not store then
		store = { d = {} }
		self.stores[stepId] = store
	end
	return store
end

-- The per-directive state tables of a step, as ns.Conditions and the directive functions receive them: [i] belongs to
-- step.directives[i]; sticky[j] belongs to step.sticky[j] and is the same table as [#step.directives + j]. A step's
-- state lasts the session (a step the player returns to keeps it) and is saved while the step is current or has an
-- active sticky directive.
function Progress:State(stepId)
	local view = self.views[stepId]
	if view then
		return view
	end
	local store = self:Store(stepId)
	view = { sticky = {} }
	local step = self.byId[stepId]
	if step then
		local directives = step.directives or EMPTY
		for i, directive in ipairs(directives) do
			view[i] = slot(store.d, directiveKey(directive, "d" .. i))
		end
		for j, directive in ipairs(step.sticky or EMPTY) do
			local state = slot(store.d, directiveKey(directive, "s" .. j))
			view.sticky[j] = state
			view[#directives + j] = state
		end
	end
	self.views[stepId] = view
	return view
end

local function startDirective(directive, state)
	local def = directive.def
	if type(def) == "table" and def.onStart then
		ns.SafeCall(def.onStart, directive.args, ns.Context, state)
	end
end

-- The step becomes current: its directives' onStart run once per state, and its sticky directives become active.
function Progress:StartStep(step)
	local store = self:Store(step.id)
	if not store.started then
		store.started = true
		local view = self:State(step.id)
		for i, directive in ipairs(step.directives or EMPTY) do
			startDirective(directive, view[i])
		end
		for j, directive in ipairs(step.sticky or EMPTY) do
			startDirective(directive, view.sticky[j])
		end
	end
	self:ActivateSticky(step)
end

-- Keeps the saved states to the current step and the steps with active sticky directives.
function Progress:SaveStates()
	local keep = { [self.guide.steps[self.index].id] = true }
	for stepId in pairs(self.record.sticky) do
		if #self:ActiveSticky(stepId) > 0 then
			keep[stepId] = true
		end
	end
	local states = self.record.states
	for stepId in pairs(states) do
		if not keep[stepId] then
			states[stepId] = nil
		end
	end
	for stepId in pairs(keep) do
		states[stepId] = self.stores[stepId]
	end
end

-- Sticky directives -----------------------------------------------------------------------------------------------
-- A sticky directive becomes active when its step becomes current (or is passed by auto-advance) and stays active
-- beside the later steps until it is satisfied once; then it is done for good (PLAN §3.3). Skipping its step dismisses
-- it; going back to its step or jumping to it starts it afresh.

function Progress:StickySatisfied(step, j)
	local directive = step.sticky[j]
	local def = directive and directive.def
	if type(def) ~= "table" or not def.isSatisfied then
		return false
	end
	local ok, satisfied = ns.SafeCall(def.isSatisfied, directive.args, ns.Context, self:State(step.id).sticky[j])
	return ok and satisfied and true or false
end

function Progress:ActivateSticky(step)
	local list = step.sticky or EMPTY
	if #list == 0 or self.record.sticky[step.id] then
		return
	end
	local entry = {}
	for j, directive in ipairs(list) do
		entry[directiveKey(directive, "s" .. j)] = not self:StickySatisfied(step, j)
	end
	self.record.sticky[step.id] = entry
	self.stickyDirty = true
end

-- The step's active sticky directives: { { index = j, directive = step.sticky[j], state = its state }, ... }.
function Progress:ActiveSticky(stepId)
	local active = {}
	local step = self.byId[stepId]
	local entry = self.record and self.record.sticky[stepId]
	if not (step and entry) then
		return active
	end
	for j, directive in ipairs(step.sticky or EMPTY) do
		if entry[directiveKey(directive, "s" .. j)] == true then
			active[#active + 1] = { index = j, directive = directive, state = self:State(stepId).sticky[j] }
		end
	end
	return active
end

function Progress:UpdateSticky()
	for stepId, entry in pairs(self.record.sticky) do
		local step = self.byId[stepId]
		for j, directive in ipairs(step and step.sticky or EMPTY) do
			local key = directiveKey(directive, "s" .. j)
			if entry[key] == true and self:StickySatisfied(step, j) then
				entry[key] = false
				self.stickyDirty = true
				self:Echo(L["Sticky done: %s"], describeDirective(directive))
			end
		end
	end
end

-- The steps before the current one with an active sticky directive, in route order. (The current step's own sticky
-- directives belong to the current step.)
function Progress:Sticky()
	local list = {}
	if not self:CurrentStep() then
		return list
	end
	local positions = self.positions
	for stepId in pairs(self.record.sticky) do
		local position = positions[stepId]
		if position and position < self.index and #self:ActiveSticky(stepId) > 0 then
			list[#list + 1] = self.guide.steps[position]
		end
	end
	table.sort(list, function(a, b)
		return positions[a.id] < positions[b.id]
	end)
	return list
end

-- Completion ------------------------------------------------------------------------------------------------------

-- Whether the step's directives are satisfied now. A step without a completable directive waits for the player's `>`,
-- except one that only starts sticky directives: it is done once they are active.
function Progress:Complete(step)
	if manualOnly(step) then
		return #(step.sticky or EMPTY) > 0
	end
	local conditions = ns.Conditions
	if not (conditions and conditions.IsComplete) then
		return false
	end
	local ok, complete = ns.SafeCall(conditions.IsComplete, conditions, step, ns.Context, self:State(step.id))
	return ok and complete and true or false
end

-- Auto progression passes a step that is skipped, was done before, or is complete now.
function Progress:Passable(step)
	local record = self.record
	return record.skipped[step.id] == true or record.done[step.id] == true or self:Complete(step)
end

-- Manual override (PLAN §3.3) -------------------------------------------------------------------------------------
-- A step the player chose by hand stays current until the player moves again, completes that step, or a quest event
-- completes one of the steps after it that were still open when it was chosen ("unless a quest event proves
-- otherwise"). Holds are not saved: after a reload, auto-skip applies again.

function Progress:Hold(index)
	local steps = self.guide.steps
	local baseline = {}
	for i = index, math.min(#steps, index + HOLD_WINDOW - 1) do
		local passable = self:Passable(steps[i])
		baseline[#baseline + 1] = { id = steps[i].id, passable = passable }
		if not passable then
			break
		end
	end
	self.hold = { id = steps[index].id, baseline = baseline }
end

function Progress:CheckHold()
	local hold, questEvent = self.hold, self.questEvent
	self.questEvent = false
	if not hold then
		return
	end
	if self.guide.steps[self.index].id ~= hold.id then
		self.hold = nil
		return
	end
	for k, entry in ipairs(hold.baseline) do
		if not entry.passable and (k == 1 or questEvent) then
			local step = self.byId[entry.id]
			if step and self:Passable(step) then
				self.hold = nil
				return
			end
		end
	end
end

-- Auto-advance and auto-skip --------------------------------------------------------------------------------------

-- The first step of a dungeon chapter in which every quest step is already complete (PLAN §3.3: such a chapter is
-- skipped silently). A chapter without quest steps never is.
function Progress:DungeonDone(index)
	local chapterIndex = self.chapterOf[index]
	local chapter = chapterIndex and self.guide.chapters and self.guide.chapters[chapterIndex]
	local range = chapterIndex and self.ranges[chapterIndex]
	if not (chapter and chapter.dungeon and range and range.first == index) then
		return false
	end
	local any = false
	for i = range.first, range.last do
		local step = self.guide.steps[i]
		if hasQuestDirective(step) then
			if not self:Complete(step) then
				return false
			end
			any = true
		end
	end
	return any
end

-- Moves the pointer past the current step when it is complete, then past every following step that is already
-- satisfied (auto-skip). Skipped steps are passed without starting them; a held step stops the walk.
function Progress:Advance()
	local steps, record = self.guide.steps, self.record
	for _ = 1, #steps + 1 do
		local step = steps[self.index]
		if self.hold and self.hold.id == step.id then
			return
		end
		if not record.skipped[step.id] then
			if self:DungeonDone(self.index) then
				local range = self.ranges[self.chapterOf[self.index]]
				for i = range.first, range.last do
					if not record.skipped[steps[i].id] then
						record.done[steps[i].id] = true
					end
				end
				self.index = range.last
			else
				self:StartStep(step)
				if not self:Passable(step) then
					return
				end
				record.done[step.id] = true
			end
		end
		if self.index >= #steps then
			return
		end
		self.index = self.index + 1
	end
end

-- Step changes ----------------------------------------------------------------------------------------------------

-- The step's text for chat: ns.Conditions' description lines, else its id.
function Progress:Describe(step)
	local conditions = ns.Conditions
	if conditions and conditions.Describe then
		local ok, lines = ns.SafeCall(conditions.Describe, conditions, step, ns.Context, self:State(step.id))
		if ok and type(lines) == "table" then
			local parts = {}
			for _, line in ipairs(lines) do
				parts[#parts + 1] = lineText(line)
			end
			if #parts > 0 then
				return table.concat(parts, " / ")
			end
		end
	end
	return tostring(step.id)
end

function Progress:ChapterName(index)
	local chapter = self.guide.chapters and self.guide.chapters[self.chapterOf[index]]
	return chapter and chapter.name or "-"
end

-- PLAN §3.3: reaching a dungeon chapter 5+ levels above its maximum brings a one-time offer to skip it.
function Progress:EnterChapter()
	local chapterIndex = self.chapterOf[self.index]
	local range = chapterIndex and self.ranges[chapterIndex]
	local key = range and self.guide.steps[range.first].id
	if key == self.chapterKey then
		return
	end
	self.chapterKey = key
	local chapter = key and self.guide.chapters and self.guide.chapters[chapterIndex]
	if not (chapter and chapter.dungeon) or self.record.offered[key] then
		return
	end
	local levels = chapter.levels or EMPTY
	local maxLevel = levels[2] or levels[1]
	local level = ns.Player and ns.Player.level
	if type(maxLevel) ~= "number" or type(level) ~= "number" or level - maxLevel < DUNGEON_OFFER_LEVELS then
		return
	end
	self.record.offered[key] = true
	ns.Util.Print(
		L["You are %d levels above %s (up to level %d). Type /signpost skip chapter to skip it."],
		level - maxLevel,
		tostring(chapter.name),
		maxLevel
	)
	ns.Events:Fire("DUNGEON_SKIP_OFFER", chapterIndex, chapter)
end

-- Saves the pointer and announces what changed: STEP_CHANGED (and the chat line with debug chat on) when the current
-- step is another one, STICKY_CHANGED when the sticky set changed.
function Progress:Commit(reason)
	local step = self.guide.steps[self.index]
	self.record.current = step.id
	local frontier = self.frontier and self.positions[self.frontier]
	if not frontier or self.index > frontier then
		self.frontier = step.id
	end
	self:SaveStates()
	if self.announced ~= step then
		self.announced = step
		self:Echo(
			L["Step %d/%d (%s) [%s]: %s"],
			self.index,
			#self.guide.steps,
			self:ChapterName(self.index),
			tostring(reason),
			self:Describe(step)
		)
		ns.Events:Fire("STEP_CHANGED", step, self.index, reason)
		if self:CurrentStep() == step then
			self:EnterChapter()
		end
	end
	if self.stickyDirty then
		self.stickyDirty = false
		ns.Events:Fire("STICKY_CHANGED", self:Sticky())
	end
end

-- Evaluation ------------------------------------------------------------------------------------------------------

local function evaluate(self)
	for _ = 1, MAX_PASSES do
		self.again = false
		self:CheckHold()
		self:Advance()
		self:UpdateSticky()
		if not self.again then
			return
		end
	end
end

-- Evaluates at once: releases a hold that a quest event disproved, advances past completed steps, auto-skips the
-- satisfied ones after them and retires satisfied sticky directives. `reason` goes into STEP_CHANGED.
function Progress:EvaluateNow(reason)
	if not self:CurrentStep() then
		return
	end
	if self.busy then
		self.again = true
		return
	end
	self.busy = true
	ns.SafeCall(evaluate, self)
	self.busy = false
	self:Commit(reason or "auto")
end

-- The throttled entry point (CONTEXT_CHANGED): at once when the last evaluation is a second old, otherwise once when
-- the second is over.
function Progress:Evaluate()
	if not self:CurrentStep() then
		return
	end
	local now = GetTime()
	local wait = (self.lastEvaluate or -math.huge) + THROTTLE - now
	if wait <= 0 then
		self.lastEvaluate = now
		self:EvaluateNow("auto")
	elseif not self.pending then
		self.pending = true
		C_Timer.After(wait, function()
			self.pending = false
			self.lastEvaluate = GetTime()
			ns.SafeCall(self.EvaluateNow, self, "auto")
		end)
	end
end

function Progress:OnContextChanged(what)
	if what == "quests" then
		self.questEvent = true
		ns.SafeCall(self.CheckPlacement, self) -- a failure here must not stop the evaluation
	end
	self:Evaluate()
end

-- Manual moves ----------------------------------------------------------------------------------------------------

-- Puts the pointer on `index` after a manual move and evaluates. With "back" and "jump" the player chose that step: it
-- loses its done/skipped marks, starts afresh and is held. "forward" (next, skip) holds only behind the furthest step
-- reached this session, so stepping through steps already passed goes one step per press; from the front, auto-skip
-- applies as usual.
function Progress:Land(index, how)
	local step = self.guide.steps[index]
	local record = self.record
	self.hold = nil
	self.undo = nil
	self.index = index
	local hold = how ~= "forward"
	if hold then
		record.done[step.id] = nil
		record.skipped[step.id] = nil
		record.sticky[step.id] = nil
	else
		local frontier = self.frontier and self.positions[self.frontier]
		hold = frontier ~= nil and index < frontier
	end
	if hold then
		if not record.skipped[step.id] then
			self:StartStep(step)
		end
		self:Hold(index)
	end
	self:EvaluateNow("manual")
end

-- `>`: the current step is done (in the player's word) and the next one becomes current. False at the last step.
function Progress:Next()
	local step = self:CurrentStep()
	if not step then
		return false
	end
	if not self.record.skipped[step.id] then
		self.record.done[step.id] = true
	end
	self.declined = nil
	if self.index >= #self.guide.steps then
		self:Commit("manual")
		return false
	end
	self:Land(self.index + 1, "forward")
	return true
end

-- `<`: the previous step becomes current again; right after "Find my place" it takes the placement back instead (the
-- pointer and the marks as they were). False at the first step.
function Progress:Back()
	if not self:CurrentStep() then
		return false
	end
	if self:UndoPlacement() or self:UndoDecline() then
		return true
	end
	self.declined = nil
	if self.index <= 1 then
		return false
	end
	self:Land(self.index - 1, "back")
	return true
end

-- skip: the current step is marked skipped for this character (its sticky directives are dismissed) and the route goes
-- on. Skipping the step of a profession track that teaches the profession declines it (PLAN §3.8).
function Progress:Skip()
	local step = self:CurrentStep()
	if not step then
		return false
	end
	local record = self.record
	record.skipped[step.id] = true
	record.done[step.id] = nil
	if record.sticky[step.id] then
		record.sticky[step.id] = nil
		self.stickyDirty = true
	end
	local declines = self:TaughtTrack(step)
	self.declined = nil
	if self.index < #self.guide.steps then
		self:Land(self.index + 1, "forward")
	else
		self:Commit("manual")
	end
	if declines then
		self:Decline(declines, step.id)
	end
	return true
end

-- Makes guide.steps[index] current (journal clicks, /signpost step <n>).
function Progress:JumpTo(index)
	index = tonumber(index)
	if not (self:CurrentStep() and index and self.guide.steps[index]) then
		return false
	end
	self.declined = nil
	self:Land(index, "jump")
	return true
end

function Progress:JumpToId(stepId)
	local index = self.positions[stepId]
	return index ~= nil and self:JumpTo(index)
end

function Progress:IsDone(stepId)
	return self.record ~= nil and self.record.done[stepId] == true
end

function Progress:IsSkipped(stepId)
	return self.record ~= nil and self.record.skipped[stepId] == true
end

-- Dungeon chapters ------------------------------------------------------------------------------------------------

-- The current step's chapter: index into guide.chapters, chapter.
function Progress:CurrentChapter()
	local chapterIndex = self:CurrentStep() and self.chapterOf[self.index]
	if chapterIndex then
		return chapterIndex, self.guide.chapters and self.guide.chapters[chapterIndex]
	end
end

function Progress:ChapterSkipped(chapterIndex)
	local range = self:CurrentStep() and self.ranges[chapterIndex]
	if not range then
		return false
	end
	for i = range.first, range.last do
		if not self.record.skipped[self.guide.steps[i].id] then
			return false
		end
	end
	return true
end

-- The Skip toggle of a dungeon chapter (PLAN §3.3): skipping marks every step in it skipped and, when the pointer is
-- in the chapter, moves on past it; un-skipping clears the marks. Returns true, or false and the reason.
function Progress:SetChapterSkipped(chapterIndex, skipped)
	local chapter = self:CurrentStep() and self.guide.chapters and self.guide.chapters[chapterIndex]
	local range = chapter and self.ranges[chapterIndex]
	if not range then
		return false, L["There is no such chapter."]
	end
	if not chapter.dungeon then
		return false, L["Only dungeon chapters can be skipped as a whole."]
	end
	local steps, record = self.guide.steps, self.record
	for i = range.first, range.last do
		local id = steps[i].id
		if skipped then
			record.skipped[id] = true
			record.done[id] = nil
			record.sticky[id] = nil
		else
			record.skipped[id] = nil
		end
	end
	self.stickyDirty = true
	self.undo = nil
	if skipped and self.index >= range.first and self.index <= range.last and range.last < #steps then
		self.declined = nil
		self:Land(range.last + 1, "forward")
	else
		self:EvaluateNow("manual")
	end
	return true
end

-- Profession tracks (PLAN §3.8) -----------------------------------------------------------------------------------

-- The track key when `step` is the first step of its profession track that teaches the profession (.trainprof).
function Progress:TaughtTrack(step)
	local key = step.track
	if not key or not hasDirective(step, "trainprof") then
		return nil
	end
	for _, other in ipairs(self.guide.steps) do
		if other.track == key and hasDirective(other, "trainprof") then
			return other == step and key or nil
		end
	end
end

-- Declines the profession (which re-parses the guide without its track) and remembers how to undo it: `<` right
-- after restores the profession and returns to the skipped step.
function Progress:Decline(key, stepId)
	local professions = ns.Professions
	if not (professions and professions.Decline) then
		return
	end
	self.declined = { key = key, stepId = stepId }
	ns.SafeCall(professions.Decline, professions, key)
	local step = self:CurrentStep()
	if self.declined and step then
		self.declined.afterId = step.id
	end
end

function Progress:UndoDecline()
	local declined, step = self.declined, self:CurrentStep()
	local professions = ns.Professions
	if not (declined and step and declined.afterId == step.id and professions and professions.Restore) then
		return false
	end
	self.declined = nil
	ns.SafeCall(professions.Restore, professions, declined.key)
	local index = self.positions[declined.stepId]
	if not index then
		return false
	end
	self:Land(index, "back")
	return true
end

-- Placement (docs/ENGINE.md "Engine/Placement.lua") -------------------------------------------------------------------
-- Where in the guide the character is, from its level and the quests it has done or has in its log: ns.Placement
-- works it out, this puts the pointer and the marks there. It runs by itself the first time a guide runs for a
-- character with no progress in it, when the saved step is not in the guide any more or the record is for another text
-- of the guide, and once more when the quest history turns up late; the player runs it with the Journal's "Find my
-- place" and /signpost place.

-- fn(questID) -> boolean from a Context query; a stand-in without that query knows nothing.
local function asker(context, name)
	local fn = type(context) == "table" and context[name]
	return function(questID)
		if type(fn) ~= "function" then
			return false
		end
		local ok, answer = ns.SafeCall(fn, context, questID)
		return ok and answer and true or false
	end
end

local function liveLevel()
	local context = ns.Context
	if type(context) == "table" and type(context.Level) == "function" then
		local ok, value = ns.SafeCall(context.Level, context)
		return ok and tonumber(value) or nil
	end
end

-- The player's state as ns.Placement takes it: the level, and which quests are done, in the log, and ready to hand in.
local function liveSnapshot()
	local context = ns.Context
	return {
		level = liveLevel(),
		done = asker(context, "QuestCompleted"),
		active = asker(context, "QuestInLog"),
		ready = asker(context, "QuestReady"),
	}
end

-- Whether the quest history can be read: the completed-quest list has loaded and holds something. An empty list is a
-- character with nothing done or a list the client has not filled yet, so above the first levels a first placement
-- waits a few seconds for it. A quest in the log does not say that the list has loaded (the two are separate reads, and
-- the log is there first): a placement made on the log alone puts the quests the character has done behind it as
-- skipped, and nothing would correct that when the list arrives, so the wait goes on, and a placement made without the
-- list is made once more when it comes (Settle, CheckPlacement).
-- VERIFY(beta): when C_QuestLog.GetAllCompletedQuestIDs is filled (docs/FOREVER-API-NOTES.md, Open probes).
local function historyReady(level)
	local context, placement = ns.Context, ns.Placement
	if type(context) ~= "table" or type(context.QuestLog) ~= "function" or not placement then
		return true -- a stand-in without a history: there is nothing to wait for
	end
	if (level or 0) <= placement.NO_EVIDENCE_LEVEL then
		return true
	end
	ns.SafeCall(context.QuestLog, context) -- this also loads the completed-quest list
	return context.completedEmpty == false
end

-- Whether the record says the character has never been in the guide: no step done or skipped, no placement, and at most
-- the first step as its place (what a placement that was still waiting for the quest history left behind).
function Progress:IsFresh()
	local record, first = self.record, self.guide.steps[1]
	if record.placed ~= nil or next(record.done) ~= nil or next(record.skipped) ~= nil then
		return false
	end
	return record.current == nil or (first ~= nil and record.current == first.id)
end

-- Whether the record was made for another text of the guide, or for one nobody can say (it has no fingerprint: a
-- record from before fingerprints, or one that was never stamped). A step id is a position in the guide's text, so
-- after the text changed every id can mean another step, and nothing in the record can be trusted. A guide without a
-- fingerprint (a parser that does not give one) cannot be told apart from itself: its records are trusted as before.
function Progress:IsOutdated(guide)
	return guide.fingerprint ~= nil and self.record.fingerprint ~= guide.fingerprint
end

-- Drops everything in the record that is keyed by a step id (the marks, the stickies, the saved states, the offers, the
-- place itself): for another text of the guide it describes other steps. The character is then placed from its quest
-- history instead (SetGuide).
function Progress:Forget()
	local record = self.record
	record.current, record.placed, record.fingerprint = nil, nil, nil
	record.done, record.skipped, record.sticky, record.states, record.offered = {}, {}, {}, {}, {}
end

-- Puts the marks and the pointer where `result` (ns.Placement:Find) says. A step before the pointer is done when its
-- quests are (or it holds none) and skipped when they are not; the pointer's step and every step after it are clear. A
-- skip the player made by hand on a step with no quest of its own stays. The flags are set here and not through
-- Progress:Skip, which would decline a profession; the sticky directives of a step skipped are dismissed, those of a
-- step marked done are started (below) as the walk through it would have.
-- `prune` also drops marks of steps the guide does not have (ids from an older install).
function Progress:ApplyPlacement(result, prune)
	local record, pointer = self.record, result.index
	if prune then
		for _, marks in ipairs({ record.done, record.skipped }) do
			for id in pairs(marks) do
				if not self.positions[id] then
					marks[id] = nil
				end
			end
		end
	end
	for i, step in ipairs(self.guide.steps) do
		local id, label = step.id, result.labels[i]
		if i >= pointer then
			record.done[id], record.skipped[id] = nil, nil
		elseif label == "open" or (label == "neutral" and record.skipped[id]) then
			record.skipped[id], record.done[id] = true, nil
			if record.sticky[id] then
				record.sticky[id] = nil
				self.stickyDirty = true
			end
		else
			record.done[id], record.skipped[id] = true, nil
		end
	end
	-- A character that walked the route has the goals of its passed steps going (Advance starts every step it passes: a
	-- skill to reach, a level to get to), those not satisfied yet. The steps a placement passes were not walked, so the
	-- ones it marks done are started here, or the same character placed at the same step would have no goal at all.
	for i = 1, pointer - 1 do
		local step = self.guide.steps[i]
		if #(step.sticky or EMPTY) > 0 and record.done[step.id] then
			self:StartStep(step)
		end
	end
	self.index, self.hold, self.declined = pointer, nil, nil
end

-- The chat lines of a placement: where (the step the engine settled on), why in numbers, how to put it right. A
-- character with nothing to go on and no reason to expect more hears nothing.
function Progress:Announce(result, reason, outdated)
	local say = ns.Util.Print
	local n, index = #self.guide.steps, self.index or result.index
	if reason == "lost" and outdated then
		say(
			L["Your saved place may not match this version of the guide, so it is found again from your quest history."]
		)
	elseif reason == "lost" then
		say(L["The guide was updated and your saved place is not in it any more."])
	elseif reason == "refine" then
		say(L["Your quest history has loaded: placing you again."])
	end
	if result.mode == "none" then
		if reason == "manual" or reason == "lost" then
			say(
				L["Your place: step 1. None of this guide's quests are done and you are level %d: nothing to go on yet."],
				result.level or 1
			)
		end
		return
	elseif result.mode == "end" then
		if result.top and result.level and result.level > result.top then
			say(
				L["This guide ends at level %d and you are level %d: your place is its last step, %d/%d."],
				math.floor(result.top),
				result.level,
				n,
				n
			)
		else
			say(L["All of this guide's quests are done: your place is its last step, %d/%d."], n, n)
		end
	elseif result.mode == "level" then
		say(
			L["Your place: step %d/%d (%s). None of this guide's quests are done yet, so this is a guess from your level (%d)."],
			index,
			n,
			self:ChapterName(index),
			result.level
		)
	elseif result.level then
		say(
			L["Your place: step %d/%d (%s). %d of this guide's %d quests are done, %d are in your quest log, "]
				.. L["and you are level %d."],
			index,
			n,
			self:ChapterName(index),
			result.done,
			result.total,
			result.active,
			result.level
		)
	else
		say(
			L["Your place: step %d/%d (%s). %d of this guide's %d quests are done and %d are in your quest log."],
			index,
			n,
			self:ChapterName(index),
			result.done,
			result.total,
			result.active
		)
	end
	local hint = L["Wrong? Click a step in the Journal, or type /signpost place to try again."]
	if result.confidence == "low" then
		hint =
			L["Not sure about this one: click the step you are at in the Journal, or type /signpost place to try again."]
	end
	if result.skipped > 0 then
		hint = string.format(L["%d earlier steps you have not done are marked skipped."], result.skipped) .. " " .. hint
	end
	say(hint)
end

-- Places the character: the pointer on the step its level and quests say, the marks before it set (ApplyPlacement),
-- one record.placed so that it never happens by itself again, GUIDE_PLACED(result, reason), the evaluation (the
-- engine passes what is done already) and then Settle. opts.reason is "first" (a character new to the guide), "lost"
-- (its saved step is not in the guide, or the record is for another text of it: opts.outdated, which only changes what
-- the chat line says), "refine" (the quest history came late) or "manual" (the player asked; the default: `<` right
-- afterwards takes it back); opts.evaluate = false leaves the evaluation, and Settle, to the caller (SetGuide);
-- opts.quiet prints nothing. Returns the result, or nil without a guide.
function Progress:Place(opts)
	opts = opts or {}
	local guide, record, placement = self.guide, self.record, ns.Placement
	if not (guide and record and placement and #guide.steps > 0) then
		return nil
	end
	local reason = opts.reason or "manual"
	local snapshot = liveSnapshot()
	local ok, result = ns.SafeCall(placement.Find, placement, guide, snapshot)
	if not (ok and result) then
		return nil
	end
	local before, undo = self:CurrentStep(), nil
	if reason == "manual" and before then
		undo = {
			stepId = before.id,
			frontier = self.frontier,
			done = ns.Util.CopyTable(record.done),
			skipped = ns.Util.CopyTable(record.skipped),
			sticky = ns.Util.CopyTable(record.sticky),
		}
	end
	self.placing, self.refining, self.undo = nil, nil, nil
	self:ApplyPlacement(result, reason == "lost")
	local step = guide.steps[result.index]
	record.placed = { step = step.id, index = result.index, reason = reason, mode = result.mode, time = time() }
	self.settle = {
		result = result,
		reason = reason,
		outdated = opts.outdated,
		quiet = opts.quiet,
		undo = undo,
		-- placed before the quest history was there: look again when it turns up, if the player has not moved on
		refine = (reason == "first" or reason == "lost") and not historyReady(snapshot.level),
	}
	ns.Events:Fire("GUIDE_PLACED", result, reason)
	if opts.evaluate ~= false then
		self:EvaluateNow("place")
		self:Settle()
	end
	return result
end

-- What follows a placement once the engine has taken the pointer past the steps that are done already: the chat lines
-- (they name the step the player sees), the undo for `<`, the second look when the quest history was missing.
function Progress:Settle()
	local pending, step = self.settle, self:CurrentStep()
	self.settle = nil
	if not (pending and step) then
		return
	end
	if not pending.quiet then
		self:Announce(pending.result, pending.reason, pending.outdated)
	end
	if pending.undo then
		pending.undo.afterId = step.id
		self.undo = pending.undo
	end
	if pending.refine then
		self.refining = { id = self.guide.id, step = step.id }
	end
end

-- `<` right after a manual placement: the pointer, the marks and the furthest step as they were before it. It is there
-- while the pointer is on the step the placement ended on; any move by hand drops it (Land, SetChapterSkipped), and the
-- engine moving the pointer on by itself leaves it on a step that is not that one.
function Progress:UndoPlacement()
	local undo, step = self.undo, self:CurrentStep()
	if not (undo and step and undo.afterId == step.id) then
		return false
	end
	local index = self.positions[undo.stepId]
	if not index then
		self.undo = nil
		return false
	end
	local record = self.record
	record.done, record.skipped, record.sticky = undo.done, undo.skipped, undo.sticky
	self.frontier = undo.frontier
	self.stickyDirty = true
	self:Land(index, "back")
	return true
end

-- First use of a guide (or a lost place): place now when the quest history is there, else wait for it a few seconds.
-- `outdated` says that the record was for another text of the guide (only the chat line differs).
function Progress:BeginPlacement(reason, outdated)
	if historyReady(liveLevel()) then
		self:Place({ reason = reason, outdated = outdated, evaluate = false })
		return
	end
	local token = { id = self.guide.id, reason = reason, outdated = outdated }
	self.placing = token
	C_Timer.After(PLACE_WAIT, function()
		ns.SafeCall(Progress.OnPlaceTimer, Progress, token)
	end)
end

-- The wait is over and the quest history has not come: go by what there is (the level).
function Progress:OnPlaceTimer(token)
	if self.placing == token and self.guide and self.guide.id == token.id then
		self:Place({ reason = token.reason, outdated = token.outdated })
	end
end

-- CONTEXT_CHANGED("quests"): the quest history may have arrived. A placement that was waiting for it goes ahead; one
-- made without it is made once more, if the player has not moved on from where it put them.
function Progress:CheckPlacement()
	local guide, token, refining = self.guide, self.placing, self.refining
	if not (guide and self.record) then
		return
	end
	if token and token.id == guide.id then
		if historyReady(liveLevel()) then
			self:Place({ reason = token.reason, outdated = token.outdated })
		end
	elseif refining and refining.id == guide.id then
		local step = self:CurrentStep()
		if not (step and step.id == refining.step) then
			self.refining = nil
		elseif historyReady(liveLevel()) then
			self:Place({ reason = "refine" })
		end
	end
end

-- /signpost reset progress: forgets this character's progress in the guide and places it again, as on first use.
function Progress:Reset()
	local guide = self.guide
	if not guide then
		return false
	end
	local char = type(ns.char) == "table" and ns.char or self.unsaved
	if type(char) == "table" and type(char.progress) == "table" then
		char.progress[guide.id] = nil
	end
	self.resetAsked = nil
	self.guide = nil -- SetGuide then takes the guide for one that was just chosen
	self:SetGuide(guide)
	return true
end

-- Guide loading ---------------------------------------------------------------------------------------------------

-- The index the pointer resumes at: the saved step; after a re-parse that dropped it, the next step of the previous
-- parse that is still there (else the one before it); otherwise the step after the furthest done or skipped one. The
-- second result is true when the record has progress that matches nothing in this guide (an install changed the step
-- ids): the caller then places the character instead of taking the first step.
function Progress:Resume(previous, previousIndex)
	local steps, record, positions = self.guide.steps, self.record, self.positions
	if #steps == 0 then
		return nil
	end
	if record.current and positions[record.current] then
		return positions[record.current]
	end
	if previous and previousIndex then
		for i = previousIndex, #previous.steps do
			if positions[previous.steps[i].id] then
				return positions[previous.steps[i].id]
			end
		end
		for i = previousIndex - 1, 1, -1 do
			if positions[previous.steps[i].id] then
				return positions[previous.steps[i].id]
			end
		end
	end
	local last = 0
	for i, step in ipairs(steps) do
		if record.done[step.id] or record.skipped[step.id] then
			last = i
		end
	end
	local lost = last == 0 and (record.current ~= nil or next(record.done) ~= nil or next(record.skipped) ~= nil)
	return math.min(last + 1, #steps), lost
end

-- Steps that a re-parse inserted behind the pointer (the track of a profession just learned) are never walked: their
-- sticky directives start right away.
function Progress:StartInserted(previous)
	local known = {}
	for _, step in ipairs(previous.steps) do
		known[step.id] = true
	end
	for i = 1, self.index - 1 do
		local step = self.guide.steps[i]
		if not known[step.id] and #(step.sticky or EMPTY) > 0 then
			self:StartStep(step)
		end
	end
end

-- Makes `guide` (a parsed guide, docs/ENGINE.md) the active one and fires GUIDE_LOADED, then STEP_CHANGED("load")
-- after auto-skipping what is already done. The same guide parsed again (a profession plan change) keeps the current
-- step by id and the session's manual override.
function Progress:SetGuide(guide)
	local previous, previousIndex = self.guide, self.index
	self.guide, self.views, self.announced = guide, {}, nil
	if not guide then
		self.index, self.record, self.hold, self.declined = nil, nil, nil, nil
		self.placing, self.refining, self.undo, self.settle = nil, nil, nil, nil
		self:Index({ steps = {} })
		return
	end
	guide.steps = guide.steps or {}
	local sameGuide = previous ~= nil and previous.id == guide.id
	self.record = self:Record(guide.id)
	self:Index(guide)
	local fresh, outdated = false, false
	if not sameGuide then
		-- A record made for another text of the guide (or by a version that did not say) is not trusted: step ids are
		-- positions in the text, so the same id can be another step now. It is dropped and the character is placed from
		-- its quest history, as for a lost place. A new record is for this text from now on.
		fresh = self:IsFresh()
		outdated = not fresh and self:IsOutdated(guide)
		if outdated then
			self:Forget()
		end
		if guide.fingerprint ~= nil then
			self.record.fingerprint = guide.fingerprint
		end
		previous, previousIndex = nil, nil
		self.stores = {}
		for stepId, store in pairs(self.record.states) do
			if type(store) == "table" then
				store.d = type(store.d) == "table" and store.d or {}
				self.stores[stepId] = store
			end
		end
		self.hold, self.frontier, self.declined, self.chapterKey = nil, nil, nil, nil
		self.placing, self.refining, self.undo, self.settle = nil, nil, nil, nil
	end
	local lost
	self.index, lost = self:Resume(previous, previousIndex)
	if previous and self.index then
		self:StartInserted(previous)
	end
	-- A character new to this guide, or whose saved place is not in it (or is for another text of it), starts where its
	-- level and quests say. The same guide parsed again (a profession plan change) never does.
	if self.index and (fresh or lost or outdated) then
		-- the guide loads whatever happens here
		ns.SafeCall(self.BeginPlacement, self, (lost or outdated) and "lost" or "first", outdated)
	end
	self.stickyDirty = true
	self:Echo(
		L["Guide %s: %d steps, %d parse errors."],
		tostring(guide.name or guide.id),
		#guide.steps,
		#(guide.errors or EMPTY)
	)
	ns.Events:Fire("GUIDE_LOADED", guide)
	-- VERIFY(beta): whether the completed-quest list is already filled at PLAYER_LOGIN (open probe). If not, a character
	-- new to the guide is placed once the list is there (BeginPlacement), and for any other the auto-skip finds nothing
	-- and the first CONTEXT_CHANGED("quests") does it, as an "auto" step change.
	if self.guide == guide then
		self:EvaluateNow("load")
		ns.SafeCall(self.Settle, self)
	end
end

function Progress:Guide()
	return self.guide
end

-- The current step and its index into guide.steps; nothing without a guide.
function Progress:Current()
	local step = self:CurrentStep()
	if step then
		return step, self.index
	end
end

function Progress:Parse(def, plan)
	local headers = ns.Parser:Headers(def) or EMPTY
	local professions = ns.Professions
	if plan == nil and professions and professions.Plan then
		plan = professions:Plan(headers.professions)
	end
	return ns.Parser:ParseGuide(def, { player = ns.Player, plan = plan })
end

-- The engine's start-up (PLAYER_LOGIN, after ns.Player): selected guide -> headers -> profession plan -> parse ->
-- SetGuide. Also what to call after the player picks another guide.
function Progress:Start()
	local guides = ns.Guides
	if not (guides and guides.Selected and ns.Parser) then
		return
	end
	local ok, def = ns.SafeCall(guides.Selected, guides)
	if not (ok and def) then
		self:SetGuide(nil)
		self:Echo(L["No guide fits this character."])
		return
	end
	self.starting = true
	local parsed, guide = ns.SafeCall(self.Parse, self, def)
	self.starting = false
	if parsed and guide then
		self:SetGuide(guide)
	end
end

-- PROFESSION_PLAN_CHANGED: parse the active guide again with the new plan (step ids are stable across plans).
function Progress:OnPlanChanged(plan)
	if self.starting or not self.guide then
		return
	end
	local def = self.guide.def
	if not def and ns.Guides and ns.Guides.Selected then
		def = ns.Guides:Selected()
	end
	if not def then
		return
	end
	local ok, guide = ns.SafeCall(self.Parse, self, def, plan)
	if ok and guide then
		self:SetGuide(guide)
	end
end

ns.Events:Register("PLAYER_LOGIN", function()
	Progress:Start()
end)

ns.Events:RegisterMessage("CONTEXT_CHANGED", function(_, what)
	Progress:OnContextChanged(what)
end)

ns.Events:RegisterMessage("PROFESSION_PLAN_CHANGED", function(_, plan)
	Progress:OnPlanChanged(plan)
end)

-- ns.Guides:Select changed the character's guide: start it as at login.
ns.Events:RegisterMessage("GUIDE_SELECTED", function()
	Progress:Start()
end)

-- Slash commands --------------------------------------------------------------------------------------------------

local function printCurrent()
	local step, index = Progress:Current()
	if step then
		ns.Util.Print(
			L["Step %d/%d (%s, %s): %s"],
			index,
			#Progress.guide.steps,
			Progress:ChapterName(index),
			tostring(step.id),
			Progress:Describe(step)
		)
	end
end

-- After a move the chat shows the new step, unless debug chat already did.
local function moved()
	if not chatEnabled() then
		printCurrent()
	end
end

local function needGuide()
	if Progress:CurrentStep() then
		return true
	end
	ns.Util.Print(L["No guide is loaded for this character."])
	return false
end

ns.Slash:Register("next", function()
	if not needGuide() then
		return
	end
	if Progress:Next() then
		moved()
	else
		ns.Util.Print(L["This is the last step."])
	end
end, L["mark the current step done and go to the next one"])

ns.Slash:Register("back", function()
	if not needGuide() then
		return
	end
	if Progress:Back() then
		moved()
	else
		ns.Util.Print(L["This is the first step."])
	end
end, L["go back to the previous step"])

ns.Slash:Register("skip", function(args)
	if not needGuide() then
		return
	end
	if args:lower() == "chapter" then
		local ok, problem = Progress:SetChapterSkipped((Progress:CurrentChapter()), true)
		if not ok then
			ns.Util.Print(problem)
			return
		end
	else
		Progress:Skip()
	end
	moved()
end, L["skip the current step ('skip chapter' skips the current dungeon chapter)"])

ns.Slash:Register("step", function(args)
	if not needGuide() then
		return
	end
	if args == "" then
		printCurrent()
		return
	end
	local index = tonumber(args)
	local ok
	if index then
		ok = Progress:JumpTo(index)
	else
		ok = Progress:JumpToId(args)
	end
	if ok then
		moved()
	else
		ns.Util.Print(L["There is no step '%s' in this guide."], args)
	end
end, L["show the current step, or go to step <number> or <step id>"])

ns.Slash:Register("place", function()
	if not needGuide() then
		return
	end
	Progress:Place({ reason = "manual" })
end, L["move to the step your level and your quests say you are at (the Journal's Find my place); < takes it back"])

-- Typed twice, RESET_CONFIRM seconds apart at most: it throws the character's place in the guide away.
ns.Slash:Register("reset progress", function()
	if not needGuide() then
		return
	end
	local guide, now = Progress.guide, GetTime()
	local name = tostring(guide.name or guide.id)
	local asked = Progress.resetAsked
	if not (asked and asked.id == guide.id and now - asked.time <= RESET_CONFIRM) then
		Progress.resetAsked = { id = guide.id, time = now }
		ns.Util.Print(
			L["This forgets your progress in %s (every step marked done or skipped, and your place) and places you again "]
				.. L["from your quest history. To do it, type /signpost reset progress again within %d seconds."],
			name,
			RESET_CONFIRM
		)
		return
	end
	ns.Util.Print(L["Your progress in %s was cleared."], name)
	Progress:Reset()
end, L["forget this guide's progress and place the character again (type it twice; 'reset' alone is the step frame's)"])
